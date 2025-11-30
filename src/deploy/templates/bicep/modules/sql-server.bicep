// SQL Server and Database Module
@description('SQL Server name')
param sqlServerName string

@description('Azure region')
param location string

@description('Environment (dev, test, staging, prod)')
param environment string

@description('Resource tags')
param tags object = {}

@description('SQL Admin username')
@secure()
param sqlAdminUsername string

@description('SQL Admin password')
@secure()
param sqlAdminPassword string

@description('Database name')
param databaseName string = 'hldro-db'

// SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

// Firewall rule for Azure Services
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Database - SKU based on environment
var databaseSku = environment == 'prod' ? {
  name: 'S1'
  tier: 'Standard'
  capacity: 20
} : {
  name: 'Basic'
  tier: 'Basic'
  capacity: 5
}

resource database 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: databaseName
  location: location
  tags: tags
  sku: databaseSku
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: environment == 'prod' ? 268435456000 : 2147483648 // 250GB for prod, 2GB for others
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: environment == 'prod'
    readScale: environment == 'prod' ? 'Enabled' : 'Disabled'
    requestedBackupStorageRedundancy: environment == 'prod' ? 'Geo' : 'Local'
  }
}

// Transparent Data Encryption
resource tde 'Microsoft.Sql/servers/databases/transparentDataEncryption@2023-05-01-preview' = {
  parent: database
  name: 'current'
  properties: {
    state: 'Enabled'
  }
}

// Outputs
output sqlServerName string = sqlServer.name
output sqlServerId string = sqlServer.id
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output databaseName string = database.name
output databaseId string = database.id
output connectionString string = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${database.name};Persist Security Info=False;User ID=${sqlAdminUsername};Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
