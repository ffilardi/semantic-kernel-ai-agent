param accountName string
param logAnalyticsWorkspaceId string = ''
param enableLogs bool = true
param enableAuditLogs bool = false
param enableMetrics bool = true

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: accountName
}

resource queueServices 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticsettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'Logging'
  scope: queueServices
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
