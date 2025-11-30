// Azure Function App Module with Key Vault Integration
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

@description('Key Vault name')
param keyVaultName string

@description('Use Key Vault for secrets')
param useKeyVault bool = true

@description('Key Vault Secret URIs')
param keyVaultSecretUris object = {}

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
    keyVaultReferenceIdentity: 'SystemAssigned'
    siteConfig: {
      appSettings: useKeyVault ? [
        // Storage for Functions runtime (not from Key Vault - required at startup)
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
        // Key Vault References for application secrets
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: '@Microsoft.KeyVault(SecretUri=${keyVaultSecretUris.appInsightsInstrumentationKey})'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: '@Microsoft.KeyVault(SecretUri=${keyVaultSecretUris.appInsightsConnectionString})'
        }
        {
          name: 'ServiceBusConnection'
          value: '@Microsoft.KeyVault(SecretUri=${keyVaultSecretUris.serviceBusConnection})'
        }
        {
          name: 'SqlConnectionString'
          value: '@Microsoft.KeyVault(SecretUri=${keyVaultSecretUris.sqlConnectionString})'
        }
        {
          name: 'StorageConnectionString'
          value: '@Microsoft.KeyVault(SecretUri=${keyVaultSecretUris.storageConnectionString})'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ] : [
        // Fallback without Key Vault (for testing)
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
    keyVaultReferenceIdentity: 'SystemAssigned'
    siteConfig: {
      appSettings: functionApp.properties.siteConfig.appSettings
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
  }
}

// Grant Function App access to Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = if (useKeyVault) {
  name: keyVaultName
}

resource functionAppKeyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = if (useKeyVault) {
  name: 'add'
  parent: keyVault
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: functionApp.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

// Grant Staging Slot access to Key Vault (if prod)
resource stagingSlotKeyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = if (useKeyVault && environment == 'prod') {
  name: 'add'
  parent: keyVault
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: stagingSlot.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
  dependsOn: [
    functionAppKeyVaultAccessPolicy
  ]
}

// Outputs
output functionAppName string = functionApp.name
output functionAppId string = functionApp.id
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output principalId string = functionApp.identity.principalId
output hostingPlanId string = hostingPlan.id
output stagingSlotPrincipalId string = environment == 'prod' ? stagingSlot.identity.principalId : ''
