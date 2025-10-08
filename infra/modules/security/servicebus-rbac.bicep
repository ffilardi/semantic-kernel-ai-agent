param serviceName string
param roleNames array
param principalId string
param principalType string = 'ServicePrincipal'

var builtInRoles = {
  'Azure Service Bus Data Owner': '090c5cfd-751d-490a-894a-3ce6f1109419'
  'Azure Service Bus Data Receiver': '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
  'Azure Service Bus Data Sender': '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
}

var roleDefinitionIds = [for roleName in roleNames: builtInRoles[roleName]]

resource service 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' existing = {
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
