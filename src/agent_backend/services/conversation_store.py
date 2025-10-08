import datetime
import uuid
import logging

from typing import Any, List, Optional, Dict
from azure.cosmos import CosmosClient, PartitionKey
from semantic_kernel.contents.chat_history import ChatHistory
from semantic_kernel.contents import ChatMessageContent
from semantic_kernel.contents.utils.author_role import AuthorRole


class CosmosConversationMemory:
    """Modern ChatHistory-backed memory implementation with Cosmos DB persistence.

    Maintains a `ChatHistory` instance from semantic_kernel with full support for:
    - System, user, assistant, and tool roles
    - Message names/authors 
    - Rich message content with metadata
    - Full ChatHistory rendering via as_text()
    """

    def __init__(self, container: Any, session_id: str, max_items: int = 5) -> None:
        self.container = container
        self.session_id = session_id
        self.max_items = max_items

        # Keep an in-memory ChatHistory to satisfy the user's request to use that class.
        if ChatHistory is None:
            raise RuntimeError("semantic-kernel is required for ChatHistory but not available")

        self.chat_history = ChatHistory()

        # Load existing messages from Cosmos and populate the ChatHistory
        self._load_history_from_cosmos()

    def _load_history_from_cosmos(self) -> None:
        """Load conversation history from Cosmos DB into ChatHistory object."""
        try:
            query = """
                SELECT c.role, c.content, c.name, c.metadata, c.ts 
                FROM c
                WHERE c.sessionId = @sid
                ORDER BY c.ts DESC
                OFFSET 0 LIMIT @max_items
            """
            params = [
                {"name": "@sid", "value": self.session_id},
                {"name": "@max_items", "value": self.max_items}
            ]
            items = list(self.container.query_items(query=query, parameters=params, enable_cross_partition_query=True))

            # Reverse to get chronological order
            items = list(reversed(items))

            for item in items:
                self._add_message_to_chat_history(
                    role=item.get("role"),
                    content=item.get("content"),
                    name=item.get("name"),
                    metadata=item.get("metadata", {})
                )
                        
        except Exception as e:
            logging.warning(f"Failed to load chat history from Cosmos: {e}")
            # If the query fails, don't block initialization; keep an empty ChatHistory
            pass

    def _add_message_to_chat_history(self, role: str, content: str, name: Optional[str] = None, metadata: Optional[Dict] = None) -> None:
        """Add a message to the ChatHistory with support for roles and names."""
        # Convert string role to AuthorRole enum
        if isinstance(role, str):
            role_mapping = {
                "user": AuthorRole.USER,
                "assistant": AuthorRole.ASSISTANT,
                "system": AuthorRole.SYSTEM,
                "tool": AuthorRole.TOOL
            }
            author_role = role_mapping.get(role.lower(), AuthorRole.USER)
        else:
            author_role = role

        # Create ChatMessageContent with role, content, and optional name
        message = ChatMessageContent(
            role=author_role,
            content=content,
            name=name,
            metadata=metadata or {}
        )
        
        self.chat_history.add_message(message)

    def add_message(self, role: str, content: str, name: Optional[str] = None, 
                   metadata: Optional[Dict] = None, used_tools: List[str] | None = None) -> None:
        """Add a message with specified role, content, name and metadata."""
        # Update in-memory ChatHistory first
        self._add_message_to_chat_history(role, content, name, metadata)
        
        # Persist to Cosmos
        doc = {
            "id": str(uuid.uuid4()),
            "sessionId": self.session_id,
            "role": role.lower() if isinstance(role, str) else role.value.lower(),
            "content": content.strip(),
            "name": name,
            "metadata": metadata or {},
            "ts": datetime.datetime.utcnow().isoformat(),
            "usedTools": used_tools or [],
        }
        self.container.create_item(body=doc)

    def add_user_message(self, content: str, name: Optional[str] = None, 
                        metadata: Optional[Dict] = None) -> None:
        """Add a user message with optional name and metadata."""
        self.add_message(AuthorRole.USER.value, content, name, metadata)

    def add_assistant_message(self, content: str, name: Optional[str] = None, 
                            metadata: Optional[Dict] = None, used_tools: List[str] | None = None) -> None:
        """Add an assistant message with optional name and metadata."""
        self.add_message(AuthorRole.ASSISTANT.value, content, name, metadata, used_tools)

    def add_system_message(self, content: str, name: Optional[str] = None, 
                          metadata: Optional[Dict] = None) -> None:
        """Add a system message with optional name and metadata."""
        self.add_message(AuthorRole.SYSTEM.value, content, name, metadata)

    def add_tool_message(self, content: str, name: Optional[str] = None, 
                        metadata: Optional[Dict] = None) -> None:
        """Add a tool message with optional name and metadata."""
        self.add_message(AuthorRole.TOOL.value, content, name, metadata)

    def as_text(self) -> str:
        """Render the conversation history as text using ChatHistory's string representation."""
        return str(self.chat_history)

    def get_messages(self) -> List[ChatMessageContent]:
        """Get all messages in the ChatHistory."""
        return list(self.chat_history.messages)

    def clear(self) -> None:
        """Clear the conversation history."""
        self.chat_history = ChatHistory()

    def get_message_count(self) -> int:
        """Get the number of messages in the chat history."""
        return len(self.chat_history.messages)


class CosmosConversationStore:
    """Helper to manage Cosmos DB client + container for conversation history."""
    def __init__(
        self,
        endpoint: str,
        key: str | None,
        database: str,
        container: str,
        create_if_not_exists: bool = True
    ) -> None:
        if CosmosClient is None:
            raise RuntimeError("azure-cosmos not available")

        if not key:
            raise RuntimeError("COSMOS_KEY not provided for key-based auth")
        
        self.client = CosmosClient(endpoint, key)

        if create_if_not_exists:
            self.database = self.client.create_database_if_not_exists(database)
            self.container = self.database.create_container_if_not_exists(
                id=container, partition_key=PartitionKey(path="/sessionId")
            )
        else:
            self.database = self.client.get_database_client(database)
            self.container = self.database.get_container_client(container)

    def get_memory(self, session_id: str, max_items: int = 5) -> CosmosConversationMemory:
        return CosmosConversationMemory(self.container, session_id, max_items=max_items)
