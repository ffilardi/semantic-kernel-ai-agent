param serviceName string
param roleNames array
param principalId string
param principalType string = 'ServicePrincipal'

var builtInRoles = {
  'Search Index Data Contributor': '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  'Search Service Contributor': '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
}

var roleDefinitionIds = [for roleName in roleNames: builtInRoles[roleName]]

resource service 'Microsoft.Search/searchServices@2024-03-01-Preview' existing = {
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
