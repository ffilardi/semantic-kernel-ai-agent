param location string = resourceGroup().location
param tags object = {}
param name string
param servicePlanId string
param storageAccountName string
param serviceBusHost string = ''
param appInsightsConnectionString string = ''
param logAnalyticsWorkspaceId string = ''
param enableLogs bool = true
param enableMetrics bool = true

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: storageAccountName
}

module app 'app-service.bicep' = {
  name: name
  params: {
    location: location
    tags: union(tags, { 'azd-service-name': 'logic-app' })
    name: name
    servicePlanId: servicePlanId
    kind: 'functionapp,workflowapp'
    netFrameworkVersion: 'v6.0'
    alwaysOn: true
    buildOnDeployment: 'false'
    appSettings: [
      {
        name: 'FUNCTIONS_EXTENSION_VERSION'
        value: '~4'
      }
      {
        name: 'FUNCTIONS_WORKER_RUNTIME'
        value: 'dotnet'
      }
      {
        name: 'WEBSITE_NODE_DEFAULT_VERSION'
        value: '~20'
      }
      {
        name: 'AzureWebJobsStorage'
        value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
      }
      {
        name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
        value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
      }
      {
        name: 'WEBSITE_CONTENTSHARE'
        value: '${name}-${uniqueString(resourceGroup().id)}'
      }
      {
        name: 'AzureFunctionsJobHost__extensionBundle__id'
        value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
      }
      {
        name: 'AzureFunctionsJobHost__extensionBundle__version'
        value: '[1.*, 2.0.0)'
      }
      {
        name: 'APP_KIND'
        value: 'workflowApp'
      }
      {
        name: 'FUNCTIONS_INPROC_NET8_ENABLED'
        value: '1'
      }
      {
        name: 'serviceBus_fullyQualifiedNamespace'
        value: serviceBusHost
      }
    ]
    appInsightsConnectionString: appInsightsConnectionString
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    diagnosticLogs: !empty(logAnalyticsWorkspaceId)
    ? [
        {
          category: 'WorkflowRuntime'
          categoryGroup: null
          enabled: enableLogs
      }
      {
          category: 'FunctionAppLogs'
          categoryGroup: null
          enabled: enableLogs
      }
      {
        category: 'AppServiceAuthenticationLogs'
        categoryGroup: null
        enabled: enableLogs
    }
    ]
    : []
    diagnosticMetrics: !empty(logAnalyticsWorkspaceId)
    ? [
      {
        category: 'AllMetrics'
        enabled: enableMetrics
      }
    ]
    : []
  }
}

output appId string = app.outputs.id
output appName string = app.outputs.name
output appHostName string = app.outputs.defaultHostName
output appPrincipalId string = app.outputs.principalId

