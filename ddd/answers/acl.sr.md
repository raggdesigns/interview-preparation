Anti-Corruption Layer (ACL) je obrazac iz Domain-Driven Design (DDD) koji deluje kao zaštitna barijera, sprečavajući neželjene i korumpirajuće uticaje naslednog sistema ili eksternog sistema da utiču na integritet vašeg domenskog modela. Prevodi ili transformiše podatke između različitih sistema ili podsistema, omogućavajući čistu interakciju bez negativnog uticaja jednog sistema na dizajn ili funkciju drugog.

### Kontekst i problem

U mnogim softverskim projektima, posebno u velikim ili evoluirajućim sistemima, često ćete morati da se integrišete sa eksternim sistemima, servisima ili naslednim sistemima. Ovi sistemi mogu imati različite formate podataka, modele, ili čak suprotstavljenu poslovnu logiku. Direktna interakcija između vašeg sistema i ovih eksternih sistema može dovesti do velikih složenosti i sprezanja, čineći sistem teškim za održavanje i evoluciju.

U nastavku je pojednostavljen primer koda koji ilustruje upotrebu Anti-Corruption Layer (ACL) za integraciju eksternog sistema upravljanja zalihama u e-commerce aplikaciju. Primer je u PHP-u i prikazuje osnovni domenski model za proizvode u e-commerce sistemu, eksterni model koji pruža sistem zaliha, i implementaciju ACL-a koji premošćuje ova dva.

#### Domenski model (E-commerce sistem)

```
class Product {
    private $id;
    private $name;
    private $price;
    private $stockLevel;

    public function __construct($id, $name, $price, $stockLevel) {
        $this->id = $id;
        $this->name = $name;
        $this->price = $price;
        $this->stockLevel = $stockLevel;
    }

    // Getters and setters...
}
```

#### Eksterni model (Sistem zaliha)

```
class ExternalProduct {
    public $productId;
    public $description;
    public $cost;
    public $quantityAvailable;

    // Constructor, getters and setters...
}
```

#### Implementacija Anti-Corruption Layer-a

ACL uključuje prevodilac koji konvertuje instance `ExternalProduct` iz sistema zaliha u instance `Product` za e-commerce domen.

```
class ProductTranslator {
    public static function translate(ExternalProduct $externalProduct): Product {
        $id = $externalProduct->productId;
        $name = $externalProduct->description;
        $price = $externalProduct->cost; // Assume price in the e-commerce system maps to cost in the external system
        $stockLevel = $externalProduct->quantityAvailable;

        return new Product($id, $name, $price, $stockLevel);
    }
}
```

#### Upotreba

Ovako biste mogli koristiti ACL da preuzmete podatke o proizvodima iz eksternog sistema zaliha i konvertujete ih u domenski model e-commerce aplikacije.

```
// Simulate fetching an external product representation
$externalProduct = new ExternalProduct();
$externalProduct->productId = "123";
$externalProduct->description = "Widget";
$externalProduct->cost = 19.99;
$externalProduct->quantityAvailable = 100;

// Translate to domain model
$product = ProductTranslator::translate($externalProduct);

// Now, $product is a domain model instance, usable within the e-commerce system
```

#### Zaključak

```
This example abstracts a lot of the complexities that might exist in real-world scenarios, such as dealing with APIs,
error handling, and more sophisticated translation logic. However, it demonstrates the core idea behind the
Anti-Corruption Layer: isolating your domain model from external systems by translating between different models, thus
protecting the integrity and design of your domain.
```
