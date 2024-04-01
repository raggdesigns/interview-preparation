In object-oriented design and software architecture, Entity, Data Transfer Object (DTO), and Value Object are terms used
to describe different ways of structuring data and behavior in applications. Each serves a distinct purpose and is used
in different contexts.

### Entity

Entities are objects that have a distinct identity that runs through time and different states. An entity is defined
more by its identity than by its attributes. Attributes may change over time, but the entity remains the same.

**Characteristics**:

- **Identity**: Entities have a unique identifier.
- **Mutability**: Their state or attributes can change over time, but their identity does not.
- **Lifecycle**: They usually have a lifecycle managed through CRUD operations (Create, Read, Update, Delete).

**Example in PHP**:

```php
class User {
    private $id; // Unique identifier
    private $name; // Mutable attribute
    
    public function __construct($id, $name) {
        $this->id = $id;
        $this->name = $name;
    }
    
    // Getter and setter methods
}
```

### Data Transfer Object (DTO)

DTOs are simple objects used to transfer data between software application subsystems. DTOs do not contain any business
logic. They are used to reduce the number of method calls, especially in a network environment.

**Characteristics**:

- **Simplicity**: Only data attributes, no business logic.
- **Data Container**: Used to transport data between layers or services.
- **Immutability** (optional): Often designed as immutable to increase thread-safety in concurrent operations.

**Example in PHP**:

```php
class UserDTO {
    public $id;
    public $name;
    
    public function __construct($id, $name) {
        $this->id = $id;
        $this->name = $name;
    }
}
```

### Value Object

Value Objects are objects that describe some characteristic or attribute but are not defined by a unique identity. They
are used to describe aspects of a domain without the need for uniqueness.

**Characteristics**:

- **Immutability**: Once created, they should not be altered.
- **Equality**: Determined by the equality of their attributes rather than an identity.
- **Side-effect-free Behavior**: May contain methods that operate on the attributes but don't change the object's state.

**Example in PHP**:

```php
class EmailAddress {
    private $email;
    
    public function __construct($email) {
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new InvalidArgumentException("Invalid email address");
        }
        $this->email = $email;
    }
    
    public function getEmail() {
        return $this->email;
    }
    
    // Value objects are equal if their attributes are equal
    public function equals(EmailAddress $other) {
        return $this->email === $other->getEmail();
    }
}
```

### Entity vs DTO vs Value Object: Key Differences

- **Identity vs. Attributes**: Entities are defined by a unique identifier, while Value Objects are defined by their
  attributes. DTOs are data containers and typically do not have identity or behavior.
- **Immutability**: Value Objects are immutable, while Entities can mutate over time. DTOs can be either but are often
  immutable to simplify data transfer.
- **Usage Context**: Entities represent business objects with identity. Value Objects describe characteristics of these
  objects. DTOs simplify data transfer between parts of a system or across networks.

### Conclusion

Understanding the differences between Entity, DTO, and Value Object is crucial for designing clear, maintainable
software architectures. Choosing the right pattern depends on the specific requirements of the application, such as the
need for identity, the importance of data encapsulation, and the nature of data transfer operations.
