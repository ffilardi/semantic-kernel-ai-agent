
param location string = resourceGroup().location
param tags object = {}
param name string
param kind string
param sku string
param accessTier string
param isHnsEnabled bool = false
param isSftpEnabled bool = false
param identityType string = 'SystemAssigned'
param minimumTlsVersion string = 'TLS1_2'
param supportsHttpsTrafficOnly bool = true
param allowBlobPublicAccess bool = false
param allowSharedKeyAccess bool = true
param defaultOAuth bool = false
param allowedCopyScope string = 'PrivateLink'
param allowCrossTenantReplication bool = false
param publicNetworkAccess string = 'Enabled'
param networkAclsBypass string = 'AzureServices'
param networkAclsDefaultAction string = 'Allow'
param networkAclsVirtualNetworkRules array = []
param networkAclsIpRules array = []
param dnsEndpointType string = 'Standard'
param keySource string = 'Microsoft.Storage'
param encryptionEnabled bool = true
param infrastructureEncryptionEnabled bool = false

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  location: location
  tags: union(tags, { 'azd-service-name': name })
  name: name
  kind: kind
  sku: {
    name: sku
  }
  identity: {
    type: identityType
  }
  properties: {
    minimumTlsVersion: minimumTlsVersion
    supportsHttpsTrafficOnly: supportsHttpsTrafficOnly
    allowBlobPublicAccess: allowBlobPublicAccess
    allowSharedKeyAccess: allowSharedKeyAccess
    defaultToOAuthAuthentication: defaultOAuth
    allowedCopyScope: allowedCopyScope
    accessTier: accessTier
    publicNetworkAccess: publicNetworkAccess
    allowCrossTenantReplication: allowCrossTenantReplication
    networkAcls: {
      bypass: networkAclsBypass
      defaultAction: networkAclsDefaultAction
      virtualNetworkRules: networkAclsVirtualNetworkRules
      ipRules: networkAclsIpRules
    }
    dnsEndpointType: dnsEndpointType
    isHnsEnabled: isHnsEnabled
    isSftpEnabled: isSftpEnabled
    encryption: {
      keySource: keySource
      services: {
        blob: {
          enabled: encryptionEnabled
        }
      }
      requireInfrastructureEncryption: infrastructureEncryptionEnabled
    }
  }
}

output id string = storageAccount.id
output name string = storageAccount.name
