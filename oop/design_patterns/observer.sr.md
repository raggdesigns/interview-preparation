Observer obrazac je bihejvioralni dizajnerski obrazac gde objekat, poznat kao subjekt, održava listu svojih zavisnih objekata, zvanih posmatrači, i automatski ih obaveštava o svim promenama stanja, obično pozivanjem jedne od njihovih metoda. Uglavnom se koristi za implementaciju distribuiranih sistema obrade događaja i temeljni je aspekt arhitekturalnog obrasca Model-View-Controller (MVC). Observer obrazac promoviše labavo spajanje jer subjekt ne treba znati ništa o posmatračima, osim da implementiraju određeni interfejs.

### Kratka definicija

Observer obrazac dozvoljava grupi objekata da budu obavešteni od strane centralnog objekta kada se nešto dogodi.

### Ključni koncepti Observer obrasca

- **Subjekt (Subject)**: Entitet koji se posmatra. Održava listu posmatrača i obaveštava ih o promenama svog stanja.
- **Posmatrač (Observer)**: Interfejs ili apstraktna klasa koja definiše operacije koje se koriste za obaveštavanje ovog objekta o promenama stanja subjekta.
- **Konkretni posmatrač (ConcreteObserver)**: Implementira Observer interfejs i definiše kako reagovati na obaveštenja od Subjekta.

### Prednosti

- **Labavo spajanje**: Subjekt i posmatrači su labavo spregnuti. Subjekt ne zna detalje posmatrača, samo da implementiraju Observer interfejs.
- **Dinamički odnosi**: Posmatrači se mogu dinamički dodavati i uklanjati u vreme izvršavanja bez menjanja subjekta ili ostalih posmatrača.
- **Broadcast komunikacija**: Promene stanja subjekta mogu biti istovremeno emitovane svim zainteresovanim posmatračima.

### Primer u PHP-u

Razmotrimo jednostavan primer gde klasa `Product` (Subjekt) obaveštava listu klasa posmatrača kada se promeni njena cena.

```php
interface Observer {
    public function update($subject);
}

interface Subject {
    public function attach(Observer $observer);
    public function detach(Observer $observer);
    public function notify();
}

// Concrete Subject
class Product implements Subject {
    private $observers = [];
    private $price;

    public function attach(Observer $observer) {
        $this->observers[spl_object_hash($observer)] = $observer;
    }

    public function detach(Observer $observer) {
        unset($this->observers[spl_object_hash($observer)]);
    }

    public function notify() {
        foreach ($this->observers as $observer) {
            $observer->update($this);
        }
    }

    public function setPrice($price) {
        $this->price = $price;
        $this->notify();
    }

    public function getPrice() {
        return $this->price;
    }
}

// Concrete Observer
class PriceObserver implements Observer {
    public function update($subject) {
        echo "New price: " . $subject->getPrice();
    }
}
```

### Upotreba

```php
$product = new Product();
$priceObserver = new PriceObserver();

$product->attach($priceObserver);
$product->setPrice(20); // Outputs: New price: 20

$product->detach($priceObserver);
$product->setPrice(30); // No output since the observer was detached
```

U ovom primeru, klasa `Product` obaveštava svoje posmatrače svaki put kada se promeni njena cena putem `setPrice`. `PriceObserver` reaguje na ova obaveštenja ispisivanjem nove cene. Ovo demonstrira kako Observer obrazac omogućava mehanizam pretplate-obaveštavanja između objekata, promovišući labavo spajanje između njih.
