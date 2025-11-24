# Reverse Auction Platform - Documentation

## Overview

Platforma aukcji odwrotnych (Dutch Auction) dla dużych sprzedawców e-commerce, umożliwiająca fair pricing produktów outletowych i wyprzedażowych poprzez mechanizm spadającej ceny w czasie.

## Problem Biznesowy

Sprzedawcy e-commerce chcą uzyskać lepsze marże na produktach outletowych niż przy standardowych obniżkach z góry. Kupujący otrzymują możliwość zakupu w momencie, gdy cena spadnie do poziomu, który uznają za atrakcyjny.

## Mechanizm Aukcji

- **Time-based price drop**: Cena spada precyzyjnie co do sekundy o ustaloną wartość (% lub bezwzględną)
- **Multiple items per auction**: Aukcja może zawierać wiele egzemplarzy, każdy wymaga osobnego bida
- **Real-time updates**: WebSocket informuje o zakupach przez innych użytkowników i liczbie oglądających
- **Tenant isolation**: Każdy duży sprzedawca ma dedykowany tenant z własnym katalogiem i konfiguracją

## Architektura

### Podejście
- **Microservices** z wykorzystaniem Domain-Driven Design (DDD)
- **CQRS** - separacja komend i zapytań
- **Event-Driven** - komunikacja między bounded contexts przez domain events
- **Multi-tenancy** - izolacja danych i konfiguracji per sprzedawca

### Stack Technologiczny
- **Backend**: .NET (C#), Azure
- **Frontend**: React
- **Infrastructure**: Azure (App Services, Azure SQL, Service Bus, SignalR, Storage)

## Struktura Dokumentacji

### Architecture
- [Bounded Contexts Overview](./architecture/bounded-contexts.md) - Mapa kontekstów i ich relacji
- [Integration Patterns](./architecture/integration-patterns.md) - Komunikacja między BC
- [Shared Kernel](./architecture/shared-kernel.md) - Współdzielone typy i value objects

### Bounded Contexts
Szczegółowa dokumentacja każdego bounded context:
- [Product Catalog Context](./bounded-contexts/product-catalog/overview.md)
- [Inventory Context](./bounded-contexts/inventory/overview.md)
- [Auction Context](./bounded-contexts/auction/overview.md)
- [Bidding Context](./bounded-contexts/bidding/overview.md)
- [Reservation & Checkout Context](./bounded-contexts/reservation-checkout/overview.md)
- [Tenant Management Context](./bounded-contexts/tenant-management/overview.md)

### Technical
- [Tech Stack Details](./technical/tech-stack.md)
- [CQRS Implementation](./technical/cqrs-approach.md)
- [Real-time Updates Strategy](./technical/real-time-updates.md)
- [Azure Infrastructure](./technical/azure-infrastructure.md)

### Decisions
- [Decisions to Make](./decisions/decisions-to-make.md) - Lista kluczowych decyzji wymagających rozstrzygnięcia

## Bounded Contexts - Quick Reference

| Context | Odpowiedzialność |
|---------|------------------|
| **Product Catalog** | Zarządzanie "klasami" produktów (modele, specyfikacje, kategorie) |
| **Inventory** | Zarządzanie konkretnymi egzemplarzami produktów (stan, dostępność) |
| **Auction** | Mechanizm aukcji (lifecycle, price schedule, time-based drop) |
| **Bidding** | Składanie ofert zakupu, walidacja, winner selection |
| **Reservation & Checkout** | Rezerwacja po wygraniu, integracja z e-commerce sprzedawcy |
| **Tenant Management** | Konfiguracja tenantów, branding, kategorie |

## Current Phase

**DEMO → MVP**
- Focus: Single tenant (duży sprzedawca)
- Bez open market (planowane później)
- Podstawowe integracje z platformą e-commerce sprzedawcy
- Real-time price updates i bid validation

## Dla AI Agent

Ta dokumentacja służy jako knowledge base dla AI agentów tworzących kod. Kluczowe zasady:

1. **Respect aggregate boundaries** - nie łamać granic transakcyjnych
2. **Domain Events dla komunikacji** - BC komunikują się asynchronicznie
3. **Immutable Value Objects** - Money, TenantId, etc.
4. **CQRS separation** - komendy modyfikują, queries tylko czytają
5. **Multi-tenancy first** - każdy request musi być w kontekście tenant
