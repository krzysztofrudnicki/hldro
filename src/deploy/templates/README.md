# Infrastructure as Code Templates

Szablony infrastruktury (Bicep) i moduły reużywalne.

## Struktura

### bicep/
- `main.bicep` - główny template
- `modules/` - reużywalne moduły (storage, functions, service bus, etc.)
- `parameters/` - pliki parametrów per środowisko

## Best Practices

1. **Modularność** - rozbij na małe, reużywalne moduły
2. **Parametryzacja** - używaj parametrów zamiast hardcoded values
3. **Nazewnictwo** - spójne konwencje nazewnicze
4. **Dokumentacja** - opisuj parametry i outputy
5. **Walidacja** - używaj `az deployment what-if` przed apply

## Przykładowa struktura modułów

```
bicep/
├── main.bicep
├── modules/
│   ├── storage-account.bicep
│   ├── function-app.bicep
│   ├── service-bus.bicep
│   └── app-insights.bicep
└── parameters/
    ├── dev.parameters.json
    ├── test.parameters.json
    └── prod.parameters.json
```
