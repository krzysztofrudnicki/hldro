# Quick Start - HLDRO Infrastructure Deployment

## 🚀 Deploy z Azure DevOps (ZALECANE)

### 1. Setup Azure DevOps (jednorazowo)

```bash
# A. Utwórz Service Connection
# Azure DevOps → Project Settings → Service connections
# Name: azure-hldro-dev
# Type: Azure Resource Manager

# B. Utwórz Variable Group: hldro-dev-secrets
# Azure DevOps → Pipelines → Library
Variables:
- sqlAdminUsername: sqladmin
- sqlAdminPassword: YourSecurePassword123! (mark as secret)
- azureServiceConnection: azure-hldro-dev

# C. Utwórz Environment: hldro-dev-infra
# Azure DevOps → Pipelines → Environments
```

### 2. Commit i Push

```bash
cd /c/projects/hldro

git add src/deploy/
git commit -m "Add infrastructure deployment"
git push origin develop
```

### 3. Utwórz Pipeline

```
Azure DevOps → Pipelines → New Pipeline
→ Wybierz repo
→ Existing Azure Pipelines YAML file
→ Path: /src/deploy/pipelines/infrastructure-pipeline.yml
→ Run
```

### 4. Gotowe!

Pipeline automatycznie:
- Zwaliduje Bicep templates
- Wykona what-if
- Zadeploy infrastrukturę do dev
- Pokaże outputs

---

## 💻 Deploy lokalnie (do testów)

### 1. Zaloguj do Azure

```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### 2. Deploy

```bash
cd /c/projects/hldro/src/deploy

# What-if (preview)
az deployment sub what-if \
  --name hldro-dev-test \
  --location westeurope \
  --template-file templates/bicep/main.bicep \
  --parameters environments/dev/parameters.local.json \
  --parameters sqlAdminUsername="sqladmin" \
  --parameters sqlAdminPassword="YourSecurePassword123!"

# Deploy
az deployment sub create \
  --name hldro-dev-$(date +%Y%m%d-%H%M%S) \
  --location westeurope \
  --template-file templates/bicep/main.bicep \
  --parameters environments/dev/parameters.local.json \
  --parameters sqlAdminUsername="sqladmin" \
  --parameters sqlAdminPassword="YourSecurePassword123!"
```

---

## 📦 Co zostanie utworzone?

### Resource Group: `hldro-dev-rg`

- ✅ **Storage Account** - dla aukcji i bidów
- ✅ **Application Insights** - monitoring
- ✅ **Service Bus** - kolejki eventów
- ✅ **SQL Server + Database** - dane aplikacji
- ✅ **Function App** - backend (Azure Functions)
- ✅ **Static Web App** - frontend z CDN

### Czas deployment: ~10-15 minut

---

## 🔍 Weryfikacja

```bash
# Lista zasobów
az resource list --resource-group hldro-dev-rg --output table

# Function App URL
az functionapp show \
  --name hldro-dev-func \
  --resource-group hldro-dev-rg \
  --query "defaultHostName" -o tsv

# Static Web App URL
az staticwebapp show \
  --name hldro-dev-web \
  --resource-group hldro-dev-rg \
  --query "defaultHostname" -o tsv
```

---

## 🧹 Cleanup (usunięcie)

```bash
# UWAGA: To usuwa WSZYSTKIE zasoby!
az group delete --name hldro-dev-rg --yes --no-wait
```

---

## 📚 Więcej informacji

- Pełna dokumentacja: [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
- Troubleshooting: [docs/troubleshooting-runbook.md](./docs/troubleshooting-runbook.md)
- Bicep templates: [templates/bicep/](./templates/bicep/)
