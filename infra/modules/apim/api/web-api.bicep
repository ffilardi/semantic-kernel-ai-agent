param apimServiceName string
param backendUrl string
param backendResourceId string

var apiName = 'web-api'
var apiDisplay = 'Sample Web API'
var apiDescription = 'Sample Azure Web API backend service'
var apiPath = 'web'
var apiDefinition = string(loadYamlContent('web-api-definition.yaml'))
var apiDefinitionFormat = 'openapi+json'
var apiVersionSetId = 'web-api-versionset'
var apiVersion = 'v1'
var apiRevision = '1'
var apiProductId = 'web-product'
var apiProductName = 'Web API Product'
var apiBackendId = 'web-backend'

var apiPolicyDefinition = loadTextContent('../policies/web-api-policy.xml')
var apiPolicyFormat = 'rawxml'

resource apimService 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimServiceName
}

resource apiVersionSet 'Microsoft.ApiManagement/service/apiVersionSets@2024-05-01' = {
  name: apiVersionSetId
  parent: apimService
  properties: {
    displayName: apiDisplay
    versioningScheme: 'Segment'
    description: apiDescription
  }
}

resource backend 'Microsoft.ApiManagement/service/backends@2024-05-01' = {
  name: apiBackendId
  parent: apimService
  properties: {
    description: apiDescription
    url: backendUrl
    resourceId: replace('${az.environment().resourceManager}/${backendResourceId}', '///', '/')
    protocol: 'http'
    tls: {
      validateCertificateChain: false
      validateCertificateName: false
    }
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  name: apiName
  parent: apimService
  properties: {
    path: apiPath
    displayName: apiDisplay
    apiRevision: apiRevision
    apiVersion: apiVersion
    apiVersionSetId: apiVersionSet.id
    isCurrent: true
    subscriptionRequired: true
    format: apiDefinitionFormat
    value: apiDefinition
    protocols: [
      'https'
    ]
  }
  dependsOn: [
    backend
  ]
}

resource product 'Microsoft.ApiManagement/service/products@2024-05-01' = {
  name: apiProductId
  parent: apimService
  properties: {
    approvalRequired: false
    description: apiDescription
    displayName: apiProductName
    state: 'published'
    subscriptionRequired: true
  }
}

resource productLink 'Microsoft.ApiManagement/service/products/apiLinks@2024-05-01' = {
  name: '${apiProductId}-link'
  parent: product
  properties: {
    apiId: api.id
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  name: 'policy'
  parent: api
  properties: {
    value: apiPolicyDefinition
    format: apiPolicyFormat
  }
  dependsOn: [
    backend
  ]
}
