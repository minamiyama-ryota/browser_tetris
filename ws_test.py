import json
import time

try:
    import websocket
except ImportError:
    raise SystemExit("websocket-client not installed; run: pip install websocket-client")

TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0dXNlciIsImV4cCI6MTc3NDM5OTA3Mn0.oOKIZvknPl148LHN5JzgVLD4c92GcqS9otcVuMHdMW8"

def main():
    url = "ws://localhost:8000/"
    print('Connecting to', url)
    ws = websocket.create_connection(url, timeout=5)
    auth = {"type": "auth", "token": TOKEN}
    print('Sending auth:', auth)
    ws.send(json.dumps(auth))
    # Read a few messages or until close
    for _ in range(5):
        try:
            msg = ws.recv()
            print('RECV:', msg)
        except Exception as e:
            print('Recv error:', e)
            break
    ws.close()

if __name__ == '__main__':
    main()
