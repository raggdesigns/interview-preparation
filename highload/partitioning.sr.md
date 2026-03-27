Particionisanje je podela velike tabele baze podataka na manje delove zvane **particije**. Svaka particija čuva podskup podataka, ali aplikacija ih i dalje vidi kao jednu tabelu. Particionisanje se odvija unutar jednog servera baze podataka, za razliku od sharding-a koji deli podatke po više servera.

### Zašto particionisati tabelu?

Kada tabela ima milione ili milijarde redova:

- Upiti postaju spori jer su indeksi ogromni
- INSERT operacije se usporavaju jer indeksi moraju biti ažurirani
- Operacije održavanja (backup, ALTER TABLE) traju veoma dugo

Particionisanje rešava ove probleme tako što svaku particiju čini manjom i lakšom za upravljanje.

### Tipovi particionisanja

#### 1. RANGE particionisanje

Podaci se dele po opsezima vrednosti. Veoma uobičajeno za podatke zasnovane na datumu.

```sql
CREATE TABLE orders (
    id BIGINT AUTO_INCREMENT,
    customer_id INT,
    total DECIMAL(10,2),
    created_at DATE,
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (YEAR(created_at)) (
    PARTITION p2022 VALUES LESS THAN (2023),
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);
```

#### 2. LIST particionisanje

Podaci se dele po listi specifičnih vrednosti.

```sql
CREATE TABLE users (
    id INT,
    name VARCHAR(100),
    country VARCHAR(2),
    PRIMARY KEY (id, country)
) PARTITION BY LIST COLUMNS (country) (
    PARTITION p_europe VALUES IN ('DE', 'FR', 'GB', 'IT', 'ES'),
    PARTITION p_americas VALUES IN ('US', 'CA', 'BR', 'MX'),
    PARTITION p_asia VALUES IN ('CN', 'JP', 'KR', 'IN')
);
```

#### 3. HASH particionisanje

Podaci se ravnomerno distribuiraju koristeći hash funkciju. Korisno kada ne postoji prirodni opseg ili lista.

```sql
CREATE TABLE sessions (
    id BIGINT AUTO_INCREMENT,
    user_id INT,
    data TEXT,
    PRIMARY KEY (id, user_id)
) PARTITION BY HASH (user_id) PARTITIONS 8;
```

MySQL izračunava `user_id % 8` da odredi u kojoj particiji se čuva svaki red.

#### 4. KEY particionisanje

Slično HASH-u ali koristi MySQL-ovu internu hash funkciju. Radi sa bilo kojim tipom kolone, ne samo integerima.

```sql
CREATE TABLE logs (
    id BIGINT AUTO_INCREMENT,
    session_id VARCHAR(64),
    message TEXT,
    PRIMARY KEY (id, session_id)
) PARTITION BY KEY (session_id) PARTITIONS 16;
```

### Prednosti za operacije čitanja

#### Orezivanje particija (Partition Pruning)

Najveća prednost. Kada upit uključuje ključ particije u WHERE klauzuli, MySQL skenira samo relevantne particije i preskače sve ostale.

```sql
-- Bez particionisanja: skenira celu tabelu (100 miliona redova)
SELECT * FROM orders WHERE created_at BETWEEN '2024-01-01' AND '2024-12-31';

-- Sa RANGE particionisanjem po godini: skenira samo particiju p2024 (~20 miliona redova)
-- MySQL "orezuje" particije p2022, p2023, p2025, p_future
```

Možeš proveriti sa `EXPLAIN`:

```sql
EXPLAIN SELECT * FROM orders WHERE created_at = '2024-06-15';
-- Prikazuje: partitions: p2024  (skenirana samo jedna particija)
```

#### Manji indeksi

Svaka particija ima sopstveni indeks. Umesto jednog ogromnog B-tree indeksa koji pokriva 100 miliona redova, imaš više manjih indeksa. Manji indeksi:

- Bolje se uklapaju u memoriju (buffer pool)
- Imaju manje nivoa → manje čitanja sa diska
- Brže se pretražuju

#### Paralelno čitanje (sa nekim engine-ima)

Neke konfiguracije skladištenja dozvoljavaju čitanje iz više particija paralelno, poboljšavajući performanse upita koji obuhvataju nekoliko particija.

### Prednosti za operacije pisanja

#### Brža umetanja

Kada se umeće u particionisanu tabelu, MySQL mora samo da ažurira indeks ciljne particije, a ne jedan ogromni globalni indeks:

```text
Neparticionisana tabela:
  INSERT → ažuriraj jedan ogromni indeks (100M unosa) → sporo

Particionisana tabela:
  INSERT → ažuriraj mali indeks particije (20M unosa) → brže
```

#### Smanjenje zaključavanja

Operacije pisanja na jednoj particiji ne blokiraju čitanje/pisanje na drugim particijama (sa InnoDB zaključavanjem na nivou reda + operacijama na nivou particija). Ovo poboljšava performanse istovremenog pisanja.

#### Lakše upravljanje podacima

Stari podaci mogu biti trenutno uklonjeni brisanjem particije umesto brisanja redova jedan po jedan:

```sql
-- Bez particionisanja: sporo DELETE, uzrokuje fragmentaciju tabele
DELETE FROM orders WHERE created_at < '2022-01-01';
-- Ovo može trajati satima na velikoj tabeli

-- Sa particionisanjem: trenutno
ALTER TABLE orders DROP PARTITION p2021;
-- Ovo je skoro trenutno bez obzira na broj redova u particiji
```

Dodavanje prostora za nove podatke je takođe brzo:

```sql
ALTER TABLE orders ADD PARTITION (
    PARTITION p2026 VALUES LESS THAN (2027)
);
```

### Particionisanje vs Sharding

| Osobina | Particionisanje | Sharding |
|---------|-------------|----------|
| Lokacija | Isti server, ista baza | Različiti serveri |
| Složenost | Nisko — MySQL to obrađuje | Visoko — aplikacija mora rutirati upite |
| Skalabilnost | Ograničena jednim serverom | Horizontalno skaliranje |
| Transakcije | Puna ACID podrška | Složeno — cross-shard transakcije su teške |
| Slučaj upotrebe | Optimizuj velike tabele na jednom serveru | Skaliranje izvan kapaciteta jednog servera |

Particionisanje je često prvi korak. Kada jedan server više ne može da podnese opterećenje, dodaje se sharding.

> Vidi takođe: [Sharding](sharding.sr.md) za horizontalno skaliranje po više servera.

### Ograničenja

- Ključ particije mora biti deo svakog jedinstvenog indeksa (uključujući primarni ključ)
- Strani ključevi nisu podržani na particionisanim tabelama u MySQL-u
- Maksimum 8192 particija po tabeli
- Neki upiti koji ne uključuju ključ particije u WHERE će skenirati sve particije (bez orezivanja)

### Realni scenario

Imaš analitičku tabelu sa 500 miliona redova podataka o događajima. Upiti su spori i umetanje novih događaja traje predugo:

```sql
-- Pre: jedna ogromna tabela
CREATE TABLE events (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    event_type VARCHAR(50),
    user_id INT,
    payload JSON,
    created_at DATETIME,
    INDEX idx_created (created_at),
    INDEX idx_user (user_id)
);
-- Veličina tabele: 500M redova, veličina indeksa: 40 GB
-- Upit: SELECT * FROM events WHERE created_at > '2024-10-01' → 45 sekundi
```

```sql
-- Posle: particionisano po mesecu
CREATE TABLE events (
    id BIGINT AUTO_INCREMENT,
    event_type VARCHAR(50),
    user_id INT,
    payload JSON,
    created_at DATETIME,
    PRIMARY KEY (id, created_at),
    INDEX idx_user (user_id, created_at)
) PARTITION BY RANGE (TO_DAYS(created_at)) (
    PARTITION p202401 VALUES LESS THAN (TO_DAYS('2024-02-01')),
    PARTITION p202402 VALUES LESS THAN (TO_DAYS('2024-03-01')),
    -- ... jedna particija po mesecu
    PARTITION p202412 VALUES LESS THAN (TO_DAYS('2025-01-01')),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);
-- Svaka particija: ~40M redova, indeks po particiji: ~3 GB
-- Isti upit: SELECT * FROM events WHERE created_at > '2024-10-01' → 3 sekunde
-- Čišćenje: ALTER TABLE events DROP PARTITION p202301; → trenutno
```

Isti upit je 15 puta brži jer MySQL skenira samo 3 meseca podataka umesto cele tabele.

### Zaključak

Particionisanje deli veliku tabelu na manje delove unutar iste baze podataka. Poboljšava performanse čitanja kroz orezivanje particija (skeniranje samo relevantnih particija) i manje indekse. Poboljšava performanse pisanja kroz manje indekse za ažuriranje i smanjenu borbu za zaključavanje. Čini održavanje lakšim — brisanje starih particija je trenutno. Koristi RANGE za vremenske serije podataka, LIST za kategoričke podatke i HASH/KEY za ravnomernu distribuciju. Particionisanje je jednostavnija alternativa sharding-u kada jedan server je dovoljan.
