{-# LANGUAGE OverloadedStrings #-}
module DebugVerify where

import System.Process (readProcess)
import Crypto.MAC.HMAC (HMAC, hmac)
import qualified Crypto.Hash.Algorithms as CHA
import Data.Time.Clock.POSIX (getPOSIXTime)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import Auth (verifyJwt, computeHmacSig)
import Crypto.MAC.HMAC (HMAC, hmac)
import qualified Crypto.Hash.Algorithms as CHA
import qualified Data.ByteArray as BA
import Data.Word (Word8)
import qualified Data.ByteString as BS
import Data.ByteArray.Encoding (convertToBase, convertFromBase, Base(Base64URLUnpadded, Base16))
import Control.Monad.Except (runExceptT, ExceptT)
import Crypto.JWT (SignedJWT, JWTError)
import Crypto.JOSE.Compact (decodeCompact, ToCompact(toCompact))
import qualified Data.Aeson as Aeson
import Data.Aeson ((.=), object)
import qualified Data.ByteString.Lazy as LBS
import Data.ByteArray.Encoding (convertToBase, convertFromBase, Base(Base64URLUnpadded, Base16))
import qualified Data.ByteArray as BA
import Data.ByteString (ByteString)
import System.Environment (getArgs)
-- avoid depending on jose types here; just inspect compact parts and constructed JWK JSON

main :: IO ()
main = do
  args <- getArgs
  case args of
    (secret:_) -> do
      let secretStr = secret
      -- generate token internally (HS256)
      now <- getPOSIXTime
      let expVal = (floor now :: Integer) + 3600
      let headerJson = Aeson.encode (object ["alg" .= Aeson.String "HS256", "typ" .= Aeson.String "JWT"])
      let payloadJson = Aeson.encode (object ["sub" .= Aeson.String "testuser", "exp" .= expVal])
      let headerBs = LBS.toStrict headerJson
      let payloadBs = LBS.toStrict payloadJson
      let headerB64 = (convertToBase Base64URLUnpadded headerBs :: BS.ByteString)
      let payloadB64 = (convertToBase Base64URLUnpadded payloadBs :: BS.ByteString)
      let tokenNoSig = TE.decodeUtf8 headerB64 <> "." <> TE.decodeUtf8 payloadB64
      -- derive finalSecret if input secret is shorter than 32 bytes (HKDF-SHA256)
      let secretBs = BS8.pack secretStr
      let finalSecret = if BS.length secretBs < 32
                        then let salt = BS.empty
                                 prk = hkdfExtract salt secretBs
                                 out = hkdfExpand prk "hs256-derivation" 32
                             in out
                        else secretBs

      -- compute HMAC-SHA256 signature using finalSecret
      let msg = TE.encodeUtf8 tokenNoSig
      let mac = hmac finalSecret msg :: HMAC CHA.SHA256
      let macBytes = (BA.convert mac :: BS.ByteString)
      let sigB64 = (convertToBase Base64URLUnpadded macBytes :: BS.ByteString)
      let tokenT = tokenNoSig <> "." <> TE.decodeUtf8 sigB64
      putStrLn "=== Generated token ==="
      putStrLn (T.unpack tokenT)

      -- show token signature parts (base64url + hex)
      let parts = T.splitOn "." tokenT
      case parts of
        (_:_:s:_) -> do
          putStrLn "=== Token signature (base64url) ==="
          putStrLn (T.unpack s)
          case (convertFromBase Base64URLUnpadded (TE.encodeUtf8 s) :: Either String BS.ByteString) of
            Right sigBs -> do
              putStrLn "=== Token signature (hex) ==="
              putStrLn (BS8.unpack (convertToBase Base16 sigBs))
            Left _ -> putStrLn "signature base64 decode failed"
        _ -> putStrLn "token does not have three parts"

      putStrLn "=== Local computed HMAC ==="
      case computeHmacSig finalSecret tokenT of
        Just s -> putStrLn (T.unpack s)
        Nothing -> putStrLn "computeHmacSig failed"

      -- Construct the explicit jwk JSON like Auth.verifyJwt does (use finalSecret)
      let keyB64 = (convertToBase Base64URLUnpadded finalSecret :: BS.ByteString)
      let kText = TE.decodeUtf8 keyB64
      let jwkVal = object ["kty" .= Aeson.String "oct", "k" .= Aeson.String kText, "alg" .= Aeson.String "HS256", "use" .= Aeson.String "sig", "key_ops" .= ([Aeson.String "verify"] :: [Aeson.Value])]
      putStrLn "=== Constructed JWK JSON ==="
      putStrLn (T.unpack (TE.decodeUtf8 (LBS.toStrict (Aeson.encode jwkVal))))

      -- Inspect header and payload (without library verification)
      let hdr = if length parts >= 1 then parts !! 0 else ""
      let pld = if length parts >= 2 then parts !! 1 else ""
      putStrLn "=== token header (base64url) ==="
      putStrLn (T.unpack hdr)
      putStrLn "=== token payload (base64url) ==="
      putStrLn (T.unpack pld)
      case convertFromBase Base64URLUnpadded (TE.encodeUtf8 hdr) :: Either String BS.ByteString of
        Right hb -> case Aeson.decodeStrict' hb :: Maybe Aeson.Value of
          Just hv -> putStrLn $ "=== header json === " ++ show (Aeson.encode hv)
          Nothing -> putStrLn "header json parse failed"
        Left _ -> putStrLn "header base64 decode failed"
      case convertFromBase Base64URLUnpadded (TE.encodeUtf8 pld) :: Either String BS.ByteString of
        Right pb -> case Aeson.decodeStrict' pb :: Maybe Aeson.Value of
          Just pv -> putStrLn $ "=== payload json === " ++ show (Aeson.encode pv)
          Nothing -> putStrLn "payload json parse failed"
        Left _ -> putStrLn "payload base64 decode failed"

      -- (skipping jose decode here) directly call verifyJwt to observe the library result

      -- Also attempt library verification via Auth.verifyJwt and print the result
      putStrLn "=== verifyJwt (Auth.verifyJwt) result ==="
      vres <- verifyJwt (BS8.pack secretStr) tokenT
      putStrLn (show vres)

    _ -> putStrLn "usage: debug-verify <secret>"

-- HKDF-SHA256 utilities (same logic as in Auth.hs)
hkdfExtract :: BS.ByteString -> BS.ByteString -> BS.ByteString
hkdfExtract salt ikm = BA.convert (hmac salt ikm :: HMAC CHA.SHA256)

hkdfExpand :: BS.ByteString -> BS.ByteString -> Int -> BS.ByteString
hkdfExpand prk info outLen = BS.take outLen $ BS.concat (go 1 BS.empty [])
  where
    hashLen = 32
    n = (outLen + hashLen - 1) `div` hashLen
    go :: Int -> BS.ByteString -> [BS.ByteString] -> [BS.ByteString]
    go i prev acc
      | i > n = reverse acc
      | otherwise =
          let ctr = BS.singleton (fromIntegral (i :: Int) :: Word8)
              input = BS.concat [prev, infoBS, ctr]
              t = BA.convert (hmac prk input :: HMAC CHA.SHA256)
          in go (i+1) t (t:acc)
    infoBS = infoWrapped info

infoWrapped :: BS.ByteString -> BS.ByteString
infoWrapped = id
