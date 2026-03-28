{-# LANGUAGE OverloadedStrings #-}
module Main where

import Server (runServer)

main :: IO ()
main = do
  putStrLn "Starting pairing WebSocket server on 127.0.0.1:8000"
  runServer
