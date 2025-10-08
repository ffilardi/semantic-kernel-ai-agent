import sys
import time
import logging
from fastapi import FastAPI
from fastapi.responses import HTMLResponse, JSONResponse

# Configure logging
logging.basicConfig(level=logging.ERROR, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')

# Create FastAPI app instance
app = FastAPI(title="Hello World Web App", version="1.0.0")

# Index route
@app.get("/", response_class=HTMLResponse)
async def index():
    python_version = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Hello World - Python Web App</title>
        <style>
            body {{
                font-family: Arial, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                margin: 0;
                padding: 0;
                display: flex;
                justify-content: center;
                align-items: center;
                min-height: 100vh;
                color: white;
            }}
            .container {{
                text-align: center;
                padding: 2rem;
                background: rgba(255, 255, 255, 0.1);
                border-radius: 15px;
                backdrop-filter: blur(10px);
                box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
                border: 1px solid rgba(255, 255, 255, 0.18);
            }}
            h1 {{
                font-size: 3rem;
                margin-bottom: 1rem;
                text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);
            }}
            .version {{
                font-size: 1.5rem;
                margin-top: 1rem;
                opacity: 0.9;
            }}
            .powered-by {{
                font-size: 1rem;
                margin-top: 2rem;
                opacity: 0.7;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🌍 Hello, World! 🌍</h1>
            <div class="version">
                🐍 Running on Python {python_version}
            </div>
            <div class="powered-by">
                Powered by FastAPI on Azure
            </div>
        </div>
    </body>
    </html>
    """
    return html_content

# Sample API endpoint
@app.get("/api/helloworld", response_class=JSONResponse)
async def hello_world_api():
    python_version = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    return {
        "message": "Hello, World!",
        "python_version": python_version,
        "framework": "FastAPI",
        "platform": "Azure"
    }

# Health check endpoint
@app.get("/health", response_class=JSONResponse)
async def health_check():
    return {"status": "healthy", "message": "Hello World app is running!"}

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

# Run the FastAPI app using Uvicorn server
if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)