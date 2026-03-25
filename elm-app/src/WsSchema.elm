module WsSchema exposing (ClientMsg(..), ServerMsg(..), decodeClientMessage, decodeServerMessage)

import Json.Decode as D exposing (Decoder)
import Json.Decode.Pipeline exposing (optional, required)

-- Client side message types

type ClientMsg
    = CJoin String (Maybe Int) -- name, seq
    | CInput String (Maybe Int) -- action, seq
    | CMatchAck (Maybe Int)
    | CPing (Maybe Int)
    | CStateRequest (Maybe Int)


type ServerMsg
    = SMatchStart String (Maybe Int)
    | SOpponentInput String (Maybe Int)
    | SOpponentLeft (Maybe Int)
    | SStateUpdate D.Value (Maybe Int)
    | SError String (Maybe Int)


-- Decoders

maybeSeq : Decoder (Maybe Int)
maybeSeq = D.maybe (D.field "seq" D.int)

payloadField : String -> Decoder a -> Decoder a
payloadField key dec =
    D.field "payload" (D.field key dec)


decodeClientMessage : Decoder ClientMsg
decodeClientMessage =
    D.field "type" D.string
        |> D.andThen typeToClient


typeToClient : String -> Decoder ClientMsg
typeToClient t =
    case t of
        "join" ->
            D.map2 CJoin (D.field "payload" (D.field "name" D.string)) maybeSeq

        "input" ->
            D.map2 CInput (D.field "payload" (D.field "action" D.string)) maybeSeq

        "match_ack" ->
            D.map CMatchAck maybeSeq

        "ping" ->
            D.map CPing maybeSeq

        "state_request" ->
            D.map CStateRequest maybeSeq

        _ ->
            D.fail ("Unknown client message type: " ++ t)


decodeServerMessage : Decoder ServerMsg
decodeServerMessage =
    D.field "type" D.string
        |> D.andThen typeToServer


typeToServer : String -> Decoder ServerMsg
typeToServer t =
    case t of
        "match_start" ->
            D.map2 SMatchStart (D.field "payload" (D.field "opponent" D.string)) maybeSeq

        "opponent_input" ->
            D.map2 SOpponentInput (D.field "payload" (D.field "action" D.string)) maybeSeq

        "opponent_left" ->
            D.map SOpponentLeft maybeSeq

        "state_update" ->
            D.map2 SStateUpdate (D.field "payload" D.value) maybeSeq

        "error" ->
            D.map2 SError (D.field "payload" (D.field "message" D.string)) maybeSeq

        _ ->
            D.fail ("Unknown server message type: " ++ t)
