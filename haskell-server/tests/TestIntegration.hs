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
import Auth (verifyJwt, verifyJwtFromEnv)
import System.Environment (setEnv, unsetEnv)

-- helper: base64url encode Lazy/Strict
toB64 :: BS.ByteString -> T.Text
toB64 bs = TE.decodeUtf8 (convertToBase Base64URLUnpadded bs)

-- create token with optional kid and secret bytes
-- mkToken now delegates to the Python CLI so tokens are generated the same
-- way as the Python tooling (pyjwt). Returns token Text.
mkToken :: BS.ByteString -> Maybe T.Text -> Aeson.Value -> IO T.Text
mkToken secret mKid _payload = do
  let secretStr = BS8.unpack secret
  let kidArg = case mKid of
        Just k -> [T.unpack k]
        Nothing -> []
  -- script path is relative to haskell-server/tests
  token <- readProcess "python" (["../gen_jwt_cli.py", secretStr] ++ kidArg) ""
  return (T.pack (head (lines token)))

integrationTests :: TestTree
integrationTests = testGroup "Auth.verifyJwtFromEnv integration" [
        testCase "kid selects correct secret via JWT_SECRETS" $ do
          let secret = BS8.pack "secret1"
          let secretB64 = TE.decodeUtf8 (convertToBase Base64URLUnpadded secret)
          let payload = object ["sub" .= ("intuser" :: T.Text), "exp" .= (9999999999 :: Int)]
          token <- mkToken secret (Just "k1") payload
          -- verify via env-path selection
          setEnv "JWT_SECRETS" (T.unpack (TE.decodeUtf8 (LBS.toStrict (Aeson.encode (Aeson.object ["k1" .= secretB64])))))
          r <- verifyJwtFromEnv token
          unsetEnv "JWT_SECRETS"
          case r of
            Right _ -> assertBool "ok" True
            Left e -> assertBool ("expected success, got: " ++ e) False

      , testCase "no kid uses JWT_SECRET default" $ do
          let secret = BS8.pack "dev-secret"
          let payload = object ["sub" .= ("u2" :: T.Text), "exp" .= (9999999999 :: Int)]
          token <- mkToken secret Nothing payload
          setEnv "JWT_SECRET" "dev-secret"
          r <- verifyJwtFromEnv token
          unsetEnv "JWT_SECRET"
          case r of
            Right _ -> assertBool "ok" True
            Left e -> assertBool ("expected success, got: " ++ e) False

        , testCase "kid mismatch fails" $ do
          let secret = BS8.pack "sA"
          let payload = object ["sub" .= ("u3" :: T.Text), "exp" .= (9999999999 :: Int)]
          token <- mkToken secret (Just "kX") payload
          -- set a different secret under kX
          let wrong = TE.decodeUtf8 (convertToBase Base64URLUnpadded (BS8.pack "other"))
          setEnv "JWT_SECRETS" (T.unpack (TE.decodeUtf8 (LBS.toStrict (Aeson.encode (Aeson.object ["kX" .= wrong])))))
          r <- verifyJwtFromEnv token
          unsetEnv "JWT_SECRETS"
          case r of
            Left _ -> assertBool "ok" True
            Right _ -> assertBool "expected failure" False
      ]
