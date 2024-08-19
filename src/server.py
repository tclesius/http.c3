import asyncio
from fastapi import FastAPI, Request, Response
from fastapi.responses import StreamingResponse

app = FastAPI()


async def fake_data_generator():
    """Simulate generating data in chunks."""
    for i in range(10):
        # Simulate a delay to represent data generation time
        await asyncio.sleep(1)
        yield f"Chunk {i + 1}\n"


@app.get("/stream")
async def stream_large_file():
    return StreamingResponse(fake_data_generator(), media_type="text/plain")


@app.get("/")
def create_cookie(response: Response):
    response.set_cookie(key="fakesession", value="fake-cookie-session-value")
    return {"message": "Come to the dark side, we have cookies"}


@app.get("/json")
async def get_body(request: Request):
    return await request.json()
