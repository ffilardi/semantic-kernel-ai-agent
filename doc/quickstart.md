# Quickstart

## Provisioning

1. In the VS Code (local or VS Code for web, if using Codespace via browser), open a terminal window.
2. Sign into your Azure account:

    ```shell
     azd auth login --use-device-code
    ```

3. Initialize the environment (optional):

    ```shell
    azd init
    ```

4. Provision Azure resources and deploy the app code:

    ```shell
    azd up
    ```
    
    This will:
    - Prompt for environment name (if not initialised yet)
    - Prompt for Azure subscription and region (if not selected yet)
    - Provision all Azure resources (App Service, APIM, AI Foundry, Cosmos DB, Key Vault, Storage, Monitoring)
    - Deploy both frontend and backend applications
    - Configure APIM endpoints and AI model load balancing

> [!NOTE]
> Alternative deployment methods:
> - For infra provisioning only, use `azd provision`
> - For code deployment only, use `azd deploy`

5. Configure GitHub CI/CD pipeline (optional, when using your own repository):

    ```shell
    azd pipeline config
    ```

6. Test the web application using a browser
    - Visit the frontend URL (typically `https://app-frontend-{env}-{token}.azurewebsites.net`)
    - Start a conversation with the AI agent
    - Ask questions about Microsoft technologies or weather forecasts
    - Observe which tools/plugins are used for each response

7. Monitor the application
    - Open Application Insights in the Azure portal
    - View real-time metrics, request traces, and custom events
    - Check the monitoring dashboard for agent performance statistics

## Local Development

### Running with Docker Compose

The easiest way to run both services locally is using Docker Compose:

```shell
cd src/
cp .env.example .env  # Create and configure your .env file
docker-compose up
```

Access the services:
- Frontend: `http://localhost:8001`
- Backend API: `http://localhost:8000`

Required environment variables in `.env`:
```env
APIM_GATEWAY_ENDPOINT=https://{apim-instance}.azure-api.net
APIM_SUBSCRIPTION_KEY={your-subscription-key}
AI_MODEL_DEPLOYMENT={deployment-name}
COSMOS_ENDPOINT=https://{cosmos-account}.documents.azure.com:443/
COSMOS_KEY={cosmos-key}
COSMOS_DB=agent_db
COSMOS_CONTAINER=conversations
LEARN_MCP_URL=https://{learn-mcp-server-url}
AGENT_BACKEND_CHAT_URL=http://agent-backend:8000/chat
```

### Backend Development (without Docker)

Run the backend agent directly with Python:

```shell
cd src/agent_backend
pip install -r requirements.txt

# Configure environment variables
export APIM_GATEWAY_ENDPOINT="https://{apim-instance}.azure-api.net"
export APIM_SUBSCRIPTION_KEY="{your-subscription-key}"
export AI_MODEL_DEPLOYMENT="{deployment-name}"
export COSMOS_ENDPOINT="https://{cosmos-account}.documents.azure.com:443/"
export COSMOS_KEY="{cosmos-key}"
export LEARN_MCP_URL="https://{learn-mcp-server-url}"

# Run with uvicorn
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

The backend will be available at `http://localhost:8000` with:
- Chat endpoint: `POST /chat`
- Health check: `GET /ping`
- Root: `GET /` (returns Python version)

### Frontend Development (without Docker)

Run the frontend separately:

```shell
cd src/agent_frontend
pip install -r requirements.txt

# Configure backend URL
export AGENT_BACKEND_CHAT_URL="http://localhost:8000/chat"

# Run with uvicorn
uvicorn app:app --host 0.0.0.0 --port 8001 --reload
```

Access the chat interface at `http://localhost:8001`

### Testing the Chat API Directly

You can test the backend chat endpoint using curl:

```shell
curl -X POST "http://localhost:8000/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "test-session-123",
    "chatInput": "What is Azure App Service?",
    "userName": "TestUser"
  }'
```

Expected response:
```json
{
  "sessionId": "test-session-123",
  "answer": "Azure App Service is...",
  "usedTools": ["MicrosoftLearn-search_microsoft_learn"],
  "tokenUsage": {
    "prompt_tokens": 150,
    "completion_tokens": 85,
    "total_tokens": 235
  }
}
```

### MCP Plugin Development

The backend uses two types of MCP plugins:

**HTTP Streaming Plugin (Microsoft Learn):**
```python
# mcp_plugins/mcp_microsoft_learn.py
async with MCPStreamableHttpPlugin(
    name="MicrosoftLearn",
    url=os.getenv("LEARN_MCP_URL"),
    load_tools=True,
    load_prompts=True,
) as plugin:
    yield plugin
```

**Stdio Plugin (Weather - runs as subprocess):**
```python
# mcp_plugins/mcp_weather.py
async with MCPStdioPlugin(
    name="Weather",
    command=sys.executable,
    args=[os.path.abspath(__file__)],
) as plugin:
    yield plugin
```

To add new MCP plugins:
1. Create a new file in `src/agent_backend/mcp_plugins/`
2. Implement the plugin context manager
3. Register it in `services/agent.py` in the `initialize_agent_and_plugins()` function

## Extending the Solution

### Adding New Infrastructure Resources

The solution follows a modular Bicep architecture:

```
infra/
├── main.bicep                 # Main orchestration file
├── main.parameters.json       # Environment-specific parameters
└── modules/
    ├── ai/                    # AI Foundry & model deployments
    ├── apim/                  # API Management configuration
    │   ├── api/               # API definitions (OpenAPI/Swagger)
    │   ├── policies/          # APIM policy XML files
    │   └── resources/         # APIM service Bicep modules
    ├── app/                   # App Service resources
    ├── cosmosdb/              # Cosmos DB configuration
    ├── keyvault/              # Key Vault configuration
    ├── monitor/               # Monitoring and logging
    ├── security/              # RBAC configurations
    └── storage/               # Storage account configuration
```

To add new Azure services:

1. Create or reuse a module under `infra/modules/<service>/`
2. Reference the module from `infra/main.bicep`
3. Grant RBAC permissions via security modules (`infra/modules/security/`)
4. Update `main.parameters.json` with any required parameters
5. Add necessary outputs for application configuration

**Example: Adding a new storage service**
```bicep
// In infra/main.bicep
module newStorage './modules/storage/storage.bicep' = {
  name: 'new-storage'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    location: location
    tags: tags
    storageName: 'stnew${token}'
  }
}
```

### Adding Semantic Kernel Plugins

To extend agent capabilities with new plugins:

1. **Create a plugin class:**
```python
# src/agent_backend/mcp_plugins/mcp_custom.py
from semantic_kernel.functions import kernel_function

class CustomPlugin:
    @kernel_function(description="Your function description")
    async def my_function(self, parameter: str) -> dict:
        # Your implementation
        return {"result": "..."}
```

2. **Register in agent initialization:**
```python
# In src/agent_backend/services/agent.py
from mcp_plugins.mcp_custom import custom_mcp_plugin

async def initialize_agent_and_plugins():
    # ... existing code ...
    custom_ctx = await custom_mcp_plugin().__aenter__()
    plugins = (learn_ctx, weather_ctx, custom_ctx)
    # ... rest of initialization
```

3. **Update agent instructions if needed:**
```python
AGENT_INSTRUCTIONS = """
    You are helpful AI agent.
    You can now also <describe new capability>.
    """.strip()
```

### Customizing Conversation Storage

The Cosmos DB conversation store can be extended:

```python
# In src/agent_backend/services/conversation_store.py
class CosmosConversationMemory:
    def add_metadata(self, metadata: dict):
        """Add custom metadata to conversation"""
        # Your implementation
    
    def search_history(self, query: str):
        """Search conversation history"""
        # Your implementation
```

### Modifying APIM Policies

APIM policies control request routing, authentication, rate limiting, and transformation. The main policy file is located at `infra/modules/apim/policies/aifoundry-api-policy.xml`.

**Key Policy Components:**

1. **Authentication (Managed Identity)**
```xml
<authentication-managed-identity
    resource="https://cognitiveservices.azure.com/"
    output-token-variable-name="managed-id-access-token"
/>
```

2. **Rate Limiting (Requests)**
```xml
<rate-limit-by-key calls="100" renewal-period="60" />
<quota-by-key calls="6000" renewal-period="3600" />
```

3. **Token Limiting**
```xml
<llm-token-limit
    tokens-per-minute="100000"
    token-quota="6000000"
    token-quota-period="Hourly"
/>
```

**Common Customizations:**

**Increase rate limits for higher traffic:**
```xml
<rate-limit-by-key
    calls="500"
    renewal-period="60"
    counter-key="@(context.Subscription?.Key ?? "anonymous")"
/>
```

**Add custom headers to requests:**
```xml
<inbound>
    <base />
    <set-header name="X-Custom-Header" exists-action="override">
        <value>custom-value</value>
    </set-header>
    <!-- ... rest of policies -->
</inbound>
```

**Add request/response logging:**
```xml
<outbound>
    <base />
    <log-to-eventhub>
        @{
            return new JObject(
                new JProperty("request-id", context.RequestId),
                new JProperty("subscription-key", context.Subscription?.Key),
                new JProperty("tokens-consumed", context.Variables["tokens-consumed"])
            ).ToString();
        }
    </log-to-eventhub>
</outbound>
```

**Testing Policy Changes Locally:**

Before deploying, you can test policy expressions using APIM's policy test console in the Azure Portal:
1. Navigate to your APIM instance
2. Select APIs > AI Foundry API
3. Select "All operations" or specific operation
4. Click "Test" tab
5. Modify policies inline and test with sample requests

After modifying policies, redeploy with `azd up` or `azd deploy`.

**Policy Best Practices:**
- Always test policy changes in a development environment first
- Monitor Application Insights after policy changes for unexpected behavior
- Use policy fragments for reusable policy components
- Document custom policy logic with XML comments
- Keep rate limits aligned with Azure OpenAI quota allocations

See [Architecture](./architecture.md#33-ai-foundry-api-policies) for complete policy documentation.

**API version discovery**

Use Azure CLI locally or in Codespaces/Dev Containers to list provider API versions when introducing new resources:

```shell
az provider show --namespace Microsoft.Web --query "resourceTypes[?resourceType=='sites'].apiVersions" -o tsv
```

## Cleaning-up

To remove all resources at once, including the resource groups, and purge any soft-deleted service, just run:

```shell
azd down --purge
```

> [!NOTE]
> Azd will scan and list all the resource(s) to be deleted and their respective groups, within the current environment, asking for a confirmation before proceeding. Keep the terminal open during the process until it's done.