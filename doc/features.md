# Features

## AI Agent Backend (Semantic Kernel)
The agent backend is a Python FastAPI application that implements an intelligent AI agent using the Microsoft Semantic Kernel SDK with the following capabilities:

- **Semantic Kernel Integration:** Built on top of Microsoft's Semantic Kernel SDK for orchestrating AI interactions
- **Azure OpenAI via APIM:** Connects to Azure OpenAI models through API Management gateway for enterprise-grade security and load balancing
- **MCP Plugin Architecture:** Extensible plugin system using Model Context Protocol (MCP):
  - **Microsoft Learn Plugin:** Provides access to Microsoft technical documentation via MCP HTTP streaming
  - **Weather Plugin:** Local mock weather service demonstrating MCP stdio plugin implementation
- **Conversation Memory:** Cosmos DB-backed conversation persistence with `ChatHistory` support for maintaining context across sessions
- **Tool Tracking:** Built-in tracking of plugin/tool invocations during agent responses
- **Token Usage Reporting:** Captures and reports token consumption metrics from AI model calls
- **User Context Support:** Optional user name tracking in conversation history
- **Health Checks:** `/ping` endpoint for health monitoring

**Key Components:**
- `services/agent.py` - Agent initialization and chat completion logic
- `services/kernel.py` - Semantic Kernel configuration with Azure OpenAI via APIM
- `services/conversation_store.py` - Cosmos DB conversation memory implementation
- `services/tool_tracker.py` - Plugin/tool invocation tracking
- `mcp_plugins/` - MCP plugin implementations (Microsoft Learn, Weather)
- `routes/chat.py` - FastAPI chat endpoint
- `schemas/chat.py` - Pydantic models for request/response validation

## AI Agent Frontend
The agent frontend is a lightweight Python FastAPI web application providing a user interface for interacting with the AI agent:

- **Web Chat Interface:** Modern, responsive chat UI with real-time streaming responses
- **Session Management:** Maintains conversation sessions across multiple interactions
- **Backend Proxy:** Forwards chat requests to the agent backend via HTTP
- **Tool Visibility:** Displays which plugins/tools were used for each response
- **Token Metrics:** Shows token usage statistics when available
- **Health Checks:** `/ping` endpoint for health monitoring

**Key Files:**
- `app.py` - Frontend application with chat proxy endpoint
- `templates/index.html` - Chat interface HTML template
- `static/styles.css` - UI styling

## Azure Infrastructure Services

### API Management (APIM)
- **AI Foundry API:** Proxies requests to multiple Azure AI Foundry model deployments with intelligent load balancing
- **Managed Identity Authentication:** Passwordless authentication to Azure OpenAI using system-assigned managed identity
- **Multi-Layered Rate Limiting:** 
  - Request-based: 100 requests/minute, 6,000 requests/hour per subscription
  - Token-based: 100,000 tokens/minute, 6M tokens/hour
- **Token Metrics:** Real-time token consumption tracking and quota monitoring
- **Subscription Key Security:** All endpoints secured via APIM subscription keys (`api-key` header/query parameter)
- **Application Insights Integration:** Full diagnostics and logging of API calls with custom token metrics
- **Policy-Based Routing:** Advanced routing policies for model endpoint selection and load balancing
- **Response Headers:** Rate limit and quota information included in every response

See [Architecture](./architecture.md#33-ai-foundry-api-policies) for detailed policy documentation.

### AI Services
- **AI Foundry Hub & Project:** Azure AI Foundry hub with project (`proj-sample-01`) for AI model deployments
- **Model Deployments:** GPT-4.1 and GPT-4.1-mini (GlobalStandard SKUs) with multiple instances for load balancing
- **Managed Identity Access:** RBAC-based access using system-assigned managed identities

### Common Services
- **Key Vault:** Centralized secret management for API keys, connection strings, and credentials
- **Cosmos DB:** NoSQL database with:
  - Database: `agent_db` 
  - Container: `conversations` (partitioned by sessionId)
  - Used for conversation history persistence
- **Storage Account:** Blob, queue, table and file services for general storage needs

### Application Services
- **App Service Plan:** Shared Linux-based plan for hosting both frontend and backend
- **Frontend Web App:** Hosts the agent frontend (Python/FastAPI)
- **Backend Web App:** Hosts the agent backend (Python/FastAPI with Semantic Kernel)
- **Docker Support:** Both apps include Dockerfiles for containerized deployment

### Monitoring Services
- **Log Analytics Workspace:** Centralized log aggregation for all services
- **Application Insights:** APM solution capturing:
  - HTTP request/response telemetry
  - Agent performance metrics
  - Token usage statistics
  - Custom events and traces
- **Dashboard:** Real-time monitoring dashboard using Application Insights data

> [!NOTE]
> Both web apps are deployed with managed identities and have RBAC permissions to access Key Vault, Cosmos DB, and AI Foundry resources.

## Security

This template uses [Managed Identity](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview) and Key Vault for secure, passwordless authentication. System-assigned managed identities are configured for both web apps and API Management, with RBAC roles granting least-privilege access to Azure resources.

**RBAC Permissions:**

| Service         | Access to       | Role(s) Assigned                                          |
|-----------------|-----------------|-----------------------------------------------------------|
| Frontend App    | Key Vault       | Key Vault Secrets User                                    |
| Frontend App    | Cosmos DB       | Cosmos DB Operator; Cosmos DB Account Reader Role         |
| Backend App     | Key Vault       | Key Vault Secrets User                                    |
| Backend App     | Cosmos DB       | Cosmos DB Operator; Cosmos DB Account Reader Role         |
| Backend App     | AI Foundry      | Azure AI User (via APIM)                                  |
| API Management  | Key Vault       | Key Vault Secrets User                                    |
| API Management  | AI Foundry      | Routes to multiple AI model deployments                   |
| AI Foundry      | Key Vault       | Key Vault Secrets User                                    |
| AI Foundry      | Cosmos DB       | Cosmos DB Operator; Cosmos DB Account Reader              |
| AI Foundry      | Storage Account | Storage Blob Data Contributor                             |

**Key Vault Secrets:**
- `apim-aifoundry-api-key` - APIM subscription key for AI Foundry API access
- `cosmos-db-key` - Cosmos DB primary key for conversation storage

**Environment Variables:**
The backend agent requires the following configuration (set via App Service settings):
- `APIM_GATEWAY_ENDPOINT` - API Management gateway URL
- `APIM_SUBSCRIPTION_KEY` - APIM subscription key (from Key Vault)
- `AI_MODEL_DEPLOYMENT` - Name of the AI model deployment
- `COSMOS_ENDPOINT` - Cosmos DB account endpoint
- `COSMOS_KEY` - Cosmos DB access key (from Key Vault)
- `COSMOS_DB` - Database name (default: `agent_db`)
- `COSMOS_CONTAINER` - Container name (default: `conversations`)
- `LEARN_MCP_URL` - Microsoft Learn MCP server URL
- `APPLICATIONINSIGHTS_CONNECTION_STRING` - Application Insights connection string