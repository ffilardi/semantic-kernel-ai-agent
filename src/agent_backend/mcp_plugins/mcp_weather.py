import sys
import os
import random
import asyncio

from contextlib import asynccontextmanager
from dotenv import load_dotenv
from datetime import datetime, timezone

from semantic_kernel.connectors.mcp import MCPStdioPlugin
from semantic_kernel.connectors.mcp import create_mcp_server_from_functions
from semantic_kernel.functions import kernel_function

load_dotenv()


class WeatherPlugin:
    @kernel_function(description="Return weather for a single city. Provide city as a string parameter.")
    async def get_weather_for_city(self, city: str) -> dict:
        now = datetime.now(timezone.utc).isoformat()
        temp_c = random.randint(-10, 40)
        await asyncio.sleep(0.02)
        return {
            "city": city,
            "temperature": f"{temp_c} \u00b0C",
            "units": "C",
            "timestamp": now,
        }


async def _create_server():
    plugin = WeatherPlugin()
    server = create_mcp_server_from_functions(
        plugin,
        server_name="WeatherMCP",
        plugin_name="weather",
        version="0.1.0",
        instructions="Mock Weather MCP server exposing simple weather tools for demonstration.",
    )
    return server


@asynccontextmanager
async def weather_mcp_plugin():
    python = sys.executable or "python"
    async with MCPStdioPlugin(
        name="Weather",
        description="Local mock Weather MCP server (top capitals temperatures)",
        command=python,
        args=[os.path.abspath(__file__)],
        env={},
    ) as plugin:
        yield plugin


async def _run_stdio_server():
    from mcp.server.stdio import stdio_server
    server = await _create_server()
    init_options = server.create_initialization_options()
    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, init_options)


def main():
    try:
        asyncio.run(_run_stdio_server())
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
