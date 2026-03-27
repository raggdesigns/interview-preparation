Relacije entiteta opisuju kako su tabele u relacionoj bazi podataka međusobno povezane. Veza se ostvaruje kroz strane ključeve — kolonu u jednoj tabeli koja referencira primarni ključ druge tabele.

### Jedan-prema-jedan (1:1)

Jedan red u tabeli A pripada tačno jednom redu u tabeli B i obrnuto. Ovo je najređi tip relacije.

```sql
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL
);

CREATE TABLE user_profiles (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL UNIQUE,           -- UNIQUE osigurava 1:1
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    bio TEXT,
    avatar_url VARCHAR(255),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

`UNIQUE` ograničenje na `user_id` garantuje da svaki korisnik može imati samo jedan profil. Bez `UNIQUE`, postalo bi relacija jedan-prema-mnogo.

**Kada koristiti 1:1:**

- Odvoji retko pristupane podatke od često pristupanih podataka (performanse)
- Čuvaj opcionalne informacije u posebnoj tabeli da bi glavna tabela bila čista
- Bezbednost — osetljivi podaci (npr. naplata) u posebnoj tabeli sa različitim pravilima pristupa

### Jedan-prema-mnogo (1:N)

Jedan red u tabeli A može imati mnogo povezanih redova u tabeli B. Ovo je najčešći tip relacije.

```sql
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE orders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    total DECIMAL(10, 2) NOT NULL,
    status ENUM('pending', 'paid', 'shipped', 'cancelled') DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);
```

Jedan korisnik može imati mnogo narudžbina, ali svaka narudžbina pripada tačno jednom korisniku. Strani ključ `user_id` je na "mnogo" strani (tabela narudžbina).

**Pravilo:** Strani ključ uvek ide u tabelu na "mnogo" strani relacije.

### Mnogo-prema-mnogo (M:N)

Mnogo redova u tabeli A je povezano sa mnogo redova u tabeli B. Relacione baze podataka ne mogu direktno predstaviti ovo — potrebna ti je **pivot tabela** (poznata i kao junction tabela ili join tabela).

```sql
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE roles (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL UNIQUE    -- 'admin', 'editor', 'viewer'
);

-- Pivot tabela
CREATE TABLE user_roles (
    user_id INT NOT NULL,
    role_id INT NOT NULL,
    assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id),     -- Kompozitni primarni ključ sprečava duplikate
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
);
```

Jedan korisnik može imati mnogo uloga (admin + editor). Jedna uloga može pripadati mnogim korisnicima (mnogo ljudi su "editor"). Pivot tabela `user_roles` ih povezuje.

**Upit M:N relacija:**

```sql
-- Dobij sve uloge korisnika 5
SELECT r.name
FROM roles r
JOIN user_roles ur ON ur.role_id = r.id
WHERE ur.user_id = 5;

-- Dobij sve korisnike koji imaju 'admin' ulogu
SELECT u.email
FROM users u
JOIN user_roles ur ON ur.user_id = u.id
JOIN roles r ON r.id = ur.role_id
WHERE r.name = 'admin';
```

### Pivot tabele sa dodatnim podacima

Ponekad pivot tabela čuva dodatne informacije o relaciji:

```sql
CREATE TABLE products (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL
);

-- Pivot tabela sa dodatnim kolonama
CREATE TABLE order_items (
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    price_at_purchase DECIMAL(10, 2) NOT NULL,  -- Snimak cene u trenutku narudžbine
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id)
);
```

Kolona `price_at_purchase` čuva cenu u trenutku narudžbine, jer se cena proizvoda može promeniti kasnije.

### Doctrine ORM mapiranje

U Symfony-ju sa Doctrine-om, relacije se definišu PHP atributima:

```php
// Jedan-prema-mnogo: Korisnik ima mnogo narudžbina
#[Entity]
class User
{
    #[Id, GeneratedValue, Column]
    private int $id;

    #[OneToMany(targetEntity: Order::class, mappedBy: 'user', cascade: ['persist'])]
    private Collection $orders;
}

#[Entity]
class Order
{
    #[Id, GeneratedValue, Column]
    private int $id;

    #[ManyToOne(targetEntity: User::class, inversedBy: 'orders')]
    #[JoinColumn(nullable: false)]
    private User $user;
}

// Mnogo-prema-mnogo: Korisnik ima mnogo uloga
#[Entity]
class User
{
    #[ManyToMany(targetEntity: Role::class)]
    #[JoinTable(name: 'user_roles')]
    private Collection $roles;
}
```

Ključni Doctrine termini:

- **vlasnik strane** (owning side) — strana koja ima `JoinColumn` ili `JoinTable` (ova strana piše u bazu podataka)
- **inverzna strana** (inverse side) — koristi `mappedBy` (samo za čitanje, ne pokre SQL)
- Uvek dodaj/uklanjaj entitete na **vlasničkoj strani** da bi promene bile persistirane

### Ponašanje ON DELETE

Strani ključevi definišu šta se dešava kada se parent red obriše:

| Opcija | Ponašanje |
|--------|----------|
| `CASCADE` | Automatski briše child redove |
| `SET NULL` | Postavlja kolonu stranog ključa na NULL |
| `RESTRICT` | Sprečava brisanje ako child redovi postoje (podrazumevano u MySQL-u) |
| `NO ACTION` | Isto kao RESTRICT u MySQL-u |

```sql
-- Ako je korisnik obrisan, sve njegove narudžbine su obrisane
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE

-- Ako je kategorija obrisana, proizvodi ostaju ali category_id postaje NULL
FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
```

### Kako odabrati pravu relaciju

| Pitanje | Odgovor → Tip relacije |
|----------|---------------------------|
| Može li A postojati bez B? | Da → odvojene tabele sa FK |
| Koliko B po A? | Tačno jedan → 1:1 |
| Koliko B po A? | Mnogo → 1:N |
| Mogu li obe strane imati mnogo? | Da → M:N sa pivot tabelom |
| Nosi li relacija dodatne podatke? | Da → pivot tabela sa dodatnim kolonama |

### Realni scenario

Gradiš e-commerce platformu. Model podataka izgleda ovako:

```text
users (1) ──── (N) orders
                      │
orders (1) ──── (N) order_items (N) ──── (1) products
                                                 │
                      products (N) ──── (N) categories
                                    (pivot: product_categories)

users (1) ──── (1) user_profiles
users (N) ──── (N) roles  (pivot: user_roles)
```

- Korisnik ima jedan profil (1:1) i mnogo narudžbina (1:N)
- Narudžbina ima mnogo stavki narudžbine (1:N), svaka vezana za proizvod
- Proizvod pripada mnogim kategorijama, a kategorija ima mnogo proizvoda (M:N putem pivot tabele `product_categories`)
- Korisnik ima mnogo uloga i uloga pripada mnogim korisnicima (M:N putem pivot tabele `user_roles`)

### Zaključak

Relacije entiteta u relacionim bazama podataka su 1:1 (jedan-prema-jedan), 1:N (jedan-prema-mnogo) i M:N (mnogo-prema-mnogo). Strani ključ uvek ide na "mnogo" strani. M:N relacije zahtevaju pivot tabelu jer ih relacione baze podataka ne mogu direktno predstaviti. Pivot tabele mogu nositi dodatne podatke kao što su količina ili vremenske oznake. U Doctrine ORM-u, uvek modifikuj vlasničku stranu relacije da bi promene bile persistirane. Koristi `ON DELETE CASCADE` ili `SET NULL` da kontrolišeš šta se dešava kada se parent redovi obrišu.

> Vidi takođe: [ACID transakcije](acid_transactions.sr.md), [Deadlocks u MySQL-u](../highload/deadlocks_in_mysql.sr.md)
