# Family-Tenant Architecture

## Specification (v1)

Arthit Pukhampung  
Dec 2025 Surrey Hills, VIC Australia

---

## 1. Scope

A multi-tenant system where:

- One Family = One Tenant
- Each Child = One Property / Branch
- Users belong to the Family, not to individual Children
- Configuration is Global-first with controlled overrides
- Reporting works naturally at Family level

Not building AI  
Not building complex rule engines  
Not building cross-family sharing (out of scope v1)

---

## 2. Core Domain Model (DATA FIRST)

### 2.1 Tenant Structure

Family (Tenant)

- Child (Property / Branch)
- Users
- Global Config
- Audit / Reporting

---

### 2.2 Entities

#### Family

`Family { id: UUID name: string ownerUserId: UUID createdAt }`

---

#### Child (Property / Branch)

`Child { id: UUID familyId: UUID name: string status: active | archived createdAt }`

---

#### User

`User { id: UUID familyId: UUID email name status: active | suspended }`

Users never belong to a Child directly.

---

#### UserAssignment (User <-> Child)

`UserAssignment { id: UUID userId: UUID childId: UUID role: staff | supervisor | manager }`

This solves:

- Supervisor / Manager are operational roles
- Not family relationships
- Can change over time

---

## 3. Configuration Model

### 3.1 Global Config (Family level)

`FamilyConfig { familyId: UUID key: string value: JSON }`

Examples:

- cleaning_time_1BR = 35
- supervisor_threshold = 1800
- roster_minutes_per_staff = [300, 360]

---

### 3.2 Child Override (Whitelist only)

`ChildConfigOverride { childId: UUID key: string value: JSON }`

Rule:  
If override exists -> use override  
others -> fallback to FamilyConfig

No inheritance trees  
No rule engines  
Only simple resolution

---

## 4. Navigation

Classic page-by-page navigation:

- `/dashboard`
- `/family/settings`
- `/children`
- `/child/:id`
- `/supervisor`
- `/manager`
- `/reports`

- Clicking Supervisor -> `/supervisor`
- Clicking Manager -> `/manager`

No SPA complexity required.

---

## 5. Permission Model

Role meaning:

| Role | Scope | Can do |
| ---- | ----- | ------ |
| staff | child | view tasks |
| supervisor | child | approve, inspect |
| manager | family | assign roles, configs |

Enforcement rule:  
User must:

- belong to Family
- have assignment to Child (or family-level role)

---

## 6. Reporting

Family-level reporting (default)

Examples:

- Total rooms cleaned across all children
- Total labour minutes this week
- Supervisor load across properties

Child-level reporting (filtered)

Example SQL concept:

```sql
SELECT * FROM tasks WHERE child_id = ?;
```

Family-level:

```sql
SELECT * FROM tasks WHERE family_id = ?;
```

No cross-tenant joins  
No duplication  
No hacks

---

## 7. Audit & Reality Tracking (NON-NEGOTIABLE)

`AuditLog { id: UUID familyId: UUID actorUserId: UUID action: string entity: string before: JSON after: JSON timestamp }`

This makes the "family" real over time.

---

## 8. MVP BUILD ORDER

Engineers must build in this order:

1. Family creation
2. Child creation
3. User creation
4. UserAssignment
5. Global Config
6. Child Override
7. Dashboard navigation
8. Reporting
9. Audit log

Skip audit -> system loses trust  
Skip config model -> system explodes later

---

## 9. What this architecture SOLVES

- No duplicated users
- No duplicated configs
- Clean reporting
- Easy expansion (new child = new row, not new tenant)
- Governance without complexity

---

## 10. Summary

"It's a global-first multi-tenant system where one tenant represents a family, children represent branches, users belong to the family, and child overrides are explicitly whitelisted."
