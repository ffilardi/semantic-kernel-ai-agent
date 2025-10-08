import os

from contextlib import asynccontextmanager
from dotenv import load_dotenv
from semantic_kernel.connectors.mcp import MCPStreamableHttpPlugin

load_dotenv()


@asynccontextmanager
async def microsoft_learn_mcp_plugin(url: str | None = None, headers: dict | None = None):
    resolved_url = url or os.getenv("LEARN_MCP_URL", "")
    if not resolved_url:
        raise RuntimeError("Missing LEARN_MCP_URL in environment.")

    hdrs = dict(headers) if headers else {}

    async with MCPStreamableHttpPlugin(
        name="MicrosoftLearn",
        url=resolved_url,
        headers=hdrs,
        load_tools=True,
        load_prompts=True,
    ) as plugin:
        yield plugin
