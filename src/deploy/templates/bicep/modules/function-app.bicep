// Azure Function App Module
@description('Function App name')
param functionAppName string

@description('Azure region')
param location string

@description('Environment (dev, test, staging, prod)')
param environment string

@description('Resource tags')
param tags object = {}

@description('Storage Account name for Function App')
param storageAccountName string

@description('Application Insights Instrumentation Key')
param appInsightsInstrumentationKey string

@description('Application Insights Connection String')
param appInsightsConnectionString string

@description('Service Bus Connection String')
@secure()
param serviceBusConnectionString string

@description('SQL Connection String')
@secure()
param sqlConnectionString string

// App Service Plan (Hosting Plan)
var hostingPlanName = '${functionAppName}-plan'
var functionWorkerRuntime = 'dotnet-isolated'

// SKU based on environment
var appServicePlanSku = environment == 'prod' ? {
  name: 'EP1'
  tier: 'ElasticPremium'
  size: 'EP1'
  family: 'EP'
  capacity: 1
} : {
  name: 'Y1'
  tier: 'Dynamic'
  size: 'Y1'
  family: 'Y'
  capacity: 0
}

resource hostingPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: hostingPlanName
  location: location
  tags: tags
  sku: appServicePlanSku
  properties: {
    reserved: false
  }
  kind: environment == 'prod' ? 'elastic' : 'functionapp'
}

// Function App
resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccountName), '2023-01-01').keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccountName), '2023-01-01').keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'ServiceBusConnection'
          value: serviceBusConnectionString
        }
        {
          name: 'SqlConnectionString'
          value: sqlConnectionString
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      netFrameworkVersion: 'v8.0'
      use32BitWorkerProcess: false
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
      }
    }
  }
}

// Staging slot for production (blue-green deployment)
resource stagingSlot 'Microsoft.Web/sites/slots@2023-01-01' = if (environment == 'prod') {
  parent: functionApp
  name: 'staging'
  location: location
  tags: tags
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: functionApp.properties.siteConfig.appSettings
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
  }
}

// Outputs
output functionAppName string = functionApp.name
output functionAppId string = functionApp.id
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output principalId string = functionApp.identity.principalId
output hostingPlanId string = hostingPlan.id
