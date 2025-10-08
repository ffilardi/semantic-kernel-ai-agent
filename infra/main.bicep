// ================================================================================
// FILE: main.bicep
// PURPOSE: This file serves as the entry point for the Azure Bicep deployment.
// ================================================================================

targetScope = 'subscription'

@minLength(3)
@maxLength(10)
@description('Environment name for the deployment, used to create unique resource names.')
param environment string

@description('Primary location to deploy all resources.')
param location string

// Set unique token
var token string = toLower(uniqueString(subscription().id, environment, location))

// Set default tag
var tags object = { 'azd-env-name': environment }

// ================================================================================
// Logs & Monitoring Services Deployment
// ================================================================================

var monitorResourceGroupName string = 'rg-monitor-${environment}-${token}'
var logAnalyticsName string = 'log-${environment}-${token}'
var applicationInsightsName string = 'appi-${environment}-${token}'
var dashboardName string = 'dash-${environment}-${token}'

resource monitorResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: monitorResourceGroupName
  location: location
  tags: tags
}

module monitor './modules/monitor/monitor.bicep' = {
  name: 'monitor'
  scope: monitorResourceGroup
  params: {
    location: location
    tags: tags
    logAnalyticsName: logAnalyticsName
    applicationInsightsName: applicationInsightsName
    dashboardName: dashboardName
  }
}

// ================================================================================
// Common Services Deployment
// ================================================================================

var commonResourceGroupName string = 'rg-common-${environment}-${token}'
var vaultName string = 'kv-${environment}-${token}'
var serviceBusName string = 'sb-${environment}-${token}'
var storageName string = 'st${replace(environment,'-','')}${token}'
var cosmosDbName string = 'cosmos-${environment}-${token}'

resource commonResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: commonResourceGroupName
  location: location
  tags: tags
}

module keyVault './modules/keyvault/keyvault.bicep' = {
  name: 'keyvault'
  scope: commonResourceGroup
  params: {
    location: location
    tags: tags
    vaultName: vaultName
    logAnalyticsWorkspaceId: monitor.outputs.logAnalyticsWorkspaceId
  }
}

module storage './modules/storage/storage.bicep' = {
  name: 'storage'
  scope: commonResourceGroup
  params: {
    location: location
    tags: tags
    storageName: storageName
    logAnalyticsWorkspaceId: monitor.outputs.logAnalyticsWorkspaceId
  }
}

module cosmosDb './modules/cosmosdb/cosmosdb.bicep' = {
  name: 'cosmosdb'
  scope: commonResourceGroup
  params: {
    location: location
    tags: tags
    cosmosDbName: cosmosDbName
    logAnalyticsWorkspaceId: monitor.outputs.logAnalyticsWorkspaceId
    databases: [
      { name: 'database-01', container: 'db-01-container-01', partitionKey: '/field_id' }
    ]
  }
}

// ================================================================================
// AI Services Deployment
// ================================================================================

var aiResourceGroupName string = 'rg-ai-${environment}-${token}'
var aiSearchName string = 'srch-${environment}-${token}'
var aiFoundryAccountName string = 'aif-${environment}-${token}'
var aiFoundryProjectName string = 'proj-sample-01'

resource aiResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: aiResourceGroupName
  location: location
  tags: tags
}

module ai 'modules/ai/ai.bicep' = {
  name: 'ai-services'
  scope: aiResourceGroup
  params: {
    location: location
    tags: tags
    aiSearchName: aiSearchName
    aiFoundryAccountName: aiFoundryAccountName
    aiFoundryProjectName: aiFoundryProjectName
    storageName: storage.outputs.accountName
    cosmosDbName: cosmosDb.outputs.cosmosDbName
    logAnalyticsWorkspaceId: monitor.outputs.logAnalyticsWorkspaceId
    commonResourceGroupName: commonResourceGroup.name
    keyVaultName: keyVault.outputs.vaultName
  }
}

// ================================================================================
// App & Integration Services Deployment
// ================================================================================

var appResourceGroupName string = 'rg-app-${environment}-${token}'
var apimServiceName string = 'apim-${environment}-${token}'
var webAppName string = 'app-${environment}-${token}'
var webAppServicePlanName string = 'plan-${webAppName}'
var functionAppName string = 'func-${environment}-${token}'
var functionAppServicePlanName string = 'plan-${functionAppName}'
var functionAppStorageName string = 'st${replace(functionAppName,'-','')}'
var logicAppName string = 'logic-${environment}-${token}'
var logicAppServicePlanName string = 'plan-${logicAppName}'
var logicAppStorageName string = 'st${replace(logicAppName,'-','')}'

resource appResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: appResourceGroupName
  location: location
  tags: tags
}

module apiManagement './modules/apim/apim.bicep' = {
  name: 'api-management'
  scope: appResourceGroup
  params: {
    location: location
    tags: tags
    apimServiceName: apimServiceName
    applicationInsightsId: monitor.outputs.applicationInsightsId
    applicationInsightsInstrumentationKey: monitor.outputs.applicationInsightsInstrumentationKey
    logAnalyticsWorkspaceId: monitor.outputs.logAnalyticsWorkspaceId
    commonResourceGroupName: commonResourceGroup.name
    keyVaultName: keyVault.outputs.vaultName
  }
}

module serviceBus './modules/servicebus/servicebus.bicep' = {
  name: 'servicebus'
  scope: appResourceGroup
  params: {
    location: location
    tags: tags
    serviceBusName: serviceBusName
    logAnalyticsWorkspaceId: monitor.outputs.logAnalyticsWorkspaceId
    queues: [ { name: 'sbq-sample-01' } ]
    topics: [ { name: 'sbt-sample-01' } ]
  }
}

module appServices './modules/app/app.bicep' = {
  name: 'app-services'
  scope: appResourceGroup
  params: {
    location: location
    tags: tags
    webAppName: webAppName
    webAppServicePlanName: webAppServicePlanName
    functionAppName: functionAppName
    functionAppServicePlanName: functionAppServicePlanName
    functionAppStorageName: functionAppStorageName
    logicAppName: logicAppName
    logicAppServicePlanName: logicAppServicePlanName
    logicAppStorageName: logicAppStorageName
    appInsightsConnectionString: monitor.outputs.applicationInsightsConnectionString
    logAnalyticsWorkspaceId: monitor.outputs.logAnalyticsWorkspaceId
    commonResourceGroupName: commonResourceGroup.name
    aiResourceGroupName: aiResourceGroup.name
    keyVaultName: keyVault.outputs.vaultName
    cosmosDbName: cosmosDb.outputs.cosmosDbName
    apimServiceName: apiManagement.outputs.apimServiceName
    serviceBusName: serviceBus.outputs.namespaceName
    serviceBusHost: serviceBus.outputs.namespaceHost
    aiFoundryName: ai.outputs.aiFoundryAccountName
  }
}

// Output the application resource group for code deployment via Azure Developer CLI
output AZURE_RESOURCE_GROUP string = appResourceGroup.name

// Output application hostnames
output AZURE_APIM_HOSTNAME string = apiManagement.outputs.apimServiceHostName
output AZURE_APIM_DEVELOPER_PORTAL string = apiManagement.outputs.apimServiceDeveloperPortalUrl
output AZURE_WEB_APP_HOSTNAME string = appServices.outputs.webAppHostName
output AZURE_FUNCTION_APP_HOSTNAME string = appServices.outputs.functionAppHostName
output AZURE_LOGIC_APP_HOSTNAME string = appServices.outputs.logicAppHostName
