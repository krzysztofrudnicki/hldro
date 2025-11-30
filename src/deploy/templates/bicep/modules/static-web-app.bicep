// Static Web App with CDN Module (for Frontend)
@description('Static Web App name')
param staticWebAppName string

@description('Azure region')
param location string = 'westeurope'

@description('Environment (dev, test, staging, prod)')
param environment string

@description('Resource tags')
param tags object = {}

@description('Repository URL (optional)')
param repositoryUrl string = ''

@description('Repository branch')
param repositoryBranch string = environment == 'prod' ? 'main' : 'develop'

// SKU based on environment
var sku = environment == 'prod' ? 'Standard' : 'Free'

// Static Web App
resource staticWebApp 'Microsoft.Web/staticSites@2023-01-01' = {
  name: staticWebAppName
  location: location
  tags: tags
  sku: {
    name: sku
    tier: sku
  }
  properties: {
    repositoryUrl: repositoryUrl
    branch: repositoryBranch
    buildProperties: {
      appLocation: '/src/frontend'
      apiLocation: ''
      outputLocation: 'dist'
    }
    stagingEnvironmentPolicy: environment == 'prod' ? 'Enabled' : 'Disabled'
    allowConfigFileUpdates: true
    provider: 'GitHub'
  }
}

// Custom domain (for production)
resource customDomain 'Microsoft.Web/staticSites/customDomains@2023-01-01' = if (environment == 'prod') {
  parent: staticWebApp
  name: 'www.hldro.com'
  properties: {}
}

// Outputs
output staticWebAppName string = staticWebApp.name
output staticWebAppId string = staticWebApp.id
output defaultHostname string = staticWebApp.properties.defaultHostname
output repositoryUrl string = staticWebApp.properties.repositoryUrl
output apiKey string = staticWebApp.listSecrets().properties.apiKey
