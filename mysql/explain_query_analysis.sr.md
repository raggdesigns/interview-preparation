Kada pronađeš spori SQL upit (kroz logove ili slow query log), sledeći korak je razumeti **zašto** je spor. Komanda `EXPLAIN` ti pokazuje plan izvršavanja upita — kako baza podataka planira da pronađe i vrati tvoje podatke.

### Osnovna upotreba

Stavi `EXPLAIN` pre bilo kog SELECT upita:

```sql
EXPLAIN SELECT * FROM users WHERE status = 'active' AND city = 'Belgrade';
```

Rezultat je tabela sa kolonama koje objašnjavaju kako će MySQL izvršiti upit. Najvažnije kolone su `type`, `key`, `rows` i `Extra`.

### Najvažnije kolone

#### type — Kako MySQL pristupa tabeli

Ova kolona prikazuje metod pristupa. Od najgoreg do najboljeg:

| type | Značenje | Performanse |
|------|---------|------------|
| `ALL` | Puno skeniranje tabele — čita svaki red | Veoma loše |
| `index` | Puno skeniranje indeksa — čita svaki unos u indeksu | Loše |
| `range` | Čita opseg unosa indeksa (npr. BETWEEN, >, <) | OK |
| `ref` | Pronalazi redove koristeći nejedinstveni indeks | Dobro |
| `eq_ref` | Pronalazi tačno jedan red koristeći jedinstven/primarni ključ (JOIN-ovi) | Veoma dobro |
| `const` | Pronalazi tačno jedan red koristeći primarni ključ ili jedinstven indeks | Najbolje |

**Crvena zastavica:** Ako je `type` `ALL`, upit skenira svaki red u tabeli. Ovo je skoro uvek znak da nedostaje indeks.

```sql
-- type = ALL (loše) — nema indeksa na 'status'
EXPLAIN SELECT * FROM users WHERE status = 'active';

-- Nakon dodavanja indeksa:
CREATE INDEX idx_status ON users(status);

-- type = ref (dobro) — sada koristi indeks
EXPLAIN SELECT * FROM users WHERE status = 'active';
```

#### key — Koji indeks se koristi

Prikazuje naziv indeksa koji je MySQL odabrao. Ako piše `NULL`, nijedan indeks se ne koristi.

```sql
EXPLAIN SELECT * FROM orders WHERE user_id = 5;
-- key: idx_user_id  ← koristi indeks
-- key: NULL         ← NE koristi nijedan indeks (loše!)
```

#### possible_keys — Koji indeksi su razmatrani

Navodi sve indekse koje MySQL potencijalno može koristiti. Ako je ovo `NULL` ali je i `key` `NULL`, definitivno treba kreirati indeks.

#### rows — Procenjeni redovi za ispitivanje

Prikazuje koliko redova MySQL procenjuje da treba pročitati. Manje je bolje.

```sql
-- Pre indeksa: rows = 5,000,000 (skenira celu tabelu)
-- Posle indeksa:  rows = 230 (samo odgovarajući redovi)
```

#### Extra — Dodatne informacije

| Vrednost | Značenje |
|-------|---------|
| `Using index` | Upit je odgovorjen u potpunosti iz indeksa (pokrivajući indeks) — veoma brzo |
| `Using where` | MySQL primenjuje WHERE filter posle čitanja redova |
| `Using temporary` | MySQL kreira privremenu tabelu (često za GROUP BY) — sporo |
| `Using filesort` | MySQL sortira rezultate bez indeksa — sporo sa velikim skupovima podataka |
| `Using index condition` | Index Condition Pushdown — filter primenjen na nivou indeksa |

### Čitanje kompletnog EXPLAIN izlaza

```sql
EXPLAIN SELECT u.name, COUNT(o.id) as order_count
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE u.status = 'active'
GROUP BY u.id;
```

Izlaz:

```
+----+------+-------+------+---------------+---------+------+------+-------------+
| id | type | table | key  | possible_keys | rows    | Extra               |
+----+------+-------+------+---------------+---------+---------------------+
|  1 | ref  | u     | idx_status | idx_status | 2300   | Using where         |
|  1 | ref  | o     | idx_user   | idx_user   |    12  | Using index         |
+----+------+-------+------+---------------+---------+---------------------+
```

Čitanje ovoga:
1. MySQL najpre pronalazi aktivne korisnike koristeći `idx_status` indeks (2300 redova)
2. Za svakog korisnika, pronalazi narudžbine koristeći `idx_user` indeks (oko 12 redova po korisniku)
3. Ukupno procenjeni posao: 2300 × 12 = ~27,600 pretraga redova (umesto miliona sa punim skeniranjima)

### EXPLAIN ANALYZE (MySQL 8.0+)

`EXPLAIN ANALYZE` zapravo pokreće upit i prikazuje stvarna vremena izvršavanja:

```sql
EXPLAIN ANALYZE SELECT * FROM users WHERE status = 'active' AND city = 'Belgrade';
```

```
-> Filter: ((users.status = 'active') AND (users.city = 'Belgrade'))
    -> Table scan on users  (cost=512345 rows=5000000)
       (actual time=0.05..3456.00 rows=5000000 loops=1)
```

`actual time` prikazuje stvarne milisekunde. Ovo ti govori tačno gde se troši vreme.

### Uobičajeni problemi i rešenja

#### Problem 1: Puno skeniranje tabele (type = ALL)

```sql
EXPLAIN SELECT * FROM products WHERE category = 'electronics' AND price < 100;
-- type: ALL, key: NULL, rows: 2,000,000
```

**Popravka:** Kreiraj kompozitni indeks na kolonama korišćenim u WHERE:

```sql
CREATE INDEX idx_category_price ON products(category, price);
-- Sada: type: range, key: idx_category_price, rows: 340
```

#### Problem 2: Using filesort

```sql
EXPLAIN SELECT * FROM orders WHERE user_id = 5 ORDER BY created_at DESC;
-- Extra: Using filesort
```

**Popravka:** Uključi kolonu ORDER BY u indeks:

```sql
CREATE INDEX idx_user_created ON orders(user_id, created_at);
-- Sada: Extra: Using index (nema više filesort-a)
```

#### Problem 3: Using temporary (GROUP BY)

```sql
EXPLAIN SELECT city, COUNT(*) FROM users GROUP BY city;
-- Extra: Using temporary; Using filesort
```

**Popravka:** Kreiraj indeks na koloni GROUP BY:

```sql
CREATE INDEX idx_city ON users(city);
-- Sada: Extra: Using index
```

#### Problem 4: JOIN bez indeksa

```sql
EXPLAIN SELECT u.name, o.total
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE u.id = 5;
-- orders red: type: ALL, key: NULL (skenira sve narudžbine!)
```

**Popravka:** Dodaj indeks na strani ključ:

```sql
CREATE INDEX idx_user_id ON orders(user_id);
-- Sada: type: ref, key: idx_user_id
```

### Kontrolna lista za EXPLAIN analizu

1. **Proveri `type`** — ako piše `ALL`, treba ti indeks
2. **Proveri `key`** — ako piše `NULL`, nijedan indeks se ne koristi
3. **Proveri `rows`** — ako je broj blizu ukupne veličine tabele, nešto nije u redu
4. **Proveri `Extra`** — ako vidiš `Using temporary` ili `Using filesort`, dodaj indekse na GROUP BY / ORDER BY kolone
5. **Uporedi `possible_keys` vs `key`** — MySQL može odabrati suboptimalan indeks; možda treba nagoveštaj ili restrukturisanje

### Realni scenario

Spori GET endpoint traje 8 sekundi. Pronalazite ovaj upit u slow query log-u:

```sql
SELECT p.name, p.price, c.name as category_name
FROM products p
JOIN categories c ON c.id = p.category_id
WHERE p.status = 'active' AND p.price BETWEEN 50 AND 200
ORDER BY p.created_at DESC
LIMIT 20;
```

Korak 1 — Pokreni EXPLAIN:

```sql
EXPLAIN SELECT p.name, p.price, c.name as category_name
FROM products p
JOIN categories c ON c.id = p.category_id
WHERE p.status = 'active' AND p.price BETWEEN 50 AND 200
ORDER BY p.created_at DESC
LIMIT 20;
```

Korak 2 — Čitaj izlaz:
- `type: ALL` na tabeli products (loše — puno skeniranje tabele)
- `key: NULL` (nijedan indeks se ne koristi)
- `rows: 3,000,000`
- `Extra: Using where; Using filesort`

Korak 3 — Kreiraj indeks:

```sql
CREATE INDEX idx_status_price_created ON products(status, price, created_at);
```

Korak 4 — Ponovo pokreni EXPLAIN:
- `type: range` (dobro — koristi skeniranje opsega indeksa)
- `key: idx_status_price_created`
- `rows: 4,500`
- `Extra: Using index condition`

Vreme upita pada sa 8 sekundi na 50 milisekundi.

### Zaključak

`EXPLAIN` ti pokazuje kako MySQL planira da izvrši upit. Ključne stvari za provjeru: `type` nikada ne sme biti `ALL` (puno skeniranje tabele), `key` ne sme biti `NULL` (znači da se ne koristi nijedan indeks), `rows` treba biti što manji, a `Extra` ne sme imati `Using temporary` ili `Using filesort`. Kada vidiš ove probleme, kreiraj pravi indeks (obično na WHERE, JOIN, ORDER BY i GROUP BY kolonama). Koristi `EXPLAIN ANALYZE` u MySQL 8.0+ da vidiš stvarna vremena izvršavanja.

> Vidi takođe: [MySQL indeksi](./answers/indices.sr.md), [Optimizovanje sporog GET endpoint-a](../highload/optimizing_slow_get_endpoint.sr.md)
