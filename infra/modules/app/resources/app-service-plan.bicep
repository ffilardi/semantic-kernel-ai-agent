param location string = resourceGroup().location
param tags object = {}
param name string
param sku string
param skuCode string
param reserved bool
param kind string = ''
param zoneRedundant bool = false

resource servicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  location: location
  tags: union(tags, { 'azd-service-name': name })
  name: name
  sku: {
    name: skuCode
    tier: sku
  }
  kind: kind
  properties: {
    reserved: reserved
    zoneRedundant: zoneRedundant
  }
}

output id string = servicePlan.id
