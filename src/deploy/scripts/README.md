# Deployment Scripts

Pomocnicze skrypty do automatyzacji deploymentu.

## Struktura

### powershell/
Skrypty PowerShell dla:
- Provisioning i konfiguracja Azure
- Deployment Azure Functions
- Zarządzanie Key Vault
- Setup środowisk

### bash/
Skrypty Bash dla:
- CI/CD automation
- Cross-platform tasks
- Linux-based operations

## Dobre praktyki

1. **Idempotentność** - skrypty powinny być bezpieczne do wielokrotnego uruchomienia
2. **Error handling** - zawsze sprawdzaj kody wyjścia
3. **Logging** - loguj wszystkie operacje
4. **Parametry** - używaj parametrów zamiast hardcoded values
5. **Dokumentacja** - komentuj złożone operacje

## Przykładowe skrypty

- `deploy-infrastructure.ps1` - deploy Bicep templates
- `deploy-functions.ps1` - deploy Azure Functions
- `setup-keyvault.ps1` - konfiguracja Key Vault i sekretów
- `run-smoke-tests.sh` - uruchomienie testów smoke
