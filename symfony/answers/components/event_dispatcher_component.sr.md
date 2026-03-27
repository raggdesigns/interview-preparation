
# Event Dispatcher Component

EventDispatcher Component pruža lagan i fleksibilan sistem za Symfony aplikacije da se pretplate na dogadjaje i da ih dispečuju širom aplikacije. Ova komponenta je neophodna za implementaciju Observer obrasca, omogućavajući arhitekturu aplikacije sa razdvojenim komponentama.

## Osnovni koncepti

- **Dogadjaj (Event)**: Objekat koji enkapsulira informacije vezane za specifičnu akciju ili pojavu unutar aplikacije.
- **Dispečer (Dispatcher)**: Upravlja dispečovanjem dogadjaja i obaveštava registrovane osluškivače ili pretplatnike o tim dogadjajima.
- **Osluškivač (Listener)**: PHP callable koji osluškuje specifičan dogadjaj i izvršava se kada se taj dogadjaj dispečuje.
- **Pretplatnik (Subscriber)**: Sličan osluškivaču, ali pretplatnik može da osluškuje više dogadjaja.

## Prednosti

- **Odvajanje zavisnosti**: Pomaže u odvajanju različitih delova aplikacije omogućavajući komunikaciju driven dogadjajima između komponenti.
- **Fleksibilnost**: Čini aplikaciju fleksibilnijom i prilagodljivijom promenama omogućavanjem dinamičkog rukovanja dogadjajima.
- **Višekratna upotreba**: Promoviše višekratnu upotrebu logike rukovanja dogadjajima u različitim delovima aplikacije ili u različitim aplikacijama.

## Primer upotrebe

### Kreiranje dogadjaja

Prvo, definišite klasu dogadjaja:

```php
namespace App\Event;

use Symfony\Contracts\EventDispatcher\Event;

class OrderPlacedEvent extends Event
{
    public const NAME = 'order.placed';

    protected $orderId;

    public function __construct(int $orderId)
    {
        $this->orderId = $orderId;
    }

    public function getOrderId(): int
    {
        return $this->orderId;
    }
}
```

### Dispečovanje dogadjaja

Zatim, dispečujte dogadjaj bilo gde u vašoj aplikaciji:

```php
use App\Event\OrderPlacedEvent;
use Symfony\Component\EventDispatcher\EventDispatcher;

$dispatcher = new EventDispatcher();
$event = new OrderPlacedEvent(123);

$dispatcher->dispatch($event, OrderPlacedEvent::NAME);
```

### Osluškivanje dogadjaja

Za osluškivanje `OrderPlacedEvent`, definišite osluškivač:

```php
class OrderListener
{
    public function onOrderPlaced(OrderPlacedEvent $event)
    {
        // Handle the event, e.g., send an email confirmation
    }
}

$listener = new OrderListener();
$dispatcher->addListener(OrderPlacedEvent::NAME, [$listener, 'onOrderPlaced']);
```

### Korišćenje pretplatnika

Alternativno, možete koristiti pretplatnika dogadjaja da osluškujete jedan ili više dogadjaja:

```php
use Symfony\Component\EventDispatcher\EventSubscriberInterface;

class OrderSubscriber implements EventSubscriberInterface
{
    public static function getSubscribedEvents()
    {
        return [
            OrderPlacedEvent::NAME => 'onOrderPlaced',
        ];
    }

    public function onOrderPlaced(OrderPlacedEvent $event)
    {
        // Handle the event
    }
}

$dispatcher->addSubscriber(new OrderSubscriber());
```

## Zaključak

EventDispatcher Component je moćan alat za implementaciju programiranja vođenog dogadjajima u Symfony aplikacijama, omogućavajući čisto razdvajanje zaduženja i povećavajući proširivost i fleksibilnost aplikacije.
