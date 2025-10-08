param location string = resourceGroup().location
param tags object = {}
param name string
param servicePlanId string
param storageAccountName string
param appInsightsConnectionString string = ''
param logAnalyticsWorkspaceId string = ''
param serviceBusHost string = ''
param enableLogs bool = true
param enableMetrics bool = true

var stagingSlots array = []

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

module app 'app-service.bicep' = {
  name: name
  params: {
    location: location
    tags: union(tags, { 'azd-service-name': 'function-app' })
    name: name
    servicePlanId: servicePlanId
    kind: 'functionapp,linux'
    linuxFxVersion: 'Python|3.12'
    alwaysOn: true
    appSettings: [
      {
        name: 'FUNCTIONS_EXTENSION_VERSION'
        value: '~4'
      }
      {
        name: 'FUNCTIONS_WORKER_RUNTIME'
        value: 'python'
      }
      {
        name: 'AzureWebJobsStorage'
        value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
      }
      {
        name: 'ServiceBusConnection__fullyQualifiedNamespace'
        value: serviceBusHost
      }
    ]
    appInsightsConnectionString: appInsightsConnectionString
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    diagnosticLogs: !empty(logAnalyticsWorkspaceId)
    ? [
      {
        category: 'FunctionAppLogs'
        enabled: enableLogs
      }
      {
        category: 'AppServiceAuthenticationLogs'
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

module appStaging 'app-service-slot.bicep' = [for slot in stagingSlots: {
  name: '${name}-${slot.name}'
  params: {
    location: location
    tags: union(tags, { 'azd-service-name': 'function-app-${slot.name}' })
    name: slot.name
    appServiceName: app.outputs.name
    servicePlanId: servicePlanId
    kind: 'functionapp,linux'
    linuxFxVersion: 'Python|3.12'
    appSettings: [
      {
        name: 'FUNCTIONS_EXTENSION_VERSION'
        value: '~4'
      }
      {
        name: 'FUNCTIONS_WORKER_RUNTIME'
        value: 'python'
      }
      {
        name: 'AzureWebJobsStorage'
        value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
      }
    ]
    appInsightsConnectionString: appInsightsConnectionString
  }
}]

output appId string = app.outputs.id
output appName string = app.outputs.name
output appHostName string = app.outputs.defaultHostName
output appPrincipalId string = app.outputs.principalId
