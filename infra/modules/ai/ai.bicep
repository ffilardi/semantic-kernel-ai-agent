param primaryLocation string = resourceGroup().location
param secondaryLocation string = resourceGroup().location
param tags object = {}
param aiFoundryAccountName string
param aiFoundryProjectName string
param storageName string = ''
param cosmosDbName string = ''
param logAnalyticsWorkspaceId string = ''
param commonResourceGroupName string = ''
param keyVaultName string = ''
param appResourceGroupName string = ''
param apimServiceName string = ''
param apimServicePrincipalId string = ''
param applicationInsightsLoggerName string = ''

var modelDeployments array = [
      {
        format: 'OpenAI'
        name: 'gpt-4.1-mini'
        version: ''
        sku: {
          name: 'GlobalStandard'
          capacity: 100
        }
      }
      {
        format: 'OpenAI'
        name: 'gpt-4.1'
        version: ''
        sku: {
          name: 'GlobalStandard'
          capacity: 25
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

// AI Foundry Instance 01
module aiFoundry01 './resources/aifoundry.bicep' = {
  name: '${aiFoundryAccountName}-01'
  params: {
    location: primaryLocation
    tags: tags
    name: '${aiFoundryAccountName}-01'
    sku: 'S0'
    kind: 'AIServices'
    modelDeployments: modelDeployments
    projectName: aiFoundryProjectName
    storageName: storageName
    cosmosDbName: cosmosDbName
    commonResourceGroupName: commonResourceGroupName
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

module aiFoundry01Rbac01 '../security/keyvault-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(keyVaultName)) {
  name: '${aiFoundryAccountName}-01-rbac-01'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: keyVaultName
    roleNames: [ 'Key Vault Secrets User' ]
    principalId: aiFoundry01.outputs.principalId
  }
}

module aiFoundry01Rbac02 '../security/cosmosdb-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(cosmosDbName)) {
  name: '${aiFoundryAccountName}-01-rbac-02'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: cosmosDbName
    roleNames: [
      'Cosmos DB Operator'
      'Cosmos DB Account Reader Role'
    ]
    principalId: aiFoundry01.outputs.principalId
  }
}

module aiFoundry01Rbac03 '../security/storage-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(storageName)) {
  name: '${aiFoundryAccountName}-01-rbac-03'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: storageName
    roleNames: [ 'Storage Blob Data Contributor' ]
    principalId: aiFoundry01.outputs.principalId
  }
}

// AI Foundry Instance 02
module aiFoundry02 './resources/aifoundry.bicep' = {
  name: '${aiFoundryAccountName}-02'
  params: {
    location: secondaryLocation
    tags: tags
    name: '${aiFoundryAccountName}-02'
    sku: 'S0'
    kind: 'AIServices'
    modelDeployments: modelDeployments
    projectName: aiFoundryProjectName
    storageName: storageName
    cosmosDbName: cosmosDbName
    commonResourceGroupName: commonResourceGroupName
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

module aiFoundry02Rbac01 '../security/keyvault-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(keyVaultName)) {
  name: '${aiFoundryAccountName}-02-rbac-01'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: keyVaultName
    roleNames: [ 'Key Vault Secrets User' ]
    principalId: aiFoundry02.outputs.principalId
  }
}

module aiFoundry02Rbac02 '../security/cosmosdb-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(cosmosDbName)) {
  name: '${aiFoundryAccountName}-02-rbac-02'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: cosmosDbName
    roleNames: [
      'Cosmos DB Operator'
      'Cosmos DB Account Reader Role'
    ]
    principalId: aiFoundry02.outputs.principalId
  }
}

module aiFoundry02Rbac03 '../security/storage-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(storageName)) {
  name: '${aiFoundryAccountName}-02-rbac-03'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: storageName
    roleNames: [ 'Storage Blob Data Contributor' ]
    principalId: aiFoundry02.outputs.principalId
  }
}

// APIM role assignments for AI Foundry instances
module apimAiFoundry01Rbac '../security/aifoundry-rbac.bicep' = if (!empty(appResourceGroupName) && !empty(apimServiceName) && !empty(apimServicePrincipalId)) {
  name: 'apim-aifoundry-01-rbac'
  params: {
    serviceName: aiFoundry01.outputs.name
    roleNames: [ 'Cognitive Services OpenAI User' ]
    principalId: apimServicePrincipalId
  }
}

module apimAiFoundry02Rbac '../security/aifoundry-rbac.bicep' = if (!empty(appResourceGroupName) && !empty(apimServiceName) && !empty(apimServicePrincipalId)) {
  name: 'apim-aifoundry-02-rbac'
  params: {
    serviceName: aiFoundry02.outputs.name
    roleNames: [ 'Cognitive Services OpenAI User' ]
    principalId: apimServicePrincipalId
  }
}

// APIM configuration for AI Foundry instances
module aiFoundryApi '../apim/api/aifoundry-api.bicep' = if (!empty(apimServiceName)) {
  name: 'aifoundry-api'
  scope: resourceGroup(appResourceGroupName)
  params: {
    apimServiceName: apimServiceName
    backendUrls: [
      'https://${aiFoundry01.outputs.name}.services.ai.azure.com/openai'
      'https://${aiFoundry02.outputs.name}.services.ai.azure.com/openai'
    ]
    backendResourceIds: [
      aiFoundry01.outputs.id
      aiFoundry02.outputs.id
    ]
    enableLoadBalancing: true
    backendPriorities: [ 1, 1 ]
    backendWeights: [ 50, 50 ]
    applicationInsightsLoggerName: applicationInsightsLoggerName
    enableApplicationInsightsDiagnostics: !empty(applicationInsightsLoggerName)
    enableAzureMonitorDiagnostics: true
    enableLLMMessages: true
  }
  dependsOn: [
    apimAiFoundry01Rbac
    apimAiFoundry02Rbac
  ]
}

output aiFoundry01AccountId string = aiFoundry01.outputs.id
output aiFoundry01AccountName string = aiFoundry01.outputs.name
output aiFoundry01AccountUri string = aiFoundry01.outputs.endpoint
output aiFoundry01ProjectId string = aiFoundry01.outputs.projectId
output aiFoundry01ProjectName string = aiFoundry01.outputs.projectName

output aiFoundry02AccountId string = aiFoundry02.outputs.id
output aiFoundry02AccountName string = aiFoundry02.outputs.name
output aiFoundry02AccountUri string = aiFoundry02.outputs.endpoint
output aiFoundry02ProjectId string = aiFoundry02.outputs.projectId
output aiFoundry02ProjectName string = aiFoundry02.outputs.projectName
