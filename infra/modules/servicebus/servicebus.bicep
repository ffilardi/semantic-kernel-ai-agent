param location string = resourceGroup().location
param tags object = {}
param serviceBusName string
param logAnalyticsWorkspaceId string = ''
param queues array = []
param topics array = []


module namespace './resources/namespace.bicep' = {
  name: serviceBusName
  params: {
    location: location
    tags: tags
    name: serviceBusName
    sku: 'Standard'
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

module queue './resources/queue.bicep' = [for queue in queues: {
  name: '${serviceBusName}-${queue.name}'
  params: {
    namespace: namespace.outputs.name
    name: queue.name
  }
}]

module topic './resources/topic.bicep' = [for topic in topics: {
  name: '${serviceBusName}-${topic.name}'
  params: {
    namespace: namespace.outputs.name
    name: topic.name
  }
}]

output namespaceId string = namespace.outputs.id
output namespaceName string = namespace.outputs.name
output namespaceHost string = namespace.outputs.hostname
