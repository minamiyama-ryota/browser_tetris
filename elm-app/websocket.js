(function(){
  // This file bridges Elm ports and a browser WebSocket.
  var app = (typeof Elm !== 'undefined' && Elm.Main) ? Elm.Main.init({ node: document.getElementById('elm') }) : null;
  if(!app){
    console.error('Elm app not found. Build Elm to dist/main.js and include it.');
    return;
  }
  console.log('websocket.js loaded, Elm app present:', !!app);
  var ws = null;
  var reconnectAttempts = 0;
  var lastConnect = null;
  var pingInterval = null;
  var pongTimeout = null;
  var PING_INTERVAL_MS = 20000;
  var PONG_TIMEOUT_MS = 5000;

  function handlePortMessage(msg){
    console.log('port message received:', msg);
    try{
      var data = (typeof msg === 'string') ? JSON.parse(msg) : msg;
      if(data.type === 'connect'){
        // store last connect info for reconnects
        lastConnect = data;
        if(ws){ try{ ws.close(); }catch(e){} ws = null; }
        ws = new WebSocket(data.url);
        console.log('new WebSocket created, readyState=', ws.readyState);
        // addEventListener を使って確実にイベントを拾う
        ws.addEventListener('open', function(ev){
          console.log('WS onopen event', ev);
          try{ app.ports.onMessage.send(JSON.stringify({type:'status',status:'open'})); }catch(e){ console.error('port send on open failed', e); }
          // reset reconnect attempts and start application-level heartbeat
          reconnectAttempts = 0;
          startPingLoop();
          // send auth immediately if provided
          try{
            if(data.token){
              var authMsg = JSON.stringify({type:'auth', token: data.token});
              if(ws && ws.readyState === WebSocket.OPEN){ ws.send(authMsg); console.log('sent auth token'); }
            }
          }catch(e){ console.error('send auth failed', e); }
        });
        ws.addEventListener('message', function(ev){
          console.log('WS onmessage', ev.data);
          // Auto-ACK: if server sends match_start, reply with match_ack
          try{
            var parsed = JSON.parse(ev.data);
            if(parsed && parsed.type === 'match_start'){
              try{
                var ack = JSON.stringify({type: 'match_ack'});
                if(ws && ws.readyState === WebSocket.OPEN){ ws.send(ack); console.log('sent auto match_ack'); }
              }catch(e){ console.error('auto-ack send failed', e); }
            }
            // application-level ping/pong
            if(parsed && parsed.type === 'pong'){
              // received pong, clear pong timeout
              if(pongTimeout){ clearTimeout(pongTimeout); pongTimeout = null; }
            }
            if(parsed && parsed.type === 'ping'){
              try{ if(ws && ws.readyState === WebSocket.OPEN){ ws.send(JSON.stringify({type:'pong'})); } }catch(e){}
            }
          }catch(e){ /* not JSON or parse failed; ignore */ }
          try{ app.ports.onMessage.send(ev.data); }catch(e){ console.error('port send on message failed', e); }
        });
        ws.addEventListener('close', function(ev){
          console.warn('WS onclose', ev && ev.code, ev && ev.reason);
          try{ app.ports.onMessage.send(JSON.stringify({type:'status',status:'closed', code: ev && ev.code, reason: ev && ev.reason})); }catch(e){ console.error('port send on close failed', e); }
          cleanupPingLoop();
          ws=null;
          // attempt reconnect with exponential backoff
          scheduleReconnect();
        });
        ws.addEventListener('error', function(ev){ console.error('WS onerror', ev); try{ app.ports.onMessage.send(JSON.stringify({type:'status',status:'error'})); }catch(e){ console.error('port send on error failed', e); } });
        // 状態を追うための短い遅延ログ
        setTimeout(function(){ console.log('ws.readyState @50ms =', ws && ws.readyState); }, 50);
        setTimeout(function(){ console.log('ws.readyState @200ms =', ws && ws.readyState); }, 200);
      } else if(data.type === 'send'){
        if(ws && ws.readyState === WebSocket.OPEN){
          var payload = typeof data.payload === 'string' ? data.payload : JSON.stringify(data.payload);
          try{
            ws.send(payload);
          }catch(err){
            console.error('ws.send error', err);
            app.ports.onMessage.send(JSON.stringify({type:'error',message: 'ws.send failed'}));
          }
        } else {
          app.ports.onMessage.send(JSON.stringify({type:'error',message:'ws not open'}));
        }
      }
    }catch(e){
      console.error('port msg parse error', e);
    }
  }
  app.ports.sendToJs.subscribe(handlePortMessage);
  // Helpers: ping loop and reconnect scheduling
  function startPingLoop(){
    cleanupPingLoop();
    pingInterval = setInterval(function(){
      try{
        if(ws && ws.readyState === WebSocket.OPEN){
          ws.send(JSON.stringify({type:'ping', ts: Date.now()}));
          // set pong timeout
          if(pongTimeout){ clearTimeout(pongTimeout); }
          pongTimeout = setTimeout(function(){
            console.warn('pong timeout, closing socket');
            try{ ws.close(); }catch(e){}
          }, PONG_TIMEOUT_MS);
        }
      }catch(e){ console.error('ping send failed', e); }
    }, PING_INTERVAL_MS);
  }
  function cleanupPingLoop(){
    if(pingInterval){ clearInterval(pingInterval); pingInterval = null; }
    if(pongTimeout){ clearTimeout(pongTimeout); pongTimeout = null; }
  }
  function scheduleReconnect(){
    if(!lastConnect) return;
    reconnectAttempts += 1;
    var backoff = Math.min(30000, Math.pow(2, reconnectAttempts) * 1000);
    console.log('scheduling reconnect in', backoff, 'ms');
    setTimeout(function(){
      try {
        if (typeof handlePortMessage === 'function') {
          handlePortMessage(JSON.stringify(Object.assign({}, lastConnect)));
        } else {
          console.error('reconnect failed: no handler');
        }
      } catch (e) { console.error('reconnect send failed', e); }
    }, backoff);
  }
  // Expose a small debug API so console can control the Elm app safely
  try{
    window.ElmApp = app;
    window.sendToJs = function(msg){
      try{
        var payload = (typeof msg === 'string') ? msg : JSON.stringify(msg);
        // Prefer to route to the websocket bridge handler so console can mimic Elm->JS messages
        if(typeof handlePortMessage === 'function'){
          handlePortMessage(payload);
          return;
        }
        // fallback: send into Elm's onMessage port
        if(app && app.ports && app.ports.onMessage && typeof app.ports.onMessage.send === 'function'){
          app.ports.onMessage.send(payload);
          return;
        }
        console.error('No suitable target for sendToJs');
      }catch(e){ console.error('sendToJs helper failed', e); }
    };
  }catch(e){ /* window may be unavailable in non-browser env */ }
})();