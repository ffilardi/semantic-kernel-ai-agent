param location string = resourceGroup().location
param tags object = {}
param name string
param kind string
param databaseAccountOfferType string
param totalThroughputLimit int
param identityType string = 'SystemAssigned'
param defaultConsistencyLevel string = 'Session'
param maxIntervalInSeconds int = 5
param maxStalenessPrefix int = 100
param failoverPriority int = 0
param isZoneRedundant bool = false
param enableAutomaticFailover bool = false
param enableMultipleWriteLocations bool = false
param isVirtualNetworkFilterEnabled bool = false
param enableFreeTier bool = true
param enableAnalyticalStorage bool = false
@allowed(['Periodic','Continuous'])
param backupType string = 'Periodic'
param backupIntervalInMinutes int = 240
param backupRetentionIntervalInHours int = 8
param backupStorageRedundancy string = 'Local'
param virtualNetworkRules array = []
param networkAclBypass string = 'AzureServices'
param networkAclBypassResourceIds array = []
param ipRules array = []
param minimalTlsVersion string = 'Tls12'
param publicNetworkAccess string = 'Enabled'
param logAnalyticsWorkspaceId string = ''
param enableLogs bool = true
param enableAuditLogs bool = false
param enableMetrics bool = true

resource account 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  location: location
  tags: union(tags, { 'azd-service-name': name })
  name: name
  kind: kind
  identity: {
    type: identityType
  }
  properties: {
    databaseAccountOfferType: databaseAccountOfferType
    locations: [
      {
        locationName: location
        failoverPriority: failoverPriority
        isZoneRedundant: isZoneRedundant
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: defaultConsistencyLevel
      maxIntervalInSeconds: maxIntervalInSeconds
      maxStalenessPrefix: maxStalenessPrefix
    }
    capabilities: []
    capacity: {
        totalThroughputLimit: totalThroughputLimit
    }
    virtualNetworkRules: virtualNetworkRules
    ipRules: ipRules
    networkAclBypass: networkAclBypass
    networkAclBypassResourceIds: networkAclBypassResourceIds
    minimalTlsVersion: minimalTlsVersion
    publicNetworkAccess: publicNetworkAccess
    enableMultipleWriteLocations: enableMultipleWriteLocations
    enableAutomaticFailover: enableAutomaticFailover
    isVirtualNetworkFilterEnabled: isVirtualNetworkFilterEnabled
    enableFreeTier: enableFreeTier
    enableAnalyticalStorage: enableAnalyticalStorage
    backupPolicy: backupType == 'Periodic' ? {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: backupIntervalInMinutes
        backupRetentionIntervalInHours: backupRetentionIntervalInHours
        backupStorageRedundancy: backupStorageRedundancy
      }
    } : {
      type: 'Continuous'
    }
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticsettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'Logging'
  scope: account
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

output id string = account.id
output name string = account.name
output endpoint string = account.properties.documentEndpoint
