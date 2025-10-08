# Copilot Instructions for Semantic Kernel AI Agent

## Architecture Overview

This is a **two-tier AI agent system** using Microsoft Semantic Kernel with Azure AI Foundry, deployed on Azure App Service with API Management gateway for intelligent load balancing.

**Key Components:**
- **Backend (`src/agent_backend/`)**: FastAPI + Semantic Kernel agent with MCP plugins
- **Frontend (`src/agent_frontend/`)**: FastAPI web UI that proxies to backend
- **Infrastructure (`infra/`)**: Bicep modules for multi-resource group deployment
- **API Gateway**: Azure APIM with token-based rate limiting and load balancing

## Critical Development Patterns

### Agent Initialization & Plugin Architecture
```python
# Pattern: Agent setup in services/agent.py
kernel = create_kernel()  # APIM-configured Azure OpenAI
learn_ctx = await microsoft_learn_mcp_plugin().__aenter__()
weather_ctx = await weather_mcp_plugin().__aenter__()
plugins = (learn_ctx, weather_ctx)
install_wrappers(*plugins)  # Tool tracking wrapper

agent = ChatCompletionAgent(
    name="SK-Agent",
    instructions=AGENT_INSTRUCTIONS,
    kernel=kernel,
    plugins=list(plugins),
    arguments=KernelArguments(PromptExecutionSettings(
        function_choice_behavior=FunctionChoiceBehavior.Auto()
    ))
)
```

### Conversation Memory Pattern
Uses `ChatHistory` from Semantic Kernel with Cosmos DB persistence:
```python
# Pattern: CosmosConversationMemory in services/conversation_store.py
self.chat_history = ChatHistory()  # In-memory semantic kernel object
self._load_history_from_cosmos()   # Populate from DB on init
# Messages are persisted as: role, content, name, metadata, timestamp
```

### MCP Plugin Registration
Plugins use `@asynccontextmanager` pattern for proper lifecycle management:
```python
# Pattern: mcp_plugins/*.py
@asynccontextmanager
async def microsoft_learn_mcp_plugin(url: str | None = None):
    async with MCPStreamableHttpPlugin(
        name="MicrosoftLearn",
        url=resolved_url,
        load_tools=True,
        load_prompts=True,
    ) as plugin:
        yield plugin
```

### Tool Usage Tracking
Custom wrapper system tracks tool invocations via thread-local storage:
```python
# Pattern: services/tool_tracker.py
set_current_used_tools(used_tools_list)  # Before agent call
# Tools automatically append to list during execution
```

## Infrastructure Conventions

### Bicep Module Structure
- **Entry point**: `infra/main.bicep` (subscription scope)
- **Resource groups**: Separate RGs for monitor, common, ai, app services
- **Module pattern**: `modules/{service}/{service}.bicep` → `resources/*.bicep`
- **Naming**: `{resourceType}-{environment}-{uniqueToken}` (e.g., `apim-dev-abc123`)

### APIM Gateway Configuration
**Critical**: All Azure OpenAI calls go through APIM (`infra/modules/apim/`):
- **Authentication**: Managed Identity to Azure AI Foundry (no API keys in APIM)
- **Rate Limiting**: 250 req/min, 15K req/hour + 25K tokens/min, 1.5M tokens/hour
- **Load Balancing**: Backend pool with multiple model deployments
- **Headers**: Token consumption metrics in response headers

### Environment Variables Pattern
Backend requires these App Service settings (populated by Bicep):
```bash
APIM_GATEWAY_ENDPOINT    # APIM gateway URL (not direct Azure OpenAI)
APIM_SUBSCRIPTION_KEY    # From Key Vault secret
AI_MODEL_DEPLOYMENT      # Deployment name (e.g., gpt-4.1)
COSMOS_ENDPOINT          # Cosmos DB account URL
COSMOS_KEY              # From Key Vault secret
LEARN_MCP_URL           # Microsoft Learn MCP server endpoint
```

## Development Workflows

### Local Development
```bash
# Backend setup
cd src/agent_backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
# Requires .env with APIM credentials

# Frontend setup  
cd src/agent_frontend
pip install -r requirements.txt
uvicorn app:app --reload --port 8000
```

### Azure Functions Alternative
Use `func: host start` task for local Azure Functions runtime (see `.vscode/tasks.json`).

### Deployment
```bash
azd up  # Full infrastructure + app deployment
azd deploy  # App code only (after infra exists)
```

## Key Integration Points

### Backend → APIM → Azure AI Foundry
```python
# services/kernel.py - Never direct Azure OpenAI calls
kernel.add_service(AzureChatCompletion(
    deployment_name=deployment,
    endpoint=endpoint,    # This is APIM gateway endpoint
    api_key=api_key      # This is APIM subscription key
))
```

### Frontend → Backend Communication
```python
# Frontend app.py proxies to backend
backend_url = os.getenv("BACKEND_URL", "http://localhost:8001")
async with httpx.AsyncClient() as client:
    response = await client.post(f"{backend_url}/chat", json=chat_data)
```

### Cosmos DB Session Management
- **Database**: `agent_db`
- **Container**: `conversations` (partitioned by `sessionId`)
- **Pattern**: Each message stored with `role`, `content`, `name`, `metadata`, `ts`

## Security Model

- **Managed Identity**: All Azure service authentication (no secrets in code)
- **Key Vault**: Only for APIM subscription keys and Cosmos DB keys
- **RBAC**: Least-privilege access (see README.md security table)
- **APIM Subscription Keys**: Required for all AI model access

## Debugging & Monitoring

- **Application Insights**: Token usage metrics, request telemetry
- **Log Analytics**: Centralized logging across all services
- **APIM Diagnostics**: Request/response logging with token headers
- **Health Checks**: `/ping` endpoints on both frontend and backend