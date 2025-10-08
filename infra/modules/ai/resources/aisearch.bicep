param location string = resourceGroup().location
param tags object = {}
param name string
param sku string 
param hostingMode string
param semanticSearch string
param identityType string = 'SystemAssigned'
param partitionCount int = 1
param replicaCount int = 1
param ipRules array = []
param publicNetworkAccess string = 'Enabled'
param logAnalyticsWorkspaceId string = ''
param enableLogs bool = true
param enableAuditLogs bool = false
param enableMetrics bool = true

resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  location: location
  tags: union(tags, { 'azd-service-name': name })
  name: name
  sku: {
    name: sku
  }
  identity: {
    type: identityType
  }
  properties: {
    partitionCount: partitionCount
    replicaCount: replicaCount
    hostingMode: hostingMode
    networkRuleSet: empty(ipRules) ? null : {
      ipRules: ipRules
    }
    semanticSearch: semanticSearch
    publicNetworkAccess: publicNetworkAccess
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticsettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'Logging'
  scope: searchService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
        {
          category: null
          categoryGroup: 'allLogs'
          enabled: enableLogs
      }
      {
          category: null
          categoryGroup: 'audit'
          enabled: enableAuditLogs
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: enableMetrics
      }
    ]
  }
}

output id string = searchService.id
output name string = searchService.name
output uri string = 'https://${searchService.name}.search.windows.net/'
output principalId string = searchService.identity.principalId
