# Key Vault Setup Guide - HLDRO

## Szybki Start

### Co zostało zrobione?

✅ **Key Vault module** - Bicep template do zarządzania Key Vault
✅ **Automatyczne przechowywanie sekretów** - SQL, Service Bus, Storage, App Insights
✅ **Managed Identity** - Function App automatycznie dostaje uprawnienia
✅ **Key Vault References** - App settings używają `@Microsoft.KeyVault(...)`
✅ **Pipeline validation** - Automatyczna weryfikacja sekretów po deploymencie

## Architektura Bezpieczeństwa

```
┌─────────────────────────────────────────────────┐
│  Deployment (Bicep)                              │
│  ├─ Tworzy Key Vault                            │
│  ├─ Dodaje wszystkie sekrety                    │
│  ├─ Tworzy Function App z Managed Identity      │
│  └─ Nadaje uprawnienia get/list do Key Vault    │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  Azure Key Vault (hldro-dev-kv)                  │
│  ┌────────────────────────────────────────────┐ │
│  │ Secrets:                                   │ │
│  │ • SqlConnectionString                      │ │
│  │ • ServiceBusConnection                     │ │
│  │ • StorageConnectionString                  │ │
│  │ • AppInsightsInstrumentationKey            │ │
│  │ • ApplicationInsightsConnectionString      │ │
│  │ • SqlAdminUsername                         │ │
│  │ • SqlAdminPassword                         │ │
│  └────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
                    ↑
                    │ Managed Identity
                    │ (get, list permissions)
┌─────────────────────────────────────────────────┐
│  Function App (hldro-dev-func)                   │
│  App Settings:                                   │
│  • SqlConnectionString:                          │
│    @Microsoft.KeyVault(SecretUri=https://...)    │
│                                                  │
│  Runtime:                                        │
│  • Azure resolves @Microsoft.KeyVault(...)       │
│  • Uses Managed Identity for auth               │
│  • Returns secret value to application          │
└─────────────────────────────────────────────────┘
```

## Deployment

### Automatyczny (przez Pipeline)

Pipeline już zawiera wszystko:

```yaml
# infrastructure-pipeline.yml
- Deploy Infrastructure with Key Vault
- Verify Key Vault Secrets
- Verify Function App Configuration
- Security Audit (prod)
```

### Ręczny (lokalnie)

```bash
cd /c/projects/hldro/src/deploy

# Deploy z Key Vault (domyślnie włączony)
az deployment sub create \
  --name hldro-dev-keyvault \
  --location westeurope \
  --template-file templates/bicep/main.bicep \
  --parameters environments/dev/parameters.local.json \
  --parameters sqlAdminUsername="sqladmin" \
  --parameters sqlAdminPassword="YourSecurePassword123!" \
  --parameters useKeyVault=true
```

## Weryfikacja

### 1. Sprawdź czy Key Vault został utworzony

```bash
az keyvault list --query "[?contains(name, 'hldro')].{Name:name, Location:location}" -o table
```

### 2. Sprawdź sekrety w Key Vault

```bash
# Lista wszystkich sekretów
az keyvault secret list \
  --vault-name hldro-dev-kv \
  --query "[].{Name:name, Enabled:attributes.enabled, Updated:attributes.updated}" \
  --output table

# Powinno pokazać:
# SqlConnectionString
# ServiceBusConnection
# StorageConnectionString
# AppInsightsInstrumentationKey
# ApplicationInsightsConnectionString
# SqlAdminUsername
# SqlAdminPassword
```

### 3. Sprawdź wartość sekretu (OSTROŻNIE!)

```bash
# Tylko do debugowania!
az keyvault secret show \
  --vault-name hldro-dev-kv \
  --name SqlConnectionString \
  --query "value" -o tsv
```

### 4. Sprawdź Function App

```bash
# Managed Identity
az functionapp identity show \
  --name hldro-dev-func \
  --resource-group hldro-dev-rg

# App Settings z Key Vault references
az functionapp config appsettings list \
  --name hldro-dev-func \
  --resource-group hldro-dev-rg \
  --query "[?contains(value, '@Microsoft.KeyVault')].{Name:name, Value:value}" \
  --output table

# Powinno pokazać:
# SqlConnectionString: @Microsoft.KeyVault(SecretUri=https://...)
# ServiceBusConnection: @Microsoft.KeyVault(SecretUri=https://...)
# etc.
```

### 5. Test połączenia

```bash
# Sprawdź czy Function App może odczytać sekrety
# W Azure Portal:
# Function App → Configuration → Application settings
# Każdy secret z @Microsoft.KeyVault powinien pokazywać:
# ✓ Key Vault Reference (zielona ikona)
```

## Zarządzanie sekretami

### Dodanie nowego sekretu

```bash
# 1. Dodaj sekret do Key Vault
az keyvault secret set \
  --vault-name hldro-dev-kv \
  --name MyNewSecret \
  --value "my-secret-value"

# 2. Dodaj reference w Function App
az functionapp config appsettings set \
  --name hldro-dev-func \
  --resource-group hldro-dev-rg \
  --settings MyNewSecret="@Microsoft.KeyVault(SecretUri=https://hldro-dev-kv.vault.azure.net/secrets/MyNewSecret/)"
```

### Aktualizacja sekretu

```bash
# Aktualizuj wartość w Key Vault
az keyvault secret set \
  --vault-name hldro-dev-kv \
  --name SqlConnectionString \
  --value "NEW_CONNECTION_STRING"

# Function App automatycznie użyje nowej wartości
# Opcjonalnie: restart dla natychmiastowego efektu
az functionapp restart \
  --name hldro-dev-func \
  --resource-group hldro-dev-rg
```

### Rotacja sekretów

```bash
# Skrypt rotacji SQL password
#!/bin/bash

NEW_PASSWORD="NewSecurePassword456!"

# 1. Update SQL Server password
az sql server update \
  --name hldro-dev-sql \
  --resource-group hldro-dev-rg \
  --admin-password "$NEW_PASSWORD"

# 2. Update connection string w Key Vault
SQL_CONNECTION_STRING="Server=tcp:hldro-dev-sql.database.windows.net,1433;Initial Catalog=hldro-db;User ID=sqladmin;Password=$NEW_PASSWORD;Encrypt=True;"

az keyvault secret set \
  --vault-name hldro-dev-kv \
  --name SqlConnectionString \
  --value "$SQL_CONNECTION_STRING"

# 3. Update SqlAdminPassword secret
az keyvault secret set \
  --vault-name hldro-dev-kv \
  --name SqlAdminPassword \
  --value "$NEW_PASSWORD"

# 4. Restart Function App
az functionapp restart \
  --name hldro-dev-func \
  --resource-group hldro-dev-rg

echo "Password rotation completed!"
```

## Troubleshooting

### Problem: "Key Vault reference not resolved"

```bash
# 1. Sprawdź czy Function App ma Managed Identity
az functionapp identity show \
  --name hldro-dev-func \
  --resource-group hldro-dev-rg

# 2. Sprawdź access policies
PRINCIPAL_ID=$(az functionapp identity show --name hldro-dev-func --resource-group hldro-dev-rg --query principalId -o tsv)

az keyvault show \
  --name hldro-dev-kv \
  --query "properties.accessPolicies[?objectId=='$PRINCIPAL_ID']"

# 3. Jeśli brak, dodaj access policy
az keyvault set-policy \
  --name hldro-dev-kv \
  --object-id $PRINCIPAL_ID \
  --secret-permissions get list
```

### Problem: "Access denied to Key Vault"

```bash
# Sprawdź network rules
az keyvault show \
  --name hldro-dev-kv \
  --query "properties.networkAcls"

# Upewnij się że Azure Services mają dostęp
az keyvault update \
  --name hldro-dev-kv \
  --bypass AzureServices \
  --default-action Allow
```

### Problem: "Secret not found"

```bash
# Sprawdź czy sekret istnieje
az keyvault secret list \
  --vault-name hldro-dev-kv \
  --query "[].name"

# Sprawdź czy sekret jest enabled
az keyvault secret show \
  --vault-name hldro-dev-kv \
  --name SqlConnectionString \
  --query "attributes.enabled"
```

## Monitoring & Auditing

### Włącz audyt (już włączone w Bicep)

```bash
# Sprawdź diagnostic settings
az monitor diagnostic-settings list \
  --resource $(az keyvault show --name hldro-dev-kv --query id -o tsv)
```

### Zapytania Log Analytics

```kql
// Wszystkie operacje na Key Vault
AzureDiagnostics
| where ResourceType == "VAULTS"
| where ResourceId contains "hldro-dev-kv"
| project TimeGenerated, OperationName, CallerIPAddress, ResultType
| order by TimeGenerated desc

// Kto odczytywał sekrety?
AzureDiagnostics
| where ResourceType == "VAULTS"
| where OperationName == "SecretGet"
| project TimeGenerated, CallerIdentity = identity_claim_appid_g, SecretName = id_s
| order by TimeGenerated desc

// Failed access attempts
AzureDiagnostics
| where ResourceType == "VAULTS"
| where ResultType != "Success"
| project TimeGenerated, OperationName, ResultType, CallerIPAddress
```

## Parametry Bicep

W `main.bicep`:

```bicep
@description('Use Key Vault for secrets management')
param useKeyVault bool = true  // Domyślnie włączone

// Jeśli useKeyVault = true:
// - Tworzy Key Vault
// - Przechowuje wszystkie sekrety
// - Function App używa Key Vault references

// Jeśli useKeyVault = false:
// - Sekrety w app settings jako plain text
// - Tylko do testów lokalnych!
```

## Różnice Dev vs Prod

| Feature | Dev | Prod |
|---------|-----|------|
| SKU | Standard | Premium |
| Soft Delete | 7 dni | 90 dni |
| Purge Protection | Wyłączone | Włączone |
| Audit Logs | 30 dni | 90 dni |
| Network Access | Allow all | Może być restricted |

## Best Practices

✅ **Zawsze używaj Key Vault** w prod
✅ **Managed Identity** zamiast connection strings
✅ **Monitoruj dostęp** do sekretów
✅ **Rotuj sekrety** regularnie (90 dni)
✅ **Nie wyłączaj** soft delete w prod
✅ **Używaj versioning** - nie usuwaj starych wersji
✅ **Audytuj dostęp** przez Log Analytics

❌ **Nie hardcode** sekretów w kodzie
❌ **Nie commituj** wartości do repo
❌ **Nie shareuj** sekretów przez email/chat
❌ **Nie dawaj** uprawnień `all` - tylko `get`, `list`
❌ **Nie wyłączaj** diagnostic settings

## Dokumentacja

- [Full Key Vault Guide](./docs/KEY_VAULT_GUIDE.md)
- [Pipeline Configuration](./pipelines/infrastructure-pipeline.yml)
- [Bicep Module](./templates/bicep/modules/key-vault.bicep)
