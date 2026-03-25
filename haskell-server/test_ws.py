import asyncio
import websockets

async def run():
    uri = "ws://127.0.0.1:8000"
    try:
        async with websockets.connect(uri) as ws:
            print("connected")
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=2.0)
                print("recv:", msg)
            except asyncio.TimeoutError:
                print("no message within 2s")
            await asyncio.sleep(1)
    except Exception as e:
        print("connect error:", e)

asyncio.run(run())