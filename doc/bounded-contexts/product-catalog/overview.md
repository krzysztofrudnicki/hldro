# Product Catalog Context - Overview

## Responsibility

Zarządzanie katalogiem **modeli produktów** - definicja "klas" produktów (np. Samsung XC1575C jako model), ich specyfikacji technicznych, opisów, zdjęć i przypisania do kategorii.

**Kluczowa różnica**: Ten context NIE zarządza konkretnymi egzemplarzami. Zarządza "szablonem" produktu, który jest następnie instancjonowany w Inventory Context.

## Business Rules

1. **Tenant Isolation**: Każdy tenant ma własny katalog produktów i hierarchię kategorii
2. **Product Model Uniqueness**: ProductModel jest unikalny w ramach tenanta (SKU uniqueness)
3. **Category Hierarchy**: Kategorie tworzą drzewo (parent-child relationship)
4. **Immutable History**: Zmiany w ProductModel nie wpływają na już wystawione aukcje
5. **Media Management**: ProductModel może mieć wiele zdjęć, jeden main image

## Ubiquitous Language

| Term | Definition |
|------|------------|
| **ProductModel** | "Klasa" produktu - np. Samsung XC1575C. Opisuje model bez odniesienia do konkretnego egzemplarza |
| **SKU** | Stock Keeping Unit - unikalny kod produktu w ramach tenanta |
| **Specification** | Para klucz-wartość opisująca cechę produktu (np. "Screen Size": "55 inches") |
| **Category** | Węzeł w drzewie kategorii (np. "Electronics" → "TV" → "OLED TVs") |
| **Media** | Zdjęcia, wideo lub inne multimedia przypisane do ProductModel |

## Key Scenarios

### 1. Dodanie nowego ProductModel do katalogu
```
Given: Sprzedawca ma active tenant
When: Sprzedawca dodaje nowy ProductModel
Then: ProductModel jest utworzony z unikalnym SKU
And: ProductModel jest przypisany do kategorii
And: ProductModelCreated event jest publishowany
```

### 2. Aktualizacja specyfikacji ProductModel
```
Given: ProductModel exists w katalogu
When: Sprzedawca aktualizuje specyfikacje
Then: Specyfikacje są aktualizowane
And: ProductModelUpdated event jest publishowany
And: Istniejące aukcje NIE są modyfikowane (immutability)
```

### 3. Reorganizacja hierarchii kategorii
```
Given: Kategoria z produktami
When: Sprzedawca przenosi kategorię pod inny parent
Then: Kategoria i wszystkie sub-categories są przenoszone
And: ProductModels pozostają przypisane do swoich kategorii
And: CategoryHierarchyChanged event jest publishowany
```

## Integration Points

### Downstream
- **Inventory Context**: Inventory trzyma reference ProductModelId, query side może denormalizować szczegóły
- **Auction Context**: Auction może pobierać dane ProductModel dla display purposes (read model)

### Upstream
- **Tenant Management Context**: Tenant musi być active, category hierarchy pochodzi z tenant configuration

## Non-Functional Requirements

- **Consistency**: Strong consistency w ramach aggregate (ProductModel)
- **Performance**: Read-heavy workload, aggressive caching OK
- **Search**: Full-text search po nazwach, opisach, specyfikacjach
- **Scalability**: Query side może być osobna read database (CQRS)

## Domain Events (Published)

- `ProductModelCreated`
- `ProductModelUpdated`
- `ProductModelArchived`
- `CategoryCreated`
- `CategoryRenamed`
- `CategoryHierarchyChanged`
- `ProductModelCategorized` (assigned to category)

## Technical Considerations

### Storage
- Primary: Azure SQL (relational dla categories tree)
- Read Model: Cosmos DB lub Azure Search dla fast queries (optional)
- Media: Azure Blob Storage

### Caching Strategy
- Aggressive caching dla ProductModel details (rarely change)
- Cache invalidation przez domain events
- Category hierarchy może być cached per tenant

### Multi-tenancy
- TenantId jako partition key
- Row-level security w database
- Isolated category hierarchies per tenant
