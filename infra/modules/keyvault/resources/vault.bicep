param location string = resourceGroup().location
param tags object = {}
param name string
param skuFamily string
param sku string
param enableRbacAuthorization bool = true
param enabledForTemplateDeployment bool = true
param publicNetworkAccess string = 'Enabled'
param networkAclsBypass string = 'AzureServices'
param networkAclsDefaultAction string = 'Allow'
param networkAclsVirtualNetworkRules array = []
param networkAclsIpRules array = []
param logAnalyticsWorkspaceId string = ''
param enableLogs bool = true
param enableAuditLogs bool = false
param enableMetrics bool = true

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  location: location
  tags: union(tags, { 'azd-service-name': name })
  name: name
  properties: {
    sku: {
      family: skuFamily
      name: sku
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: enableRbacAuthorization
    enabledForTemplateDeployment: enabledForTemplateDeployment
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      bypass: networkAclsBypass
      defaultAction: networkAclsDefaultAction
      virtualNetworkRules: networkAclsVirtualNetworkRules
      ipRules: networkAclsIpRules
    }
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticsettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'Logging'
  scope: vault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: enableAuditLogs
      }
      {
        categoryGroup: 'allLogs'
        enabled: enableLogs
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

output id string = vault.id
output name string = vault.name
output uri string = vault.properties.vaultUri
