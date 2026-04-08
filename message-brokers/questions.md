# Message brokers questions

Notes and interview answers covering message brokers, async processing, and message-driven patterns. Focused primarily on RabbitMQ (the broker most commonly used in PHP/Symfony stacks), with comparisons to Kafka and conceptual coverage of delivery semantics, idempotency, and the outbox pattern.

## RabbitMQ

- [Core model: producers, exchanges, bindings, queues, consumers](rabbitmq_core_model.md)
- [Exchange types: direct, topic, fanout, headers](rabbitmq_exchange_types.md)
- [Reliability: acknowledgements, prefetch, durability, persistent messages](rabbitmq_reliability.md)
- [Dead-letter exchanges (DLX)](rabbitmq_dead_letter_exchanges.md)
- [RabbitMQ in PHP: php-amqplib, ext-amqp, Supervisor, Symfony Messenger](rabbitmq_in_php.md)
- [RabbitMQ vs Kafka — when to pick which](rabbitmq_vs_kafka.md)

## Delivery semantics and patterns

- [At-least-once vs at-most-once vs exactly-once](at_least_once_vs_at_most_once_vs_exactly_once.md)
- [Idempotent consumers](idempotent_consumers.md)
- [The outbox pattern](outbox_pattern.md)
- [Queue topologies: work queue, pub/sub, RPC, priority](queue_topologies.md)
