{-# LANGUAGE OverloadedStrings #-}
module Auth (verifyJwt, verifyJwtFromEnv, extractKid, computeHmacSig, loadSecrets) where

import Crypto.JWT
import Crypto.JOSE.JWK (fromOctets)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.ByteString as BS
import qualified Data.ByteArray as BA
import Crypto.MAC.HMAC (HMAC, hmac)
import qualified Crypto.Hash.Algorithms as CHA
import Crypto.Hash (hash, Digest)
import Data.ByteArray.Encoding (convertToBase, convertFromBase, Base(Base64URLUnpadded, Base16))
import Control.Monad.Except (runExceptT, ExceptT)
import Data.ByteString (ByteString)
import Data.Time.Clock (getCurrentTime)
import Data.Word (Word8)
import Data.Aeson (Value)
import qualified Data.Aeson as Aeson
import Data.Aeson (fromJSON, object, (.=), Result(..))
import qualified Data.ByteString.Lazy as LBS
import System.Environment (lookupEnv)
import Control.Monad.IO.Class (liftIO)
import Control.Monad (when)
import Data.Char (toLower)
import Data.Aeson.Types (withObject, (.:?), parseMaybe)
import Data.Maybe (fromMaybe, isJust)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Text.IO as TIO
import Network.HTTP.Client (newManager, parseRequest, httpLbs, responseBody, requestHeaders)
import Network.HTTP.Client.TLS (tlsManagerSettings)
import qualified Data.Aeson.KeyMap as KM
import qualified Data.Aeson.Key as Key
import Data.List (foldl')

-- Verify JWT using jose (Crypto.JWT).
-- Validates signature, standard claims and optional `aud`/`iss` from env vars.
-- Returns either an error string or the Claims as a JSON Value.
verifyJwt :: ByteString -> T.Text -> IO (Either String Value)
verifyJwt secret token = do
  -- If secret is shorter than 32 bytes, derive a 32-byte key using HKDF-SHA256.
  let secretLen = BS.length secret
  (finalSecret, derived) <- if secretLen < 32
    then do
      let salt = BS.empty
      let info = "hs256-derivation"
      let prk = hkdfExtract salt secret
      let out = hkdfExpand prk info 32
      putStrLn $ "Auth debug: secret too short (" ++ show secretLen ++ " bytes); deriving 32-byte key via HKDF-SHA256"
      return (out, True)
    else return (secret, False)
  -- Build explicit JWK JSON with kty=oct and k=<base64url(finalSecret)> and alg=HS256
  let keyB64 = (convertToBase Base64URLUnpadded finalSecret :: BS.ByteString)
  let kText = TE.decodeUtf8 keyB64
  let keyHex = (convertToBase Base16 finalSecret :: BS.ByteString)
  let keyHexT = TE.decodeUtf8 keyHex
  let finalSecretSha256 = TE.decodeUtf8 (convertToBase Base16 (BA.convert (hash finalSecret :: Digest CHA.SHA256) :: BS.ByteString))
  putStrLn $ "Auth debug: secret base64url(k)=" ++ T.unpack kText ++ " secret(hex)=" ++ T.unpack keyHexT ++ (if derived then " (derived)" else "")
  putStrLn $ "Auth debug: final_secret_sha256=" ++ T.unpack finalSecretSha256
  let jwkVal = object ["kty" .= Aeson.String "oct", "k" .= Aeson.String kText, "alg" .= Aeson.String "HS256", "use" .= Aeson.String "sig", "key_ops" .= ([Aeson.String "verify"] :: [Value])]
  -- Prefer explicit JWK constructed from JSON; fall back to fromOctets
  jwk <- case fromJSON jwkVal :: Result JWK of
    Aeson.Success j -> do
      putStrLn $ "Auth debug: using explicit jwk json: " ++ show (Aeson.encode jwkVal)
      putStrLn $ "Auth debug: jwk (show)=" ++ show j
      return j
    Aeson.Error _ -> do
      let j = fromOctets secret
      putStrLn $ "Auth debug: falling back to fromOctets jwk"
      return j
    -- no other cases
  -- Split token into parts for header/payload decoding and logging
  let parts = T.splitOn "." token
  case parts of
    (h:p:_) -> do
      let hdrDec = convertFromBase Base64URLUnpadded (TE.encodeUtf8 h) :: Either String BS.ByteString
      let pldDec = convertFromBase Base64URLUnpadded (TE.encodeUtf8 p) :: Either String BS.ByteString
      putStrLn $ "Auth debug: header raw decode: " ++ either (const "<decode error>") (const "ok") hdrDec
      putStrLn $ "Auth debug: payload raw decode: " ++ either (const "<decode error>") (const "ok") pldDec
      case hdrDec of
        Right hb -> case Aeson.decodeStrict' hb :: Maybe Value of
          Just hv -> putStrLn $ "Auth debug: header json: " ++ show (Aeson.encode hv)
          Nothing -> putStrLn "Auth debug: header json parse failed"
        Left _ -> return ()
      case pldDec of
        Right pb -> case Aeson.decodeStrict' pb :: Maybe Value of
          Just pv -> putStrLn $ "Auth debug: payload json: " ++ show (Aeson.encode pv)
          Nothing -> putStrLn "Auth debug: payload json parse failed"
        Left _ -> return ()
    _ -> return ()

  -- Debug: locally compute HMAC-SHA256 over header.payload and compare to token signature
  case parts of
    (h:p:s:_) -> do
      let msg = TE.encodeUtf8 (T.intercalate "." [h,p])
      let mac = hmac finalSecret msg :: HMAC CHA.SHA256
      let macBytes = (BA.convert mac :: BS.ByteString)
      let comp = (convertToBase Base64URLUnpadded macBytes :: BS.ByteString)
      let compT = TE.decodeUtf8 comp
      let compHex = TE.decodeUtf8 (convertToBase Base16 macBytes :: BS.ByteString)
      -- signing input diagnostics: utf8, hex and length
      let msgHex = (convertToBase Base16 msg :: BS.ByteString)
      let msgHexT = TE.decodeUtf8 msgHex
      let msgUtf8 = TE.decodeUtf8 msg
      -- token signature raw bytes and hex
      let sigDec = convertFromBase Base64URLUnpadded (TE.encodeUtf8 s) :: Either String BS.ByteString
      let sigHex = case sigDec of
                     Right sb -> TE.decodeUtf8 (convertToBase Base16 sb :: BS.ByteString)
                     Left _ -> "<sig decode error>"
      putStrLn $ "Auth debug: signing-input (utf8): " ++ T.unpack msgUtf8
      putStrLn $ "Auth debug: signing-input (hex): " ++ T.unpack msgHexT ++ " len=" ++ show (BS.length msg)
      putStrLn $ "Auth debug: token sig (base64url): " ++ T.unpack s ++ " sig(hex): " ++ T.unpack sigHex
      putStrLn $ "Auth debug: computed sig (base64url): " ++ T.unpack compT ++ " sig(hex): " ++ T.unpack compHex ++ " match=" ++ show (compT == s)
    _ -> putStrLn "Auth debug: token does not split into three parts"
    -- Fallbacks removed: always fail on signature verification error.
  let settings = defaultJWTValidationSettings (const True)
  -- First attempt using the constructed jwk
  res1 <- runExceptT $ do
    jwt <- (decodeCompact (LBS.fromStrict (TE.encodeUtf8 token)) :: ExceptT JWTError IO SignedJWT)
    liftIO $ putStrLn $ "Auth debug: parsed SignedJWT: " ++ show jwt
    now <- liftIO getCurrentTime
    verifyClaimsAt settings jwk now jwt :: ExceptT JWTError IO ClaimsSet
  case res1 of
    Left err1 -> do
      putStrLn $ "Auth debug: primary verifyClaimsAt failed: " ++ show (err1 :: JWTError)
      putStrLn $ "Auth debug: primary jwk (json)=" ++ show (Aeson.encode jwkVal)
      putStrLn $ "Auth debug: primary jwk secret(hex)=" ++ T.unpack keyHexT
      putStrLn "Auth error: verification failed (local HMAC fallback removed)"
      return $ Left (show err1)
    Right claims -> do
      let val = Aeson.toJSON (claims :: ClaimsSet)
      mAudEnv <- lookupEnv "JWT_AUD"
      mIssEnv <- lookupEnv "JWT_ISS"
      let mAudMatch = case mAudEnv of
            Nothing -> True
            Just expected -> case parseMaybe (withObject "claims" (\o -> o .:? "aud")) val of
              Just (Just audVal) -> expected == audVal
              _ -> False
      let mIssMatch = case mIssEnv of
            Nothing -> True
            Just expected -> case parseMaybe (withObject "claims" (\o -> o .:? "iss")) val of
              Just (Just issVal) -> expected == issVal
              _ -> False
      if mAudMatch && mIssMatch then return $ Right val else return $ Left "aud/iss mismatch"

-- | Load secrets from environment.
-- Preferred: JWT_SECRETS as JSON map { kid: base64urlsecret }
-- Fallback: JWT_SECRET as raw secret string (mapped under key "default").
loadSecrets :: IO (Map T.Text ByteString)
loadSecrets = do
  -- Vault path takes precedence
  mVaultPath <- lookupEnv "JWT_SECRETS_VAULT_PATH"
  case mVaultPath of
    Just vaultPath -> do
      vaultAddr <- lookupEnv "VAULT_ADDR"
      vaultToken <- lookupEnv "VAULT_TOKEN"
      case (vaultAddr, vaultToken) of
        (Just addr, Just tok) -> do
          ev <- fetchJwtSecretsFromVault addr tok vaultPath
          case ev of
            Right m -> return m
            Left e -> do
              putStrLn $ "Auth warning: vault fetch failed: " ++ e
              fallbackParse
        _ -> do
          putStrLn "Auth warning: VAULT_ADDR or VAULT_TOKEN not set; falling back"
          fallbackParse
    Nothing -> fallbackParse
  where
    fallbackParse = do
      mJson <- lookupEnv "JWT_SECRETS"
      case mJson of
        Just j -> case Aeson.decodeStrict' (TE.encodeUtf8 (T.pack j)) :: Maybe (Map T.Text T.Text) of
          Just m -> do
            -- decode base64url values to ByteString where possible
            let decodeEntry t = case convertFromBase Base64URLUnpadded (TE.encodeUtf8 t) of
                  Right bs -> Just bs
                  Left _ -> Nothing
            let pairs = Map.toList m
            let decoded = Map.fromList $ foldr (\t acc -> case decodeEntry (snd t) of
                                                          Just bs -> (fst t, bs):acc
                                                          Nothing -> acc) [] pairs
            return decoded
          Nothing -> do
            putStrLn "Auth warning: JWT_SECRETS present but failed to parse JSON"
            return Map.empty
        Nothing -> do
          mSecret <- lookupEnv "JWT_SECRET"
          case mSecret of
            Just s -> do
                let sBS = TE.encodeUtf8 (T.pack s)
                case convertFromBase Base64URLUnpadded sBS of
                  Right decoded -> return $ Map.singleton "default" decoded
                  Left _ -> return $ Map.singleton "default" sBS
            Nothing -> return Map.empty


-- | Minimal Vault fetch implementation. Calls Vault HTTP API and looks for
-- secret map in either `data.data` (KV v2) or `data` (KV v1) or top-level.
fetchJwtSecretsFromVault :: String -> String -> String -> IO (Either String (Map T.Text ByteString))
fetchJwtSecretsFromVault vaultAddr vaultToken vaultPath = do
  manager <- newManager tlsManagerSettings
  let url = if "http" `T.isPrefixOf` T.pack vaultAddr then vaultAddr ++ "/v1/" ++ vaultPath else vaultAddr ++ "/v1/" ++ vaultPath
  req <- parseRequest url
  let req' = req { requestHeaders = [("X-Vault-Token", TE.encodeUtf8 (T.pack vaultToken))] }
  resp <- httpLbs req' manager
  let body = responseBody resp
  case Aeson.decode body :: Maybe Aeson.Value of
    Nothing -> return $ Left "failed to parse vault response as JSON"
    Just v -> do
      -- extract possible nested maps
      let tryExtract (Aeson.Object o) =
            case KM.lookup (Key.fromString "data") o of
              Just (Aeson.Object inner) -> -- could be KVv2: inner contains "data"
                case KM.lookup (Key.fromString "data") inner of
                  Just (Aeson.Object m) -> Just m
                  _ -> Just inner
              _ -> Just o
          tryExtract _ = Nothing
      case tryExtract v of
        Nothing -> return $ Left "unexpected vault JSON shape"
        Just obj -> do
          -- convert KeyMap to Map Text ByteString if values are strings
          let pairs = KM.toList obj
          let foldFn acc (k, val) = case val of
                Aeson.String t -> case convertFromBase Base64URLUnpadded (TE.encodeUtf8 t) of
                  Right bs -> Map.insert (Key.toText k) bs acc
                  Left _ -> acc
                _ -> acc
          let result = foldl' foldFn Map.empty pairs
          return $ Right result

-- | Select secret for given kid (or fallback to default)
selectSecret :: Map T.Text ByteString -> Maybe T.Text -> Maybe ByteString
selectSecret mp mKid = case mKid of
  Just k -> Map.lookup k mp
  Nothing -> case Map.lookup "default" mp of
    Just s -> Just s
    Nothing -> if Map.size mp == 1 then Just (snd $ head (Map.toList mp)) else Nothing

-- | Verify a token by automatically loading secrets from environment and
-- selecting by `kid` if present in the token header.
verifyJwtFromEnv :: T.Text -> IO (Either String Value)
verifyJwtFromEnv token = do
  secrets <- loadSecrets
  let mKid = extractKid token
  case selectSecret secrets mKid of
    Just sec -> do
      let secB64 = (convertToBase Base64URLUnpadded sec :: BS.ByteString)
      putStrLn $ "Auth debug: verifyJwtFromEnv selected secret for kid=" ++ show mKid ++ " secretB64=" ++ T.unpack (TE.decodeUtf8 secB64)
      verifyJwt sec token
    Nothing -> return $ Left "no matching secret for token kid"

-- | Extract `kid` from JWT header if present (does not verify signature)
extractKid :: T.Text -> Maybe T.Text
extractKid token =
  let parts = T.splitOn "." token in
  case parts of
    (h:_) -> case convertFromBase Base64URLUnpadded (TE.encodeUtf8 h) :: Either String BS.ByteString of
      Right hb -> case Aeson.decodeStrict' hb :: Maybe Aeson.Value of
        Just v -> case parseMaybe (withObject "hdr" (.:? "kid")) v of
          Just (Just k) -> Just k
          _ -> Nothing
        Nothing -> Nothing
      Left _ -> Nothing
    _ -> Nothing

-- | Compute HMAC-SHA256 signature (base64url) for given secret and token.
-- Returns computed signature string if token has header.payload.signature format.
computeHmacSig :: ByteString -> T.Text -> Maybe T.Text
computeHmacSig secret token =
  let parts = T.splitOn "." token in
  case parts of
    (h:p:s:_) ->
      let msg = TE.encodeUtf8 (T.intercalate "." [h,p])
          mac = hmac secret msg :: HMAC CHA.SHA256
          macBytes = (BA.convert mac :: BS.ByteString)
          comp = (convertToBase Base64URLUnpadded macBytes :: BS.ByteString)
      in Just (TE.decodeUtf8 comp)
    _ -> Nothing

-- HKDF-SHA256: extract and expand utilities
hkdfExtract :: ByteString -> ByteString -> ByteString
hkdfExtract salt ikm = BA.convert (hmac salt ikm :: HMAC CHA.SHA256)

hkdfExpand :: ByteString -> ByteString -> Int -> ByteString
hkdfExpand prk info outLen = BS.take outLen $ BS.concat (go 1 BS.empty [])
  where
    hashLen = 32
    n = (outLen + hashLen - 1) `div` hashLen
    go :: Int -> ByteString -> [ByteString] -> [ByteString]
    go i prev acc
      | i > n = reverse acc
      | otherwise =
          let ctr = BS.singleton (fromIntegral (i :: Int) :: Word8)
              input = BS.concat [prev, infoBS, ctr]
              t = BA.convert (hmac prk input :: HMAC CHA.SHA256)
          in go (i+1) t (t:acc)
    infoBS = infoWrapped info

infoWrapped :: ByteString -> ByteString
infoWrapped = id
