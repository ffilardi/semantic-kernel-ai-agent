import os
import logging
import httpx

from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles


# Configure logging
logging.basicConfig(level=logging.WARNING, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger("frontend.app")


# Configure backend URL
backend_url = os.getenv("AGENT_BACKEND_CHAT_URL", "http://127.0.0.1:8000/chat")


# Initialize FastAPI app
app = FastAPI(title="AI Agent Frontend",
              description="AI Agent Frontend built on Python/FastAPI",
              version="0.0.1",
              debug=False)


# Get the current directory
app_directory = os.path.dirname(os.path.abspath(__file__))


# Load Jinja2 templates
templates_directory = os.path.join(app_directory, "templates")
templates = Jinja2Templates(directory=templates_directory)


# Mount static files directory
static_directory = os.path.join(app_directory, "static")
app.mount("/static", StaticFiles(directory=static_directory), name="static")


# Set up assistant index page
@app.get("/", tags=["index"], response_class=HTMLResponse)
def index(request: Request):
    return templates.TemplateResponse("index.html", {"request": request, "backend_url": backend_url})


# Set up chat route
@app.post("/chat", tags=["chat_endpoint"], response_class=JSONResponse)
async def chat(request: Request):
    try:
        body = await request.json()
    except Exception as exc:  # pragma: no cover - defensive
        raise HTTPException(status_code=400, detail=f"Invalid JSON body: {exc}")

    session_id = body.get("session_id")
    chat_input = body.get("chat_input")
    user_name = body.get("user_name")  # Optional user name

    if not isinstance(session_id, str) or not session_id:
        raise HTTPException(status_code=422, detail="session_id must be a non-empty string")
    if not isinstance(chat_input, str) or not chat_input.strip():
        return {"agent_response": "", "response_id": session_id, "used_tools": []}

    payload = {
        "sessionId": session_id,
        "chatInput": chat_input
    }

    # Include user name in payload if provided
    if user_name and isinstance(user_name, str) and user_name.strip():
        payload["userName"] = user_name.strip()

    # Allow disabling TLS verification for local dev self-signed certs via env flag.
    verify_ssl = os.getenv("AGENT_BACKEND_VERIFY_SSL", "false").lower() in ("1", "true", "yes")

    try:
        timeout = httpx.Timeout(30.0, connect=5.0)
        async with httpx.AsyncClient(verify=verify_ssl, timeout=timeout) as client:
            resp = await client.post(backend_url, json=payload)
    except httpx.RequestError as exc:
        logger.error(f"Error calling external chat service: {exc}")
        raise HTTPException(status_code=502, detail="Failed to reach external chat service")

    if resp.status_code != 200:
        logger.warning(f"External service returned status {resp.status_code}: {resp.text[:200]}")
        raise HTTPException(status_code=502, detail="External chat service error")

    try:
        data = resp.json()
    except ValueError:
        raise HTTPException(status_code=502, detail="External chat service returned invalid JSON")

    answer = data.get("answer", "")
    used_tools = data.get("usedTools") or []
    token_usage = data.get("tokenUsage")
    ext_session = data.get("sessionId") or session_id

    response_data = {
        "agent_response": answer,
        "response_id": ext_session,
        "used_tools": used_tools,
    }

    # Include token usage if available
    if token_usage:
        response_data["tokenUsage"] = token_usage

    return response_data


# Health check endpoint
@app.get("/ping", response_class=JSONResponse)
async def health_check():
    return {"status": "healthy"}


# Set exception handler for all unhandled exceptions
@app.exception_handler(Exception)
async def validation_exception_handler(request, err):
    logging.error(f"Unhandled exception: {err}", exc_info=True)
    return JSONResponse(
        status_code = 500,
        content = {
            "reason": f"{err}",
            "source": {
                "url": f"{request.url}",
                "method": f"{request.method}"
            }
        }
    )

# Run the app with Uvicorn if executed directly
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)