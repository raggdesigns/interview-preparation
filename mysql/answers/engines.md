### MySQL Engines

MySQL supports multiple storage engines, each designed for specific use cases and providing distinct performance characteristics.

#### MySQL Engines Overview

- **InnoDB**: The default transaction-safe engine with support for foreign keys. Optimized for performance and reliability.
- **MyISAM**: The older storage engine, optimized for read-heavy workloads but does not support transactions.
- **Memory**: Stores data in RAM, offering very fast access times at the expense of volatility.
- **Archive**: Optimized for storing large amounts of archival or historical data.
- **Others**: Blackhole, CSV, Merge, and more, each with specialized uses.

### MyISAM vs InnoDB

- **Transactions**: InnoDB supports transactions (COMMIT and ROLLBACK), while MyISAM does not.
- **Table-locking vs Row-locking**: MyISAM locks the entire table which can be a bottleneck. InnoDB supports row-level locking which is more efficient for write-heavy databases.
- **Foreign Keys**: InnoDB supports foreign keys and referential integrity, whereas MyISAM does not.
- **Crash Recovery**: InnoDB provides better crash recovery compared to MyISAM.
- **Concurrency**: InnoDB offers better concurrency as it allows multiple readers and writers to access the same data simultaneously.
