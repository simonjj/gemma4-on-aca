targetScope = 'resourceGroup'

@description('Location for all resources')
param location string

@description('Environment name for resource naming')
param environmentName string

@description('Unique suffix for resource names')
param resourceToken string

@description('Username for nginx basic auth')
param proxyAuthUser string = 'admin'

@description('Password for nginx basic auth')
@secure()
param proxyAuthPassword string

@description('GPU workload profile type')
param gpuProfileType string

@description('Ollama model to pull and serve')
param ollamaModel string

@description('Container image registry prefix (must allow anonymous pull)')
param imageRegistry string = 'simon.azurecr.io/gemma4-on-aca'

@description('Enable diagnostic logging')
param enableDebugging bool = false

// GPU resource allocation lookup
var gpuResources = gpuProfileType == 'Consumption-GPU-NC24-A100' ? {
  cpu: 24
  memory: '220Gi'
} : {
  cpu: 8
  memory: '56Gi'
}

var baseName = toLower('${environmentName}-${resourceToken}')
var containerAppsEnvironmentName = 'cae-${baseName}'
var ollamaAppName = 'ollama-${baseName}'
var nginxAuthProxyAppName = 'proxy-${baseName}'
var logAnalyticsWorkspaceName = 'log-${baseName}'

// ─── Log Analytics (optional) ───
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = if (enableDebugging) {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    retentionInDays: 30
    features: { enableLogAccessUsingOnlyResourcePermissions: true }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ─── ACA Environment with GPU workload profile ───
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppsEnvironmentName
  location: location
  properties: union({
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
      {
        name: 'GPU'
        workloadProfileType: gpuProfileType
      }
    ]
  }, enableDebugging ? {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: listKeys(logAnalyticsWorkspace.id, '2020-08-01').primarySharedKey
      }
    }
  } : {})
}

// ─── Ollama Container App (GPU, internal) ───
resource ollamaApp 'Microsoft.App/containerApps@2025-02-02-preview' = {
  name: ollamaAppName
  location: location
  properties: {
    environmentId: containerAppsEnvironment.id
    workloadProfileName: 'GPU'
    configuration: {
      ingress: {
        external: false
        targetPort: 11434
        allowInsecure: true
      }
    }
    template: {
      containers: [
        {
          name: 'ollama'
          image: '${imageRegistry}/ollama:latest'
          env: [
            {
              name: 'OLLAMA_MODEL'
              value: ollamaModel
            }
            {
              name: 'OLLAMA_CONTEXT_LENGTH'
              value: '32768'
            }
            {
              name: 'OLLAMA_KEEP_ALIVE'
              value: '15m'
            }
          ]
          resources: {
            cpu: gpuResources.cpu
            memory: gpuResources.memory
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

// ─── Nginx Auth Proxy (Consumption, external) ───
resource nginxAuthProxyApp 'Microsoft.App/containerApps@2025-02-02-preview' = {
  name: nginxAuthProxyAppName
  location: location
  properties: {
    environmentId: containerAppsEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        transport: 'Auto'
        allowInsecure: false
      }
      secrets: [
        {
          name: 'basic-auth-password'
          value: proxyAuthPassword
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'nginx-auth-proxy'
          image: '${imageRegistry}/nginx-auth-proxy:latest'
          env: [
            {
              name: 'BACKEND_URL'
              value: ollamaApp.properties.configuration.ingress.fqdn
            }
            {
              name: 'BASIC_AUTH_USER'
              value: proxyAuthUser
            }
            {
              name: 'BASIC_AUTH_PASSWORD'
              secretRef: 'basic-auth-password'
            }
            {
              name: 'BACKEND_TIMEOUT'
              value: '600'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

// ─── Outputs ───
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = containerAppsEnvironment.id
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = containerAppsEnvironment.name
output OLLAMA_APP_NAME string = ollamaApp.name
output NGINX_AUTH_PROXY_APP_NAME string = nginxAuthProxyApp.name
output OLLAMA_PROXY_ENDPOINT string = 'https://${nginxAuthProxyApp.properties.configuration.ingress.fqdn}'
