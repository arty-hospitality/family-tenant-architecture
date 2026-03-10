# Family Tenant Architecture

## Abstract

The family tenant architecture is a descriptive pattern for multi-tenant systems in which one tenant represents an organisation — the "family" — and its children represent branches, properties, or sub-units. Data is organised as a graph of people, relationships, and time-stamped events, secured through role-based access control and an audit-first design. This document describes the pattern in detail, explains the reasoning behind each design decision, and provides guidance for anyone who wishes to implement or adapt it.

---

## 1. Introduction

Many domains — hospitality, property management, care services, professional services — share a common structural challenge: a single legal entity (the organisation) contains multiple semi-independent operational units (branches, sites, departments), each of which manages its own staff, clients, and records, but which must remain visible and accountable to a central authority.

Conventional multi-tenancy models either treat every unit as a fully isolated tenant (losing visibility across units) or collapse everything into a single tenant with complex filtering logic (losing clean separation). The family tenant architecture sits between these extremes: the organisation as a whole is one tenant, and each of its operational units is a child tenant nested within it.

This document is a reference, not a product. It describes a pattern that can be discussed, adapted, and implemented across different domains and technology stacks. No framework, library, or SDK is implied.

---

## 2. Problem Statement

Systems that must serve both an organisation and its branches face several recurring tensions:

- **Isolation vs. visibility.** Branch data must be private enough for day-to-day operations, yet accessible to managers who need a consolidated view.
- **Consistency vs. autonomy.** Central policies (e.g. data retention, access rules) must apply uniformly, while branches retain the ability to manage their own staff and workflows.
- **Simplicity vs. expressiveness.** Relationships between people (supervision, family membership, professional association) must be first-class concepts without requiring a full graph database.
- **Auditability.** Regulated domains require a complete, tamper-evident record of who changed what and when.

The family tenant architecture addresses all four tensions through a small set of composable primitives.

---

## 3. Architecture Overview

```
Organisation (family tenant)
│
├── Branch A (child tenant)
│   ├── People (nodes)
│   ├── Relationships (edges)
│   └── Events (time-stamped records)
│
├── Branch B (child tenant)
│   ├── People (nodes)
│   ├── Relationships (edges)
│   └── Events (time-stamped records)
│
└── Branch C (child tenant)
    ├── People (nodes)
    ├── Relationships (edges)
    └── Events (time-stamped records)
```

Three layers govern the system:

| Layer | Responsibility |
|-------|---------------|
| **Tenancy** | Isolates data between the organisation and its branches |
| **Graph** | Models people and their relationships within a tenant |
| **Timeline** | Records all changes as immutable, time-stamped events |

Each layer is independent: the tenancy layer does not need to understand graph semantics, and the graph layer does not need to understand event sourcing. This separation makes each concern easier to reason about, test, and replace.

---

## 4. Core Concepts

### 4.1 Family Tenant

A *family tenant* is the top-level tenant representing an organisation. It owns all configuration, policies, and cross-branch data. Child tenants are created beneath it; they inherit policy but cannot modify it.

A child tenant is sometimes called a *branch tenant*. It contains only the data belonging to one operational unit, together with a pointer to its parent family tenant.

There is no limit on the depth of nesting beyond what the domain requires. In most cases a single level of children (family → branch) is sufficient, but the model supports deeper hierarchies where needed.

### 4.2 Graph Data Model

Within each tenant, data is organised as a directed graph:

- **Nodes** represent people (members, staff, clients, or any person relevant to the domain).
- **Edges** represent relationships between people. An edge has a *type* (e.g. `parent`, `child`, `supervisor`, `colleague`) and an optional *weight* or *metadata* payload. Edges are directional: an edge from A to B does not imply an edge from B to A.
- **Graph traversal** is used to compute derived facts: who reports to whom, which members share a household, which supervisor is responsible for a given case.

The graph is stored in a relational or document database; a dedicated graph database is not required. A simple adjacency-list representation is sufficient for most deployments.

### 4.3 Event Timeline

Every change to the graph — a node being added, an edge being modified, an attribute being updated — is recorded as an immutable, time-stamped event. Events are never deleted or overwritten. The current state of the graph is derived by replaying the event log.

An event record contains at minimum:

| Field | Description |
|-------|-------------|
| `id` | Unique identifier |
| `tenant_id` | The tenant to which this event belongs |
| `actor_id` | The person who triggered the event |
| `event_type` | A namespaced string such as `node.created` or `edge.removed` |
| `payload` | A JSON object describing the change |
| `occurred_at` | ISO 8601 timestamp |

Typical event types include relocation, conflict resolution, asset transfer, role change, and relationship update.

### 4.4 Role-Based Access Control

Three roles are defined at the branch level:

| Role | Permissions |
|------|-------------|
| **Member** | Read own data; write own non-sensitive attributes |
| **Supervisor** | Read and write data for people they supervise (defined by the graph) |
| **Manager** | Full read/write access within the branch; read access to aggregated family-level data |

At the family level, an additional **Administrator** role may read and write configuration, create or archive branches, and access the full cross-branch audit log.

Role assignments are themselves nodes and edges in the graph, making role history part of the event timeline.

### 4.5 Audit-First Design

The event timeline satisfies audit requirements by construction: there is no separate audit log to maintain. Every mutation goes through the event layer, which means:

- The complete history of any node or edge is always available.
- Deletions are represented as `node.archived` or `edge.removed` events, not as physical deletions.
- Any point-in-time snapshot of the graph can be reconstructed by replaying events up to a given timestamp.
- Compliance queries (who accessed what, when a relationship changed) are answered by querying the event table.

---

## 5. Hierarchical Tenancy in Detail

### 5.1 Tenant Isolation

Each tenant has its own namespace for node IDs, edge IDs, and event IDs. A query against one tenant never returns data from another tenant. Isolation is enforced at the data layer (e.g. a `tenant_id` column present on every table and included in every index) rather than relying solely on application logic.

### 5.2 Cross-Tenant Access

A family-level Manager or Administrator may query aggregated data across all child tenants. Cross-tenant queries are always read-only from the perspective of any individual child tenant; writes must be directed at a specific branch.

Cross-tenant access is mediated by a dedicated service or query layer that enforces the parent–child relationship before executing the query. Direct cross-branch queries (Branch A reading Branch B data) are not permitted.

### 5.3 Policy Inheritance

Configuration at the family level — data retention periods, allowed relationship types, required event fields — is inherited by all children. Children may not override inherited policies, but they may add stricter local rules on top of them.

---

## 6. Graph Structure in Detail

### 6.1 Node Schema

A node represents one person. Its core attributes are:

| Attribute | Type | Notes |
|-----------|------|-------|
| `id` | UUID | Globally unique within the tenant |
| `tenant_id` | UUID | Reference to the owning tenant |
| `display_name` | string | Human-readable label |
| `created_at` | timestamp | When the node first appeared |
| `archived_at` | timestamp \| null | When the node was archived, if applicable |
| `attributes` | JSON | Domain-specific fields (address, date of birth, etc.) |

Attributes are stored as a schemaless JSON field to allow domain-specific extension without schema migrations. Implementations may enforce a schema on the `attributes` field if consistency is required.

### 6.2 Edge Schema

An edge represents a relationship between two nodes:

| Attribute | Type | Notes |
|-----------|------|-------|
| `id` | UUID | Globally unique within the tenant |
| `tenant_id` | UUID | Reference to the owning tenant |
| `from_node_id` | UUID | Source node |
| `to_node_id` | UUID | Target node |
| `relationship_type` | string | Namespaced string, e.g. `family.parent` |
| `valid_from` | timestamp | When this relationship began |
| `valid_until` | timestamp \| null | When this relationship ended, if applicable |
| `metadata` | JSON | Optional domain-specific payload |

Bi-directional relationships (e.g. "siblings") are represented as two edges, one in each direction, to keep traversal logic uniform.

### 6.3 Graph Queries

Common graph queries include:

- **Descendants**: all nodes reachable from a given node by following edges of a given type.
- **Ancestors**: the reverse traversal.
- **Shortest path**: the minimum number of hops between two nodes via a given relationship type.
- **Neighbourhood**: all nodes within N hops of a given node.
- **Supervision chain**: the sequence of `supervisor` edges from a given node to the root.

These queries can be implemented with recursive common-table expressions (CTEs) in SQL, or with simple breadth-first/depth-first traversal in application code. They do not require a graph database engine.

---

## 7. Event Timeline in Detail

### 7.1 Writing Events

All mutations follow this sequence:

1. Validate the incoming request against current graph state and applicable policies.
2. Construct an event record describing the intended change.
3. Persist the event record.
4. Apply the change to the current-state projection (a denormalised view of the current graph, maintained for read performance).
5. Return a success response.

Steps 3 and 4 must be atomic. If the current-state projection cannot be updated (e.g. due to a transient error), the event is still preserved; the projection can be rebuilt from the event log at any time.

### 7.2 Replaying Events

The current-state projection can be fully rebuilt by:

1. Deleting all projection records for the target tenant.
2. Reading all events for that tenant in ascending `occurred_at` order.
3. Applying each event to the empty projection.

Replay is used for disaster recovery, migration, and debugging. It is intentionally straightforward: any event type that the system does not recognise is skipped and logged, allowing the event schema to evolve without breaking replays of older logs.

### 7.3 Querying History

Historical queries take one of two forms:

- **Point-in-time snapshot**: replay events up to a given timestamp to produce the graph as it existed at that moment.
- **Change log for a node/edge**: filter the event table by `payload->>'node_id'` or `payload->>'edge_id'` to retrieve the full history of a single entity.

---

## 8. Role-Based Access Control in Detail

### 8.1 Permission Checks

Every request is evaluated against three factors:

1. **Authentication**: is the actor a known person in the system?
2. **Tenancy**: does the actor belong to the tenant being queried?
3. **Role**: does the actor's role grant the requested permission?

For Supervisor-level operations, an additional graph check is performed: is the target node reachable from the actor via a supervision edge? This check is the primary use of graph traversal at request time.

### 8.2 Role Assignment

Roles are assigned by writing an edge of type `role.assignment` from the actor (the person granting the role) to the target (the person receiving it), with a `role` field in the edge metadata. Role assignments expire when the edge's `valid_until` date is reached.

Because role assignments are edges, they appear in the event timeline and their full history is automatically preserved.

### 8.3 Elevation and Delegation

A Supervisor may delegate their supervision responsibilities to another person by creating a `supervision.delegation` edge. Delegation does not transfer the Supervisor role itself; it only extends the graph reachability used for permission checks.

A Manager may temporarily elevate a Member to Supervisor by creating a time-bounded `role.assignment` edge.

---

## 9. User Experience Principles

The user interface for systems built on this pattern follows a deliberately simple model:

- **Page-to-page navigation.** Users move through the system by following links and submitting forms, in the style of traditional server-rendered web applications. Complex single-page application flows are avoided.
- **Progressive disclosure.** Summary views show high-level information; detail views show the full graph context. Managers see aggregated family-level summaries; branch staff see only their branch.
- **Explicit actions.** Every mutation (adding a person, updating a relationship, recording an event) is a named, deliberate action rather than an auto-save or background sync. This makes the event timeline easier to understand and explain to end users.
- **Audit transparency.** History views are available at every level: per-node, per-edge, per-branch, and family-wide. Users can see who made a change and when.

---

## 10. Implementation Considerations

### 10.1 Technology Stack

The pattern is stack-agnostic. A typical minimal implementation requires:

- A relational database (PostgreSQL is a natural choice for its JSON support and recursive CTE capability).
- A server-side web framework capable of rendering HTML pages (e.g. Django, Rails, Laravel, or any equivalent).
- No dedicated graph database, event streaming platform, or real-time layer is needed for most deployments.

### 10.2 Schema Migration

Because attributes and event payloads are stored as JSON, new fields can be added without schema migrations. When a structural change is required (e.g. adding a new indexed column), events provide a migration path: the new column is backfilled by replaying the event log.

### 10.3 Performance

For organisations with up to a few thousand nodes per branch, in-memory graph traversal at request time is practical. For larger graphs, pre-computed materialised views of common traversals (supervision chains, household membership) can be maintained as part of the current-state projection and refreshed when relevant edges change.

The event table grows indefinitely but is append-only; it is well-suited to archival storage and partitioning by `occurred_at`.

### 10.4 Multi-Region and Multi-Database Deployments

Child tenants may be stored in separate databases or regions without breaking the architecture, provided that:

- Cross-tenant queries are routed through a family-level query service that federates results.
- Event IDs remain globally unique (UUIDs are the natural choice).
- Clock skew between regions is accounted for when ordering events (use logical clocks or a globally coordinated timestamp service if strict ordering across regions is required).

### 10.5 Compliance and Data Retention

The audit-first design makes compliance straightforward. Data retention policies are implemented by archiving (not deleting) nodes and edges after the retention period, and by moving old events to cold storage. Archived entities remain accessible in the event log but are excluded from current-state queries.

Deletion requests (e.g. GDPR right to erasure) are handled by replacing personally identifiable information in the event log with a tombstone marker, preserving the structural history while removing the personal data.

---

## 11. Extending the Pattern

The family tenant architecture is intentionally minimal. Common extensions include:

- **Documents.** Attaching documents (contracts, reports, images) to nodes or events by storing a reference (URL or object-store key) in the node's `attributes` or the event's `payload`.
- **Notifications.** Triggering notifications when certain event types are written, using the event log as a trigger source rather than introducing a separate messaging layer.
- **Integrations.** Exporting events to external systems (accounting software, reporting tools) by consuming the event log as a feed.
- **Additional role tiers.** Adding domain-specific roles (e.g. Auditor, Read-Only Analyst) by defining new role types and their permission sets.

Extensions should follow the same principles as the core pattern: make changes through events, keep tenancy boundaries explicit, and avoid hidden state.

---

## 12. Conclusion

The family tenant architecture offers a compact set of primitives — hierarchical tenancy, a person graph, and an event timeline — that together address the recurring challenges of multi-tenant systems serving both an organisation and its branches. It does so without requiring exotic infrastructure, and it produces a system that is auditable by construction, easy to reason about, and adaptable to many domains.

This document is a starting point. Implementors are encouraged to adapt the pattern to their domain, to challenge the assumptions made here, and to share what they learn.

---

*This document is part of the `arty-hospitality/family-tenant-architecture` repository. See the [README](../README.md) for a brief summary of the pattern.*
