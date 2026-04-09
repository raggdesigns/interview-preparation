# JSONB in PostgreSQL

**Interview framing:**

"JSONB is PostgreSQL's binary JSON column type, and it's the feature that most blurs the line between relational and document databases. You get to store schemaless data in a relational table, query into it with SQL, index it with GIN, and keep transactional guarantees for all of it. The senior insight is that JSONB is powerful enough to be misused — it's tempting to throw all unstructured data in a JSONB column and call it a day, but doing so gives up the benefits of a relational schema. The skill is knowing when JSONB is the right tool and when a proper relational design is better."

### JSON vs JSONB

PostgreSQL has two JSON column types:

- **`json`** — stores JSON as text, preserves whitespace and key ordering, no binary parsing. Validates syntax on input. Each query re-parses the JSON.
- **`jsonb`** — stores JSON in a decomposed binary format. Faster queries, indexable, but reformats on input (loses key ordering and whitespace).

**Always use JSONB unless you specifically need to preserve the original text representation.** The text-preserving behavior of `json` is almost never what you actually want, and the query performance difference is significant.

### Basic usage

```sql
CREATE TABLE events (
  id BIGSERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  event_type TEXT NOT NULL,
  attributes JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO events (user_id, event_type, attributes) VALUES
  (42, 'purchase', '{"amount": 49.99, "currency": "USD", "items": [{"sku": "ABC", "qty": 2}]}'),
  (42, 'signup', '{"source": "web", "referrer": "google"}'),
  (99, 'purchase', '{"amount": 12.50, "currency": "EUR", "items": [{"sku": "XYZ", "qty": 1}]}');
```

### Querying JSONB

PostgreSQL has a rich set of operators for JSONB:

```sql
-- Get a field as JSON
SELECT attributes -> 'amount' FROM events;

-- Get a field as text
SELECT attributes ->> 'amount' FROM events;

-- Get a nested field
SELECT attributes -> 'items' -> 0 ->> 'sku' FROM events;

-- Path access (JSON Path-like)
SELECT attributes #> '{items, 0, sku}' FROM events;
SELECT attributes #>> '{items, 0, sku}' FROM events;

-- Containment: does this JSONB contain this sub-document?
SELECT * FROM events WHERE attributes @> '{"currency": "USD"}';

-- Key existence
SELECT * FROM events WHERE attributes ? 'referrer';

-- Key existence (any of)
SELECT * FROM events WHERE attributes ?| ARRAY['referrer', 'source'];

-- Key existence (all of)
SELECT * FROM events WHERE attributes ?& ARRAY['amount', 'currency'];
```

The distinction between `->` and `->>` is important:

- **`->`** returns a JSONB value. Use when you want to keep chaining operators.
- **`->>`** returns text. Use for the final extraction.

Common mistake: using `->` when you want `->>` and then comparing the result to a string. `attributes -> 'status' = 'active'` fails because `'active'` isn't JSONB; you want `attributes ->> 'status' = 'active'`.

### Modifying JSONB

JSONB values are immutable — you can't modify a field in place. You write a new value by constructing a modified version.

```sql
-- Set or replace a field
UPDATE events
SET attributes = attributes || '{"processed": true}'::jsonb
WHERE id = 1;

-- Set a nested field (jsonb_set)
UPDATE events
SET attributes = jsonb_set(
  attributes,
  '{payment, status}',
  '"completed"'::jsonb,
  true  -- create if missing
)
WHERE id = 1;

-- Remove a field
UPDATE events
SET attributes = attributes - 'processed'
WHERE id = 1;

-- Remove a nested field
UPDATE events
SET attributes = attributes #- '{payment, status}'
WHERE id = 1;
```

The `||` operator for merging is the most common pattern. `jsonb_set` is for deeper modifications.

### Indexing JSONB

GIN indexes make JSONB queries fast. Two index operator classes:

**Default GIN (`jsonb_ops`):**

```sql
CREATE INDEX idx_events_attrs ON events USING gin (attributes);
```

Supports all JSONB operators including `@>`, `?`, `?|`, `?&`. Larger index, slower writes.

**`jsonb_path_ops`:**

```sql
CREATE INDEX idx_events_attrs_path ON events USING gin (attributes jsonb_path_ops);
```

Only supports `@>` (containment). Smaller index, faster writes, faster containment queries. **Use this by default if you only need containment queries** (which is 80% of JSONB queries in practice).

**Expression indexes** for specific fields:

```sql
CREATE INDEX idx_events_user_id_jsonb
  ON events ((attributes ->> 'user_id'));
```

This indexes just the `user_id` field extracted as text. Faster than a full GIN index for queries that filter on exactly one field.

### The rule of indexes for JSONB

- **Whole-document containment queries** (`WHERE data @> '{...}'`) → GIN index with `jsonb_path_ops`.
- **Single-field equality queries** (`WHERE data->>'field' = 'value'`) → expression index on the field.
- **Mixed** — both indexes, each serving their query type.

Don't default to full GIN if you only need containment. The smaller `jsonb_path_ops` index is cheaper and usually sufficient.

### When JSONB is the right choice

- **Schema that genuinely varies per row.** Event attributes, user preferences, feature flags, A/B test variants — things where different rows have different fields and enforcing a columnar schema is impossible or awkward.
- **External data you don't control.** Webhook payloads, API responses, third-party data.
- **Sparse attributes.** Many possible fields but most rows only have a few.
- **Configuration blobs.** Settings, metadata, flags that are read as a whole unit.
- **Mixing relational and document workloads** in one database, avoiding the operational cost of running two databases.

### When JSONB is the wrong choice

- **Structured data with known fields.** If you can write down the schema, use real columns. Type enforcement, smaller storage, better query plans, easier indexing, clearer intent.
- **Frequently queried individual fields.** Extracting a field from JSONB on every query is slower than reading a column. Expression indexes help but don't fully close the gap.
- **Joins on JSONB fields.** Joining tables on a JSONB-extracted value is awkward and often slow.
- **Aggregations over JSONB fields.** `SUM((data->>'amount')::numeric)` works but costs more than summing a numeric column.
- **Foreign key relationships.** You can't have a foreign key on a JSONB field.
- **Critical data integrity.** CHECK constraints on JSONB fields work but are harder to reason about than constraints on real columns.

The trap: JSONB feels flexible, so you throw everything into it. Then you find yourself extracting the same fields constantly, indexing them individually, and wishing they were columns. If you find yourself in that situation, promote the fields to real columns.

### The hybrid pattern

A common and powerful pattern: columns for the fields you *always* query, JSONB for the fields you *sometimes* query or don't know in advance.

```sql
CREATE TABLE events (
  id BIGSERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),  -- always queried
  event_type TEXT NOT NULL,                       -- always queried
  created_at TIMESTAMPTZ NOT NULL,                -- always queried
  attributes JSONB NOT NULL                        -- variable, sometimes queried
);

CREATE INDEX idx_events_user_id ON events (user_id);
CREATE INDEX idx_events_type_time ON events (event_type, created_at DESC);
CREATE INDEX idx_events_attrs ON events USING gin (attributes jsonb_path_ops);
```

The common queries hit real columns and real indexes; the rare queries reach into JSONB. Best of both worlds.

### JSONB and NULL handling

JSONB has its own notion of null (the JSON null) distinct from SQL NULL:

- **SQL NULL:** the column itself is not set.
- **JSON null:** the column contains the JSON value `null`.

`WHERE data IS NULL` is not the same as `WHERE data = 'null'::jsonb`. The first tests for SQL NULL; the second tests for a JSONB value that's JSON null.

Similarly, `data ->> 'field'` returns SQL NULL if `field` doesn't exist OR if it exists and is JSON null. Use `data ? 'field'` to distinguish "missing" from "present and null".

### Size considerations

JSONB is stored compactly but isn't free:

- **Keys are stored per-row.** If every row has the same 20 keys, each row stores those keys. Normalized columns are more efficient for repeated structure.
- **TOAST** — large JSONB values are compressed and stored out of line. Access is slower for huge blobs.
- **Index size** — GIN indexes on JSONB can be surprisingly large.

For very large JSONB documents (many KB or more), the overhead becomes noticeable. Relational schemas are more compact for repetitive structured data.

### JSON Path (PostgreSQL 12+)

PostgreSQL 12 added SQL/JSON Path support — a standard way to query JSONB with expressions:

```sql
SELECT * FROM events
WHERE attributes @@ '$.items[*].qty > 1';

SELECT jsonb_path_query_array(attributes, '$.items[*].sku')
FROM events
WHERE event_type = 'purchase';
```

JSON Path is more powerful than the basic operators for complex queries — you can filter arrays, use predicates, and traverse paths with conditionals. But it's newer and less familiar than the basic operators, and the planner support is still maturing. For most queries, the basic operators are fine.

### JSONB in Doctrine / ORM

PHP ORMs support JSONB with some caveats:

- **Doctrine** — use the `json` column type, which maps to JSONB on PostgreSQL. You can set and retrieve PHP arrays, but Doctrine doesn't give you query-level JSONB operators — you fall back to DQL's native SQL or raw SQL for containment queries.
- **Eloquent** — has JSON column casts that automatically encode/decode. Query builder support is limited for JSONB-specific operations.
- **Raw SQL** — for complex JSONB queries, you drop to raw SQL or use the ORM's native-SQL escape hatch. This is the normal pattern — JSONB queries are often rare enough that ORM support isn't the bottleneck.

The pattern: ORM for the structured part, raw SQL or query builder escape hatches for the JSONB-specific bits.

> **Mid-level answer stops here.** A mid-level dev can describe JSONB operators. To sound senior, speak to when JSONB is the right tool, the hybrid pattern, and the failure modes of misusing it ↓
>
> **Senior signal:** treating JSONB as one tool in the toolkit — powerful for the right use cases, wrong for others — rather than as a general-purpose "schemaless" escape hatch.

### The decision framework I use

When deciding whether a field belongs in a column or in JSONB:

1. **Can I write down the schema?** Yes → real columns. No → JSONB.
2. **Do I query this field frequently and selectively?** Yes → real columns (or expression index on JSONB). No → plain JSONB.
3. **Do I need foreign keys or constraints?** Yes → real columns.
4. **Is this data structurally identical across rows?** Yes → real columns.
5. **Does it change shape per row?** Yes → JSONB.
6. **Is it a nested document structure that's meaningful as a unit?** Yes → JSONB works well.

Most real schemas end up hybrid: stable relational columns, JSONB for variable metadata.

### Common mistakes

- **Using `json` instead of `jsonb`.** Always use JSONB.
- **Full GIN index when `jsonb_path_ops` suffices.** Bigger, slower writes.
- **`->` when you need `->>`.** Type mismatch in comparisons.
- **Indexing JSONB fields that are never queried.** Cost without benefit.
- **Putting structured data in JSONB for "flexibility".** You give up type safety, foreign keys, and planner effectiveness.
- **Nesting deeply for no reason.** Flat JSONB is easier to query than deeply nested JSONB.
- **Treating `jsonb_set` as cheap.** It creates a new tuple and updates indexes; frequent small modifications are expensive.
- **Not using expression indexes for hot fields.** Querying `data->>'user_id'` without an index is always a full scan.

### Closing

"So JSONB is PostgreSQL's indexable binary JSON type, queryable with rich operators, indexable with GIN, and the right tool for schemaless or variable data within a relational schema. The hybrid pattern — columns for structured data, JSONB for variable metadata — is how most real systems use it. Index with `jsonb_path_ops` for containment queries and expression indexes for specific fields. The senior skill is knowing when to promote JSONB fields to real columns — once you're querying them frequently, the cost of extraction outweighs the flexibility of the schemaless model. Used well, JSONB collapses the need for a separate document database; used badly, it turns a relational schema into an untyped blob store."
