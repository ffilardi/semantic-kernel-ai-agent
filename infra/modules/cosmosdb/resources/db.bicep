param accountName string
param name string
param containerName string
param partitionKey string
param indexingMode string = 'consistent'
param partitionKeyKind string = 'Hash'
param partitionKeyVersion int = 2
param conflictResolutionPolicyMode string = 'LastWriterWins'

resource account 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: accountName
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: account
  name: name
  properties: {
    resource: {
      id: name
    }
  }
}

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: database
  name: containerName
  properties: {
    resource: {
      id: containerName
      indexingPolicy: {
        indexingMode: indexingMode
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
      }
      partitionKey: {
        paths: [
          partitionKey
        ]
        kind: partitionKeyKind
        version: partitionKeyVersion
      }
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
      conflictResolutionPolicy: {
        mode: conflictResolutionPolicyMode
        conflictResolutionPath: '/_ts'
      }
    }
  }
}

output id string = database.id
output name string = database.name
output container string = container.name
