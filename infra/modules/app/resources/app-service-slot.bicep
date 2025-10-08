param location string = resourceGroup().location
param tags object = {}
param name string
param appServiceName string
param servicePlanId string
param kind string
param linuxFxVersion string = ''
param netFrameworkVersion string = ''
param appCommandLine string = ''
param alwaysOn bool = false
param appSettings array = []
param identityType string = 'SystemAssigned'
param ftpsState string = 'Disabled'
param use32BitWorkerProcess bool = false
param functionAppScaleLimit int = 0
param buildOnDeployment string = 'true'
param runFromPackage string = '0'
param httpsOnly bool = true
param clientAffinityEnabled bool = false
param clientCertEnabled bool = false
param clientCertMode string = 'Required'
param publicNetworkAccess string = 'Enabled'
param healthCheckPath string = ''
param appInsightsConnectionString string = ''

resource app 'Microsoft.Web/sites@2024-04-01' existing = {
  name: appServiceName
}

resource appSlot 'Microsoft.Web/sites/slots@2024-04-01' = {
  parent: app
  name: name
  location: location
  tags: tags
  kind: kind
  identity: {
    type: identityType
  }
  properties: {
    serverFarmId: servicePlanId
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      appCommandLine: appCommandLine
      ftpsState: ftpsState
      alwaysOn: alwaysOn
      healthCheckPath: healthCheckPath
      use32BitWorkerProcess: use32BitWorkerProcess
      netFrameworkVersion: netFrameworkVersion
      functionAppScaleLimit: functionAppScaleLimit
      appSettings: union(appSettings,
        [
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: appInsightsConnectionString
          }
          {
            name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
            value: buildOnDeployment
          }
          {
            name: 'WEBSITE_RUN_FROM_PACKAGE'
            value: runFromPackage
          }
        ])
    }
    httpsOnly: httpsOnly
    clientAffinityEnabled: clientAffinityEnabled
    clientCertEnabled: clientCertEnabled
    clientCertMode: clientCertMode
    publicNetworkAccess: publicNetworkAccess
  }
}

output id string = appSlot.id
output name string = appSlot.name
output defaultHostName string = 'https://${appSlot.properties.defaultHostName}/'
