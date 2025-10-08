param namespace string
param name string
param maxSizeMB int = 1024
param duplicateDetection bool = false
param duplicateDetectionHistoryTimeWindow string = 'PT10M'
param defaultMessageTimeToLive string = 'P7D'
param partitioning bool = false

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2024-01-01' existing = {
  name: namespace
}

resource topic 'Microsoft.ServiceBus/namespaces/topics@2024-01-01' = {
  parent: serviceBusNamespace
  name: name
  properties: {
    maxSizeInMegabytes: maxSizeMB
    requiresDuplicateDetection: duplicateDetection
    defaultMessageTimeToLive: defaultMessageTimeToLive
    duplicateDetectionHistoryTimeWindow: duplicateDetectionHistoryTimeWindow
    enablePartitioning: partitioning
  }
}
