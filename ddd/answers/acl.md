The Anti-Corruption Layer (ACL) is a pattern from Domain-Driven Design (DDD) that acts as a protective barrier,
preventing undesirable and corrupting influences from a legacy system or an external system from affecting the integrity
of your domain model. It translates or transforms data between different systems or subsystems, allowing for clean
interaction without one system negatively impacting the design or function of the other.

### Context and Problem

In many software projects, especially in large or evolving systems, you'll often need to integrate with external
systems, services, or legacy systems. These systems might have different data formats, models, or even conflicting
business logic. Direct interaction between your system and these external systems can lead to a lot of complexities and
coupling, making the system hard to maintain and evolve.

Below is a simplified code example illustrating the use of an Anti-Corruption Layer (ACL) to integrate an external
inventory management system into an e-commerce application. The example is in PHP and shows a basic domain model for
products in the e-commerce system, the external model as provided by the inventory system, and the ACL implementation
that bridges the two.

#### Domain Model (E-commerce System)

```text
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

#### External Model (Inventory System)

```text
class ExternalProduct {
    public $productId;
    public $description;
    public $cost;
    public $quantityAvailable;

    // Constructor, getters and setters...
}
```

#### Anti-Corruption Layer Implementation

The ACL includes a translator that converts ExternalProduct instances from the inventory system into Product instances
for the e-commerce domain.

```text
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

#### Usage

This is how you might use the ACL to fetch product data from the external inventory system and convert it into the
domain model of the e-commerce application.

```text
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

#### Conclusion

```text
This example abstracts a lot of the complexities that might exist in real-world scenarios, such as dealing with APIs,
error handling, and more sophisticated translation logic. However, it demonstrates the core idea behind the
Anti-Corruption Layer: isolating your domain model from external systems by translating between different models, thus
protecting the integrity and design of your domain.
```
