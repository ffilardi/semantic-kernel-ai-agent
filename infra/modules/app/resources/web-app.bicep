param location string = resourceGroup().location
param tags object = {}
param name string
param servicePlanId string
param appInsightsConnectionString string = ''
param logAnalyticsWorkspaceId string = ''
param enableLogs bool = true
param enableMetrics bool = true
param enableAuditLogs bool = false

var stagingSlots array = [
  { name: 'staging-01' }
]

module app 'app-service.bicep' = {
  name: name
  params: {
    location: location
    tags: union(tags, { 'azd-service-name': 'web-app' })
    name: name
    servicePlanId: servicePlanId
    kind: 'app,linux'
    linuxFxVersion: 'Python|3.12'
    appCommandLine: 'python -m uvicorn main:app --host 0.0.0.0 --port 8000'
    alwaysOn: true
    healthCheckPath: '/health'
    appSettings: [
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: appInsightsConnectionString
      }
      {
        name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
        value: '~3'
      }
      {
        name: 'XDT_MicrosoftApplicationInsights_Mode'
        value: 'default'
      }
    ]
    appInsightsConnectionString: appInsightsConnectionString
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    diagnosticLogs: !empty(logAnalyticsWorkspaceId)
    ? [
      {
        category: 'AppServiceHTTPLogs'
        enabled: enableLogs
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: enableLogs
      }
      {
        category: 'AppServiceAppLogs'
        enabled: enableLogs
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: enableLogs
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: enableAuditLogs
      }
      {
        category: 'AppServiceIPSecAuditLogs'
        enabled: enableAuditLogs
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
    tags: union(tags, { 'azd-service-name': 'web-app-${slot.name}' })
    name: slot.name
    appServiceName: app.outputs.name
    servicePlanId: servicePlanId
    kind: 'app,linux'
    linuxFxVersion: 'Python|3.12'
    appCommandLine: 'python -m uvicorn main:app --host 0.0.0.0 --port 8000'
    appSettings: [
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: appInsightsConnectionString
      }
      {
        name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
        value: '~3'
      }
      {
        name: 'XDT_MicrosoftApplicationInsights_Mode'
        value: 'default'
      }
    ]
    appInsightsConnectionString: appInsightsConnectionString
  }
}]

output appId string = app.outputs.id
output appName string = app.outputs.name
output appHostName string = app.outputs.defaultHostName
output appPrincipalId string = app.outputs.principalId
