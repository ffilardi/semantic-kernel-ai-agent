param location string = resourceGroup().location
param tags object = {}
param cosmosDbName string
param logAnalyticsWorkspaceId string = ''
param databases array = []


module account './resources/account.bicep' = {
  name: cosmosDbName
  params: {
    location: location
    tags: tags
    name: cosmosDbName
    kind: 'GlobalDocumentDB'
    databaseAccountOfferType: 'Standard'
    totalThroughputLimit: 1000
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

module database './resources/db.bicep' = [for db in databases: {
  name: '${cosmosDbName}-${db.name}'
  params: {
    accountName: account.outputs.name
    name: db.name
    containerName: db.container
    partitionKey: db.partitionKey
  }
}]

output cosmosDbId string = account.outputs.id
output cosmosDbName string = account.outputs.name
output cosmosDbUri string = account.outputs.endpoint
