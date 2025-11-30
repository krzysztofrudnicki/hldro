# Environments Configuration

Konfiguracje specyficzne dla środowisk.

## Środowiska

- **dev/** - Development (lokalne/testowe)
- **test/** - Testing/QA
- **staging/** - Pre-production
- **prod/** - Production

## Struktura plików per środowisko

Każde środowisko powinno zawierać:
- `parameters.json` - parametry dla Bicep
- `variables.yml` - zmienne dla Azure Pipelines
- `config.json` - konfiguracja aplikacji
- `secrets.template.yml` - template dla sekretów (bez wartości)

## Zarządzanie sekretami

Sekrety przechowywane w:
- Azure Key Vault (production)
- Azure DevOps Variable Groups
- Nigdy w repo (tylko templates)
