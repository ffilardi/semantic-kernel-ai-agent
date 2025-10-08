param location string = resourceGroup().location
param tags object = {}
param webAppFrontendName string
param webAppBackendName string
param webAppServicePlanName string
param logAnalyticsWorkspaceId string = ''
param appInsightsConnectionString string = ''
param commonResourceGroupName string = ''
param keyVaultName string = ''
param cosmosDbName string = ''
param apimServiceName string = ''

// Base Resources

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = if(!empty(apimServiceName)) {
  name: apimServiceName
}

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = if(!empty(cosmosDbName) && !empty(commonResourceGroupName)) {
  name: cosmosDbName
  scope: resourceGroup(commonResourceGroupName)
}

// Vault Secrets

module apimVaultSecret '../keyvault/resources/secret.bicep' = if (!empty(apim.name) && !empty(keyVaultName) && !empty(commonResourceGroupName)) {
  name: 'apim-secret'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    vaultName: keyVaultName
    secretName: 'apim-aifoundry-api-key'
    secretValue: !empty(apim.name) ? listSecrets('${apim.id}/subscriptions/master', '2024-05-01').primaryKey : ''
  }
}

module cosmosDbVaultSecret '../keyvault/resources/secret.bicep' = if (!empty(cosmosDb.name) && !empty(keyVaultName) && !empty(commonResourceGroupName)) {
  name: 'cosmosdb-secret'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    vaultName: keyVaultName
    secretName: 'cosmos-db-key'
    secretValue: cosmosDb.listKeys().primaryMasterKey
  }
}

// App Service Plan

module webAppServicePlan './resources/app-service-plan.bicep' = {
  name: 'web-app-service-plan'
  params: {
    location: location
    tags: tags
    name: webAppServicePlanName
    sku: 'Basic'
    skuCode: 'B3'
    kind: 'linux'
    reserved: true
  }
}

// Agent Backend

module webAppBackend './resources/web-app.bicep' = {
  name: 'agent-backend'
  params: {
    location: location
    tags: union(tags, { 'azd-service-name': 'agent-backend' })
    name: webAppBackendName
    servicePlanId: webAppServicePlan.outputs.id
    kind: 'app,linux'
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    appInsightsConnectionString: appInsightsConnectionString
    linuxFxVersion: 'PYTHON|3.12'
    appCommandLine: 'python3 -m gunicorn app:app -k uvicorn.workers.UvicornWorker'
    healthCheckPath: '/ping'
    appSettings: [
      {
        name: 'APIM_GATEWAY_ENDPOINT'
        value: !empty(apim.name) ? apim.properties.gatewayUrl : ''
      }
      {
        name: 'APIM_SUBSCRIPTION_KEY'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=apim-aifoundry-api-key)'
      }
      {
        name: 'AI_MODEL_DEPLOYMENT'
        value: 'gpt-4.1-mini'
      }
      {
        name: 'COSMOS_ENDPOINT'
        value: !empty(cosmosDb.name) ? cosmosDb.properties.documentEndpoint : ''
      }
      {
        name: 'COSMOS_KEY'
        value: !empty(cosmosDbVaultSecret.outputs.reference) ? cosmosDbVaultSecret.outputs.reference : ''
      }
      {
        name: 'LEARN_MCP_URL'
        value: 'https://learn.microsoft.com/api/mcp'
      }
    ]
  }
}

module webAppBackendRbac01 '../security/keyvault-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(keyVaultName)) {
  name: '${webAppBackendName}-rbac-01'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: keyVaultName
    roleNames: [ 'Key Vault Secrets User' ]
    principalId: webAppBackend.outputs.appPrincipalId
  }
}

module webAppBackendRbac02 '../security/cosmosdb-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(cosmosDbName)) {
  name: '${webAppBackendName}-rbac-02'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: cosmosDbName
    roleNames: [
      'Cosmos DB Operator'
      'Cosmos DB Account Reader Role'
    ]
    principalId: webAppBackend.outputs.appPrincipalId
  }
}

// Agent Frontend

module webAppFrontend './resources/web-app.bicep' = {
  name: 'agent-frontend'
  params: {
    location: location
    tags: union(tags, { 'azd-service-name': 'agent-frontend' })
    name: webAppFrontendName
    servicePlanId: webAppServicePlan.outputs.id
    kind: 'app,linux'
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    appInsightsConnectionString: appInsightsConnectionString
    linuxFxVersion: 'PYTHON|3.12'
    appCommandLine: 'python3 -m gunicorn app:app -k uvicorn.workers.UvicornWorker'
    healthCheckPath: '/ping'
    appSettings: [
      {
        name: 'AGENT_BACKEND_CHAT_URL'
        value: (!empty(apimServiceName)) ? '${webAppBackend.outputs.appHostName}/chat' : ''
      }
    ]
  }
}

module webAppFrontendRbac01 '../security/keyvault-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(keyVaultName)) {
  name: '${webAppFrontendName}-rbac-01'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: keyVaultName
    roleNames: [ 'Key Vault Secrets User' ]
    principalId: webAppFrontend.outputs.appPrincipalId
  }
}

output webAppFrontendId string = webAppFrontend.outputs.appId
output webAppFrontendName string = webAppFrontend.outputs.appName
output webAppFrontendHostName string = webAppFrontend.outputs.appHostName
output webAppFrontendPrincipalId string = webAppFrontend.outputs.appPrincipalId

output webAppBackendId string = webAppBackend.outputs.appId
output webAppBackendName string = webAppBackend.outputs.appName
output webAppBackendHostName string = webAppBackend.outputs.appHostName
output webAppBackendPrincipalId string = webAppBackend.outputs.appPrincipalId
