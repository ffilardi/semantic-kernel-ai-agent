param location string = resourceGroup().location
param tags object = {}
param logAnalyticsName string
param applicationInsightsName string
param dashboardName string

module logAnalytics './resources/loganalytics.bicep' = {
  name: logAnalyticsName
  params: {
    location: location
    tags: tags
    name: logAnalyticsName
    sku: 'PerGB2018'
  }
}

module applicationInsights './resources/applicationinsights.bicep' = {
  name: applicationInsightsName
  params: {
    location: location
    tags: tags
    name: applicationInsightsName
    kind: 'web'
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

module dashboard './resources/applicationinsights-dashboard.bicep' = {
  name: dashboardName
  params: {
    location: location
    tags: tags
    name: dashboardName
    applicationInsightsName: applicationInsights.name
  }
}

output logAnalyticsWorkspaceId string = logAnalytics.outputs.id
output logAnalyticsWorkspaceName string = logAnalytics.outputs.name
output applicationInsightsId string = applicationInsights.outputs.id
output applicationInsightsName string = applicationInsights.outputs.name
output applicationInsightsConnectionString string = applicationInsights.outputs.connectionString
output applicationInsightsInstrumentationKey string = applicationInsights.outputs.instrumentationKey
output dashboardId string = dashboard.outputs.id
output dashboardName string = dashboard.outputs.name
