param serviceName string
param roleNames array
param principalId string
param principalType string = 'ServicePrincipal'

var builtInRoles = {
  'Azure AI User': '53ca6127-db72-4b80-b1b0-d745d6d5456d'
  'Azure AI Project Manager': 'eadc314b-1a2d-4efa-be10-5d325db5065e'
  'Azure AI Account Owner': 'e47c6f54-e4a2-4754-9501-8e0985b135e1'
}

var roleDefinitionIds = [for roleName in roleNames: builtInRoles[roleName]]

resource service 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
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
