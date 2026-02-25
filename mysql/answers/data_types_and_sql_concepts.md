### Data Types and SQL Concepts

#### Char vs Varchar

- **CHAR**: Fixed length. Space is reserved to accommodate the specified number of characters. If the entered string is smaller than the specified length, it is padded with spaces.
- **VARCHAR**: Variable length. Only uses as much space as needed plus overhead for length storage.

#### What is Selectivity

Selectivity refers to the percentage of rows in a table that are returned by a particular value in an index. High selectivity means fewer rows are returned, making the index more effective.

#### ANALYZE vs EXPLAIN Commands

- **ANALYZE**: Analyzes and stores the key distribution for a table, which helps MySQL optimize queries more effectively.
- **EXPLAIN**: Provides information about how MySQL executes a query, helping developers optimize query performance by showing the query plan.

#### WHERE vs HAVING

- **WHERE**: Filters records before any groupings are made.
- **HAVING**: Filters groups created by GROUP BY based on a condition.

#### Events on Which a Trigger Can Be Added

Triggers can be created to execute in response to various events:

- **INSERT**: Triggered after or before an INSERT operation.
- **UPDATE**: Triggered after or before an UPDATE operation.
- **DELETE**: Triggered after or before a DELETE operation.

#### Foreign Keys - Why They Are Used

Foreign keys are used to enforce referential integrity between tables, ensuring that relationships between columns are maintained consistently.

#### Locks (Pessimistic, Optimistic, Advisory)

- **Pessimistic Locking**: Involves locking resources as they are accessed, preventing other transactions from accessing the same resource until the lock is released.
- **Optimistic Locking**: Assumes that multiple transactions can complete without affecting each other, and checks at commit time if another transaction has made changes.
- **Advisory Locks**: These are locks that the database doesn't enforce automatically. Applications must explicitly acquire and release these locks.
