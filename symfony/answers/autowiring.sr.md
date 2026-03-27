
# Autowiring u Symfony-ju

Autowiring u Symfony-ju je funkcionalnost koja vam omogućava automatsko upravljanje zavisnostima servisa tipskim naznačavanjem u konstruktoru servisa. Symfony-jev Dependency Injection Container (DIC) automatski će proslediti ispravne servise u vašu klasu bez potrebe za ručnim definisanjem servisa i njihovih argumenata u konfiguracionim fajlovima. Ovo značajno smanjuje količinu konfiguracije potrebne za podešavanje Symfony aplikacije, čineći razvoj bržim i lakšim.

## Primer 1: Osnovni Autowiring

Pretpostavimo da imate `MailerService` koji zavisi od `LoggerInterface` za logovanje poruka.

```php
namespace App\Service;

use Psr\Log\LoggerInterface;

class MailerService
{
    private $logger;

    public function __construct(LoggerInterface $logger)
    {
        $this->logger = $logger;
    }

    public function sendEmail($message)
    {
        // Logic to send email
        $this->logger->info("Email sent: " + $message);
    }
}
```

Sa autowiring, možete jednostavno tipski naznačiti `LoggerInterface` u konstruktoru `MailerService`, a Symfony će automatski injektovati instancu `LoggerInterface` definisanu u kontejneru servisa.

## Primer 2: Autowiring sa konfiguracijom

Da biste dodatno kontrolisali kako su vaši servisi povezani, možete koristiti Symfony-jeve konfiguracione fajlove servisa (npr. `services.yaml`). Ovde možete definisati servise i specificirati autowiring i autoconfiguration:

```yaml
services:
    _defaults:
        autowire: true
        autoconfigure: true

    App\Service\MailerService: ~
```

Sa ovim podešavanjima, `MailerService` će automatski dobiti potreban `LoggerInterface` injektovan, a takođe se automatski registruje kao servis u kontejneru zbog `_defaults` konfiguracije.

## Primer 3: Autowiring prilagođenih klasa

Ako imate prilagođene klase koje nisu interfejsi ili široko prepoznate klase, i dalje možete koristiti autowiring pravilnim tipskim naznačavanjem. Pretpostavimo da imate prilagođenu klasu `OrderProcessor`:

```php
namespace App\Service;

class OrderProcessor
{
    private $mailerService;

    public function __construct(MailerService $mailerService)
    {
        $this->mailerService = $mailerService;
    }

    public function processOrder($order)
    {
        // Logic to process the order
        $this->mailerService->sendEmail("Order processed: " + $order);
    }
}
```

Tipskim naznačavanjem `MailerService` u konstruktoru `OrderProcessor` i osiguravanjem da je `MailerService` pravilno definisan kao servis u `services.yaml`, Symfony-jeva funkcionalnost autowiringa automatski će injektovati `MailerService` u `OrderProcessor`.
