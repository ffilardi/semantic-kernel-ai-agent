param location string = resourceGroup().location
param tags object = {}
param name string
param servicePlanId string
param kind string
param appSettings array = []
param appInsightsConnectionString string = ''
param logAnalyticsWorkspaceId string = ''
param enableLogs bool = true
param enableMetrics bool = true
param enableAuditLogs bool = false
param stagingSlots array = []
param linuxFxVersion string = ''
param appCommandLine string = ''
param healthCheckPath string = ''

module app 'app-service.bicep' = {
  name: name
  params: {
    location: location
    tags: tags
    name: name
    servicePlanId: servicePlanId
    kind: kind
    linuxFxVersion: linuxFxVersion
    appCommandLine: appCommandLine
    healthCheckPath: healthCheckPath
    appSettings: union([
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
    ], appSettings)
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
    tags: union(tags, { 'azd-service-name': '${name}-${slot.name}' })
    name: slot.name
    appServiceName: app.outputs.name
    servicePlanId: servicePlanId
    kind: kind
    linuxFxVersion: linuxFxVersion
    appCommandLine: appCommandLine
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
