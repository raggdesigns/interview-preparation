Entity relationships describe how tables in a relational database are connected to each other. The connection is made through foreign keys — a column in one table that references the primary key of another table.

### One-to-One (1:1)

One row in table A belongs to exactly one row in table B, and vice versa. This is the rarest type of relationship.

```sql
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL
);

CREATE TABLE user_profiles (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL UNIQUE,           -- UNIQUE ensures 1:1
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    bio TEXT,
    avatar_url VARCHAR(255),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

The `UNIQUE` constraint on `user_id` guarantees that each user can have only one profile. Without `UNIQUE`, it would become a one-to-many relationship.

**When to use 1:1:**

- Separate rarely accessed data from frequently accessed data (performance)
- Store optional information in a separate table to keep the main table clean
- Security — sensitive data (e.g., billing) in a separate table with different access rules

### One-to-Many (1:N)

One row in table A can have many related rows in table B. This is the most common relationship type.

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

One user can have many orders, but each order belongs to exactly one user. The foreign key `user_id` is in the "many" side (orders table).

**Rule:** The foreign key always goes in the table on the "many" side of the relationship.

### Many-to-Many (M:N)

Many rows in table A are connected to many rows in table B. Relational databases cannot represent this directly — you need a **pivot table** (also called a junction table or join table).

```sql
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE roles (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL UNIQUE    -- 'admin', 'editor', 'viewer'
);

-- Pivot table
CREATE TABLE user_roles (
    user_id INT NOT NULL,
    role_id INT NOT NULL,
    assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id),     -- Composite primary key prevents duplicates
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
);
```

One user can have many roles (admin + editor). One role can belong to many users (many people are "editor"). The pivot table `user_roles` connects them.

**Querying M:N relationships:**

```sql
-- Get all roles for user 5
SELECT r.name
FROM roles r
JOIN user_roles ur ON ur.role_id = r.id
WHERE ur.user_id = 5;

-- Get all users who have the 'admin' role
SELECT u.email
FROM users u
JOIN user_roles ur ON ur.user_id = u.id
JOIN roles r ON r.id = ur.role_id
WHERE r.name = 'admin';
```

### Pivot Tables with Extra Data

Sometimes the pivot table stores additional information about the relationship:

```sql
CREATE TABLE products (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL
);

-- Pivot table with extra columns
CREATE TABLE order_items (
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    price_at_purchase DECIMAL(10, 2) NOT NULL,  -- Price snapshot at order time
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id)
);
```

The `price_at_purchase` column stores the price at the time of order, because the product price might change later.

### Doctrine ORM Mapping

In Symfony with Doctrine, relationships are defined with PHP attributes:

```php
// One-to-Many: User has many Orders
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

// Many-to-Many: User has many Roles
#[Entity]
class User
{
    #[ManyToMany(targetEntity: Role::class)]
    #[JoinTable(name: 'user_roles')]
    private Collection $roles;
}
```

Key Doctrine terms:

- **owning side** — the side that has the `JoinColumn` or `JoinTable` (this side writes to the database)
- **inverse side** — uses `mappedBy` (read-only, does not trigger SQL)
- Always add/remove entities on the **owning side** for changes to be persisted

### ON DELETE Behavior

Foreign keys define what happens when the parent row is deleted:

| Option | Behavior |
|--------|----------|
| `CASCADE` | Delete child rows automatically |
| `SET NULL` | Set the foreign key column to NULL |
| `RESTRICT` | Prevent deletion if child rows exist (default in MySQL) |
| `NO ACTION` | Same as RESTRICT in MySQL |

```sql
-- If a user is deleted, all their orders are deleted too
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE

-- If a category is deleted, products keep existing but category_id becomes NULL
FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
```

### How to Choose the Right Relationship

| Question | Answer → Relationship type |
|----------|---------------------------|
| Can A exist without B? | Yes → separate tables with FK |
| How many B per A? | Exactly one → 1:1 |
| How many B per A? | Many → 1:N |
| Can both sides have many? | Yes → M:N with pivot table |
| Does the relationship carry extra data? | Yes → pivot table with extra columns |

### Real Scenario

You are building an e-commerce platform. The data model looks like this:

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

- A user has one profile (1:1) and many orders (1:N)
- An order has many order items (1:N), each linking to a product
- A product belongs to many categories, and a category has many products (M:N via `product_categories` pivot table)
- A user has many roles and a role belongs to many users (M:N via `user_roles` pivot table)

### Conclusion

Entity relationships in relational databases are 1:1 (one-to-one), 1:N (one-to-many), and M:N (many-to-many). The foreign key always goes on the "many" side. M:N relationships need a pivot table because relational databases cannot represent them directly. Pivot tables can carry extra data like quantity or timestamps. In Doctrine ORM, always modify the owning side of a relationship for changes to persist. Use `ON DELETE CASCADE` or `SET NULL` to control what happens when parent rows are deleted.

> See also: [ACID Transactions](acid_transactions.md), [Deadlocks in MySQL](../highload/deadlocks_in_mysql.md)
