import asyncio
from urllib.parse import urlencode
from fastapi import FastAPI, Form, Request, Response
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

app = FastAPI()


async def fake_data_generator():
    """Simulate generating data in chunks."""
    for i in range(9):
        # Simulate a delay to represent data generation time
        await asyncio.sleep(0.2)
        yield f"Chunk {i + 1}"


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


# Define a Pydantic model for the data you expect in the POST request
class User(BaseModel):
    name: str
    age: int

# Define the POST endpoint
@app.post("/users/")
async def create_user(name: str = Form(...), age: int = Form(...)):
    return {"message": f"User {name} aged {age} created successfully."}

@app.get("/echo")
async def echo_query_params(request: Request):
    # Extract the query parameters from the request
    query_params = request.query_params
    
    # Convert the query parameters to a dictionary
    query_dict = dict(query_params)
    
    # Encode the dictionary back to a query string format
    encoded_query_string = urlencode(query_dict)
    
    # Return the encoded query string as part of the response
    return {"encoded_query_string": encoded_query_string}