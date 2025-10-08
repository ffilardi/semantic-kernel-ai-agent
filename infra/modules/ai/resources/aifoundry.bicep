param location string = resourceGroup().location
param tags object = {}
param name string
param sku string
param kind string
param identityType string = 'SystemAssigned'
param modelDeployments array = []
param projectName string = 'default-project'
param projectDescription string = 'Default Project for ${name}'
param aiSearchName string = ''
param storageName string = ''
param cosmosDbName string = ''
param commonResourceGroupName string = ''
param publicNetworkAccess string = 'Enabled'
param allowProjectManagement bool = true
param disableLocalAuth bool = false
param restrictOutboundNetworkAccess bool = false
param raiPolicyName string = 'Microsoft.DefaultV2'
param logAnalyticsWorkspaceId string = ''
param enableLogs bool = true
param enableAuditLogs bool = false
param enableMetrics bool = true

// AI Foundry Account
resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  location: location
  tags: union(tags, { 'azd-service-name': name })
  name: name
  sku: {
    name: sku
  }
  kind: kind
  identity: {
    type: identityType
  }
  properties: {
    publicNetworkAccess: publicNetworkAccess
    allowProjectManagement: allowProjectManagement
    customSubDomainName: name
    disableLocalAuth: disableLocalAuth
    restrictOutboundNetworkAccess: restrictOutboundNetworkAccess
    allowedFqdnList: [
      'ai.azure.com'
      'search.windows.net'
      'cognitiveservices.azure.com'
      'azure-api.net'
    ]
  }
}

// AI Foundry Models Deployment
@batchSize(1)
resource modelDeploymentResources 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = [
  for deployment in modelDeployments: {
    parent: account
    name: deployment.name
    sku: deployment.sku
    properties: {
      model: {
        format: deployment.format
        name: deployment.name
        version: deployment.version
      }
      raiPolicyName: raiPolicyName
    }
  }
]

// AI Foundry Project
resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: account
  name: projectName
  location: location
  identity: {
    type: identityType
  }
  properties: {
    displayName: projectName
    description: projectDescription
  }
}

// Azure AI Search Connection
resource aiSearch 'Microsoft.Search/searchServices@2025-02-01-Preview' existing = if (!empty(aiSearchName)) {
  name: aiSearchName
}

resource aiSearchConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = if (!empty(aiSearchName)) {
  parent: project
  name: '${projectName}-${aiSearchName}-connection'
  properties: {
    category: 'CognitiveSearch'
    target: aiSearch.properties.endpoint
    authType: 'AAD'
    useWorkspaceManagedIdentity: false
    metadata: {
      type: 'azure_ai_search'
      ApiType: 'Azure'
      ResourceId: aiSearch.id
      location: aiSearch.location
    }
  }
}

// Storage Account Connection
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = if (!empty(storageName)) {
  name: storageName
  scope: resourceGroup(commonResourceGroupName)
}

resource storageConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = if (!empty(storageName)) {
  parent: project
  name: '${projectName}-${storageName}-connection'
  properties: {
    category: 'AzureStorageAccount'
    target: storageAccount.properties.primaryEndpoints.blob
    authType: 'AAD'
    useWorkspaceManagedIdentity: false
    metadata: {
      ResourceId: storageAccount.id
      ApiType: 'Azure'
      location: storageAccount.location
    }
  }
}

// CosmosDB Connection
resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2025-05-01-preview' existing = if (!empty(cosmosDbName)) {
  name: cosmosDbName
  scope: resourceGroup(commonResourceGroupName)
}

resource cosmosDbConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = if (!empty(cosmosDbName)) {
  parent: project
  name: '${projectName}-${cosmosDbName}-connection'
  properties: {
    category: 'CosmosDB'
    target: cosmosDb.properties.documentEndpoint
    authType: 'AAD'
    useWorkspaceManagedIdentity: false
    metadata: {
      ResourceId: cosmosDb.id
      ApiType: 'Azure'
      location: cosmosDb.location
    }
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticsettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'Logging'
  scope: account
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
        {
          category: null
          categoryGroup: 'allLogs'
          enabled: enableLogs
      }
      {
          category: null
          categoryGroup: 'audit'
          enabled: enableAuditLogs
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: enableMetrics
      }
    ]
  }
}

output id string = account.id
output name string = account.name
output endpoint string = account.properties.endpoint
output principalId string = account.identity.principalId
output projectId string = project.id
output projectName string = project.name
