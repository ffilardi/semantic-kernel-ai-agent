param serviceName string
param roleNames array
param principalId string
param principalType string = 'ServicePrincipal'

var builtInRoles = {
  'Cosmos DB Operator': '230815da-be43-4aae-9cb4-875f7bd000aa'
  'Cosmos DB Account Reader Role': 'fbdf93bf-df7d-467e-a4d2-9458aa1360c8'
}

var roleDefinitionIds = [for roleName in roleNames: builtInRoles[roleName]]

resource service 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: serviceName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for roleDefinitionId in roleDefinitionIds: {
  scope: service
  name: guid(subscription().id, principalId, roleDefinitionId)
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalType: principalType
  }
}]

