// Key Vault Module
@description('Key Vault name')
param keyVaultName string

@description('Azure region')
param location string

@description('Environment (dev, test, staging, prod)')
param environment string

@description('Resource tags')
param tags object = {}

@description('Azure AD Tenant ID')
param tenantId string = subscription().tenantId

@description('Object IDs that need access to Key Vault (Function App, users, etc)')
param accessPolicies array = []

@description('Enable RBAC authorization instead of access policies')
param enableRbacAuthorization bool = false

@description('SQL Connection String to store')
@secure()
param sqlConnectionString string

@description('Service Bus Connection String to store')
@secure()
param serviceBusConnectionString string

@description('Storage Account Connection String to store')
@secure()
param storageConnectionString string

@description('Application Insights Instrumentation Key to store')
@secure()
param appInsightsInstrumentationKey string

@description('Application Insights Connection String to store')
@secure()
param appInsightsConnectionString string

@description('SQL Admin Username to store')
@secure()
param sqlAdminUsername string

@description('SQL Admin Password to store')
@secure()
param sqlAdminPassword string

// Key Vault SKU based on environment
var sku = environment == 'prod' ? 'premium' : 'standard'

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: sku
    }
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: environment == 'prod' ? 90 : 7
    enableRbacAuthorization: enableRbacAuthorization
    enablePurgeProtection: environment == 'prod' ? true : null
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    accessPolicies: accessPolicies
  }
}

// Secrets
resource sqlConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'SqlConnectionString'
  properties: {
    value: sqlConnectionString
    contentType: 'text/plain'
  }
}

resource serviceBusConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ServiceBusConnection'
  properties: {
    value: serviceBusConnectionString
    contentType: 'text/plain'
  }
}

resource storageConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'StorageConnectionString'
  properties: {
    value: storageConnectionString
    contentType: 'text/plain'
  }
}

resource appInsightsInstrumentationKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AppInsightsInstrumentationKey'
  properties: {
    value: appInsightsInstrumentationKey
    contentType: 'text/plain'
  }
}

resource appInsightsConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ApplicationInsightsConnectionString'
  properties: {
    value: appInsightsConnectionString
    contentType: 'text/plain'
  }
}

resource sqlAdminUsernameSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'SqlAdminUsername'
  properties: {
    value: sqlAdminUsername
    contentType: 'text/plain'
  }
}

resource sqlAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'SqlAdminPassword'
  properties: {
    value: sqlAdminPassword
    contentType: 'text/plain'
  }
}

// Diagnostic Settings (for audit logging)
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVaultName}-diagnostics'
  scope: keyVault
  properties: {
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
  }
}

// Outputs
output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri

// Secret URIs for Key Vault references in App Settings
output sqlConnectionStringSecretUri string = sqlConnectionStringSecret.properties.secretUri
output serviceBusConnectionSecretUri string = serviceBusConnectionStringSecret.properties.secretUri
output storageConnectionStringSecretUri string = storageConnectionStringSecret.properties.secretUri
output appInsightsInstrumentationKeySecretUri string = appInsightsInstrumentationKeySecret.properties.secretUri
output appInsightsConnectionStringSecretUri string = appInsightsConnectionStringSecret.properties.secretUri
