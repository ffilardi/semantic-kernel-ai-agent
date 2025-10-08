param location string = resourceGroup().location
param tags object = {}
param name string
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
param allowedOrigins array = ['https://portal.azure.com']
param allowFtpPublishing bool = false
param allowScmPublishing bool = true
param buildOnDeployment string = 'true'
param runFromPackage string = '0'
param httpsOnly bool = true
param clientAffinityEnabled bool = false
param clientCertEnabled bool = false
param clientCertMode string = 'Required'
param publicNetworkAccess string = 'Enabled'
param healthCheckPath string = ''
param fileSystemLogLevel string = 'Error'
param fileSystemDetailedErrorMessages bool = false
param fileSystemFailedRequestsTracing bool = false
param fileSystemHttpLogsEnabled bool = false
param fileSystemRetentionInDays int = 1
param fileSystemRetentionInMb int = 35
param appInsightsConnectionString string = ''
param logAnalyticsWorkspaceId string = ''
param diagnosticLogs array = []
param diagnosticMetrics array = []

resource app 'Microsoft.Web/sites@2024-04-01' = {
  location: location
  tags: tags
  name: name
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
      cors: { allowedOrigins: allowedOrigins }
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

  resource logs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: {
        fileSystem: {
          level: fileSystemLogLevel
        }
      }
      detailedErrorMessages: {
        enabled: fileSystemDetailedErrorMessages
      }
      failedRequestsTracing: {
        enabled: fileSystemFailedRequestsTracing
      }
      httpLogs: {
        fileSystem: {
          enabled: fileSystemHttpLogsEnabled
          retentionInDays: fileSystemRetentionInDays
          retentionInMb: fileSystemRetentionInMb
        }
      }
    }
  }
}

resource ftpBasicPublishingCred 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-04-01' = {
  parent: app
  name: 'ftp'
  properties: {
    allow: allowFtpPublishing
  }
}

resource scmBasicPublishingCred 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-04-01' = {
  parent: app
  name: 'scm'
  properties: {
    allow: allowScmPublishing
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticsettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'Logging'
  scope: app
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: diagnosticLogs
    metrics: diagnosticMetrics
  }
}

output id string = app.id
output name string = app.name
output defaultHostName string = 'https://${app.properties.defaultHostName}'
output principalId string = app.identity.principalId
