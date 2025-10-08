param location string = resourceGroup().location
param tags object = {}
param aiSearchName string
param aiFoundryAccountName string
param aiFoundryProjectName string
param storageName string = ''
param cosmosDbName string = ''
param logAnalyticsWorkspaceId string = ''
param commonResourceGroupName string = ''
param keyVaultName string = ''

// AI Search
module aiSearch './resources/aisearch.bicep' = {
  name: aiSearchName
  params: {
    location: location
    tags: tags
    name: aiSearchName
    sku: 'basic'
    hostingMode: 'default'
    semanticSearch: 'free'
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

module aiSearchRbac01 '../security/storage-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(storageName)) {
  name: '${aiSearchName}-rbac-01'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: storageName
    roleNames: [ 'Storage Blob Data Contributor' ]
    principalId: aiSearch.outputs.principalId
  }
}

// AI Foundry
module aiFoundry './resources/aifoundry.bicep' = {
  name: aiFoundryAccountName
  params: {
    location: location
    tags: tags
    name: aiFoundryAccountName
    sku: 'S0'
    kind: 'AIServices'
    modelDeployments: [
      {
        format: 'OpenAI'
        name: 'gpt-4o'
        version: ''
        sku: {
          name: 'GlobalStandard'
          capacity: 50
        }
      }
      {
        format: 'OpenAI'
        name: 'gpt-4.1'
        version: ''
        sku: {
          name: 'GlobalStandard'
          capacity: 50
        }
      }
      {
        format: 'OpenAI'
        name: 'text-embedding-3-small'
        version: ''
        sku: {
          name: 'GlobalStandard'
          capacity: 150
        }
      }
    ]
    projectName: aiFoundryProjectName
    aiSearchName: aiSearch.outputs.name
    storageName: storageName
    cosmosDbName: cosmosDbName
    commonResourceGroupName: commonResourceGroupName
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

module aiFoundryRbac01 '../security/keyvault-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(keyVaultName)) {
  name: '${aiFoundryAccountName}-rbac-01'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: keyVaultName
    roleNames: [ 'Key Vault Secrets User' ]
    principalId: aiFoundry.outputs.principalId
  }
}

module aiFoundryRbac02 '../security/cosmosdb-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(cosmosDbName)) {
  name: '${aiFoundryAccountName}-rbac-02'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: cosmosDbName
    roleNames: [
      'Cosmos DB Operator'
      'Cosmos DB Account Reader Role'
    ]
    principalId: aiFoundry.outputs.principalId
  }
}

module aiFoundryRbac03 '../security/storage-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(storageName)) {
  name: '${aiFoundryAccountName}-rbac-03'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: storageName
    roleNames: [ 'Storage Blob Data Contributor' ]
    principalId: aiFoundry.outputs.principalId
  }
}

module aiFoundryRbac04 '../security/aisearch-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(aiSearchName)) {
  name: '${aiFoundryAccountName}-rbac-04'
  scope: resourceGroup()
  params: {
    serviceName: aiSearch.outputs.name
    roleNames: [
      'Search Service Contributor'
      'Search Index Data Contributor'
    ]
    principalId: aiFoundry.outputs.principalId
  }
}

output aiSearchId string = aiSearch.outputs.id
output aiSearchName string = aiSearch.outputs.name
output aiSearchUri string = aiSearch.outputs.uri
output aiFoundryAccountId string = aiFoundry.outputs.id
output aiFoundryAccountName string = aiFoundry.outputs.name
output aiFoundryAccountUri string = aiFoundry.outputs.endpoint
output aiFoundryProjectId string = aiFoundry.outputs.projectId
output aiFoundryProjectName string = aiFoundry.outputs.projectName
