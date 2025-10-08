# Guidance

## Region Availability

This template deploys Azure AI Foundry with model deployments (GPT-4.1, GPT-4.1-mini) which may not be available in all regions. Check the current model availability and choose a supported region:

- **Model availability:** https://learn.microsoft.com/azure/ai-services/openai/concepts/models#standard-deployment-model-availability
- **Region selection:** Pick a region supporting "GlobalStandard" SKU for your required models
- **Recommended regions:** East US, East US 2, Australia East, West Europe

## Quotas

Ensure your subscription has sufficient quota for Azure OpenAI model deployments:

- **Azure OpenAI quotas:** https://learn.microsoft.com/azure/ai-services/openai/quotas-limits
- **Request increases:** Azure portal > Help + support > Service and subscription limits (quotas)
- **TPM Requirements:** Each GPT-4.1 deployment requires quota allocation (Tokens Per Minute)

## Required Dependencies

**Backend Dependencies (semantic-kernel):**
- `semantic-kernel[mcp]` - Microsoft Semantic Kernel with MCP support
- `fastapi` - Web framework
- `uvicorn` & `gunicorn` - ASGI servers
- `azure-cosmos` - Cosmos DB SDK
- `azure-identity` - Azure authentication
- `pydantic` - Data validation

**Frontend Dependencies:**
- `fastapi` - Web framework
- `jinja2` - Template engine
- `httpx` - HTTP client for backend communication

## Environment Configuration

**Required for Backend:**
| Variable | Description | Example |
|----------|-------------|---------|
| `APIM_GATEWAY_ENDPOINT` | API Management gateway URL | `https://apim-env-token.azure-api.net` |
| `APIM_SUBSCRIPTION_KEY` | APIM subscription key | Retrieved from Key Vault |
| `AI_MODEL_DEPLOYMENT` | Model deployment name | `gpt-4.1` or `gpt-4.1-mini` |
| `COSMOS_ENDPOINT` | Cosmos DB endpoint | `https://cosmos-env-token.documents.azure.com:443/` |
| `COSMOS_KEY` | Cosmos DB key | Retrieved from Key Vault |
| `COSMOS_DB` | Database name | `agent_db` |
| `COSMOS_CONTAINER` | Container name | `conversations` |
| `LEARN_MCP_URL` | Microsoft Learn MCP server | External MCP service URL |

**Required for Frontend:**
| Variable | Description | Example |
|----------|-------------|---------|
| `AGENT_BACKEND_CHAT_URL` | Backend chat endpoint | `http://agent-backend:8000/chat` |

## Monitoring and Troubleshooting

**Application Insights:**
- View agent request traces in Application Insights > Transaction search
- Monitor token usage via custom metrics
- Track plugin invocations with custom events
- Set up alerts for error rates or high latency

**Logging:**
All services log to Application Insights with structured logging:
- Request/response payloads (filtered for sensitive data)
- Tool/plugin invocation tracking
- Error traces with stack traces
- Performance metrics

**Common Issues:**

1. **"Agent not ready" error:**
   - Check that APIM_GATEWAY_ENDPOINT and APIM_SUBSCRIPTION_KEY are set
   - Verify AI model deployment exists and is accessible via APIM

2. **"Conversation store not configured":**
   - Ensure COSMOS_ENDPOINT and COSMOS_KEY are set
   - Verify Cosmos DB database and container exist

3. **MCP Plugin failures:**
   - Check LEARN_MCP_URL is reachable
   - Verify plugin initialization in Application Insights logs

4. **Token usage not reported:**
   - Ensure model responses include usage metadata
   - Check Application Insights for token metrics

5. **Rate limit errors (429 responses):**
   - Check response headers for rate limit information:
     - `x-apim-ratelimit-remaining-tokens` - Tokens left in current minute
     - `x-apim-ratelimit-remaining-quota-tokens` - Tokens left in hourly quota
   - Consider adjusting policy limits in `aifoundry-api-policy.xml`
   - Review per-client IP usage in Application Insights

6. **Managed identity authentication failures:**
   - Verify APIM has system-assigned managed identity enabled
   - Ensure RBAC role "Cognitive Services User" is assigned to APIM identity
   - Check APIM policy configuration for correct resource URL

## Security Best Practices

1. **Never commit secrets** - Use Key Vault for all sensitive configuration
2. **Use managed identities** - Enable system-assigned identities for all Azure services
3. **Apply least privilege** - Grant only necessary RBAC roles
4. **Enable diagnostic logs** - Send all logs to Log Analytics
5. **Rotate keys regularly** - Use Key Vault secret versioning
6. **Secure APIM endpoints** - Always require subscription keys
7. **Monitor access** - Review Key Vault and Cosmos DB access logs

## Performance Optimization

1. **Conversation history limiting** - Default max_items=5, adjust based on context needs
2. **APIM caching** - Consider caching policies for frequently accessed endpoints
3. **Model selection** - Use GPT-4.1-mini for faster, cost-effective responses when appropriate
4. **Concurrent requests** - APIM load balances across multiple model deployments
5. **Connection pooling** - Cosmos DB client reuses connections automatically
6. **Rate limit tuning** - Adjust APIM policy limits based on actual usage patterns:
   - Monitor rate limit headers in responses
   - Align token limits with Azure OpenAI TPM quota
   - Consider per-subscription limits for multi-tenant scenarios
7. **Token optimization** - Minimize token usage:
   - Limit conversation history (max_items)
   - Use concise system prompts
   - Implement prompt caching where applicable
   - Monitor token metrics in Application Insights

**Performance Monitoring:**

- Track `x-apim-ratelimit-consumed-tokens` header for per-request token usage
- Monitor Application Insights for token consumption trends
- Set up alerts for approaching rate limits or quota thresholds
- Review backend pool distribution in APIM analytics
