targetScope = 'resourceGroup'

@description('Name of the environment used for resource naming')
param environmentName string

@description('Primary location for all resources')
param location string

@description('Password for nginx auth proxy basic authentication')
@secure()
param proxyAuthPassword string

@description('GPU workload profile type')
@allowed([
  'Consumption-GPU-NC8as-T4'
  'Consumption-GPU-NC24-A100'
])
param gpuProfileType string = 'Consumption-GPU-NC8as-T4'

@description('Ollama model to pull and serve')
param ollamaModel string = 'gemma4:e4b'

@description('Container image registry prefix (must allow anonymous pull)')
param imageRegistry string = 'simon.azurecr.io/gemma4-on-aca'

@description('Toggle diagnostic logging')
param enableDebugging bool = false

var resourceToken = take(toLower(uniqueString(subscription().id, environmentName, location)), 5)

module resources 'resources.bicep' = {
  name: 'resources'
  params: {
    location: location
    environmentName: environmentName
    resourceToken: resourceToken
    proxyAuthPassword: proxyAuthPassword
    gpuProfileType: gpuProfileType
    ollamaModel: ollamaModel
    imageRegistry: imageRegistry
    enableDebugging: enableDebugging
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = resources.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_ID
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = resources.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_NAME
output OLLAMA_APP_NAME string = resources.outputs.OLLAMA_APP_NAME
output NGINX_AUTH_PROXY_APP_NAME string = resources.outputs.NGINX_AUTH_PROXY_APP_NAME
output OLLAMA_PROXY_ENDPOINT string = resources.outputs.OLLAMA_PROXY_ENDPOINT
