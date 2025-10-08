param location string = resourceGroup().location
param tags object = {}
param storageName string
param logAnalyticsWorkspaceId string = ''

module account './resources/account.bicep' = {
  name: storageName
  params: {
    location: location
    tags: tags
    name: storageName
    kind: 'StorageV2'
    sku: 'Standard_LRS'
    accessTier: 'Hot'
  }
}

module blob './resources/blob.bicep' = {
  name: '${storageName}-blob'
  params: {
    accountName: account.outputs.name
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

module file './resources/file.bicep' = {
  name: '${storageName}-file'
  params: {
    accountName: account.outputs.name
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

module table './resources/table.bicep' = {
  name: '${storageName}-table'
  params: {
    accountName: account.outputs.name
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

module queue './resources/queue.bicep' = {
  name: '${storageName}-queue'
  params: {
    accountName: account.outputs.name
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

output accountId string = account.outputs.id
output accountName string = account.outputs.name
