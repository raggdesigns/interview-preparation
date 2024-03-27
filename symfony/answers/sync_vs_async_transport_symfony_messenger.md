
# Sync vs Async Transport in Symfony Messenger

Symfony Messenger component provides powerful messaging capabilities for your applications, allowing for the decoupling of components by passing messages between them. One of the key decisions in using Messenger is choosing between synchronous (sync) and asynchronous (async) transports for handling messages.

## Synchronous (Sync) Transport

In synchronous transport, messages are handled immediately as they are dispatched. This means the message sender waits for the message handler to process the message before proceeding. Sync transport is akin to a direct method call but wrapped in the Messenger's message handling logic.

### Use Cases for Sync Transport

- **Direct Feedback Required**: When immediate processing and feedback to the user or system is required.
- **Simple Workflows**: In applications where workflows are straightforward and don't need background processing.

## Asynchronous (Async) Transport

Asynchronous transport defers the handling of messages. When a message is dispatched, it's sent to a queue, and the sender proceeds without waiting for the message to be handled. A separate process reads messages from the queue and processes them, potentially at a much later time.

### Use Cases for Async Transport

- **Background Processing**: Ideal for tasks that are time-consuming, such as sending emails, generating reports, or handling file uploads.
- **Scalability**: Helps applications scale by offloading heavy processing to background workers, improving request throughput.
- **Reliability**: Increases application reliability by allowing retries and delayed processing in case of temporary failures.

## Configuring Sync and Async Transports

### Installation

Ensure you have the Messenger component installed:

```bash
composer require symfony/messenger
```

### Configuration

In `config/packages/messenger.yaml`, you can configure transports and define which transport a message should use.

```yaml
framework:
    messenger:
        transports:
            async: '%env(MESSENGER_TRANSPORT_DSN)%'
            sync: 'sync://'

        routing:
            'App\Message\YourAsyncMessage': async
            'App\Message\YourSyncMessage': sync
```

In this configuration:

- **Async Transport**: Messages of type `YourAsyncMessage` are routed to an asynchronous transport (e.g., RabbitMQ, Redis).
- **Sync Transport**: Messages of type `YourSyncMessage` are handled synchronously using the `sync://` transport.

## Conclusion

Choosing between sync and async transport in Symfony Messenger depends on the specific needs of your application, such as the need for immediate processing, background task execution, scalability, and reliability. Properly configuring and utilizing these transports can significantly enhance your application's performance and user experience.
