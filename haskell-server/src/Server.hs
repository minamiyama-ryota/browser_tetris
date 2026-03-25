{-# LANGUAGE OverloadedStrings #-}
module Server (runServer) where

import Protocol
import System.Environment (lookupEnv)
import Auth (verifyJwtFromEnv)
import Data.Time.Clock.POSIX (getPOSIXTime)
import qualified Data.ByteArray as BA
import Data.ByteArray.Encoding (convertFromBase, Base(Base64URLUnpadded))
import Crypto.MAC.HMAC (HMAC, hmac)
import Crypto.Hash.Algorithms (SHA256)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BC8
import qualified Data.ByteString.Lazy as LBS
import Data.Aeson (eitherDecode, Value(..), Object)
import Data.Aeson.Types (parseMaybe, withObject, (.:))
import Data.Maybe (fromMaybe)
import qualified Network.WebSockets as WS
import Control.Concurrent.STM
import Control.Concurrent (forkIO, threadDelay)
import qualified Data.ByteString.Char8 as BC
import Control.Monad (forever, void)
import Control.Exception (SomeException, try, fromException)
import Data.Time.Clock (getCurrentTime)
import System.Timeout (timeout)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (encode, decode)
import qualified Data.ByteString.Lazy.Char8 as BL8
import qualified Data.ByteString as B
import Data.Text.Encoding (decodeUtf8)
import qualified Data.Text.Encoding as TE

-- 最小の待機キュー + ペアリングサーバ

type Client = (Int, WS.Connection, Text, String)

-- Top-level timestamped logger
logT :: String -> IO ()
logT msg = do
  t <- getCurrentTime
  putStrLn $ show t ++ " - " ++ msg

-- Configuration: control requeue behavior when a client closes
requeueOnClientClose :: Bool
requeueOnClientClose = True

-- Close codes for which we should NOT requeue the opponent (example)
noRequeueOnCloseCodes :: [Int]
noRequeueOnCloseCodes = []

runServer :: IO ()
runServer = do
  waitingVar <- newTVarIO Nothing -- Maybe Client
  nextIdVar <- newTVarIO (1 :: Int)
  putStrLn "Starting pairing WebSocket server on 0.0.0.0:8000"
  -- bind to 0.0.0.0 so connections from other interfaces (WSL2/VM) are accepted
  WS.runServer "0.0.0.0" 8000 (application waitingVar nextIdVar)

application :: TVar (Maybe Client) -> TVar Int -> WS.PendingConnection -> IO ()
application waitingVar nextIdVar pending = do
  -- Log pending request info (host/path/headers) before accept for richer context
  let pendingInfo = show (WS.pendingRequest pending)
  logT $ "incoming pending request: " ++ pendingInfo
  -- Accept may throw; catch and log to help diagnose ConnectionClosed / RST cases
  eConn <- try (WS.acceptRequest pending) :: IO (Either SomeException WS.Connection)
  case eConn of
    Left ex -> putStrLn $ "acceptRequest failed: " ++ show (ex :: SomeException)
    Right conn -> do
      logT "acceptRequest succeeded"
      -- Require authentication token as the first message after accept
      -- Verify token using environment-configured secrets (JWT_SECRETS or JWT_SECRET)
      -- The helper will load secrets and select by `kid` if present.
      do
          -- wait for auth message with timeout (5s)
          mAuth <- timeout 5000000 (WS.receiveData conn :: IO Text)
          case mAuth of
            Nothing -> do
              logT "auth timeout; closing connection"
              _ <- try (WS.sendClose conn (T.pack "auth timeout")) :: IO (Either SomeException ())
              return ()
            Just txt -> do
              -- parse client message and expect CAuth
              case decode (LBS.fromStrict (TE.encodeUtf8 txt)) :: Maybe ClientMessage of
                Just (CAuth token) -> do
                  -- Debug: log the raw token received for troubleshooting signature mismatches
                  logT $ "received auth token: " ++ T.unpack token
                  vr <- verifyJwtFromEnv token
                  case vr of
                    Left err -> do
                      logT $ "auth failed: " ++ err
                      _ <- try (WS.sendClose conn (T.pack "auth failed")) :: IO (Either SomeException ())
                      return ()
                    Right _payload -> do
                      logT "auth succeeded"
                      -- continue with connection handling
                      WS.withPingThread conn 30 (return ()) $ do
                        -- generate a simple incremental client id
                        cid <- atomically $ do
                          nid <- readTVar nextIdVar
                          writeTVar nextIdVar (nid + 1)
                          return nid
                        let clientName = T.pack ("player" ++ show cid)
                        logT $ "Client connected: " ++ show cid ++ " peer=" ++ pendingInfo
                        -- Enqueue client for pairing. joinQueue returns immediately for the first
                        -- client (waiting for opponent). We must keep this handler alive so the
                        -- connection remains open; otherwise the server thread returns and the
                        -- connection is closed (observed as immediate FIN/RST). Block here until
                        -- the connection is closed to maintain the session.
                        joinQueue waitingVar (cid, conn, clientName, pendingInfo)
                        logT $ "connection handler entering idle loop for client " ++ show cid
                        -- Do not consume application messages here; relayLoop handles message
                        -- IO. Keep this handler alive to maintain the connection while relay
                        -- threads run. This avoids competing readers on the same connection.
                        forever $ threadDelay 1000000
                        logT $ "withPingThread body finished for client " ++ show cid
                _ -> do
                  logT "first message was not auth; closing"
                  _ <- try (WS.sendClose conn (T.pack "auth required")) :: IO (Either SomeException ())
                  return ()
      -- end Right conn

joinQueue :: TVar (Maybe Client) -> Client -> IO ()
joinQueue waitingVar c = do
  mbOther <- atomically $ do
    w <- readTVar waitingVar
    case w of
      Nothing -> writeTVar waitingVar (Just c) >> return Nothing
      Just other -> writeTVar waitingVar Nothing >> return (Just other)
  case mbOther of
    Nothing -> putStrLn "waiting for opponent"
    Just other -> do
      putStrLn "pairing clients"
      void $ forkIO $ handlePair waitingVar other c

handlePair :: TVar (Maybe Client) -> Client -> Client -> IO ()
handlePair waitingVar (id1, conn1, name1, peer1) (id2, conn2, name2, peer2) = do
  let msgStart1 = SMatchStart { sOpponent = name2 }
  let msgStart2 = SMatchStart { sOpponent = name1 }
  -- Increased delay and probe messages to debug early client disconnects
  threadDelay 500000 -- 500ms
  logT $ "sending probe to " ++ show id1 ++ " and " ++ show id2
  okProbe1 <- safeSend conn1 (BC.pack "__probe__")
  okProbe2 <- safeSend conn2 (BC.pack "__probe__")
  logT $ "probe results: " ++ show okProbe1 ++ ", " ++ show okProbe2
  -- If probe shows one side dead, requeue the alive side and close the dead one.
  case (okProbe1, okProbe2) of
    (False, False) -> do
      putStrLn "both probes failed; closing both connections"
      safeClose conn1
      safeClose conn2
    (False, True) -> do
      putStrLn $ "client " ++ show id1 ++ " appears dead; requeueing " ++ show id2 ++ " peer=" ++ peer2
      atomically $ writeTVar waitingVar (Just (id2, conn2, name2, peer2))
      safeClose conn1
    (True, False) -> do
      putStrLn $ "client " ++ show id2 ++ " appears dead; requeueing " ++ show id1 ++ " peer=" ++ peer1
      atomically $ writeTVar waitingVar (Just (id1, conn1, name1, peer1))
      safeClose conn2
    (True, True) -> do
      logT $ "sending start to " ++ show id1 ++ " and " ++ show id2
      ok1 <- safeSend conn1 (LBS.toStrict $ encode msgStart1)
      ok2 <- safeSend conn2 (LBS.toStrict $ encode msgStart2)
      case (ok1, ok2) of
        (False, False) -> do
          putStrLn "failed to send start to both; closing both"
          safeClose conn1
          safeClose conn2
        (False, True) -> do
          putStrLn $ "failed to send start to " ++ show id1 ++ ", requeueing " ++ show id2 ++ " peer=" ++ peer2
          atomically $ writeTVar waitingVar (Just (id2, conn2, name2, peer2))
          safeClose conn1
        (True, False) -> do
          putStrLn $ "failed to send start to " ++ show id2 ++ ", requeueing " ++ show id1 ++ " peer=" ++ peer1
          atomically $ writeTVar waitingVar (Just (id1, conn1, name1, peer1))
          safeClose conn2
        (True, True) -> do
          -- Wait for ACKs from both clients before starting relay
          logT "waiting for match_ack from both clients"
          ack1 <- waitForAck conn1 5000000
          ack2 <- waitForAck conn2 5000000
          logT $ "ack results: " ++ show ack1 ++ ", " ++ show ack2
          case (ack1, ack2) of
            (False, False) -> do
              logT "neither client acked; closing both"
              safeClose conn1
              safeClose conn2
            (False, True) -> do
              logT $ "client " ++ show id1 ++ " failed to ack; requeueing " ++ show id2 ++ " peer=" ++ peer2
              atomically $ writeTVar waitingVar (Just (id2, conn2, name2, peer2))
              safeClose conn1
            (True, False) -> do
              logT $ "client " ++ show id2 ++ " failed to ack; requeueing " ++ show id1 ++ " peer=" ++ peer1
              atomically $ writeTVar waitingVar (Just (id1, conn1, name1, peer1))
              safeClose conn2
            (True, True) -> do
                  logT "both acked; starting relay loops"
                  void $ forkIO $ relayLoop waitingVar (id1, conn1, name1, peer1) (id2, conn2, name2, peer2)
                  void $ forkIO $ relayLoop waitingVar (id2, conn2, name2, peer2) (id1, conn1, name1, peer1)


-- Safe send helper: returns False on exception
safeSend :: WS.Connection -> B.ByteString -> IO Bool
safeSend conn bs = do
  -- convert strict ByteString (UTF-8) to Text and send
  let txt = decodeUtf8 bs
  res <- try (WS.sendTextData conn txt >> return True) :: IO (Either SomeException Bool)
  case res of
    Left e -> do
      t <- getCurrentTime
      putStrLn $ show t ++ " - safeSend failed: " ++ show e
      return False
    Right v -> return v
safeClose :: WS.Connection -> IO ()
safeClose conn = do
  t <- getCurrentTime
  putStrLn $ show t ++ " - safeClose: sending server closing"
  _ <- try (WS.sendClose conn (T.pack "server closing")) :: IO (Either SomeException ())
  return ()

relayLoop :: TVar (Maybe Client) -> Client -> Client -> IO ()
relayLoop waitingVar (idFrom, from, nameFrom, peerFrom) (idTo, to, nameTo, peerTo) = do
  res <- try (forever $ do
      msg <- WS.receiveData from :: IO Text
      t <- getCurrentTime
      putStrLn (show t ++ " - recv from " ++ peerFrom ++ " (" ++ show idFrom ++ "): " ++ T.unpack msg)
      -- try parse client message
      case decode (LBS.fromStrict (TE.encodeUtf8 msg)) :: Maybe ClientMessage of
        Just (CInput action) -> do
          let om = SOpponentInput { sAction = action }
          _ <- safeSend to (LBS.toStrict $ encode om)
          return ()
        _ -> do
          _ <- safeSend to (LBS.toStrict $ encode (SError "unknown or unhandled message"))
          return ()
    ) :: IO (Either SomeException ())
  case res of
    Left e -> do
      -- If exception is a WebSocket ConnectionException, extract close code/reason
      let mConnEx = fromException e :: Maybe WS.ConnectionException
      case mConnEx of
        Just (WS.CloseRequest code reason) -> do
          logT $ "relayLoop CloseRequest for " ++ show idFrom ++ " peer=" ++ peerFrom ++ ": code=" ++ show code ++ " reason=" ++ show reason
          -- notify opponent that their opponent left
          _ <- safeSend to (LBS.toStrict $ encode SOpponentLeft)
          -- decide requeue based on policy and close code
          if not requeueOnClientClose || (fromIntegral code `elem` noRequeueOnCloseCodes) then do
            logT $ "not requeueing opponent " ++ show idTo ++ " peer=" ++ peerTo ++ " due to policy/close code"
          else do
            probeOk <- safeSend to (BC.pack "__probe__")
            if probeOk then do
              logT $ "requeueing client " ++ show idTo ++ " peer=" ++ peerTo
              atomically $ writeTVar waitingVar (Just (idTo, to, nameTo, peerTo))
            else logT $ "client " ++ show idTo ++ " peer=" ++ peerTo ++ " also dead; closing."
        _ -> do
          logT $ "relayLoop exited for " ++ show idFrom ++ " peer=" ++ peerFrom ++ ": " ++ show e
          -- best-effort notify opponent
          _ <- safeSend to (LBS.toStrict $ encode SOpponentLeft)
          probeOk <- safeSend to (BC.pack "__probe__")
          if probeOk then do
            logT $ "requeueing client " ++ show idTo ++ " peer=" ++ peerTo
            atomically $ writeTVar waitingVar (Just (idTo, to, nameTo, peerTo))
          else logT $ "client " ++ show idTo ++ " peer=" ++ peerTo ++ " also dead; closing."
      safeClose from
    Right _ -> return ()

-- Wait for a match_ack from the client within the given microsecond timeout
waitForAck :: WS.Connection -> Int -> IO Bool
waitForAck conn usec = do
  mres <- timeout usec (WS.receiveData conn :: IO Text)
  case mres of
    Nothing -> return False
    Just txt -> case decode (LBS.fromStrict (TE.encodeUtf8 txt)) :: Maybe ClientMessage of
      Just CMatchAck -> return True
      _ -> return False


