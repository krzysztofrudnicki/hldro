# Deployment Tests

Testy weryfikujące poprawność deploymentu.

## Typy testów

### integration/
Testy integracyjne sprawdzające:
- Komunikację między komponentami
- Działanie całych flow
- Integrację z zewnętrznymi serwisami

### smoke/
Smoke tests (quick sanity checks):
- Dostępność endpointów
- Podstawowe funkcjonalności
- Health checks

### validation/
Walidacja deploymentu:
- Sprawdzenie zasobów Azure
- Weryfikacja konfiguracji
- Sprawdzenie connection strings
- Walidacja uprawnień

## Uruchamianie

Testy powinny być uruchamiane:
1. **Po deploymencie** - automatycznie w pipeline
2. **Przed release do prod** - gate w Azure Pipelines
3. **On-demand** - ręcznie dla weryfikacji

## Narzędzia

- Pester (PowerShell testing)
- Azure CLI + jq (bash testing)
- Postman/Newman (API testing)
- Custom scripts
