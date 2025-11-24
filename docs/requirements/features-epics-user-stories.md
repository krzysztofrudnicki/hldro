# Features, Epics & User Stories

## Personas

### 👤 Operator (Internal Role)
**Description**: Wewnętrzny administrator platformy odpowiedzialny za zarządzanie tenantami, monitoring systemu i wsparcie techniczne.

**Key Responsibilities**:
- Onboarding nowych sprzedawców (tenants)
- Monitoring wydajności i błędów
- Zarządzanie uprawnieniami
- Wsparcie techniczne dla Marketerów

**Tech Skills**: Wysokie
**Business Knowledge**: Średnie

---

### 🛒 Customer (Buyer/Bidder Role)
**Description**: Końcowy użytkownik kupujący produkty poprzez aukcje reverse. Szuka okazji, licytuje produkty i finalizuje zakupy.

**Key Responsibilities**:
- Przeglądanie dostępnych aukcji
- Składanie ofert (bidów)
- Finalizowanie checkout po wygranej
- Zarządzanie kontem

**Tech Skills**: Niskie do średnich
**Business Knowledge**: Niskie

---

### 📊 Marketer (Seller Role)
**Description**: Pracownik sprzedawcy (tenanta) odpowiedzialny za konfigurację aukcji, zarządzanie katalogiem produktów i inventorym.

**Key Responsibilities**:
- Tworzenie i konfiguracja aukcji
- Zarządzanie katalogiem produktów
- Zarządzanie inventory (dodawanie egzemplarzy)
- Monitoring wyników sprzedaży
- Konfiguracja brandingu i kategorii

**Tech Skills**: Średnie
**Business Knowledge**: Wysokie

---

## Epic Structure

```
Epic
├── Feature 1
│   ├── User Story 1.1
│   ├── User Story 1.2
│   └── User Story 1.3
└── Feature 2
    ├── User Story 2.1
    └── User Story 2.2
```

---

# EPICS

## Epic 1: Tenant Management 🏢
**Description**: Zarządzanie tenantami (sprzedawcami) - onboarding, konfiguracja, branding.

**Business Value**: Umożliwia onboarding nowych sprzedawców i izolację ich danych

**Priority**: 🔴 Critical (MVP)

### Feature 1.1: Tenant Onboarding
#### User Story 1.1.1: Tworzenie nowego tenanta
```
AS AN Operator
I WANT TO create a new tenant account
SO THAT a new seller can start using the platform

ACCEPTANCE CRITERIA:
- [ ] Mogę podać nazwę tenanta, subdomain i contact email
- [ ] System waliduje unikalność subdomeny
- [ ] Po utworzeniu tenant ma status "PendingActivation"
- [ ] Subdomena jest automatycznie konfigurowana (*.reverseauction.com)
- [ ] Email powitalny jest wysyłany do tenanta

TECHNICAL NOTES:
- TenantCreated event jest publikowany
- Inicjalizuje puste katalogi w innych contexts
```

#### User Story 1.1.2: Aktywacja tenanta
```
AS AN Operator
I WANT TO activate a tenant account
SO THAT they can start creating auctions

ACCEPTANCE CRITERIA:
- [ ] Mogę aktywować tenant w statusie "PendingActivation"
- [ ] Po aktywacji tenant może się logować
- [ ] Status zmienia się na "Active"
- [ ] Tenant otrzymuje email z instrukcjami logowania

TECHNICAL NOTES:
- TenantActivated event jest publikowany
```

### Feature 1.2: Tenant Configuration
#### User Story 1.2.1: Konfiguracja brandingu
```
AS A Marketer
I WANT TO configure my company's branding
SO THAT the auction page matches our brand identity

ACCEPTANCE CRITERIA:
- [ ] Mogę upload logo (max 2MB, PNG/JPG)
- [ ] Mogę wybrać primary color (hex picker)
- [ ] Mogę wybrać secondary color (hex picker)
- [ ] Mogę upload favicon
- [ ] Preview zmian przed zapisaniem
- [ ] Zmiany są widoczne natychmiast na subdomain

TECHNICAL NOTES:
- Logo przechowywane w Azure Blob Storage
- TenantConfigurationUpdated event
```

#### User Story 1.2.2: Zarządzanie hierarchią kategorii
```
AS A Marketer
I WANT TO customize my category hierarchy
SO THAT products are organized according to my business needs

ACCEPTANCE CRITERIA:
- [ ] Mogę tworzyć nowe kategorie (max 5 poziomów)
- [ ] Mogę przenosić kategorie (drag & drop)
- [ ] Mogę zmieniać kolejność wyświetlania
- [ ] Mogę dezaktywować nieużywane kategorie
- [ ] Mogę przypisać kolory do kategorii lvl 1

TECHNICAL NOTES:
- CategoryCreated, CategoryMoved events
- Nie mogę usunąć kategorii z przypisanymi produktami
```

---

## Epic 2: Product Catalog Management 📦
**Description**: Zarządzanie katalogiem produktów - tworzenie modeli produktów, specyfikacji, zdjęć.

**Business Value**: Umożliwia Marketerom budowanie katalogu produktów do aukcjonowania

**Priority**: 🔴 Critical (MVP)

### Feature 2.1: Product Model Creation
#### User Story 2.1.1: Dodawanie nowego modelu produktu
```
AS A Marketer
I WANT TO add a new product model to catalog
SO THAT I can later create inventory items and auctions for it

ACCEPTANCE CRITERIA:
- [ ] Mogę podać SKU (unikalny w ramach tenanta)
- [ ] Mogę podać nazwę produktu (3-200 znaków)
- [ ] Mogę dodać opis (max 5000 znaków, rich text)
- [ ] Mogę przypisać do kategorii
- [ ] Mogę ustawić base price (referencyjną cenę)
- [ ] Status początkowy to "Draft"

TECHNICAL NOTES:
- ProductModelCreated event
- SKU uniqueness validation
```

#### User Story 2.1.2: Dodawanie specyfikacji technicznych
```
AS A Marketer
I WANT TO add technical specifications to product model
SO THAT customers can see detailed product information

ACCEPTANCE CRITERIA:
- [ ] Mogę dodać parę klucz-wartość (np. "Screen Size": "55 inches")
- [ ] Mogę dodać max 50 specyfikacji per product
- [ ] Mogę edytować istniejące specyfikacje
- [ ] Mogę usunąć specyfikację
- [ ] Specyfikacje są widoczne w auction details

TECHNICAL NOTES:
- SpecificationAdded, SpecificationRemoved events
```

#### User Story 2.1.3: Upload zdjęć produktu
```
AS A Marketer
I WANT TO upload product images
SO THAT customers can see what they're bidding on

ACCEPTANCE CRITERIA:
- [ ] Mogę upload max 20 zdjęć per product
- [ ] Obsługiwane formaty: JPG, PNG, WEBP
- [ ] Max rozmiar: 5MB per image
- [ ] Mogę ustawić jedno zdjęcie jako main image
- [ ] Mogę zmienić kolejność zdjęć (drag & drop)
- [ ] System automatycznie generuje thumbnails

TECHNICAL NOTES:
- ProductMediaAdded event
- Azure Blob Storage dla images
- Thumbnail generation (Azure Function)
```

### Feature 2.2: Product Model Management
#### User Story 2.2.1: Aktywacja product model
```
AS A Marketer
I WANT TO activate a product model
SO THAT it can be used to create inventory items

ACCEPTANCE CRITERIA:
- [ ] Mogę aktywować product model w statusie "Draft"
- [ ] Przed aktywacją muszę mieć: nazwę, kategorię, min 1 zdjęcie
- [ ] Po aktywacji status zmienia się na "Active"
- [ ] Active products są widoczne w inventory item creation

TECHNICAL NOTES:
- ProductModelActivated event
- Validation rules enforced
```

#### User Story 2.2.2: Archiwizacja product model
```
AS A Marketer
I WANT TO archive outdated product models
SO THAT my catalog stays clean and organized

ACCEPTANCE CRITERIA:
- [ ] Mogę zarchiwizować active product model
- [ ] Nie mogę zarchiwizować jeśli są active auctions
- [ ] Archived products nie są widoczne w listach
- [ ] Mogę reaktywować archived product

TECHNICAL NOTES:
- ProductModelArchived event
- Search index aktualizowany
```

---

## Epic 3: Inventory Management 📋
**Description**: Zarządzanie konkretnymi fizycznymi egzemplarzami produktów

**Business Value**: Tracking konkretnych items, ich stanu i dostępności

**Priority**: 🔴 Critical (MVP)

### Feature 3.1: Inventory Item Creation
#### User Story 3.1.1: Dodawanie inventory item do stock
```
AS A Marketer
I WANT TO add physical product items to inventory
SO THAT they can be auctioned

ACCEPTANCE CRITERIA:
- [ ] Wybieramy product model z listy
- [ ] Podajemy condition: New/Unpacked/Display/Refurbished/Damaged
- [ ] Możemy dodać condition notes (opcjonalne, max 1000 znaków)
- [ ] Możemy podać serial number (opcjonalny)
- [ ] Podajemy acquisition cost (koszt nabycia)
- [ ] Status początkowy: Available
- [ ] Mogę dodać bulk items (np. 50 sztuk tego samego modelu)

TECHNICAL NOTES:
- InventoryItemAdded event
- SerialNumber must be unique per tenant
- Internal SKU auto-generated
```

#### User Story 3.1.2: Aktualizacja condition inventory item
```
AS A Marketer
I WANT TO update item condition
SO THAT accurate information is displayed to customers

ACCEPTANCE CRITERIA:
- [ ] Mogę zmienić condition (np. Display → Damaged)
- [ ] Mogę zaktualizować condition notes
- [ ] Historia zmian jest zapisywana (audit trail)
- [ ] Nie mogę edytować sold items
- [ ] Zmiany są widoczne w active auctions

TECHNICAL NOTES:
- ItemConditionUpdated event
- ItemStatusHistory entity tracks changes
```

### Feature 3.2: Inventory Item Status Management
#### User Story 3.2.1: Wycofywanie uszkodzonych items
```
AS A Marketer
I WANT TO withdraw damaged items from inventory
SO THAT they are not available for auctions

ACCEPTANCE CRITERIA:
- [ ] Mogę wybrać reason: Damaged/ReturnedToSupplier/QualityIssue/Lost
- [ ] Mogę dodać notes (opcjonalne)
- [ ] Status zmienia się na "Withdrawn"
- [ ] Item nie jest dostępny dla nowych aukcji
- [ ] Jeśli item był na aukcji, aukcja jest kończona

TECHNICAL NOTES:
- ItemWithdrawn event
- Active auctions handling required
```

#### User Story 3.2.2: Powrót do stock
```
AS A Marketer
I WANT TO return withdrawn item back to stock
SO THAT it can be auctioned again (rare case)

ACCEPTANCE CRITERIA:
- [ ] Mogę przywrócić withdrawn item
- [ ] Status zmienia się na "Available"
- [ ] Item jest ponownie dostępny dla aukcji

TECHNICAL NOTES:
- ItemReturnedToStock event
```

---

## Epic 4: Auction Creation & Management 🎯
**Description**: Tworzenie, konfiguracja i zarządzanie aukcjami reverse

**Business Value**: Core functionality - umożliwia sprzedaż przez aukcje

**Priority**: 🔴 Critical (MVP)

### Feature 4.1: Auction Creation
#### User Story 4.1.1: Tworzenie nowej aukcji
```
AS A Marketer
I WANT TO create a reverse auction
SO THAT I can sell inventory items

ACCEPTANCE CRITERIA:
- [ ] Podaję title aukcji (10-200 znaków)
- [ ] Podaję description (opcjonalny, max 2000 znaków)
- [ ] Wybieram product model
- [ ] Wybieram inventory items tego modelu (1-100 sztuk)
- [ ] Ustawiam start price (wyższa cena)
- [ ] Ustawiam end price (niższa cena, minimum)
- [ ] Ustawiam czas trwania (1h - 7 dni)
- [ ] Mogę ustawić price drop interval (co ile sekund cena spada)
- [ ] Status początkowy: Draft

ACCEPTANCE CRITERIA (Validation):
- [ ] Start price > End price
- [ ] Wszystkie items muszą być Available
- [ ] Wszystkie items muszą być tego samego product model
- [ ] Czas trwania minimum 1 godzina

TECHNICAL NOTES:
- AuctionCreated event
- PriceSchedule calculation
- Items nie są jeszcze reserved (dopiero przy publish)
```

#### User Story 4.1.2: Konfiguracja price schedule
```
AS A Marketer
I WANT TO configure how price drops over time
SO THAT I can control the speed of price reduction

ACCEPTANCE CRITERIA:
- [ ] Widzę preview jak cena spada w czasie (wykres)
- [ ] Mogę wybrać: Linear / Stepped / Custom drop strategy
- [ ] Linear: cena spada równomiernie co sekundę
- [ ] Stepped: cena spada w krokach (np. co 5 minut)
- [ ] Widzę ile będzie price drops w sumie
- [ ] Widzę szacowany czas do end price

TECHNICAL NOTES:
- PriceSchedule value object
- Calculator pokazuje preview
```

### Feature 4.2: Auction Publishing
#### User Story 4.2.1: Publikacja aukcji
```
AS A Marketer
I WANT TO publish a draft auction
SO THAT customers can start bidding

ACCEPTANCE CRITERIA:
- [ ] Mogę publish auction ze statusu "Draft"
- [ ] System sprawdza czy items są nadal Available
- [ ] System sprawdza czy nie przekroczono MaxConcurrentAuctions
- [ ] Po publish status zmienia się na "Active"
- [ ] Aukcja jest natychmiast widoczna dla customers
- [ ] Price zaczyna spadać zgodnie z harmonogramem
- [ ] Nie mogę edytować published auction

TECHNICAL NOTES:
- AuctionPublished event
- Items są reserved dla auction (status: Reserved)
- Read models aktualizowane
```

### Feature 4.3: Auction Monitoring
#### User Story 4.3.1: Podgląd active auctions
```
AS A Marketer
I WANT TO monitor my active auctions
SO THAT I can track their performance

ACCEPTANCE CRITERIA:
- [ ] Widzę listę wszystkich active auctions
- [ ] Dla każdej aukcji widzę: current price, viewers count, items sold, time remaining
- [ ] Mogę filtrować po statusie
- [ ] Mogę sortować po dacie rozpoczęcia, liczbie viewers
- [ ] Live updates (cena, viewers) bez refresh

TECHNICAL NOTES:
- CQRS read model
- SignalR dla real-time updates
```

#### User Story 4.3.2: Podgląd szczegółów aukcji
```
AS A Marketer
I WANT TO see detailed auction analytics
SO THAT I can understand auction performance

ACCEPTANCE CRITERIA:
- [ ] Widzę historię bids (kto, kiedy, cena)
- [ ] Widzę wykres viewers w czasie
- [ ] Widzę conversion rate (viewers → bidders)
- [ ] Widzę który items zostały sprzedane
- [ ] Widzę średni czas do first bid
- [ ] Mogę export danych do CSV

TECHNICAL NOTES:
- Analytics read model
- Event sourcing consideration dla historical data
```

### Feature 4.4: Auction Management
#### User Story 4.4.1: Przedwczesne zakończenie aukcji
```
AS A Marketer
I WANT TO end an active auction early
SO THAT I can handle exceptional situations

ACCEPTANCE CRITERIA:
- [ ] Mogę end active auction manualnie
- [ ] Muszę podać reason (dropdown + notes)
- [ ] Wszyscy viewers dostają notification
- [ ] Remaining items wracają do Available
- [ ] Reserved items (pending checkout) pozostają reserved

TECHNICAL NOTES:
- AuctionEnded event (EndedReason: Manual)
- SignalR broadcast do all viewers
```

---

## Epic 5: Bidding & Real-time Updates ⚡
**Description**: Składanie ofert przez customers i real-time communication

**Business Value**: Core user experience - umożliwia buying przez bids

**Priority**: 🔴 Critical (MVP)

### Feature 5.1: Auction Discovery
#### User Story 5.1.1: Przeglądanie active auctions
```
AS A Customer
I WANT TO browse available auctions
SO THAT I can find products I'm interested in

ACCEPTANCE CRITERIA:
- [ ] Widzę listę active auctions
- [ ] Dla każdej aukcji widzę: title, main image, current price, items remaining, time left
- [ ] Mogę filtrować po kategorii
- [ ] Mogę sortować po: cenie, czasie pozostałym, popularności
- [ ] Mogę search po nazwie produktu
- [ ] Infinite scroll lub pagination

TECHNICAL NOTES:
- CQRS read model (denormalized)
- Aggressive caching (1-5s TTL)
```

#### User Story 5.1.2: Podgląd szczegółów aukcji
```
AS A Customer
I WANT TO see auction details
SO THAT I can decide if I want to bid

ACCEPTANCE CRITERIA:
- [ ] Widzę product images (gallery)
- [ ] Widzę current price (live updates)
- [ ] Widzę price drop schedule (wykres)
- [ ] Widzę product specifications
- [ ] Widzę condition details
- [ ] Widzę items remaining count
- [ ] Widzę active viewers count (live)
- [ ] Widzę countdown timer

TECHNICAL NOTES:
- SignalR connection dla real-time updates
- WebSocket fallback to polling
```

### Feature 5.2: Bid Placement
#### User Story 5.2.1: Składanie bid
```
AS A Customer
I WANT TO place a bid at current price
SO THAT I can buy the product

ACCEPTANCE CRITERIA:
- [ ] Widzę duży przycisk "BID NOW" z current price
- [ ] Po kliknięciu bid jest submitted natychmiast
- [ ] Widzę loader podczas processing
- [ ] Otrzymuję instant feedback: accepted/rejected
- [ ] Jeśli accepted → redirect do checkout
- [ ] Jeśli rejected → widzę reason i mogę spróbować ponownie

ACCEPTANCE CRITERIA (Validation):
- [ ] Muszę być zalogowany aby bid
- [ ] Nie mogę bid na własną aukcję (tenant check)
- [ ] Nie mogę bid jeśli items są already sold out

TECHNICAL NOTES:
- POST /api/auctions/{id}/bids
- BidAttemptCreated event
- Optimistic locking dla prevent double-bidding
```

#### User Story 5.2.2: Notification o wyniku bid
```
AS A Customer
I WANT TO receive immediate notification about bid result
SO THAT I know if I won or need to try again

ACCEPTANCE CRITERIA:
- [ ] Jeśli accepted: widzę "Congratulations!" + countdown do checkout (15 min)
- [ ] Jeśli rejected: widzę reason (np. "Item was just sold", "Price dropped")
- [ ] Jeśli rejected: current price jest aktualizowana
- [ ] Toast notification z wynikiem

TECHNICAL NOTES:
- SignalR push: BidAccepted / BidRejected
- User-specific message (nie broadcast)
```

### Feature 5.3: Real-time Updates
#### User Story 5.3.1: Live price updates
```
AS A Customer
I WANT TO see price updates in real-time
SO THAT I know when to place my bid

ACCEPTANCE CRITERIA:
- [ ] Current price aktualizuje się co sekundę
- [ ] Nie widzę "jumps" (smooth updates)
- [ ] Widzę animation przy price drop
- [ ] Widzę countdown timer do next drop (jeśli stepped)
- [ ] Updates działają nawet jeśli mam otwarte multiple tabs

TECHNICAL NOTES:
- SignalR: PriceUpdated event co 5s (throttled)
- Frontend interpoluje price between updates
```

#### User Story 5.3.2: Viewer count updates
```
AS A Customer
I WANT TO see how many people are watching
SO THAT I can gauge competition

ACCEPTANCE CRITERIA:
- [ ] Widzę "🔴 42 watching" badge
- [ ] Count aktualizuje się real-time
- [ ] Animation przy join/leave innych viewers

TECHNICAL NOTES:
- SignalR: ViewerCountUpdated event
- ViewerSession tracking w Bidding Context
```

#### User Story 5.3.3: "Item sold" notifications
```
AS A Customer
I WANT TO be notified when someone buys an item
SO THAT I know remaining availability

ACCEPTANCE CRITERIA:
- [ ] Toast notification: "Someone just bought this!"
- [ ] Items remaining count decrementuje
- [ ] Sound notification (opcjonalny, user setting)
- [ ] Animation na items counter

TECHNICAL NOTES:
- SignalR: ItemSold broadcast
- BidAccepted event subscriber
```

---

## Epic 6: Checkout & Reservation 🛒
**Description**: Zarządzanie reservation po wygranym bid i checkout flow

**Business Value**: Finalizacja transakcji i integracja z e-commerce

**Priority**: 🔴 Critical (MVP)

### Feature 6.1: Reservation Management
#### User Story 6.1.1: Utworzenie reservation po bid accepted
```
AS A Customer
I WANT MY won item to be reserved
SO THAT I have time to complete checkout

ACCEPTANCE CRITERIA:
- [ ] Po successful bid item jest reserved na 15 minut
- [ ] Widzę countdown timer: "Complete checkout in 14:32"
- [ ] Item nie jest dostępny dla innych users
- [ ] Reservation ID jest utworzone

TECHNICAL NOTES:
- ReservationCreated event (triggered by BidAccepted)
- ItemReserved event w Inventory Context
- 15 min timeout
```

#### User Story 6.1.2: Checkout initiation
```
AS A Customer
I WANT TO proceed to checkout
SO THAT I can complete my purchase

ACCEPTANCE CRITERIA:
- [ ] Po bid accepted widzę "Proceed to Checkout" button
- [ ] Redirect do checkout (external e-commerce lub embedded)
- [ ] Widzę reservation timer
- [ ] Widzę product details i winning price
- [ ] Mogę cancel reservation (button "I changed my mind")

TECHNICAL NOTES:
- CheckoutOrchestrationService
- Integration z tenant's e-commerce platform
- ExternalCheckoutId linking
```

### Feature 6.2: Reservation Timeout
#### User Story 6.2.1: Wygaśnięcie reservation
```
AS A Customer
I WANT TO be warned before my reservation expires
SO THAT I don't lose the item

ACCEPTANCE CRITERIA:
- [ ] Warning notification przy 5 min pozostałych
- [ ] Warning notification przy 1 min pozostałej
- [ ] Po wygaśnięciu: "Your reservation expired" message
- [ ] Item wraca do available (może być ponownie wystawiony)

TECHNICAL NOTES:
- ReservationExpired event
- Background job checks expired reservations co 1 min
- ItemReservationReleased event
```

### Feature 6.3: Checkout Completion
#### User Story 6.3.1: Finalizacja checkout w external e-commerce
```
AS A Customer
I WANT TO complete payment in seller's store
SO THAT I can receive the product

ACCEPTANCE CRITERIA:
- [ ] Redirect do seller's e-commerce checkout
- [ ] Item dodany do cart z winning price (jako discount)
- [ ] Po successful payment: otrzymuję order confirmation
- [ ] Platform otrzymuje webhook notification
- [ ] Item status zmienia się na "Sold"
- [ ] Nie mogę już anulować reservation

TECHNICAL NOTES:
- CheckoutCompleted event (triggered by webhook)
- ItemSold event w Inventory Context
- Anti-corruption layer dla różnych platform (Shopify/WooCommerce)
```

---

## Epic 7: User Authentication & Profile 👤
**Description**: Zarządzanie kontem użytkownika

**Business Value**: User identity i personalizacja

**Priority**: 🟡 High (MVP)

### Feature 7.1: Customer Registration & Login
#### User Story 7.1.1: Rejestracja nowego account
```
AS A Customer
I WANT TO create an account
SO THAT I can place bids

ACCEPTANCE CRITERIA:
- [ ] Mogę zarejestrować się przez email/password
- [ ] Mogę zarejestrować się przez social login (Google, Facebook)
- [ ] Email verification required
- [ ] Mocne hasło required (min 8 znaków, cyfry, litery)
- [ ] GDPR consent checkbox
- [ ] Terms & Conditions checkbox

TECHNICAL NOTES:
- Azure AD B2C consideration
- UserCreated event
```

#### User Story 7.1.2: Login do account
```
AS A Customer
I WANT TO log in to my account
SO THAT I can access my bids and reservations

ACCEPTANCE CRITERIA:
- [ ] Login przez email/password
- [ ] Login przez social (Google, Facebook)
- [ ] "Remember me" checkbox
- [ ] "Forgot password" link
- [ ] JWT token-based authentication
- [ ] Session expires po 24h inactivity

TECHNICAL NOTES:
- JWT tokens w httpOnly cookies
- Refresh token mechanism
```

### Feature 7.2: Marketer Authentication
#### User Story 7.2.1: Marketer login
```
AS A Marketer
I WANT TO log in to my tenant dashboard
SO THAT I can manage auctions and inventory

ACCEPTANCE CRITERIA:
- [ ] Login przez subdomain (mediamarkt.reverseauction.com)
- [ ] Azure AD B2B authentication
- [ ] Role-based access (Admin, Marketer, Viewer)
- [ ] MFA required dla admin role

TECHNICAL NOTES:
- Azure AD integration
- TenantId z subdomain resolution
- Role claims w JWT
```

---

## Epic 8: Notifications & Alerts 🔔
**Description**: System powiadomień dla users

**Business Value**: Engagement i retention

**Priority**: 🟡 High (post-MVP)

### Feature 8.1: Customer Notifications
#### User Story 8.1.1: Bid result notifications
```
AS A Customer
I WANT TO receive notification about my bid result
SO THAT I don't miss winning

ACCEPTANCE CRITERIA:
- [ ] Push notification (jeśli enabled)
- [ ] Email notification (jeśli bid accepted)
- [ ] SMS notification (opcjonalny, premium feature)
- [ ] In-app notification

TECHNICAL NOTES:
- Notification Service (separate bounded context?)
- Azure Notification Hub
```

#### User Story 8.1.2: Price drop alerts
```
AS A Customer
I WANT TO set price alert for auction
SO THAT I'm notified when price reaches my target

ACCEPTANCE CRITERIA:
- [ ] Mogę set alert: "Notify me when price drops below X"
- [ ] Otrzymuję notification gdy warunek spełniony
- [ ] Mogę mieć max 10 active alerts
- [ ] Alert expires po 24h lub auction end

TECHNICAL NOTES:
- PriceAlertService
- Event-driven (PriceDropped event subscriber)
```

### Feature 8.2: Marketer Notifications
#### User Story 8.2.1: Auction performance alerts
```
AS A Marketer
I WANT TO receive alerts about auction performance
SO THAT I can react to issues

ACCEPTANCE CRITERIA:
- [ ] Alert jeśli no bids po 50% czasu aukcji
- [ ] Alert jeśli viewer count < 5 przez 1h
- [ ] Alert jeśli auction ended by system error
- [ ] Email digest: daily auction summary

TECHNICAL NOTES:
- Analytics-driven alerts
- Background job calculates metrics
```

---

## Epic 9: Analytics & Reporting 📊
**Description**: Dashboards i raporty dla Marketerów i Operatorów

**Business Value**: Data-driven decisions

**Priority**: 🟢 Medium (post-MVP)

### Feature 9.1: Marketer Dashboard
#### User Story 9.1.1: Auction performance dashboard
```
AS A Marketer
I WANT TO see my auction performance metrics
SO THAT I can optimize my strategy

ACCEPTANCE CRITERIA:
- [ ] Widzę: total sales, conversion rate, avg. sale price
- [ ] Widzę: best performing categories
- [ ] Widzę: peak traffic hours
- [ ] Widzę: inventory turnover rate
- [ ] Mogę filtrować po dacie (last 7/30/90 days)
- [ ] Mogę export report do PDF/Excel

TECHNICAL NOTES:
- Analytics read model (CQRS)
- Pre-calculated metrics (nightly job)
```

### Feature 9.2: Operator Dashboard
#### User Story 9.2.1: Platform health monitoring
```
AS AN Operator
I WANT TO monitor platform health
SO THAT I can detect and fix issues

ACCEPTANCE CRITERIA:
- [ ] Widzę: active auctions count, total viewers, bids/min
- [ ] Widzę: system errors (last 24h)
- [ ] Widzę: slow queries (> 2s)
- [ ] Widzę: failed event processing
- [ ] Widzę: Azure resource utilization (CPU, memory)
- [ ] Alerts dla critical issues

TECHNICAL NOTES:
- Application Insights integration
- Custom metrics tracking
- Alerting rules
```

---

## Epic 10: Search & Discovery 🔍
**Description**: Zaawansowane wyszukiwanie i rekomendacje

**Business Value**: User experience, discovery

**Priority**: 🟢 Medium (post-MVP)

### Feature 10.1: Advanced Search
#### User Story 10.1.1: Full-text search
```
AS A Customer
I WANT TO search for products by name or description
SO THAT I can quickly find what I need

ACCEPTANCE CRITERIA:
- [ ] Search bar w navbar
- [ ] Wyniki w real-time (autocomplete)
- [ ] Search po: title, description, product model name
- [ ] Typo tolerance (fuzzy matching)
- [ ] Highlighting matched terms

TECHNICAL NOTES:
- Azure Cognitive Search lub SQL Full-Text
- Search index aktualizowany przez events
```

#### User Story 10.1.2: Faceted filtering
```
AS A Customer
I WANT TO filter auctions by multiple criteria
SO THAT I can narrow down results

ACCEPTANCE CRITERIA:
- [ ] Filter po: category, price range, condition, ending soon
- [ ] Multiple filters kombinowane (AND logic)
- [ ] Widzę count dla każdego filter option
- [ ] Mogę clear all filters jednym kliknięciem

TECHNICAL NOTES:
- Facets calculated w search index
- URL parameters dla shareable filters
```

---

## Epic 11: Mobile Experience 📱
**Description**: Responsywny design i mobile app

**Business Value**: Mobile users stanowią 60%+ traffic

**Priority**: 🟡 High (MVP - responsive web, post-MVP - native app)

### Feature 11.1: Responsive Web Design
#### User Story 11.1.1: Mobile-friendly auction browsing
```
AS A Customer
I WANT TO browse auctions on my phone
SO THAT I can bid from anywhere

ACCEPTANCE CRITERIA:
- [ ] Auction list jest touch-friendly
- [ ] Images load fast (lazy loading)
- [ ] Filters dostępne z hamburger menu
- [ ] Search bar w top navbar
- [ ] PWA support (add to home screen)

TECHNICAL NOTES:
- Responsive grid (mobile-first)
- Touch gestures support
- Service Worker dla offline
```

#### User Story 11.1.2: Mobile bid placement
```
AS A Customer
I WANT TO place bids quickly on mobile
SO THAT I don't miss opportunities

ACCEPTANCE CRITERIA:
- [ ] Duży "BID NOW" button (thumb-friendly)
- [ ] Bid confirmation modal (prevent accidental bids)
- [ ] Biometric authentication support (Face ID, Touch ID)
- [ ] Haptic feedback po successful bid

TECHNICAL NOTES:
- WebAuthn API dla biometric
- Native vibration API
```

---

## Priority Matrix

| Epic | Priority | MVP | Phase 2 | Phase 3 |
|------|----------|-----|---------|---------|
| Epic 1: Tenant Management | 🔴 Critical | ✅ | - | - |
| Epic 2: Product Catalog | 🔴 Critical | ✅ | - | - |
| Epic 3: Inventory Management | 🔴 Critical | ✅ | - | - |
| Epic 4: Auction Creation | 🔴 Critical | ✅ | - | - |
| Epic 5: Bidding & Real-time | 🔴 Critical | ✅ | - | - |
| Epic 6: Checkout | 🔴 Critical | ✅ | - | - |
| Epic 7: Authentication | 🟡 High | ✅ | - | - |
| Epic 8: Notifications | 🟡 High | - | ✅ | - |
| Epic 9: Analytics | 🟢 Medium | - | ✅ | - |
| Epic 10: Search | 🟢 Medium | Basic | ✅ | - |
| Epic 11: Mobile | 🟡 High | Responsive | - | Native App |

---

## User Story Template

```markdown
### User Story X.X.X: [Title]

AS A [Persona]
I WANT TO [action]
SO THAT [benefit]

ACCEPTANCE CRITERIA:
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

TECHNICAL NOTES:
- Implementation hints
- Domain events
- External integrations

DEFINITION OF DONE:
- [ ] Code implemented
- [ ] Unit tests written (80%+ coverage)
- [ ] Integration tests dla critical paths
- [ ] Documentation updated
- [ ] Code reviewed
- [ ] QA tested
- [ ] Deployed to staging
```

---

## Estimation Guidelines

**Story Points** (Fibonacci):
- **1 point**: Trivial (1-2 hours) - np. dodanie validation rule
- **2 points**: Simple (2-4 hours) - np. nowy endpoint CRUD
- **3 points**: Medium (4-8 hours) - np. feature z business logic
- **5 points**: Complex (1-2 days) - np. integration z external system
- **8 points**: Very complex (2-3 days) - np. real-time bidding flow
- **13 points**: Epic-level, rozbić na smaller stories

---

## Next Steps

1. **Priorytetyzacja**: Product Owner decyduje o kolejności epics
2. **Refinement**: Tech team estymuje story points
3. **Sprint Planning**: Wybieramy stories na sprint (velocity-based)
4. **Implementation**: Developers biorą stories do realizacji
5. **Testing**: QA testuje wg Acceptance Criteria
6. **Demo**: Sprint demo dla stakeholders
