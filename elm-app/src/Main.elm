port module Main exposing (main)

import Browser
import Html exposing (Html, div, text, h1, button, pre)
import Html.Events exposing (onClick)
import Json.Encode as Encode

-- Ports
port sendToJs : String -> Cmd msg
port onMessage : (String -> msg) -> Sub msg


-- MODEL

type alias Model =
    { status : String
    , log : List String
    }

init : () -> ( Model, Cmd Msg )
init _ =
    ( { status = "idle", log = [] }
    , Cmd.none
    )


-- UPDATE

type Msg
    = NoOp
    | SendConnect
    | SendPing
    | JsMsg String

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        SendConnect ->
            let
                payload = Encode.object [ ( "type", Encode.string "connect" ), ( "url", Encode.string "ws://127.0.0.1:8000" ) ]
            in
            ( { model | status = "connecting...", log = ("-> connect") :: model.log }
            , sendToJs (Encode.encode 0 payload)
            )

        SendPing ->
            let
                payload = Encode.object [ ( "type", Encode.string "send" ), ( "payload", Encode.string "hello from elm" ) ]
            in
            ( { model | log = ("-> send ping") :: model.log }
            , sendToJs (Encode.encode 0 payload)
            )

        JsMsg s ->
            ( { model | status = "connected", log = ("<- " ++ s) :: model.log }
            , Cmd.none
            )


-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions _ =
    onMessage JsMsg


-- VIEW

view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "TETRIS VS (Elm) — WS Test" ]
        , div []
            [ button [ onClick SendConnect ] [ text "Connect to Haskell WS" ]
            , button [ onClick SendPing ] [ text "Send Test" ]
            ]
        , div [] [ text ("Status: " ++ model.status) ]
        , pre [] [ text (String.join "\n" (List.reverse model.log)) ]
        ]


-- PROGRAM

main : Program () Model Msg
main =
    Browser.element { init = init, update = update, view = view, subscriptions = subscriptions }
