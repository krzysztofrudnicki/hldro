// Main Bicep template dla HLDRO with Key Vault Integration
// Definiuje całą infrastrukturę Azure z bezpiecznym przechowywaniem sekretów

targetScope = 'subscription'

// ========================================
// PARAMETERS
// ========================================
@description('Environment name (dev, test, staging, prod)')
@allowed(['dev', 'test', 'staging', 'prod'])
param environment string

@description('Azure region for resources')
param location string = 'westeurope'

@description('Project name prefix')
param projectName string = 'hldro'

@description('SQL Server admin username')
@secure()
param sqlAdminUsername string

@description('SQL Server admin password')
@minLength(8)
@secure()
param sqlAdminPassword string

@description('GitHub repository URL for Static Web App (optional)')
param repositoryUrl string = ''

@description('Use Key Vault for secrets management')
param useKeyVault bool = true

@description('Tags to apply to all resources')
param tags object = {
  Project: 'HLDRO'
  Environment: environment
  ManagedBy: 'Bicep'
}

// ========================================
// VARIABLES
// ========================================
var resourceGroupName = '${projectName}-${environment}-rg'
var storageAccountName = '${projectName}${environment}st${uniqueString(resourceGroupName)}'
var functionAppName = '${projectName}-${environment}-func'
var serviceBusName = '${projectName}-${environment}-servicebus'
var appInsightsName = '${projectName}-${environment}-ai'
var sqlServerName = '${projectName}-${environment}-sql'
var staticWebAppName = '${projectName}-${environment}-web'
var keyVaultName = '${projectName}-${environment}-kv'
var databaseName = 'hldro-db'

// ========================================
// RESOURCE GROUP
// ========================================
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// ========================================
// MODULES
// ========================================

// 1. Storage Account
module storage 'modules/storage-account.bicep' = {
  name: 'storage-deployment'
  scope: rg
  params: {
    storageAccountName: storageAccountName
    location: location
    environment: environment
    tags: tags
  }
}

// 2. Application Insights (Azure Monitor)
module appInsights 'modules/app-insights.bicep' = {
  name: 'appinsights-deployment'
  scope: rg
  params: {
    appInsightsName: appInsightsName
    location: location
    tags: tags
  }
}

// 3. Service Bus
module serviceBus 'modules/service-bus.bicep' = {
  name: 'servicebus-deployment'
  scope: rg
  params: {
    serviceBusName: serviceBusName
    location: location
    environment: environment
    tags: tags
  }
}

// 4. SQL Server and Database
module sqlServer 'modules/sql-server.bicep' = {
  name: 'sqlserver-deployment'
  scope: rg
  params: {
    sqlServerName: sqlServerName
    location: location
    environment: environment
    sqlAdminUsername: sqlAdminUsername
    sqlAdminPassword: sqlAdminPassword
    databaseName: databaseName
    tags: tags
  }
}

// 5. Key Vault (store all secrets)
module keyVault 'modules/key-vault.bicep' = if (useKeyVault) {
  name: 'keyvault-deployment'
  scope: rg
  params: {
    keyVaultName: keyVaultName
    location: location
    environment: environment
    tags: tags
    sqlConnectionString: sqlServer.outputs.connectionString
    serviceBusConnectionString: serviceBus.outputs.connectionString
    storageConnectionString: storage.outputs.connectionString
    appInsightsInstrumentationKey: appInsights.outputs.instrumentationKey
    appInsightsConnectionString: appInsights.outputs.connectionString
    sqlAdminUsername: sqlAdminUsername
    sqlAdminPassword: sqlAdminPassword
  }
  dependsOn: [
    storage
    appInsights
    serviceBus
    sqlServer
  ]
}

// 6. Azure Functions (Backend) with Key Vault integration
module functionApp 'modules/function-app-with-keyvault.bicep' = {
  name: 'functionapp-deployment'
  scope: rg
  params: {
    functionAppName: functionAppName
    location: location
    environment: environment
    storageAccountName: storage.outputs.storageAccountName
    keyVaultName: useKeyVault ? keyVaultName : ''
    useKeyVault: useKeyVault
    keyVaultSecretUris: useKeyVault ? {
      sqlConnectionString: keyVault.outputs.sqlConnectionStringSecretUri
      serviceBusConnection: keyVault.outputs.serviceBusConnectionSecretUri
      storageConnectionString: keyVault.outputs.storageConnectionStringSecretUri
      appInsightsInstrumentationKey: keyVault.outputs.appInsightsInstrumentationKeySecretUri
      appInsightsConnectionString: keyVault.outputs.appInsightsConnectionStringSecretUri
    } : {}
    tags: tags
  }
  dependsOn: [
    keyVault
  ]
}

// // 7. Static Web App (Frontend with CDN)
// module staticWebApp 'modules/static-web-app.bicep' = {
//   name: 'staticwebapp-deployment'
//   scope: rg
//   params: {
//     staticWebAppName: staticWebAppName
//     location: location
//     environment: environment
//     repositoryUrl: repositoryUrl
//     tags: tags
//   }
}

// ========================================
// OUTPUTS
// ========================================
output resourceGroupName string = rg.name
output resourceGroupId string = rg.id

// Storage
output storageAccountName string = storage.outputs.storageAccountName
output storageAccountId string = storage.outputs.storageAccountId

// Application Insights
output appInsightsName string = appInsights.outputs.appInsightsName

// Service Bus
output serviceBusName string = serviceBus.outputs.serviceBusName
output serviceBusEndpoint string = serviceBus.outputs.endpoint

// SQL Server
output sqlServerName string = sqlServer.outputs.sqlServerName
output sqlServerFqdn string = sqlServer.outputs.sqlServerFqdn
output databaseName string = sqlServer.outputs.databaseName

// Key Vault
output keyVaultName string = useKeyVault ? keyVault.outputs.keyVaultName : ''
output keyVaultUri string = useKeyVault ? keyVault.outputs.keyVaultUri : ''

// Function App
output functionAppName string = functionApp.outputs.functionAppName
output functionAppUrl string = functionApp.outputs.functionAppUrl
output functionAppPrincipalId string = functionApp.outputs.principalId

// // Static Web App (Frontend)
// output staticWebAppName string = staticWebApp.outputs.staticWebAppName
// output staticWebAppUrl string = 'https://${staticWebApp.outputs.defaultHostname}'
// output staticWebAppApiKey string = staticWebApp.outputs.apiKey

// Security Info
output securityInfo string = useKeyVault ? 'All secrets are stored in Key Vault: ${keyVaultName}' : 'Key Vault is disabled - secrets in app settings'
