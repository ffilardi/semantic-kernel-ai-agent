from pydantic import BaseModel
from typing import Optional


class TokenUsage(BaseModel):
    """Token usage information from the AI model."""
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int


class ChatRequest(BaseModel):
    """Request body for the /chat endpoint."""
    sessionId: str
    chatInput: str
    userName: Optional[str] = None  # Optional user name for chat history


class ChatResponse(BaseModel):
    """Response returned by the /chat endpoint."""
    sessionId: str
    answer: str
    usedTools: list[str]
    tokenUsage: Optional[TokenUsage] = None
