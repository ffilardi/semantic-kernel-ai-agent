param accountName string
param retentionPolicyEnabled bool = false
param retentionPolicyDays int = 30
param logAnalyticsWorkspaceId string = ''
param enableLogs bool = true
param enableAuditLogs bool = false
param enableMetrics bool = true

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: accountName
}

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      days: retentionPolicyDays
      enabled: retentionPolicyEnabled
    }
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticsettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'Logging'
  scope: fileServices
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
