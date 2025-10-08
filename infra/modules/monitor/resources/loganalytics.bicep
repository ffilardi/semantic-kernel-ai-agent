param location string = resourceGroup().location
param tags object = {}
param name string
param sku string
param retentionInDays int = 30
param publicNetworkAccessForQuery string = 'Enabled'
param publicNetworkAccessForIngestion string = 'Enabled'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  location: location
  tags: union(tags, { 'azd-service-name': name })
  name: name
  properties: any({
    sku: {
      name: sku
    }
    features: {
      searchVersion: 1
    }
    retentionInDays: retentionInDays
    publicNetworkAccessForIngestion: publicNetworkAccessForIngestion
    publicNetworkAccessForQuery: publicNetworkAccessForQuery
  })
}

output id string = logAnalytics.id
output name string = logAnalytics.name
