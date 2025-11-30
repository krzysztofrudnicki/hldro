# HLDRO Deployment Guide

Kompleksowy przewodnik po deploymencie infrastruktury i aplikacji HLDRO.

## Przygotowanie do pierwszego deploymentu

### 1. Wymagania

- Azure Subscription
- Azure DevOps Organization i Project
- Azure CLI zainstalowane lokalnie (dla testów)
- Uprawnienia Contributor w Azure Subscription
- Git

### 2. Konfiguracja Azure DevOps

#### A. Utwórz Service Connections

W Azure DevOps → Project Settings → Service connections:

1. **Dla Dev:**
   - Name: `azure-hldro-dev`
   - Type: Azure Resource Manager
   - Scope: Subscription
   - Grant access to all pipelines

2. **Dla Prod:**
   - Name: `azure-hldro-prod`
   - Type: Azure Resource Manager
   - Scope: Subscription
   - Grant access to all pipelines

#### B. Utwórz Variable Groups

W Azure DevOps → Pipelines → Library → Variable groups:

**1. hldro-common** (wspólne dla wszystkich środowisk)
```
azureServiceConnection: azure-hldro-dev
```

**2. hldro-dev-secrets** (dla dev)
```
sqlAdminUsername: sqladmin (plain text)
sqlAdminPassword: YourSecurePassword123! (mark as secret ✓)
azureServiceConnection: azure-hldro-dev
```

**3. hldro-prod-secrets** (dla prod)
```
sqlAdminUsername: sqladmin (plain text)
sqlAdminPassword: ProductionSecurePassword456! (mark as secret ✓)
azureServiceConnection: azure-hldro-prod
azureServiceConnectionProd: azure-hldro-prod
```

#### C. Utwórz Environments

W Azure DevOps → Pipelines → Environments:

1. **hldro-dev-infra** - bez approval
2. **hldro-prod-infra** - dodaj Approval check (1+ approvers)

### 3. Konfiguracja lokalna (do testów)

#### A. Edytuj parametry

Skopiuj i edytuj plik parametrów:
```bash
cd src/deploy/environments/dev
cp parameters.local.json my-parameters.json

# Edytuj my-parameters.json - zmień:
# - sqlAdminUsername na swoją wartość
# - sqlAdminPassword na bezpieczne hasło
```

#### B. Zaloguj się do Azure
```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

## Deployment

### Opcja 1: Lokalny deployment (do testów)

```bash
cd src/deploy

# 1. Walidacja Bicep
az bicep build --file templates/bicep/main.bicep
az bicep lint --file templates/bicep/main.bicep

# 2. What-If (preview zmian)
az deployment sub what-if \
  --name hldro-dev-test \
  --location westeurope \
  --template-file templates/bicep/main.bicep \
  --parameters environments/dev/my-parameters.json

# 3. Deploy
az deployment sub create \
  --name hldro-dev-$(date +%Y%m%d-%H%M%S) \
  --location westeurope \
  --template-file templates/bicep/main.bicep \
  --parameters environments/dev/my-parameters.json \
  --output table

# 4. Sprawdź outputs
az deployment sub show \
  --name hldro-dev-YYYYMMDD-HHMMSS \
  --query properties.outputs \
  --output json
```

### Opcja 2: Przez Azure Pipelines (produkcyjne)

#### A. Pierwszy commit

```bash
cd /c/projects/hldro

# Dodaj wszystkie pliki deployment
git add src/deploy/
git status

# Commit
git commit -m "Add infrastructure deployment with Bicep

- Complete Bicep modules for all Azure resources
- Azure Functions host
- Storage Account
- Service Bus
- SQL Server & Database
- Application Insights (Azure Monitor)
- Static Web App with CDN (frontend)
- Pipeline definitions for Azure DevOps
- Environment-specific configurations

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Push
git push origin develop  # Lub main, w zależności od brancha
```

#### B. Utwórz Pipeline w Azure DevOps

1. Przejdź do Pipelines → New Pipeline
2. Wybierz GitHub/Azure Repos (gdzie masz repo)
3. Wybierz istniejący YAML: `/src/deploy/pipelines/infrastructure-pipeline.yml`
4. Review i Run

#### C. Monitoruj deployment

1. Pipeline się uruchomi automatycznie
2. Faza Validate wykona build i lint Bicep
3. Faza DeployDev wykona what-if i deploy do dev
4. Sprawdź outputy w logach pipeline

### Opcja 3: Używając skryptu

```bash
cd src/deploy/scripts/bash

# Dla dev (z credentialami)
chmod +x deploy-infrastructure.sh
./deploy-infrastructure.sh dev "sqladmin" "YourSecurePassword123!"

# Skrypt automatycznie:
# - Waliduje pliki
# - Robi what-if
# - Pyta o potwierdzenie
# - Wykonuje deployment
# - Pokazuje outputs
```

## Co zostanie utworzone?

Po deploymencie w Azure powstanie:

### Resource Group: `hldro-dev-rg`

#### Zasoby:
1. **Storage Account** (`hldrodevstXXXXXX`)
   - Containers: auctions, bids
   - Blob, Table, Queue services
   - SKU: Standard_LRS (dev)

2. **Application Insights** (`hldro-dev-ai`)
   - Log Analytics Workspace
   - Monitoring i telemetria

3. **Service Bus** (`hldro-dev-sb`)
   - Queues: auction-events, bid-events
   - Topic: notifications
   - SKU: Standard (dev)

4. **SQL Server** (`hldro-dev-sql`)
   - Database: hldro-db
   - SKU: Basic (dev)
   - TDE enabled

5. **Function App** (`hldro-dev-func`)
   - App Service Plan: Consumption Y1 (dev)
   - Runtime: .NET 8 isolated
   - Connected to wszystkich serwisów

6. **Static Web App** (`hldro-dev-web`)
   - CDN enabled
   - SKU: Free (dev)

## Weryfikacja deploymentu

### W Azure Portal

```bash
# Lista zasobów
az resource list \
  --resource-group hldro-dev-rg \
  --output table

# Szczegóły Function App
az functionapp show \
  --name hldro-dev-func \
  --resource-group hldro-dev-rg

# Sprawdź Service Bus queues
az servicebus queue list \
  --namespace-name hldro-dev-sb \
  --resource-group hldro-dev-rg \
  --output table

# SQL Database status
az sql db show \
  --server hldro-dev-sql \
  --name hldro-db \
  --resource-group hldro-dev-rg \
  --query "status"
```

### Smoke Tests

```powershell
# Uruchom smoke tests
cd src/deploy
.\scripts\powershell\run-smoke-tests.ps1 -Environment dev
```

## Troubleshooting

### Problem: "Deployment failed - SQL password not secure enough"
**Rozwiązanie:** Hasło musi mieć min. 8 znaków, duże i małe litery, cyfry i znaki specjalne.

### Problem: "Storage account name already exists"
**Rozwiązanie:** Nazwy storage są globalne. Bicep używa `uniqueString()` - usuń stary storage lub zmień nazwę projektu.

### Problem: "Service Bus name not available"
**Rozwiązanie:** Nazwy Service Bus są globalne. Zmień nazwę w parameters.json.

### Problem: "Pipeline failed - Variable group not found"
**Rozwiązanie:** Upewnij się, że utworzyłeś Variable Groups w Azure DevOps i nazwa jest dokładnie taka jak w pipeline.

### Problem: "Unauthorized to deploy"
**Rozwiązanie:** Sprawdź czy Service Connection ma uprawnienia Contributor w subscription.

## Następne kroki

Po deploymencie infrastruktury:

1. **Deploy Backend** - Azure Functions
   ```bash
   # Build backend
   cd src/backend
   dotnet publish -c Release

   # Deploy
   cd ../deploy
   .\scripts\powershell\deploy-functions.ps1 -Environment dev -FunctionAppName hldro-dev-func -PackagePath ../backend/bin/Release/publish.zip
   ```

2. **Deploy Frontend** - Static Web App
   - Link GitHub repo w Static Web App
   - Configure build settings
   - Auto-deploy on push

3. **Konfiguracja Database**
   - Uruchom migrations
   - Seed initial data

4. **Monitoring**
   - Sprawdź Application Insights
   - Skonfiguruj alerty

## Cleanup (usuwanie zasobów)

```bash
# Usuń całą resource group (OSTROŻNIE!)
az group delete --name hldro-dev-rg --yes --no-wait

# Lub przez pipeline z rollback
.\rollback\rollback-full.ps1 -Environment dev
```

## Koszty

Szacunkowe koszty miesięczne (West Europe):

- **Dev Environment:** ~30-50 EUR/miesiąc
  - Function App (Consumption): ~5 EUR
  - SQL Database (Basic): ~5 EUR
  - Service Bus (Standard): ~10 EUR
  - Storage: ~1 EUR
  - Application Insights: ~5 EUR
  - Static Web App (Free): 0 EUR

- **Prod Environment:** ~200-300 EUR/miesiąc
  - Function App (Premium EP1): ~150 EUR
  - SQL Database (S1): ~30 EUR
  - Service Bus (Premium): ~700 EUR → rozważ Standard (~10 EUR)
  - Pozostałe podobnie do dev

💡 **Tip:** Używaj `az consumption` do śledzenia rzeczywistych kosztów.

## Wsparcie

- Issues: GitHub Issues w repo
- Documentation: `src/deploy/docs/`
- Logs: Azure Portal → Application Insights
