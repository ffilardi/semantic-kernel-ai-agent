param accountName string
param isBlobSoftDeleteEnabled bool = true
param blobSoftDeleteRetentionDays int = 7
param isContainerSoftDeleteEnabled bool = true
param containerSoftDeleteRetentionDays int = 7
param logAnalyticsWorkspaceId string = ''
param enableLogs bool = true
param enableAuditLogs bool = false
param enableMetrics bool = true

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: accountName
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: isBlobSoftDeleteEnabled
      days: blobSoftDeleteRetentionDays
    }
    containerDeleteRetentionPolicy: {
      enabled: isContainerSoftDeleteEnabled
      days: containerSoftDeleteRetentionDays
    }
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticsettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'Logging'
  scope: blobServices
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
