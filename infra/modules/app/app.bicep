param location string = resourceGroup().location
param tags object = {}
param webAppName string
param webAppServicePlanName string
param functionAppName string
param functionAppServicePlanName string
param functionAppStorageName string
param logicAppName string
param logicAppServicePlanName string
param logicAppStorageName string
param logAnalyticsWorkspaceId string = ''
param appInsightsConnectionString string = ''
param commonResourceGroupName string = ''
param aiResourceGroupName string = ''
param keyVaultName string = ''
param cosmosDbName string = ''
param apimServiceName string = ''
param serviceBusName string = ''
param serviceBusHost string = ''
param aiFoundryName string = ''

// Web App
module webAppServicePlan './resources/app-service-plan.bicep' = {
  name: 'web-app-service-plan'
  params: {
    location: location
    tags: tags
    name: webAppServicePlanName
    sku: 'Standard'
    skuCode: 'S1'
    kind: 'linux'
    reserved: true
  }
}

module webApp './resources/web-app.bicep' = {
  name: 'web-app'
  params: {
    location: location
    tags: tags
    name: webAppName
    servicePlanId: webAppServicePlan.outputs.id
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    appInsightsConnectionString: appInsightsConnectionString
  }
}

module webAppRbac01 '../security/keyvault-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(keyVaultName)) {
  name: '${webAppName}-rbac-01'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: keyVaultName
    roleNames: [ 'Key Vault Secrets User' ]
    principalId: webApp.outputs.appPrincipalId
  }
}

module webAppRbac02 '../security/cosmosdb-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(cosmosDbName)) {
  name: '${webAppName}-rbac-02'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: cosmosDbName
    roleNames: [
      'Cosmos DB Operator'
      'Cosmos DB Account Reader Role'
    ]
    principalId: webApp.outputs.appPrincipalId
  }
}

module webAppRbac03 '../security/aifoundry-rbac.bicep' = if (!empty(aiResourceGroupName) && !empty(aiFoundryName)) {
  name: '${webAppName}-rbac-03'
  scope: resourceGroup(aiResourceGroupName)
  params: {
    serviceName: aiFoundryName
    roleNames: [ 'Azure AI User' ]
    principalId: webApp.outputs.appPrincipalId
  }
}

module webApi '../apim/api/web-api.bicep' = if (apimServiceName != '') {
  name: 'web-app-api'
  params: {
    apimServiceName: apimServiceName
    backendUrl: '${webApp.outputs.appHostName}/api'
    backendResourceId: webApp.outputs.appId
  }
}

// Function App
module functionAppStorage '../storage/storage.bicep' = {
  name: 'function-app-storage'
  params: {
    location: location
    tags: tags
    storageName: functionAppStorageName
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

module functionAppServicePlan './resources/app-service-plan.bicep' = {
  name: 'function-app-service-plan'
  params: {
    location: location
    tags: tags
    name: functionAppServicePlanName
    sku: 'Standard'
    skuCode: 'S1'
    kind: 'linux'
    reserved: true
  }
}

module functionApp './resources/function-app.bicep' = {
  name: 'function-app'
  params: {
    location: location
    tags: tags
    name: functionAppName
    servicePlanId: functionAppServicePlan.outputs.id
    storageAccountName: functionAppStorage.outputs.accountName
    serviceBusHost: serviceBusHost
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    appInsightsConnectionString: appInsightsConnectionString
  }
}

module functionAppRbac01 '../security/keyvault-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(keyVaultName)) {
  name: '${functionAppName}-rbac-01'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: keyVaultName
    roleNames: [ 'Key Vault Secrets User' ]
    principalId: functionApp.outputs.appPrincipalId
  }
}

module functionAppRbac02 '../security/servicebus-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(serviceBusName)) {
  name: '${functionAppName}-rbac-02'
  params: {
    serviceName: serviceBusName
    roleNames: [ 'Azure Service Bus Data Owner' ]
    principalId: functionApp.outputs.appPrincipalId
  }
}

module functionAppRbac03 '../security/aifoundry-rbac.bicep' = if (!empty(aiResourceGroupName) && !empty(aiFoundryName)) {
  name: '${functionAppName}-rbac-03'
  scope: resourceGroup(aiResourceGroupName)
  params: {
    serviceName: aiFoundryName
    roleNames: [ 'Azure AI User' ]
    principalId: functionApp.outputs.appPrincipalId
  }
}

module functionApi '../apim/api/function-api.bicep' = if (apimServiceName != '') {
  name: 'function-app-api'
  params: {
    apimServiceName: apimServiceName
    backendUrl: '${functionApp.outputs.appHostName}/api'
    backendResourceId: functionApp.outputs.appId
  }
}

// Logic App
module logicAppStorage '../storage/storage.bicep' = {
  name: 'logic-app-storage'
  params: {
    location: location
    tags: tags
    storageName: logicAppStorageName
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

module logicAppServicePlan './resources/app-service-plan.bicep' = {
  name: 'logic-app-service-plan'
  params: {
    location: location
    tags: tags
    name: logicAppServicePlanName
    sku: 'WorkflowStandard'
    skuCode: 'WS1'
    reserved: false
  }
}

module logicApp './resources/logic-app.bicep' = {
  name: 'logic-app'
  params: {
    location: location
    tags: tags
    name: logicAppName
    servicePlanId: logicAppServicePlan.outputs.id
    storageAccountName: logicAppStorage.outputs.accountName
    serviceBusHost: serviceBusHost
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    appInsightsConnectionString: appInsightsConnectionString
  }
}

module logicAppRbac01 '../security/keyvault-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(keyVaultName)) {
  name: '${logicAppName}-rbac-01'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: keyVaultName
    roleNames: [ 'Key Vault Secrets User' ]
    principalId: logicApp.outputs.appPrincipalId
  }
}

module logicAppRbac02 '../security/servicebus-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(serviceBusName)) {
  name: '${logicAppName}-rbac-02'
  params: {
    serviceName: serviceBusName
    roleNames: [ 'Azure Service Bus Data Owner' ]
    principalId: logicApp.outputs.appPrincipalId
  }
}

module logicAppRbac03 '../security/aifoundry-rbac.bicep' = if (!empty(aiResourceGroupName) && !empty(aiFoundryName)) {
  name: '${logicAppName}-rbac-03'
  scope: resourceGroup(aiResourceGroupName)
  params: {
    serviceName: aiFoundryName
    roleNames: [ 'Azure AI User' ]
    principalId: logicApp.outputs.appPrincipalId
  }
}

output webAppId string = webApp.outputs.appId
output webAppName string = webApp.outputs.appName
output webAppHostName string = webApp.outputs.appHostName
output webAppPrincipalId string = webApp.outputs.appPrincipalId
output functionAppId string = functionApp.outputs.appId
output functionAppName string = functionApp.outputs.appName
output functionAppHostName string = functionApp.outputs.appHostName
output functionAppPrincipalId string = functionApp.outputs.appPrincipalId
output logicAppId string = logicApp.outputs.appId
output logicAppName string = logicApp.outputs.appName
output logicAppHostName string = logicApp.outputs.appHostName
output logicAppPrincipalId string = logicApp.outputs.appPrincipalId
