param location string = resourceGroup().location
param tags object = {}
param apimServiceName string
param applicationInsightsId string = ''
param applicationInsightsInstrumentationKey string = ''
param logAnalyticsWorkspaceId string = ''
param commonResourceGroupName string = ''
param keyVaultName string = ''

module apimService './resources/apim-service.bicep' = {
  name: apimServiceName
  params: {
    location: location
    tags: tags
    name: apimServiceName
    sku: 'Developer'
    skuCount: 1
    applicationInsightsId: applicationInsightsId
    applicationInsightsInstrumentationKey: applicationInsightsInstrumentationKey
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

module apimServiceRbac01 '../security/keyvault-rbac.bicep' = if (!empty(commonResourceGroupName) && !empty(keyVaultName)) {
  name: '${apimServiceName}-rbac-01'
  scope: resourceGroup(commonResourceGroupName)
  params: {
    serviceName: keyVaultName
    roleNames: [ 'Key Vault Secrets User' ]
    principalId: apimService.outputs.principalId
  }
}

output apimServiceId string = apimService.outputs.id
output apimServiceName string = apimService.outputs.name
output apimServiceHostName string = apimService.outputs.hostName
output apimServiceDeveloperPortalUrl string = apimService.outputs.developerPortalUrl
output apimServicePrincipalId string = apimService.outputs.principalId
