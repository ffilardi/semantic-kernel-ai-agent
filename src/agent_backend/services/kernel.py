import os

from dotenv import load_dotenv
from semantic_kernel import Kernel
from semantic_kernel.connectors.ai.open_ai import AzureChatCompletion

load_dotenv()


# Create and return a configured Semantic Kernel instance using API Management gateway.
def create_kernel(endpoint: str | None = None, deployment: str | None = None, api_key: str | None = None):
    """
    Create a configured Semantic Kernel instance using API Management gateway.
    
    Args:
        endpoint: APIM gateway endpoint URL
        deployment: Model deployment name
        api_key: APIM subscription key for authentication
    """
    # API Management gateway configuration
    endpoint = endpoint or os.getenv("APIM_GATEWAY_ENDPOINT")
    deployment = deployment or os.getenv("AI_MODEL_DEPLOYMENT") 
    api_key = api_key or os.getenv("APIM_SUBSCRIPTION_KEY", "")
    
    # Validate APIM configuration
    if not all([endpoint, deployment, api_key]):
        raise RuntimeError("Missing one or more API Management gateway variables: APIM_GATEWAY_ENDPOINT, AI_MODEL_DEPLOYMENT, APIM_SUBSCRIPTION_KEY")

    kernel = Kernel()
    
    kernel.add_service(
        AzureChatCompletion(
            deployment_name=deployment,
            endpoint=endpoint,
            api_key=api_key
        )
    )
    return kernel
