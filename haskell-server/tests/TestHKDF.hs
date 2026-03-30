{-# LANGUAGE OverloadedStrings #-}

module TestHKDF (hkdfTests) where

import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, assertEqual, assertBool)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.ByteArray.Encoding (convertToBase, Base(Base64URLUnpadded))
import Auth (tryB64urlDecode, hkdfExtract, hkdfExpand)

hkdfTests :: TestTree
hkdfTests = testGroup "HKDF/Base64" [
    testCase "tryB64urlDecode decodes base64url unpadded" $ do
      let raw = BS8.pack "hello-world"
      let enc = convertToBase Base64URLUnpadded raw
      let encT = TE.decodeUtf8 enc
      case tryB64urlDecode encT of
        Just got -> assertEqual "decoded matches" raw got
        Nothing -> assertBool "should decode" False

  , testCase "tryB64urlDecode rejects non-base64" $ do
      let bad = T.pack "not_base64!!"
      case tryB64urlDecode bad of
        Nothing -> assertBool "ok" True
        Just _ -> assertBool "should not decode" False

  , testCase "hkdf expands short secret to 32 bytes and is deterministic" $ do
      let secret = BS8.pack "short"
      let prk = hkdfExtract BS.empty secret
      let out1 = hkdfExpand prk (TE.encodeUtf8 (T.pack "hs256-derivation")) 32
      let out2 = hkdfExpand prk (TE.encodeUtf8 (T.pack "hs256-derivation")) 32
      assertEqual "length 32" 32 (BS.length out1)
      assertEqual "deterministic" out1 out2
      assertBool "expanded differs from input" (out1 /= secret)
  ]
