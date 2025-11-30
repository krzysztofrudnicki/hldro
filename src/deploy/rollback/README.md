# Rollback Procedures

Procedury wycofania zmian w przypadku problemów z deploymentem.

## Strategie rollback

### 1. Infrastructure Rollback
- Powrót do poprzedniej wersji Bicep templates
- Przywrócenie poprzedniej konfiguracji
- Dokumentacja w: `infrastructure-rollback.md`

### 2. Application Rollback
- Deployment poprzedniej wersji aplikacji
- Rollback Azure Functions (slot swap)
- Dokumentacja w: `application-rollback.md`

### 3. Database Rollback
- Migration down scripts
- Backup restore procedures
- Dokumentacja w: `database-rollback.md`

## Procedura

1. **Identyfikacja problemu** - co poszło nie tak?
2. **Decyzja** - rollback vs hotfix?
3. **Komunikacja** - powiadom zespół
4. **Wykonanie rollback** - zgodnie z procedurą
5. **Weryfikacja** - sprawdź czy system działa
6. **Post-mortem** - analiza przyczyn

## Skrypty rollback

- `rollback-infrastructure.ps1` - rollback infrastruktury
- `rollback-application.ps1` - rollback aplikacji
- `rollback-full.ps1` - pełny rollback (infrastructure + app)

## Backup strategy

- Automatyczne backupy przed każdym deploymentem
- Retention: 30 dni dla prod, 7 dni dla innych środowisk
- Testy restore co miesiąc
