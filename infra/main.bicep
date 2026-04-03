targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('App Service app name. Must be globally unique.')
param appName string = 'chatbubble-${uniqueString(resourceGroup().id)}'

@description('App Service plan name.')
param appServicePlanName string = '${appName}-plan'

@description('AI Horde API key passed to the app as an environment variable.')
@secure()
param aiHordeApiKey string

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: 'F1'
    tier: 'Free'
    size: 'F1'
    capacity: 1
  }
  properties: {
    reserved: true
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
          name: 'PROMPTY_PATH'
          value: '/home/site/wwwroot/prompts/agent-plane-talk.prompty'
        }
      ]
    }
    httpsOnly: true
  }
}

output AZURE_WEBAPP_NAME string = webApp.name
output AZURE_WEBAPP_URL string = 'https://${webApp.properties.defaultHostName}'
