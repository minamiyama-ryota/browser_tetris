{-# LANGUAGE OverloadedStrings #-}

module TestIntegration (integrationTests) where

import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, assertBool)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as LBS
import qualified Data.Aeson as Aeson
import Data.Aeson ((.=), object)
import Crypto.MAC.HMAC (hmac, HMAC)
import qualified Crypto.Hash.Algorithms as CHA
import Data.ByteArray (convert)
import Data.ByteArray.Encoding (convertToBase, Base(Base64URLUnpadded))
import System.Process (readProcess)
import System.Directory (doesFileExist, findExecutable)
import Data.Maybe (listToMaybe)
import Auth (verifyJwt, verifyJwtFromEnv, verifyJwtWithSecrets, tryB64urlDecode, hkdfExtract, hkdfExpand)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)

-- helper: base64url encode Lazy/Strict
toB64 :: BS.ByteString -> T.Text
toB64 bs = TE.decodeUtf8 (convertToBase Base64URLUnpadded bs)

-- create token with optional kid and secret bytes
-- mkToken now delegates to the Python CLI so tokens are generated the same
-- way as the Python tooling (pyjwt). Returns token Text.
mkToken :: BS.ByteString -> Maybe T.Text -> Aeson.Value -> IO T.Text
mkToken secret mKid payload = do
  -- Build JWT header and payload, base64url-encode (unpadded), then HMAC-SHA256 sign.
  let hdrObj = case mKid of
        Just k -> Aeson.object ["typ" .= ("JWT" :: T.Text), "alg" .= ("HS256" :: T.Text), "kid" .= k]
        Nothing -> Aeson.object ["typ" .= ("JWT" :: T.Text), "alg" .= ("HS256" :: T.Text)]
  let hdrBs = LBS.toStrict (Aeson.encode hdrObj)
  let pldBs = LBS.toStrict (Aeson.encode payload)
  let hdrB64 = convertToBase Base64URLUnpadded (hdrBs :: BS.ByteString)
  let pldB64 = convertToBase Base64URLUnpadded (pldBs :: BS.ByteString)
  let signingInput = BS.intercalate (BS8.pack ".") [hdrB64, pldB64]

  -- Normalize secret: if it looks like base64url, decode; if <32 bytes derive via HKDF
  let providedLen = BS.length secret
  let mDecoded = tryB64urlDecode (TE.decodeUtf8 secret)
  let secretBytes = case mDecoded of
        Just b -> b
        Nothing -> secret
  let hkdfApplied = BS.length secretBytes < 32
  let finalSecret = if hkdfApplied then hkdfExpand (hkdfExtract BS.empty secretBytes) (TE.encodeUtf8 (T.pack "hs256-derivation")) 32 else secretBytes

  let mac = hmac finalSecret signingInput :: HMAC CHA.SHA256
  let macBytes = (convert mac :: BS.ByteString)
  let sigB64 = convertToBase Base64URLUnpadded macBytes :: BS.ByteString
  let token = TE.decodeUtf8 hdrB64 `T.append` "." `T.append` TE.decodeUtf8 pldB64 `T.append` "." `T.append` TE.decodeUtf8 sigB64
  return token

integrationTests :: TestTree
integrationTests = testGroup "Auth.verifyJwtFromEnv integration" [
        testCase "kid selects correct secret via JWT_SECRETS" $ do
          let secret = BS8.pack "secret1"
          let secretB64 = TE.decodeUtf8 (convertToBase Base64URLUnpadded secret)
          let payload = object ["sub" .= ("intuser" :: T.Text), "exp" .= (9999999999 :: Int)]
          token <- mkToken secret (Just "k1") payload
          -- verify by passing explicit secrets map (avoid env vars)
          let secrets = Map.singleton "k1" secretB64
          r <- verifyJwtWithSecrets secrets token
          case r of
            Right _ -> assertBool "ok" True
            Left e -> assertBool ("expected success, got: " ++ e) False

      , testCase "no kid uses JWT_SECRET default" $ do
          let secret = BS8.pack "dev-secret"
          let payload = object ["sub" .= ("u2" :: T.Text), "exp" .= (9999999999 :: Int)]
          token <- mkToken secret Nothing payload
          let secrets = Map.singleton "default" (TE.decodeUtf8 (convertToBase Base64URLUnpadded secret))
          r <- verifyJwtWithSecrets secrets token
          case r of
            Right _ -> assertBool "ok" True
            Left e -> assertBool ("expected success, got: " ++ e) False

        , testCase "kid mismatch fails" $ do
          let secret = BS8.pack "sA"
          let payload = object ["sub" .= ("u3" :: T.Text), "exp" .= (9999999999 :: Int)]
          token <- mkToken secret (Just "kX") payload
          -- provide a different secret under kX
          let wrong = TE.decodeUtf8 (convertToBase Base64URLUnpadded (BS8.pack "other"))
          let secrets = Map.singleton "kX" wrong
          r <- verifyJwtWithSecrets secrets token
          case r of
            Left _ -> assertBool "ok" True
            Right _ -> assertBool "expected failure" False
      ]
