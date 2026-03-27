Entities and Value Objects are two fundamental concepts in Domain-Driven Design (DDD) that help in modeling the domain
more effectively. Understanding these concepts allows you to represent the nuances of the domain accurately within your
software.

### Entities

Entities are objects that are defined not by their attributes, but by a thread of continuity and identity. This means an
entity is unique within the system, even if its attributes change over time. The identity of an entity is constant from
the moment it's created until it ceases to exist within the system.

#### Example of an Entity

```text
class User {
    private $userId;
    private $name;
    private $email;

    public function __construct($userId, $name, $email) {
        $this->userId = $userId;
        $this->name = $name;
        $this->email = $email;
    }
    // Getters and setters...
}
```

Consider a `User` in a social media platform. A user can change their name, email, or profile picture, but they remain
the same user. This is represented by a unique identifier (like a user ID) that doesn't change, even though other
attributes might.

### Value Objects

Value Objects, on the other hand, are defined by their attributes. If you change any attribute of a Value Object, it
essentially becomes a new object. Value Objects do not have a unique identifier that tracks them throughout their
lifecycle, and they are often used to describe aspects of an entity.

#### Example of a Value Object

```text
class Address {
    private $street;
    private $city;
    private $postalCode;

    public function __construct($street, $city, $postalCode) {
        $this->street = $street;
        $this->city = $city;
        $this->postalCode = $postalCode;
    }
    // Getters...
}
```

An `Address` used in a shipping system can be a Value Object. It's defined by its attributes (street, city, postal
code), and changing any of these attributes would result in a different address.

### Misinterpretation and Its Effects

A common misinterpretation in DDD is treating an object that should be an Entity as a Value Object. This mistake can
manifest significant issues as the system evolves.

#### Incorrect Decision Example

Imagine an online bookstore system where every book is initially modeled as a Value Object, under the mistaken
assumption that all that identifies a book is its combination of title, author, and ISBN. This decision leads to
complications when the system needs to track individual copies of books for inventory purposes or handle sales and
returns, as Value Objects do not have a unique identifier.

### Corrective Action

```text
class Book {
    private $bookId;
    private $title;
    private $author;
    private $ISBN;

    public function __construct($bookId, $title, $author, $ISBN) {
        $this->bookId = $bookId;
        $this->title = $title;
        $this->author = $author;
        $this->ISBN = $ISBN;
    }
    // Getters...
}
```

To address these issues, the development team needs to refactor the model, treating `Book` as an Entity rather than a
Value Object. This involves assigning a unique identifier to each `Book` instance, allowing the system to distinguish
between different copies of the same title.

### Conclusion

The distinction between Entities and Value Objects is not just academic; it has practical implications for the design
and functionality of your system. Properly applied, these concepts can create a domain model that is robust, flexible,
and aligned with business realities, facilitating future enhancements and adjustments to meet evolving requirements.

### See Also

- [Entity vs DTO vs Value Object (OOP perspective)](../../oop/entity_vs_data_transfer_object_vs_value_object.md)
