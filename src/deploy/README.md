# HLDRO Deployment

Kompletna struktura deployment dla projektu HLDRO zgodna z Azure DevOps best practices.

## Struktura

```
deploy/
├── pipelines/              # Azure DevOps pipeline definitions (YAML)
├── environments/           # Konfiguracje per środowisko (dev/test/staging/prod)
├── templates/              # Infrastructure as Code (Bicep templates)
├── scripts/                # Skrypty pomocnicze (PowerShell/Bash)
├── tests/                  # Testy deploymentu (integration/smoke/validation)
├── docs/                   # Dokumentacja (runbooki, procedury)
├── rollback/               # Procedury rollback
```

## Quick Start

### 1. Provisioning Infrastruktury (Bicep)

```bash
# Deploy do dev
./scripts/bash/deploy-infrastructure.sh dev

# Deploy do prod (wymaga potwierdzenia)
./scripts/bash/deploy-infrastructure.sh prod
```

### 2. Deploy Aplikacji

```powershell
# Deploy Azure Functions
.\scripts\powershell\deploy-functions.ps1 `
    -Environment dev `
    -FunctionAppName hldro-dev-func `
    -PackagePath .\backend\publish.zip
```

### 3. Uruchomienie Testów

```powershell
# Smoke tests
.\scripts\powershell\run-smoke-tests.ps1 -Environment dev
```

## Azure Pipelines

Projekt zawiera gotowe pipeline dla Azure DevOps:

- **azure-pipelines.yml** - Główny multi-stage pipeline
  - Build (Backend + Frontend)
  - Deploy to Dev (automatyczny)
  - Deploy to Prod (z manual approval)

### Wymagane Variable Groups w Azure DevOps:

1. **hldro-common** - wspólne zmienne
2. **hldro-dev** - zmienne dla dev
3. **hldro-test** - zmienne dla test
4. **hldro-staging** - zmienne dla staging
5. **hldro-prod** - zmienne dla prod (z sekretami)

Template zmiennych znajduje się w `environments/{env}/variables.yml`

## Środowiska

Każde środowisko ma dedykowaną konfigurację:

- **dev/** - Development (auto-deploy z develop branch)
- **test/** - Testing/QA
- **staging/** - Pre-production
- **prod/** - Production (manual approval, blue-green deployment)

### Pliki per środowisko:

```
environments/dev/
├── parameters.json      # Parametry Bicep
├── variables.yml        # Zmienne Azure Pipelines
├── config.json          # Konfiguracja aplikacji
└── secrets.template.yml # Template sekretów (bez wartości!)
```

## Infrastructure as Code (Bicep)

### Struktura modułów:

```
templates/bicep/
├── main.bicep           # Główny template
├── modules/
│   ├── storage-account.bicep
│   ├── function-app.bicep
│   ├── service-bus.bicep
│   └── app-insights.bicep
└── parameters/
    ├── dev.parameters.json
    └── prod.parameters.json
```

### Deployment:

```bash
# Preview zmian (what-if)
az deployment sub what-if \
    --location westeurope \
    --template-file templates/bicep/main.bicep \
    --parameters environments/dev/parameters.json

# Deploy
az deployment sub create \
    --name hldro-dev \
    --location westeurope \
    --template-file templates/bicep/main.bicep \
    --parameters environments/dev/parameters.json
```

## Testy

### Smoke Tests
Szybkie testy weryfikujące podstawową funkcjonalność:
```powershell
.\scripts\powershell\run-smoke-tests.ps1 -Environment dev
```

### Integration Tests
Testy integracyjne między komponentami:
```bash
cd tests/integration
./run-tests.sh dev
```

### Validation Tests
Walidacja konfiguracji i zasobów:
```powershell
.\tests\validation\validate-deployment.ps1 -Environment prod
```

## Rollback Procedures

W przypadku problemów z deploymentem:

```powershell
# Rollback aplikacji (previous version)
.\rollback\rollback-application.ps1 -Environment prod

# Rollback infrastruktury (previous Bicep version)
.\rollback\rollback-infrastructure.ps1 -Environment prod

# Pełny rollback
.\rollback\rollback-full.ps1 -Environment prod
```

Szczegółowe procedury w: `rollback/README.md`

## Deployment Flow

### Development Environment (auto)
```
Push to develop → Build → Deploy to Dev → Smoke Tests
```

### Production Environment (manual approval)
```
Push to main → Build → Deploy to Staging Slot → Smoke Tests
→ Manual Approval → Swap Slots → Validation → Success
```

## Best Practices

1. **Nigdy nie hardcode sekretów** - używaj Azure Key Vault
2. **Zawsze rób what-if przed deploymentem** do prod
3. **Testuj na staging** przed produkcją
4. **Używaj slotów** dla zero-downtime deployment
5. **Dokumentuj zmiany** w infrastructure
6. **Zachowuj idempotentność** skryptów
7. **Monitoruj deployment** w Application Insights
8. **Miej plan rollback** przed każdym deploymentem

## Sekrety i bezpieczeństwo

- Sekrety w **Azure Key Vault** (prod)
- Sekrety w **Variable Groups** (Azure DevOps, marked as secret)
- **NIGDY** nie commituj sekretów do repo
- Używaj `.gitignore` dla lokalnych plików z sekretami
- Template pliki sekretów: `*.template.yml` (bez wartości)

## Monitoring i Alerty

- Application Insights dla każdego środowiska
- Alerty w Azure Monitor
- Dashboards w Azure Portal
- Dokumentacja: `docs/monitoring-alerts.md`

## Troubleshooting

Najczęstsze problemy i rozwiązania w: `docs/troubleshooting-runbook.md`

## Kontakt

- DevOps Team: devops@example.com
- On-call: #hldro-oncall (Slack)
- Documentation: `docs/`
