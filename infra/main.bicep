targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('App Service app name. Must be globally unique.')
param appName string = 'chatbubble-${uniqueString(resourceGroup().id)}'

@description('Function App name. Must be globally unique.')
param functionAppName string = '${appName}-func'

@description('App Service plan name.')
param appServicePlanName string = '${appName}-plan'

@description('Function App Service plan name used when SKU is F1.')
param functionAppServicePlanName string = '${functionAppName}-plan'

@description('App Service plan SKU. Allowed values: F1 (Free) or B1/B3 (Basic).')
@allowed([
  'F1'
  'B1'
  'B3'
])
param appServiceSkuName string 

@description('User Assigned Managed Identity name for GitHub Actions deployments.')
param githubDeployIdentityName string = '${appName}-gha-mi'

@description('GitHub organization or user name that owns the repository.')
param githubOrg string = ''

@description('GitHub repository name for workload identity federation.')
param githubRepo string = ''

@description('GitHub branch allowed to request OIDC tokens for deployment.')
param githubBranch string = 'main'

@description('AI Horde API key passed to the app as an environment variable.')
@secure()
param aiHordeApiKey string

@description('AI Horde model identifier used by the chat backend.')
param aiHordeModel string = 'koboldcpp/LFM2.5-1.2B-Instruct'

@description('LatLng API key used by the weather MCP Function app.')
@secure()
param latLngApiKey string

@description('LatLng API base URL for forward geocoding requests.')
param latLngBaseUrl string = 'https://api.latlng.work/api'

@description('User-Agent header used when calling weather.gov.')
param nwsUserAgent string = 'simple-chat-bubble-weather-mcp/1.0 (contact: admin@example.com)'

var enableGithubFederation = !empty(githubOrg) && !empty(githubRepo)
var isFreeSku = appServiceSkuName == 'F1'
var appServiceSkuTier = appServiceSkuName == 'F1' ? 'Free' : 'Basic'
var functionStorageName = 'st${uniqueString(resourceGroup().id, functionAppName)}'

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: appServiceSkuName
    tier: appServiceSkuTier
    size: appServiceSkuName
    capacity: 1
  }
  properties: {
    reserved: true
  }
}

resource functionAppServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = if (isFreeSku) {
  name: functionAppServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: appServiceSkuName
    tier: appServiceSkuTier
    size: appServiceSkuName
    capacity: 1
  }
  properties: {
    reserved: true
  }
}

resource githubDeployIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: githubDeployIdentityName
  location: location
}

resource githubOidcFederatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = if (enableGithubFederation) {
  parent: githubDeployIdentity
  name: 'github-main'
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    audiences: [
      'api://AzureADTokenExchange'
    ]
    subject: 'repo:${githubOrg}/${githubRepo}:ref:refs/heads/${githubBranch}'
  }
}

resource webApp 'Microsoft.Web/sites@2024-04-01' = {
  name: appName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.13'
      alwaysOn: false
      appCommandLine: 'gunicorn --worker-class uvicorn.workers.UvicornWorker --bind=0.0.0.0:8000 app.main:app'
      appSettings: [
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'WEBSITES_PORT'
          value: '8000'
        }
        {
          name: 'AIHORDE_API_KEY'
          value: aiHordeApiKey
        }
        {
          name: 'AIHORDE_BASE_URL'
          value: 'https://oai.aihorde.net/v1'
        }
        {
          name: 'AIHORDE_MODEL'
          value: aiHordeModel
        }
      ]
    }
    httpsOnly: true
  }
}

resource functionStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: functionStorageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: isFreeSku ? functionAppServicePlan.id : appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.13'
      appSettings: [
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorage.name};AccountKey=${functionStorage.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'LATLNG_API_KEY'
          value: latLngApiKey
        }
        {
          name: 'LATLNG_BASE_URL'
          value: latLngBaseUrl
        }
        {
          name: 'NWS_USER_AGENT'
          value: nwsUserAgent
        }
      ]
    }
    httpsOnly: true
  }
}

output AZURE_WEBAPP_NAME string = webApp.name
output AZURE_WEBAPP_URL string = 'https://${webApp.properties.defaultHostName}'
output AZURE_FUNCTIONAPP_NAME string = functionApp.name
output AZURE_FUNCTIONAPP_URL string = 'https://${functionApp.properties.defaultHostName}'
output AIHORDE_MODEL string = aiHordeModel
output latLngApiKey string = latLngApiKey
output GITHUB_DEPLOY_MANAGED_IDENTITY_CLIENT_ID string = githubDeployIdentity.properties.clientId
output GITHUB_DEPLOY_MANAGED_IDENTITY_PRINCIPAL_ID string = githubDeployIdentity.properties.principalId
output GITHUB_DEPLOY_MANAGED_IDENTITY_RESOURCE_ID string = githubDeployIdentity.id
output APP_SERVICE_SKU_NAME string = appServiceSkuName
