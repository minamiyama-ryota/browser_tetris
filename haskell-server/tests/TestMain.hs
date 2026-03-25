module Main where

import Test.Tasty (defaultMain, testGroup)
import TestIntegration (integrationTests)
import Test.Tasty.HUnit (testCase, (@?=), assertBool)
import qualified Data.Text as T
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import Auth (verifyJwt, extractKid, computeHmacSig)

-- Example token generated with HS256 and secret "dev-secret".
-- NOTE: If this token expires the test will fail; replace with a fresh token via gen_jwt.py when needed.
goodToken :: T.Text
goodToken = T.pack "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0dXNlciIsImV4cCI6MTc3NDM5OTA3Mn0.oOKIZvknPl148LHN5JzgVLD4c92GcqS9otcVuMHdMW8"

badToken :: T.Text
badToken = T.pack "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmb3NpbGUiLCJleHAiOjE2MDAwMDAwMDB9.invalidsig"

main :: IO ()
main = defaultMain tests
  where
    unitTests = testGroup "Auth.verifyJwt" [
        testCase "header/payload signature computed matches token signature" $ do
              let comp = computeHmacSig (BS8.pack "dev-secret") goodToken
              case comp of
                Just sig -> do
                  -- token's signature is the third part
                  let parts = T.splitOn (T.pack ".") goodToken
                  case parts of
                    (_:_:s:_) -> assertBool "signatures match" (sig == s)
                    _ -> assertBool "token malformed" False
                Nothing -> assertBool "could not compute signature" False
          , testCase "kid can be extracted when present (none in test token)" $ do
              let k = extractKid goodToken
              assertBool "kid absent or present as expected" (k == Nothing)
      , testCase "invalid token or wrong signature fails" $ do
          r <- verifyJwt (BS8.pack "wrong-secret") goodToken
          case r of
            Left _ -> assertBool "ok" True
            Right _ -> assertBool "expected failure" False
      , testCase "malformed/invalid token fails" $ do
          r <- verifyJwt (BS8.pack "dev-secret") badToken
          case r of
            Left _ -> assertBool "ok" True
            Right _ -> assertBool "expected failure" False
      ]

    tests = testGroup "All" [unitTests, integrationTests]
