# Key Decisions To Make

## Critical Decisions (Must decide before implementation)

### 1. Multi-item Auction Strategy ⚠️ HIGH PRIORITY

**Decision**: Jak działają aukcje z wieloma itemami?

**Option A: Sequential Slots** (Recommended dla MVP)
- Items są sprzedawane po kolei
- Item1 sold → Item2 staje się available
- Item2 price restartuje od StartPrice
- Prosta implementacja

**Option B: Parallel Slots**
- Wszystkie items dostępne równocześnie
- Każdy item ma własny independent price schedule
- First-come-first-served
- Bardziej complex, ale potencjalnie szybsza sprzedaż

**Option C: Batch Bidding**
- Users bidują na quantity (np. "kupuję 3 sztuki")
- Price dotyczy all items w batch
- Kompleksowa walidacja

**Impact**: 
- Wpływa na: Auction aggregate design, bid validation, price calculation
- Critical dla UX

**Recommendation**: **Option A dla MVP** - prostota > feature richness

**Status**: ⏳ Pending

---

### 2. Price Calculation Persistence ⚠️ HIGH PRIORITY

**Decision**: Czy persystować intermediate prices?

**Option A: On-the-fly Calculation** (Current approach)
- Cena kalkulowana real-time based on elapsed time
- NO intermediate price persistence
- Deterministic, simple, scalable

**Option B: Periodic Persistence**
- Background job zapisuje price co X sekund
- Query reads from database
- Potential staleness

**Option C: Event Sourcing**
- PriceDropped events persisted
- Rebuild current price from event stream
- Complex but full audit trail

**Impact**:
- Performance: A = best, B = medium, C = complex
- Audit trail: C = best, A = none, B = medium
- Complexity: A = simple, B = medium, C = high

**Recommendation**: **Option A dla MVP**, consider C dla enterprise

**Status**: ✅ Decided (Option A) - documented in price-calculation.md

---

### 3. Read Model Storage Strategy ⚠️ MEDIUM PRIORITY

**Decision**: Gdzie trzymać CQRS read models?

**Option A: Same Database (SQL)**
- Command i query side w tej samej bazie
- Separate tables (`Auctions` vs `AuctionListView`)
- Simple, ACID possible

**Option B: Cosmos DB dla Read Side**
- Command: Azure SQL (strong consistency)
- Query: Cosmos DB (eventual consistency, fast)
- Better performance, higher cost

**Option C: Hybrid**
- Critical queries: SQL
- Heavy queries: Cosmos DB
- Balance complexity vs performance

**Impact**:
- Cost: A < C < B
- Performance: B > C > A
- Complexity: A < C < B
- Consistency gap: A = none, B = yes, C = mixed

**Recommendation**: **Option A dla MVP**, migrate to B at scale

**Status**: ⏳ Pending

---

### 4. E-commerce Integration Approach ⚠️ HIGH PRIORITY

**Decision**: Jak integrujemy się z external e-commerce?

**Option A: Redirect to E-commerce**
- Po wygranym bidzie → redirect do external checkout
- Item dodany do koszyka z rabatem
- Minimal integration

**Option B: Embedded Checkout**
- iFrame z e-commerce checkout w naszej platformie
- Seamless UX
- Wymaga współpracy sprzedawcy

**Option C: Own Checkout + API Integration**
- Nasze checkout UI
- Backend wywołuje e-commerce API dla order creation
- Full control, high complexity

**Impact**:
- User experience: C > B > A
- Integration effort: A < B < C
- Maintenance: A < B < C

**Recommendation**: **Option A dla DEMO/MVP**, consider B dla production

**Status**: ⏳ Pending

---

### 5. Reservation Timeout Duration ⚠️ MEDIUM PRIORITY

**Decision**: Jak długo item jest reserved po successful bid?

**Options**:
- 5 minutes: Aggressive, forces quick decisions
- 15 minutes: Balanced (current assumption)
- 30 minutes: Generous, may lock items too long
- Configurable per tenant: Flexible ale complex

**Impact**:
- Short timeout: Higher conversion pressure, more expired reservations
- Long timeout: Better UX, locks inventory longer

**Recommendation**: **15 minutes dla MVP** with monitoring, adjust based on data

**Status**: ⏳ Pending (15 min assumed, need validation)

---

## Important Decisions (Should decide before scale)

### 6. Event Store Implementation 🔶 MEDIUM PRIORITY

**Decision**: Czy używać Event Sourcing dla audit trail?

**Option A: No Event Store**
- Domain events tylko dla communication
- No event replay
- Simple

**Option B: Append-only Event Log**
- Wszystkie events persisted
- Audit trail
- Cannot rebuild state

**Option C: Full Event Sourcing**
- Events = source of truth
- Can rebuild aggregate state
- Complex

**Recommendation**: **Option A dla MVP**, consider B dla compliance

**Status**: ⏳ Pending

---

### 7. Authentication Strategy 🔶 MEDIUM PRIORITY

**Decision**: Jak authenticatujemy users?

**Sellers/Admins**:
- Azure AD B2B? (enterprise identity)
- Custom identity? (own user store)

**Buyers**:
- Social login (Google, Facebook)?
- Email/Password?
- Anonymous browsing allowed?

**Recommendation**: 
- Sellers: Azure AD
- Buyers: Social + Email/Password dla MVP

**Status**: ⏳ Pending

---

### 8. Tenant Onboarding Process 🔶 LOW PRIORITY

**Decision**: Jak dodajemy nowych tenantów?

**Option A: Manual**
- Admin creates tenant via admin panel
- Simple, controlled

**Option B: Self-service**
- Sprzedawcy rejestrują się sami
- Approval workflow
- Scalable

**Recommendation**: **Option A dla MVP**, B dla scale

**Status**: ⏳ Pending

---

### 9. Search & Discovery 🔶 MEDIUM PRIORITY

**Decision**: Jak users znajdują aukcje?

**Option A: SQL Full-Text Search**
- Built-in SQL Server search
- Simple, adequate

**Option B: Azure Cognitive Search**
- Advanced search (typos, synonyms, facets)
- Better performance
- Higher cost

**Option C: Elasticsearch**
- Self-managed
- Most flexible
- Ops overhead

**Recommendation**: **Option A dla MVP**, consider B at scale

**Status**: ⏳ Pending

---

### 10. Analytics & Reporting 🔶 LOW PRIORITY

**Decision**: Jak dostarczamy analytics dla sprzedawców?

**Options**:
- Basic dashboards (built-in)
- Power BI integration
- Custom analytics platform

**Recommendation**: Basic dashboards dla MVP

**Status**: ⏳ Pending

---

## Technical Decisions (Can decide during implementation)

### 11. Logging Strategy 🔵 LOW PRIORITY

**Options**:
- Structured logging (Serilog)
- Log levels: Debug, Info, Warning, Error
- Correlation IDs dla distributed tracing

**Recommendation**: Serilog + Application Insights

**Status**: ⏳ Pending

---

### 12. API Versioning 🔵 LOW PRIORITY

**Options**:
- URL versioning: `/api/v1/auctions`
- Header versioning: `Accept: application/json; version=1`
- No versioning (breaking changes cautiously)

**Recommendation**: URL versioning

**Status**: ⏳ Pending

---

### 13. Caching Strategy 🔵 MEDIUM PRIORITY

**Decisions**:
- What to cache? (read models, tenant config, current prices)
- TTL values? (1-5 seconds dla prices, 30 min dla config)
- Invalidation strategy? (event-based)

**Recommendation**: Redis with short TTLs, event-based invalidation

**Status**: ⏳ Pending

---

### 14. Error Handling & Retry Policies 🔵 MEDIUM PRIORITY

**Decisions**:
- Retry count? (3 retries dla transient failures)
- Backoff strategy? (Exponential: 2s, 4s, 8s)
- Circuit breaker? (Yes, using Polly)
- Dead letter queue? (Yes, dla failed events)

**Recommendation**: Polly library dla resilience patterns

**Status**: ⏳ Pending

---

### 15. Testing Strategy 🔵 HIGH PRIORITY

**Decisions**:
- Unit test coverage target? (80%+)
- Integration tests? (Critical paths)
- E2E tests? (Happy paths)
- Load testing? (Before production)

**Recommendation**: 
- Unit: 80%+ coverage
- Integration: Critical flows (bid placement, price calc)
- E2E: Smoke tests
- Load: Before launch (1000+ concurrent users)

**Status**: ⏳ Pending

---

## Business Decisions (Product Owner)

### 16. Pricing Model 🟢 HIGH PRIORITY

**Decision**: Jak monetyzujemy platformę?

**Options**:
- Commission per sale (5-15%)
- Subscription per tenant (monthly fee)
- Listing fee per auction
- Hybrid model

**Status**: ⏳ Pending - Product decision

---

### 17. Minimum Auction Duration 🟢 MEDIUM PRIORITY

**Decision**: Constraints na auction duration?

**Suggested**:
- Minimum: 1 hour
- Maximum: 7 days
- Recommended: 3-24 hours

**Status**: ⏳ Pending - Product decision

---

### 18. Return Policy 🟢 LOW PRIORITY

**Decision**: Czy kupujący mogą zwracać items?

**Impact**: Jeśli yes, inventory management się komplikuje

**Status**: ⏳ Pending - Product decision

---

## Decision Template

When making a decision, document using this template:

```markdown
## Decision: [Title]

**Date**: YYYY-MM-DD
**Decided by**: [Name/Team]
**Status**: ✅ Decided

**Context**: [Why this decision is needed]

**Options Considered**:
1. Option A: [Description]
   - Pros: ...
   - Cons: ...
2. Option B: ...

**Decision**: Option X

**Rationale**: [Why this option was chosen]

**Consequences**: 
- Positive: ...
- Negative: ...
- Risks: ...

**Follow-up Actions**:
- [ ] Task 1
- [ ] Task 2
```

---

## Next Steps

1. **Schedule decision-making meetings** dla HIGH PRIORITY items
2. **Assign owners** dla each decision
3. **Set deadlines** (before implementation start)
4. **Document decisions** using ADR format
5. **Review decisions** regularly as we learn more

---

## Decision Status Legend

- ⚠️ **HIGH PRIORITY** - Must decide before implementation
- 🔶 **MEDIUM PRIORITY** - Should decide before scale
- 🔵 **LOW PRIORITY** - Can decide during implementation
- 🟢 **BUSINESS** - Product owner decision
- ⏳ **Pending** - Not yet decided
- ✅ **Decided** - Decision made
