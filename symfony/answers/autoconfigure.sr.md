
# Autoconfigure u Symfony

Autoconfigure je funkcionalnost u Symfony-ju koja automatski konfiguriše servise na osnovu njihovih interfejsa i traitova. Ova funkcionalnost pojednostavljuje konfiguraciju servisa automatskim primenjivanjem tagova i poziva metoda potrebnih da Symfony komponente i drugi bundlovi rade ispravno, na osnovu karakteristika vaših servisa.

## Kako funkcioniše

Kada je omogućen, autoconfiguration automatski taguje servise specifičnim Symfony tagovima ako implementiraju određene interfejse ili koriste određene traitove. Ovo smanjuje potrebu za eksplicitnom konfiguracijom i čini definicije servisa čistijim i konciznijim.

## Omogućavanje Autoconfigure

Autoconfigure se može omogućiti globalno ili po servisu u fajlu `services.yaml`. Globalno omogućavanje primenjuje autoconfiguration na sve servise u njegovom opsegu.

```yaml
services:
    _defaults:
        autowire: true
        autoconfigure: true # Enables autoconfigure globally
```

## Primer: Autoconfiguration Event Listenera

Razmotrimo event listener koji sluša `kernel.request` događaje:

```php
namespace App\EventListener;

use Symfony\Component\HttpKernel\Event\RequestEvent;

class MyRequestListener
{
    public function onKernelRequest(RequestEvent $event)
    {
        // Handle the request event
    }
}
```

Bez autoconfiguration, morali biste ručno da tagujete ovaj servis kao event listener u `services.yaml`:

```yaml
services:
    App\EventListener\MyRequestListener:
        tags:
            - { name: 'kernel.event_listener', event: 'kernel.request', method: 'onKernelRequest' }
```

Sa autoconfiguration, dovoljno je implementirati interfejs ili koristiti trait koji Symfony prepoznaje kao event listener. Symfony će automatski tagizirati servis na odgovarajući način, eliminišući potrebu za eksplicitnom konfiguracijom.

## Primer: Autowiring i Autoconfiguring komandi

Symfony komande takođe mogu koristiti prednosti autowiringa i autoconfiguracije. Proširivanjem bazne klase `Command` i omogućavanjem autoconfigure, Symfony automatski registruje komandu i čini je dostupnom konzoli.

```php
namespace App\Command;

use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;

class MyCommand extends Command
{
    protected static $defaultName = 'app:my-command';

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        // Command logic
        return Command::SUCCESS;
    }
}
```

U `services.yaml`, definicija servisa za ovu komandu može ostati minimalna:

```yaml
services:
    App\Command\MyCommand: ~
```

Autoconfiguration se brine za podešavanje komande bez potrebe za eksplicitnim tagovima.

## Zaključak

Autoconfigure pojednostavljuje podešavanje Symfony aplikacija smanjujući standardnu konfiguraciju servisa. Besprekorno radi sa autowiring, dodatno poboljšavajući iskustvo programera fokusiranjem na konvencije umesto konfiguracije.
