# MCP Servers Guide

## Overview

The Semantic Kernel AI Agent uses the [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) to extend the AI agent's capabilities through external tools and data sources. MCP provides a standardized way for AI applications to securely connect to external resources and services.

This document explains the MCP servers available in this project, how they work, and how to integrate new ones.

## What is MCP?

Model Context Protocol (MCP) is an open protocol that enables secure connections between AI applications and external data sources. It allows AI agents to:

- Access real-time data from external APIs
- Interact with databases and file systems
- Use specialized tools and services
- Maintain security boundaries between the AI and external resources

## Available MCP Servers

### 1. Microsoft Learn MCP Server

**Type**: HTTP-based external server  
**Plugin File**: `src/agent_backend/mcp_plugins/mcp_microsoft_learn.py`  
**Purpose**: Provides access to official Microsoft documentation and learning resources

#### Features
- Search Microsoft Learn documentation
- Retrieve code samples and tutorials
- Access Azure service documentation
- Get troubleshooting guides and best practices

#### Configuration
```python
# Environment variable
LEARN_MCP_URL=https://{microsoft-learn-mcp-server-url}
```

#### Usage Pattern
```python
@asynccontextmanager
async def microsoft_learn_mcp_plugin(url: str | None = None, headers: dict | None = None):
    resolved_url = url or os.getenv("LEARN_MCP_URL", "")
    if not resolved_url:
        raise RuntimeError("Missing LEARN_MCP_URL in environment.")

    async with MCPStreamableHttpPlugin(
        name="MicrosoftLearn",
        url=resolved_url,
        headers=headers or {},
        load_tools=True,
        load_prompts=True,
    ) as plugin:
        yield plugin
```

#### Tools Available
- Documentation search and retrieval
- Code sample extraction
- API reference lookup
- Tutorial and guide access

### 2. Weather MCP Server

**Type**: Local STDIO-based server  
**Plugin File**: `src/agent_backend/mcp_plugins/mcp_weather.py`  
**Purpose**: Provides mock weather data for demonstration and testing

#### Features
- Get weather information for cities
- Mock temperature data with realistic ranges
- Timestamp information for data freshness
- Asynchronous weather data retrieval

#### Implementation
This server runs as a local subprocess using the STDIO transport method:

```python
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
```

#### Tools Available
- `get_weather_for_city(city: str)` - Returns weather data for a specified city

#### Sample Response
```json
{
    "city": "London",
    "temperature": "18 °C",
    "units": "C",
    "timestamp": "2025-10-09T10:30:00.000Z"
}
```

## Architecture

### Plugin Lifecycle Management

All MCP plugins in this project use the `@asynccontextmanager` pattern to ensure proper resource management:

1. **Initialization**: Plugin context is created and connection established
2. **Registration**: Plugin is registered with the Semantic Kernel agent
3. **Usage**: Agent can invoke plugin tools during conversations
4. **Cleanup**: Plugin resources are properly cleaned up when context exits

### Integration with Semantic Kernel Agent

The agent initialization process in `src/agent_backend/services/agent.py` follows this pattern:

```python
async def initialize_agent_and_plugins():
    kernel = create_kernel()
    
    # Initialize MCP plugin contexts
    learn_ctx = await microsoft_learn_mcp_plugin().__aenter__()
    weather_ctx = await weather_mcp_plugin().__aenter__()
    plugins = (learn_ctx, weather_ctx)
    
    # Install tool tracking wrappers
    install_wrappers(*plugins)
    
    # Create agent with plugins
    agent = ChatCompletionAgent(
        name="SK-Agent",
        instructions=AGENT_INSTRUCTIONS,
        kernel=kernel,
        plugins=list(plugins),
        arguments=KernelArguments(PromptExecutionSettings(
            function_choice_behavior=FunctionChoiceBehavior.Auto()
        ))
    )
    
    return kernel, agent, plugins
```

### Tool Tracking

The system includes a tool tracking mechanism (`src/agent_backend/services/tool_tracker.py`) that monitors which MCP tools are used during conversations. This enables:

- Usage analytics and monitoring
- Debugging tool invocation issues
- Performance optimization
- Audit trails for tool usage

## MCP Server Types

### HTTP-based Servers (External)

**Example**: Microsoft Learn MCP Server

- **Transport**: HTTP/HTTPS
- **Location**: External service
- **Connection**: `MCPStreamableHttpPlugin`
- **Configuration**: URL endpoint required
- **Security**: Headers and authentication supported

**Advantages**:
- Scalable external services
- Real-time data access
- Centralized maintenance
- Shared across multiple clients

**Use Cases**:
- API integrations
- Live data feeds
- External documentation systems
- Third-party services

### STDIO-based Servers (Local)

**Example**: Weather MCP Server

- **Transport**: Standard Input/Output
- **Location**: Local subprocess
- **Connection**: `MCPStdioPlugin`
- **Configuration**: Python executable path
- **Security**: Sandboxed execution

**Advantages**:
- Self-contained functionality
- No external dependencies
- Fast local execution
- Deterministic behavior

**Use Cases**:
- Mock/demo services
- Local file system access
- Computational tools
- Development and testing

## Adding New MCP Servers

### Step 1: Create Plugin Module

Create a new Python file in `src/agent_backend/mcp_plugins/`:

```python
# src/agent_backend/mcp_plugins/mcp_example.py
import os
from contextlib import asynccontextmanager
from semantic_kernel.connectors.mcp import MCPStreamableHttpPlugin

@asynccontextmanager
async def example_mcp_plugin(url: str | None = None):
    resolved_url = url or os.getenv("EXAMPLE_MCP_URL", "")
    if not resolved_url:
        raise RuntimeError("Missing EXAMPLE_MCP_URL in environment.")
    
    async with MCPStreamableHttpPlugin(
        name="Example",
        url=resolved_url,
        load_tools=True,
        load_prompts=True,
    ) as plugin:
        yield plugin
```

### Step 2: Register with Agent

Update `src/agent_backend/services/agent.py`:

```python
from mcp_plugins.mcp_example import example_mcp_plugin

async def initialize_agent_and_plugins():
    # ... existing code ...
    
    learn_ctx = await microsoft_learn_mcp_plugin().__aenter__()
    weather_ctx = await weather_mcp_plugin().__aenter__()
    example_ctx = await example_mcp_plugin().__aenter__()  # Add new plugin
    plugins = (learn_ctx, weather_ctx, example_ctx)
    
    # ... rest of function ...
```

### Step 3: Configure Environment

Add environment variable to your deployment configuration:

**For local development** (`.env` file):
```bash
EXAMPLE_MCP_URL=https://your-mcp-server-url
```

**For Azure deployment** (`infra/modules/app/app.bicep`):
```bicep
{
  name: 'EXAMPLE_MCP_URL'
  value: exampleMcpUrl
}
```

### Step 4: Update Agent Instructions

Modify the `AGENT_INSTRUCTIONS` in `src/agent_backend/services/agent.py` to include guidance for the new plugin:

```python
AGENT_INSTRUCTIONS = """
You are helpful AI agent.
Answer any questions about Microsoft technology stack or Microsoft Azure services based on available Microsoft documentation tools. 
Answer questions about weather forecast using the available weather tools.
Use the example plugin for [describe your plugin's purpose].
When calling a tool, summarize the response concisely.
""".strip()
```

## Best Practices

### Error Handling

Always implement proper error handling for MCP connections:

```python
@asynccontextmanager
async def robust_mcp_plugin():
    try:
        async with MCPStreamableHttpPlugin(...) as plugin:
            yield plugin
    except Exception as e:
        logger.error(f"MCP plugin failed to initialize: {e}")
        # Consider fallback behavior or re-raise
        raise
```

### Connection Management

Use the `@asynccontextmanager` pattern to ensure proper cleanup:

```python
# Good: Proper resource management
async with mcp_plugin() as plugin:
    # Use plugin
    pass
# Plugin is automatically cleaned up

# Bad: Manual cleanup required
plugin = await mcp_plugin().__aenter__()
try:
    # Use plugin
    pass
finally:
    await plugin.__aexit__(None, None, None)
```

### Security Considerations

- **Environment Variables**: Store sensitive configuration in environment variables
- **Headers**: Use authentication headers for HTTP-based servers
- **Validation**: Validate all inputs to MCP tools
- **Sandboxing**: Consider security implications of STDIO-based servers

### Performance Optimization

- **Connection Pooling**: Reuse HTTP connections where possible
- **Caching**: Implement appropriate caching for frequently accessed data
- **Timeouts**: Set reasonable timeouts for external MCP servers
- **Monitoring**: Track tool usage and performance metrics

## Debugging MCP Issues

### Common Problems

1. **Connection Failures**
   - Check environment variables are set correctly
   - Verify MCP server URLs are accessible
   - Review network connectivity and firewall rules

2. **Tool Not Available**
   - Ensure plugin is properly registered with agent
   - Check MCP server is running and healthy
   - Verify tool definitions match expected interface

3. **Authentication Errors**
   - Validate API keys and headers
   - Check permissions and access controls
   - Review authentication token expiration

### Debugging Tools

**Enable detailed logging**:
```python
import logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger("semantic_kernel.connectors.mcp")
```

**Check plugin registration**:
```python
# In agent initialization
for plugin in plugins:
    print(f"Plugin: {plugin.name}, Tools: {len(plugin.tools)}")
```

**Monitor tool usage**:
```python
from services.tool_tracker import get_current_used_tools
# After agent execution
used_tools = get_current_used_tools()
print(f"Tools used: {used_tools}")
```

## Security Model

### MCP Security Boundaries

MCP provides several security mechanisms:

1. **Protocol-level Security**: Encrypted transport for HTTP-based servers
2. **Authentication**: Token-based authentication for external servers
3. **Sandboxing**: Process isolation for STDIO-based servers
4. **Validation**: Input/output validation at protocol boundaries

### Implementation Security

This implementation adds additional security layers:

- **Environment Variable Configuration**: Sensitive URLs and keys stored in environment
- **Azure Key Vault Integration**: Production secrets managed in Key Vault
- **Managed Identity**: Azure services authentication without stored credentials
- **Network Security**: APIM gateway provides additional security controls

## Monitoring and Observability

### Built-in Monitoring

The system includes monitoring capabilities through:

- **Application Insights**: Tool usage telemetry and performance metrics
- **Tool Tracking**: Detailed logging of MCP tool invocations
- **Health Checks**: Plugin connectivity and health monitoring
- **Error Logging**: Comprehensive error tracking and debugging

### Custom Monitoring

You can add custom monitoring for MCP servers:

```python
import time
from contextlib import asynccontextmanager

@asynccontextmanager
async def monitored_mcp_plugin():
    start_time = time.time()
    try:
        async with original_mcp_plugin() as plugin:
            logger.info(f"MCP plugin {plugin.name} initialized in {time.time() - start_time:.2f}s")
            yield plugin
    except Exception as e:
        logger.error(f"MCP plugin failed: {e}")
        raise
    finally:
        logger.info(f"MCP plugin session ended after {time.time() - start_time:.2f}s")
```

## References

- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [Semantic Kernel MCP Documentation](https://learn.microsoft.com/en-us/semantic-kernel/)
- [Azure AI Foundry Integration](../README.md#azure-ai-foundry-integration)
- [Deployment Guide](./quickstart.md)
- [Security Configuration](./features.md#security-model)