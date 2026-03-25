{-# LANGUAGE OverloadedStrings #-}
module Protocol where

import Data.Aeson
import Data.Aeson.Types (Parser)
import Data.Text (Text)

-- Client -> Server
data ClientMessage
  = CJoin { cName :: Text }
  | CAuth { cToken :: Text }
  | CInput { cAction :: Text }
  | CMatchAck
  | CPing
  | CStateRequest
  deriving (Show, Eq)

instance FromJSON ClientMessage where
  parseJSON = withObject "ClientMessage" $ \o -> do
    t <- o .: "type"
    case (t :: Text) of
      "auth" -> CAuth <$> o .: "token"
      "join" -> CJoin <$> o .: "name"
      "input" -> CInput <$> o .: "action"
      "match_ack" -> pure CMatchAck
      "ping" -> pure CPing
      "state_request" -> pure CStateRequest
      _ -> fail "unknown client message"

-- Server -> Client
data ServerMessage
  = SMatchStart { sOpponent :: Text }
  | SOpponentInput { sAction :: Text }
  | SOpponentLeft
  | SStateUpdate { sState :: Value }
  | SError { sMessage :: Text }
  deriving (Show, Eq)

instance ToJSON ServerMessage where
  toJSON (SMatchStart opp) = object ["type" .= String "match_start", "opponent" .= opp]
  toJSON (SOpponentInput a) = object ["type" .= String "opponent_input", "action" .= a]
  toJSON SOpponentLeft = object ["type" .= String "opponent_left"]
  toJSON (SStateUpdate v) = object ["type" .= String "state_update", "state" .= v]
  toJSON (SError m) = object ["type" .= String "error", "message" .= m]
