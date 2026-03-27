Event Sourcing je arhitekturalni pattern u kome se promene stanja aplikacije čuvaju kao niz događaja. Umesto da čuva samo trenutno stanje podataka u domenu, event sourcing takođe čuva niz akcija izvršenih nad tim podacima. Događaji se čuvaju u log-u samo za dodavanje i mogu se koristiti za rekonstrukciju prošlih stanja, reviziju promena i napredovanje stanja aplikacije.

### Ključni koncepti Event Sourcing-a:

- **Događaji**: Nepromenljivi zapisi koji beleže činjenicu ili akciju u sistemu, kao što su 'UserRegistered' ili 'OrderPlaced'. Svaki događaj predstavlja promenu stanja.
- **Event Store**: Mehanizam za skladištenje događaja. Deluje kao izvor istine za stanje aplikacije.
- **Agregati**: Entiteti ili domenski objekti koji dobijaju svoje stanje primenom događaja u nizu.
- **Projekcije**: Modeli za čitanje kreirani iz događaja koji su optimizovani za upite.
- **Event Handlers**: Logika koja reaguje na događaje, bilo ažuriranjem stanja, pokretanjem sporednih efekata ili generisanjem novih događaja.

### Prednosti:

- **Revizija**: Pošto su sve promene sačuvane kao događaji, pruža kompletnu istoriju promena stanja.
- **Fleksibilnost**: Nove funkcionalnosti mogu biti dodate uvođenjem novih događaja i handler-a bez modifikacije postojećeg koda.
- **Skalabilnost**: Događaji se samo dodaju, a projekcije se mogu rekonstruisati, što omogućava distribuirane sisteme koji se dobro skaliraju.

### Primer u PHP-u

Razmotrimo sistem za upravljanje narudžbinama gde se akcije narudžbine beleže kao događaji.

```php
interface Event {
    public function getType();
    public function getPayload();
}

class OrderPlaced implements Event {
    protected $orderId;
    protected $orderDetails;

    public function __construct($orderId, $orderDetails) {
        $this->orderId = $orderId;
        $this->orderDetails = $orderDetails;
    }

    public function getType() {
        return 'OrderPlaced';
    }

    public function getPayload() {
        return ['orderId' => $this->orderId, 'orderDetails' => $this->orderDetails];
    }
}

class EventStore {
    protected $events = [];

    public function store(Event $event) {
        $this->events[] = $event;
    }

    public function getEvents() {
        return $this->events;
    }
}
```

### Upotreba:

```php
$eventStore = new EventStore();
$orderDetails = ['product' => 'Book', 'quantity' => 1];
$orderPlacedEvent = new OrderPlaced(1, $orderDetails);

$eventStore->store($orderPlacedEvent);

foreach ($eventStore->getEvents() as $event) {
    // Process event
    echo $event->getType() . ' with payload: ' . json_encode($event->getPayload()) . "\n";
}
```

U ovom primeru, `OrderPlaced` je događaj koji predstavlja akciju postavljanja narudžbine. `EventStore` deluje kao repozitorijum za ove događaje. Čuvanjem svake akcije kao događaja, sistem može rekonstruisati stanje narudžbine u bilo kom trenutku, osigurati da su akcije narudžbine podložne reviziji i reagovati na događaje po potrebi.

### Zaključak

Event Sourcing pruža robusnu arhitekturu za upravljanje promenama stanja u sistemu, nudeći prednosti u pogledu revizije, fleksibilnosti i skalabilnosti. Međutim, uvodi složenost i zahteva pažljivo razmatranje strategija skladištenja događaja, reprodukcije i verzioniranja.
