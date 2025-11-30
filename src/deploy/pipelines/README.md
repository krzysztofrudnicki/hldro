# Azure Pipelines

Definicje pipelinów CI/CD dla Azure DevOps.

## Struktura

- `azure-pipelines.yml` - główny pipeline CI/CD
- `build-pipeline.yml` - pipeline do budowania aplikacji
- `deploy-pipeline.yml` - pipeline deploymentu
- `infrastructure-pipeline.yml` - pipeline dla IaC (Bicep)

## Stages typowego pipeline:

1. **Build** - kompilacja, testy jednostkowe
2. **Infrastructure** - provisioning i konfiguracja (Bicep)
3. **Deploy** - deployment aplikacji
4. **Test** - testy integracyjne, smoke tests
5. **Post-Deploy** - konfiguracja finalna, walidacja

## Użycie

Pipeline są wyzwalane automatycznie przy push do odpowiednich branchy lub ręcznie z Azure DevOps.
