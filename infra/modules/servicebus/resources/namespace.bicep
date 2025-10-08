param location string = resourceGroup().location
param tags object = {}
param name string
param sku string
param logAnalyticsWorkspaceId string = ''
param identityType string = 'SystemAssigned'
param minimumTlsVersion string = '1.2'
param zoneRedundat bool = false
param trustedServiceAccess bool = true
param publicNetworkAccess string = 'Enabled'
param enableLogs bool = true
param enableAuditLogs bool = false
param enableMetrics bool = true

resource namespace 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
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
    minimumTlsVersion: minimumTlsVersion
    zoneRedundant: zoneRedundat
  }
  resource networkRuleset 'networkRuleSets@2024-01-01' = {
    name: 'default'
    properties: {
      publicNetworkAccess: publicNetworkAccess
      trustedServiceAccessEnabled: trustedServiceAccess
    }
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticsettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'Logging'
  scope: namespace
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

output id string = namespace.id
output name string = namespace.name
output hostname string = namespace.properties.serviceBusEndpoint
