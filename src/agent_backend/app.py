import os
import logging
import time
import sys

from fastapi import FastAPI
from fastapi.responses import JSONResponse, PlainTextResponse
from contextlib import asynccontextmanager
from services.agent import initialize_agent_and_plugins, shutdown_plugins
from services.conversation_store import CosmosConversationStore
from routes.chat import router as chat_router


# Initialize FastAPI app
app = FastAPI(title="AI Agent Backend",
              description="AI Agent Backend built on Semantic Kernel SDK for Python/FastAPI",
              version="0.0.1",
              debug=False)


# Define the lifespan context manager
@asynccontextmanager
async def lifespan(app):

    logging.basicConfig(level=logging.WARNING, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    logger = logging.getLogger("backend.app")

    try:
        kernel, agent, plugins = await initialize_agent_and_plugins()

        app.state.kernel = kernel or None
        app.state.agent = agent or None
        app.state.plugins = plugins or None

        cosmos_endpoint = os.environ.get("COSMOS_ENDPOINT")
        cosmos_key = os.environ.get("COSMOS_KEY")
        cosmos_db = os.environ.get("COSMOS_DB", "agent_db")
        cosmos_container = os.environ.get("COSMOS_CONTAINER", "conversations")

        if CosmosConversationStore and cosmos_endpoint and cosmos_key:
            try:
                store = CosmosConversationStore(
                    cosmos_endpoint,
                    cosmos_key if cosmos_key else None,
                    cosmos_db,
                    cosmos_container
                )
                app.state.conversation_store = store
                logger.info("Cosmos conversation store initialized and stored on app.state")

            except Exception:
                logger.exception("Failed to initialize Cosmos conversation store")

        logger.info("Agent and plugins initialized and stored on app.state")
        
        yield

    finally:
        try:
            await shutdown_plugins(getattr(app.state, "plugins", None))
        except Exception:
            pass


# Set the lifespan context manager
app.router.lifespan_context = lifespan


# Index route
@app.get("/")
async def index():
    version = sys.version_info
    return PlainTextResponse(content=f"Running on Python {version.major}.{version.minor}")


# Health check endpoint
@app.get("/ping", response_class=JSONResponse)
async def health_check():
    return {"status": "healthy"}


# Set middleware to intercept requests and include process time in response header 
@app.middleware("http")
async def add_process_time_header(request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = str(f'{process_time:0.4f} sec')
    return response


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


# Add API routes and prefix
app.include_router(chat_router)

# Run the app with Uvicorn if executed directly
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)