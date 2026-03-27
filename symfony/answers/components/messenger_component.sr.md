
# Symfony Messenger Component

Symfony Messenger Component pruža moćan sistem za rukovanje porukama unutar aplikacije. Deluje kao sistem za slanje i primanje poruka između različitih delova vaše aplikacije, ili čak između različitih aplikacija. Ova komponenta pomaže u organizovanju asinhrone obrade, stavljanja u red čekanja i izvršavanja zadataka koji ne moraju biti urađeni odmah kao deo trenutnog HTTP ciklusa zahtev/odgovor.

## Ključni koncepti

- **Poruka (Message)**: PHP objekat koji enkapsulira informacije i može biti poslat putem Messenger komponente.
- **Magistrala poruka (Message Bus)**: Servis koji usmerava poruke ka odgovarajućim handler-ima.
- **Handler**: PHP klasa koja sadrži logiku za obradu poruke.
- **Transport**: Metoda transporta poruka (npr. sinhrono unutar istog PHP procesa, ili asinhrono korišćenjem reda čekanja kao što su RabbitMQ ili Amazon SQS).

## Prednosti

- **Odvajanje zavisnosti**: Omogućava odvajanje različitih delova aplikacije komunikacijom putem poruka.
- **Fleksibilnost**: Lako konfigurisanje sinhrone ili asinhrone obrade.
- **Višekratna upotreba**: Promoviše višekratnu upotrebu i razdvajanje zaduženja unutar aplikacije.
- **Interoperabilnost**: Podržava komunikaciju između različitih delova aplikacije ili čak između različitih aplikacija.

## Primer upotrebe

Zamislimo da želite da pošaljete e-mail u svojoj aplikaciji. Umesto da ga šaljete direktno u kontroleru i blokirate korisnika dok se e-mail šalje, možete to prepustiti Messenger komponenti da ga obradi asinhrono.

### Korak 1: Instalacija Messenger komponente

Prvo, uverite se da je Messenger komponenta instalirana:

```bash
composer require symfony/messenger
```

### Korak 2: Konfigurisanje Messenger komponente

U `config/packages/messenger.yaml`, definišite vaš transport i magistralu:

```yaml
framework:
    messenger:
        transports:
            async: '%env(MESSENGER_TRANSPORT_DSN)%'
        routing:
            'App\Message\SendEmailMessage': async
```

### Korak 3: Kreiranje klase poruke

```php
namespace App\Message;

class SendEmailMessage
{
    private $recipient;
    private $content;

    public function __construct(string $recipient, string $content)
    {
        $this->recipient = $recipient;
        $this->content = $content;
    }

    public function getRecipient(): string
    {
        return $this->recipient;
    }

    public function getContent(): string
    {
        return $this->content;
    }
}
```

### Korak 4: Kreiranje handler-a poruke

```php
namespace App\MessageHandler;

use App\Message\SendEmailMessage;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Messenger\Handler\MessageHandlerInterface;

class SendEmailMessageHandler implements MessageHandlerInterface
{
    private $mailer;

    public function __construct(MailerInterface $mailer)
    {
        $this->mailer = $mailer;
    }

    public function __invoke(SendEmailMessage $message)
    {
        // Logic to send the email
    }
}
```

### Korak 5: Dispečovanje poruke

Iz kontrolera ili bilo kog drugog dela vaše aplikacije, dispečujte poruku:

```php
use App\Message\SendEmailMessage;
use Symfony\Component\Messenger\MessageBusInterface;

class SomeController
{
    public function someAction(MessageBusInterface $bus)
    {
        $message = new SendEmailMessage('user@example.com', 'Hello World!');
        $bus->dispatch($message);
    }
}
```

`SendEmailMessage` se kreira i dispečuje putem magistrale poruka. Zatim se asinhrono obrađuje od strane `SendEmailMessageHandler`, omogućavajući korisniku da nastavi da interaguje sa aplikacijom bez čekanja da se e-mail pošalje.

## Zaključak

Messenger komponenta pruža moćan i fleksibilan način za asinhrono rukovanje zadacima, poboljšavajući korisničko iskustvo i skalabilnost aplikacije. Odvajanjem komponenti i centralizacijom rukovanja zadacima, Symfony-jeva Messenger komponenta olakšava izgradnju i održavanje velikih aplikacija.
