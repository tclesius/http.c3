from fastapi import FastAPI, Request, Response

app = FastAPI()


@app.get("/")
def create_cookie(response: Response):
    response.set_cookie(key="fakesession", value="fake-cookie-session-value")
    return {"message": "Come to the dark side, we have cookies"}


@app.get("/json")
async def get_body(request: Request):
    print(await request.json())
    return "test"