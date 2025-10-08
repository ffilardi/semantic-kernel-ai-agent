param location string = resourceGroup().location
param tags object = {}
param name string
param sku string
param skuCount int
param availabilityZones array = []
param identityType string = 'SystemAssigned'
param publisherEmail string = 'noreply@email.com'
param publisherName string = 'n/a'
param applicationInsightsId string = ''
param applicationInsightsInstrumentationKey string = ''
param logAnalyticsWorkspaceId string = ''
param enableLogs bool = true
param enableAuditLogs bool = false
param enableMetrics bool = true

resource apimService 'Microsoft.ApiManagement/service@2024-05-01' = {
  location: location
  tags: union(tags, { 'azd-service-name': name })
  name: name
  sku: {
    name: sku
    capacity: (sku == 'Consumption') ? 0 : ((sku == 'Developer') ? 1 : skuCount)
  }
  zones: ((length(availabilityZones) == 0) ? null : availabilityZones)
  identity: {
    type: identityType
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    customProperties: sku == 'Consumption' ? {} // Custom properties are not supported for Consumption SKU
    : {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_GCM_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'false'
    }
  }
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2024-05-01' = if (!empty(applicationInsightsId) && !empty(applicationInsightsInstrumentationKey)) {
  parent: apimService
  name: '${name}-logger'
  properties: {
    credentials: {
      instrumentationKey: applicationInsightsInstrumentationKey
    }
    description: 'API Management Logger to Application Insights'
    loggerType: 'applicationInsights'
    resourceId: applicationInsightsId
    isBuffered: false
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticsettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'Logging'
  scope: apimService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
        {
          category: null
          categoryGroup: 'allLogs'
          enabled: enableLogs
      }
      {
          category: null
          categoryGroup: 'audit'
          enabled: enableAuditLogs
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: enableMetrics
      }
    ]
  }
}

output id string = apimService.id
output name string = apimService.name
output publicIPAddresses string = apimService.properties.publicIPAddresses[0]
output hostName string = apimService.properties.hostnameConfigurations[0].hostName
output developerPortalUrl string = replace(apimService.properties.developerPortalUrl, 'https://', '')
output principalId string = apimService.identity.principalId
