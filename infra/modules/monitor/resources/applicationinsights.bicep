param location string = resourceGroup().location
param tags object = {}
param name string
param kind string
param logAnalyticsWorkspaceId string
param publicNetworkAccessForQuery string = 'Enabled'
param publicNetworkAccessForIngestion string = 'Enabled'

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  location: location
  tags: union(tags, { 'azd-service-name': name })
  name: name
  kind: kind
  properties: {
    Application_Type: kind
    WorkspaceResourceId: logAnalyticsWorkspaceId
    publicNetworkAccessForQuery: publicNetworkAccessForQuery
    publicNetworkAccessForIngestion: publicNetworkAccessForIngestion
  }
}

output id string = applicationInsights.id
output name string = applicationInsights.name
output connectionString string = applicationInsights.properties.ConnectionString
output instrumentationKey string = applicationInsights.properties.InstrumentationKey
