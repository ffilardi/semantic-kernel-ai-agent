import asyncio
import logging

from typing import Any, List, Tuple, Optional

from fastapi import HTTPException
from semantic_kernel.agents import ChatCompletionAgent
from semantic_kernel.functions import KernelArguments
from semantic_kernel.contents.chat_history import ChatHistory
from semantic_kernel.contents import ChatMessageContent
from semantic_kernel.contents.utils.author_role import AuthorRole
from semantic_kernel.connectors.ai.prompt_execution_settings import PromptExecutionSettings
from semantic_kernel.connectors.ai import FunctionChoiceBehavior

from services.kernel import create_kernel
from services.tool_tracker import install_wrappers
from mcp_plugins.mcp_microsoft_learn import microsoft_learn_mcp_plugin
from mcp_plugins.mcp_weather import weather_mcp_plugin


AGENT_INSTRUCTIONS = """
    You are helpful AI agent.
    Answer any questions about Microsoft technology stack or Microsoft Azure services based on available Microsoft documentation tools. Answer questions about weather forecast using the available weather tools.
    When calling a tool, summarize the response concisely.
    """.strip()


# Initialize kernel, plugins and create the ChatCompletionAgent.
async def initialize_agent_and_plugins() -> Tuple[object, ChatCompletionAgent, Tuple[object, ...]]:
    """Returns a tuple (kernel, agent, plugins_contexts).
    
    The caller is responsible for calling `shutdown_plugins(plugins_contexts)` when appropriate.
    """
    logging.basicConfig(level=logging.WARNING, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    logger = logging.getLogger("backend.app.services.agent")

    kernel = create_kernel()

    learn_ctx = await microsoft_learn_mcp_plugin().__aenter__()
    weather_ctx = await weather_mcp_plugin().__aenter__()
    plugins = (learn_ctx, weather_ctx)

    for p in plugins:
        try:
            if hasattr(p, "connect"):
                maybe_conn = p.connect()
                if asyncio.iscoroutine(maybe_conn):
                    await maybe_conn
        except Exception:
            logger.warning("Plugin %s connect() failed or not required", getattr(p, "name", repr(p)))

    install_wrappers(*plugins)

    agent = ChatCompletionAgent(
        name="SK-Agent",
        instructions=AGENT_INSTRUCTIONS,
        kernel=kernel,
        plugins=list(plugins),
        arguments=KernelArguments(
            PromptExecutionSettings(function_choice_behavior=FunctionChoiceBehavior.Auto())
        )
    )
    logger.info("Agent and plugins started")
    return kernel, agent, plugins


async def shutdown_plugins(plugins):
    if not plugins:
        return
    for p in plugins:
        try:
            await p.__aexit__(None, None, None)
        except Exception:
            pass


# Compose a prompt including conversation memory and return the combined answer string.
async def ask_agent_with_memory(agent: ChatCompletionAgent, memory: Any, question: str, used_tools: List[str], user_name: Optional[str] = None) -> tuple[str, Optional[dict]]:
    """Invoke the agent streaming its response, persist in memory, return answer and token usage.

    Args:
        agent: The AI agent instance
        memory: Conversation memory store
        question: User's question/input
        used_tools: List to track tools used during response
        user_name: Optional name of the user asking the question

    Returns:
        Tuple of (answer_string, token_usage_dict)

    Raises:
        HTTPException: On agent invocation failure with appropriate status code and detail
    """
    import json

    # Use ChatHistory rendering when the memory wrapper exposes it.
    try:
        messages: List[str | ChatMessageContent] = list()
        if hasattr(memory, "chat_history") and memory.chat_history is not None:
            chat_history: ChatHistory = memory.chat_history
            messages = list(chat_history.messages)
        
        messages.append(ChatMessageContent(role=AuthorRole.USER, content=question, name=user_name))
    except Exception:
        logging.exception("Failed retrieving chat history")

    parts: List[str] = []
    token_usage = None

    try:
        async for item in agent.invoke(messages):
            try:
                parts.append(str(item).strip())
                
                # Extract token usage from the first response item
                if token_usage is None and hasattr(item, 'metadata') and item.metadata:
                    usage_data = item.metadata.get('usage')
                    if usage_data:
                        token_usage = {
                            'prompt_tokens': getattr(usage_data, 'prompt_tokens', 0),
                            'completion_tokens': getattr(usage_data, 'completion_tokens', 0),
                            'total_tokens': getattr(usage_data, 'prompt_tokens', 0) + getattr(usage_data, 'completion_tokens', 0)
                        }
            except Exception:
                # Fallback representation for non-stringable parts
                parts.append(repr(item))

        answer = "\n".join(p for p in parts if p)

        try:
            # Use the modern conversation store methods with optional user name
            memory.add_user_message(question, name=user_name)
            memory.add_assistant_message(answer, used_tools=used_tools)
        except Exception:
            logging.exception("Failed storing answer in memory")
            
        return answer, token_usage

    except Exception as exc:
        error_code: str | None = "InternalError"
        error_message: str = str(exc)

        def _extract_from_dict(d: dict):
            nonlocal error_code, error_message
            if 'error' in d:
                err = d['error'] or {}
                error_code = err.get('code') or (err.get('innererror') or {}).get('code') or error_code
                error_message = err.get('message', error_message)

        for arg in getattr(exc, 'args', []):
            if isinstance(arg, dict):
                _extract_from_dict(arg)
                if error_code or 'error' in arg:
                    break
            elif isinstance(arg, str) and arg.strip().startswith('{') and arg.strip().endswith('}'):
                try:
                    data = json.loads(arg)
                    if isinstance(data, dict):
                        _extract_from_dict(data)
                        if error_code:
                            break
                except Exception:
                    pass  # Ignore JSON parse errors

        logging.exception("Agent invocation failed (code=%s)", error_code)
        
        # Map error codes to appropriate HTTP status codes
        status_code = 500  # Default to internal server error
        if error_code in ["RateLimited", "ThrottledError", "429"]:
            status_code = 429
        elif error_code in ["Unauthorized", "401"]:
            status_code = 401
        elif error_code in ["Forbidden", "403"]:
            status_code = 403
        elif error_code in ["BadRequest", "InvalidRequest", "400"]:
            status_code = 400
        elif error_code in ["ServiceUnavailable", "503"]:
            status_code = 503
            
        raise HTTPException(status_code=status_code, detail=error_message)
