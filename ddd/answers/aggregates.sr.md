U Domain-Driven Design (DDD), aggregate je grupa povezanih domenskih objekata koji se tretiraju kao jedna jedinica u svrhu primene poslovnih pravila i održavanja konzistentnosti podataka. Svaki aggregate ima jednu ulaznu tačku poznatu kao aggregate root, kroz koji se sprovode sve interakcije sa aggregatom.

### Karakteristike aggregata

- **Enkapsulacija**: Aggregate Root enkapsulira cijeli aggregate, primenjujući njegove invarijante i osiguravajući da aggregate ostane u konzistentnom stanju.
- **Granica**: Granica aggregate-a je definisana root entitetom. Samo objekti unutar ove granice mogu direktno pristupati jedni drugima.
- **Root entitet**: Svaki aggregate ima root entitet, poznat kao Aggregate Root, koji kontroliše pristup aggregatu.
- **Invarijante**: Invarijante su pravila konzistentnosti koja moraju biti održavana kad god se podaci menjaju unutar aggregate-a.

### Primer aggregata

Razmotrite e-commerce aplikaciju gde biste mogli imati `Order` aggregate. Ovaj aggregate uključuje nekoliko entiteta i value objekata, kao što su `OrderLines` (svaki predstavlja proizvod i količinu), informacije o plaćanju, informacije o isporuci, itd. Entitet `Order` bi bio Aggregate Root, kroz koji se vrše sve modifikacije i interakcije sa podacima narudžbine.

```text
class Order {
    private $orderId;
    private $orderLines = [];
    private $paymentInformation;
    private $shippingInformation;

    public function __construct($orderId) {
        $this->orderId = $orderId;
    }

    public function addOrderLine(Product $product, $quantity) {
        $this->orderLines[] = new OrderLine($product, $quantity);
        // Enforce invariants, for example, check stock levels
    }

    // Methods to modify payment and shipping information
}

class OrderLine {
    private $product;
    private $quantity;

    public function __construct(Product $product, $quantity) {
        $this->product = $product;
        $this->quantity = $quantity;
        // Maybe check some invariants here as well
    }
}

class Product {
    private $productId;
    private $name;
    private $price;

    // Constructor and methods
}

class PaymentInformation {
    // Implementation
}

class ShippingInformation {
    // Implementation
}
```

U ovom pojednostavljenom primeru, `Order` je Aggregate Root, i direktno sadrži `OrderLine`, `PaymentInformation` i `ShippingInformation`. Klasa `Order` enkapsulira sve operacije, osiguravajući da se promene narudžbine vrše na konzistentan način. Ova enkapsulacija omogućava `Order` aggregatu da primenjuje sva poslovna pravila (invarijante) vezana za narudžbine.

### Zaključak

Aggregati su moćan koncept u DDD-u, pomažući da se osigura da su promene povezanih podataka konzistentne i da su domenski invarijante primenjene. Pažljivim dizajniranjem aggregata i identifikovanjem aggregate rootova, možete učiniti vaš domenski model robusnijim, osiguravajući da tačno odražava poslovna pravila i ograničenja domena koji modelujete.
