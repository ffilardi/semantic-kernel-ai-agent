param location string = resourceGroup().location
param tags object = {}
param vaultName string
param logAnalyticsWorkspaceId string = ''


module vault './resources/vault.bicep' = {
  name: vaultName
  params: {
    location: location
    tags: tags
    name: vaultName
    skuFamily: 'A'
    sku: 'standard'
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

output vaultId string = vault.outputs.id
output vaultName string = vault.outputs.name
output vaultEndpoint string = vault.outputs.uri
