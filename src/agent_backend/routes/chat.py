from fastapi import APIRouter, HTTPException, Request
from schemas.chat import ChatRequest, ChatResponse, TokenUsage
from services.tool_tracker import set_current_used_tools
from services.agent import ask_agent_with_memory


router = APIRouter()

@router.post("/chat", response_model=ChatResponse)
async def chat_endpoint(req: ChatRequest, request: Request):
    agent = getattr(request.app.state, "agent", None)

    if agent is None:
        raise HTTPException(status_code=503, detail="Agent not ready")

    session_id = req.sessionId
    question = req.chatInput
    user_name = req.userName  # Extract optional user name

    # Short-circuit if the user prompt is empty/whitespace-only to avoid unnecessary agent call.
    if not question or not question.strip():
        return ChatResponse(sessionId=session_id, answer="", usedTools=[])

    # Conversation memory backed by Cosmos DB
    store = getattr(request.app.state, "conversation_store", None)
    if store is None:
        raise HTTPException(status_code=503, detail="Conversation store not configured")

    mem = store.get_memory(session_id, max_items=5)

    used_tools_list: list[str] = []
    set_current_used_tools(used_tools_list)

    answer, token_usage = await ask_agent_with_memory(agent, mem, question, used_tools_list, user_name)

    set_current_used_tools(None)

    # Create TokenUsage object if we have token usage information
    token_usage_obj = None
    if token_usage:
        token_usage_obj = TokenUsage(**token_usage)

    return ChatResponse(
        sessionId=session_id, 
        answer=answer, 
        usedTools=used_tools_list,
        tokenUsage=token_usage_obj
    )
