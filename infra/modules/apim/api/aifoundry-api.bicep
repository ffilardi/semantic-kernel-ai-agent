param apimServiceName string
param backendUrls array = []
param backendResourceIds array = []
param subscriptionRequired bool = true
param enableLoadBalancing bool = false
param backendWeights array = []
param backendPriorities array = []
param applicationInsightsLoggerName string = ''
param enableApplicationInsightsDiagnostics bool = false
param enableAzureMonitorDiagnostics bool = false
param samplingPercentage int = 100
param logClientIpAddress bool = true
param alwaysLogErrors bool = true
@allowed(['verbose', 'information', 'error'])
param verbosity string = 'information'
param payloadBytesToLog int = 8192
param headersToLog string[] = []
param enableLLMMessages bool = false
param logPrompts bool = true
param maxPromptSizeBytes int = 32768
param logCompletions bool = true
param maxCompletionSizeBytes int = 32768

var apiName = 'ai-foundry-api'
var apiDisplay = 'AI Foundry API'
var apiDescription = 'AI Foundry OpenAI API'
var apiPath = 'openai'
var apiDefinition = string(loadYamlContent('aifoundry-api-definition.yaml'))
var apiDefinitionFormat = 'openapi+json'
var apiRevision = '1'
var apiBackendId = 'ai-foundry-backend'
var apiBackendPoolId = '${apiBackendId}-pool'

var apiPolicyDefinition = loadTextContent('../policies/aifoundry-api-policy.xml')
var apiPolicyFormat = 'rawxml'

var customHeadersToLog = union(headersToLog, [
  'x-ratelimit-limit-requests'
  'x-ratelimit-remaining-requests'
  'x-ratelimit-limit-tokens'
  'x-ratelimit-remaining-tokens'
  'x-apim-ratelimit-consumed-tokens'
  'x-apim-ratelimit-remaining-tokens'
  'x-apim-ratelimit-remaining-quota-tokens'
  'x-ms-deployment-name'
])

resource apimService 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimServiceName
}

// Create individual backends for each URL
resource backends 'Microsoft.ApiManagement/service/backends@2024-05-01' = [for (url, i) in backendUrls: {
  name: '${apiBackendId}-${i+1}'
  parent: apimService
  properties: {
    description: '${apiDescription} - Backend ${i+1}'
    url: url
    resourceId: replace('${az.environment().resourceManager}/${backendResourceIds[i]}', '///', '/')
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}]

// Create backend pool for load balancing
resource backendPool 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = if (enableLoadBalancing) {
  name: apiBackendPoolId
  parent: apimService
  #disable-next-line BCP035
  properties: {
    description: '${apiDescription} - Load Balanced Pool'
    type: 'Pool'
    pool: {
      services: [for (url, i) in backendUrls: {
        id: backends[i].id
        priority: empty(backendPriorities) ? 0 : backendPriorities[i]
        weight: empty(backendWeights) ? 0 : backendWeights[i]
      }]
    }
  }
  dependsOn: backends
}

resource api 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  name: apiName
  parent: apimService
  properties: {
    path: apiPath
    displayName: apiDisplay
    apiRevision: apiRevision
    isCurrent: true
    subscriptionRequired: subscriptionRequired
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    format: apiDefinitionFormat
    value: apiDefinition
    protocols: [
      'https'
    ]
  }
  dependsOn: enableLoadBalancing ? [backendPool] : [backends]
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  name: 'policy'
  parent: api
  properties: {
    value: apiPolicyDefinition
    format: apiPolicyFormat
  }
  dependsOn: enableLoadBalancing ? [backendPool] : [backends]
}

// Application Insights diagnostics configuration
resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2024-05-01' = if (enableApplicationInsightsDiagnostics && !empty(applicationInsightsLoggerName)) {
  name: 'applicationinsights'
  parent: api
  properties: {
    loggerId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.ApiManagement/service/${apimServiceName}/loggers/${applicationInsightsLoggerName}'
    sampling: {
      samplingType: 'fixed'
      percentage: samplingPercentage
    }
    frontend: {
      request: {
        headers: customHeadersToLog
        body: {
          bytes: payloadBytesToLog
        }
      }
      response: {
        headers: customHeadersToLog
        body: {
          bytes: payloadBytesToLog
        }
      }
    }
    backend: {
      request: {
        headers: customHeadersToLog
        body: {
          bytes: payloadBytesToLog
        }
      }
      response: {
        headers: customHeadersToLog
        body: {
          bytes: payloadBytesToLog
        }
      }
    }
    logClientIp: logClientIpAddress
    httpCorrelationProtocol: 'Legacy'
    verbosity: verbosity
    operationNameFormat: 'Name'
    metrics: true
    alwaysLog: alwaysLogErrors ? 'allErrors' : 'none'
  }
}

// Azure Monitor diagnostics configuration
resource apiAzureMonitorDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2024-06-01-preview' = if (enableAzureMonitorDiagnostics) {
  name: 'azuremonitor'
  parent: api
  properties: {
    // Reference the built-in Azure Monitor logger
    loggerId: '/loggers/azuremonitor'
    sampling: {
      samplingType: 'fixed'
      percentage: samplingPercentage
    }
    frontend: {
      request: {
        headers: customHeadersToLog
        body: {
          bytes: payloadBytesToLog
        }
      }
      response: {
        headers: customHeadersToLog
        body: {
          bytes: payloadBytesToLog
        }
      }
    }
    backend: {
      request: {
        headers: customHeadersToLog
        body: {
          bytes: payloadBytesToLog
        }
      }
      response: {
        headers: customHeadersToLog
        body: {
          bytes: payloadBytesToLog
        }
      }
    }
    logClientIp: logClientIpAddress
    verbosity: verbosity
    alwaysLog: alwaysLogErrors ? 'allErrors' : 'none'
    metrics: true
    largeLanguageModel: enableLLMMessages ? {
      logs: 'enabled'
      requests: logPrompts ? {
        messages: 'all'
        maxSizeInBytes: maxPromptSizeBytes
      } : null
      responses: logCompletions ? {
        messages: 'all'
        maxSizeInBytes: maxCompletionSizeBytes
      } : null
    } : null
  }
}

output apiPath string = '${apimService.properties.gatewayUrl}/${apiPath}'
