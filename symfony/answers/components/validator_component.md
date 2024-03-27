
# Validator Component

The Validator Component is a flexible system for validating PHP objects against a set of rules and constraints. It's part of the Symfony ecosystem but can be used in any PHP project to ensure data integrity and validation logic separation from business logic.

## Core Concepts

- **Constraints**: Rules that describe the validation logic for properties or getter methods of PHP objects.
- **Constraint Validators**: Handle the validation logic for each constraint, checking if the data meets the specified conditions.
- **Validation Groups**: Allow specifying groups of constraints to validate objects conditionally.
- **Violation List**: Collects and reports validation errors.

## Benefits

- **Decoupling**: Separates validation logic from business logic, making code more modular and maintainable.
- **Reusability**: Constraints and custom validators can be reused across different parts of the application or even in different projects.
- **Flexibility**: Supports validating public properties, getter methods, and custom validation scenarios.

## Example Usage

### Defining Constraints

You can define constraints directly on the properties of an entity or model:

```php
use Symfony\Component\Validator\Constraints as Assert;

class Product
{
    /**
     * @Assert\NotBlank(message="Product name should not be blank.")
     */
    public $name;

    /**
     * @Assert\Range(
     *      min = 0,
     *      max = 100,
     *      notInRangeMessage = "The price must be between {{ min }} and {{ max }}."
     * )
     */
    public $price;
}
```

### Validating an Object

To validate an object, use the `Validator` service:

```php
use Symfony\Component\Validator\Validation;

$validator = Validation::createValidator();
$product = new Product();
$product->name = ''; // This will trigger the NotBlank constraint
$product->price = 150; // This will trigger the Range constraint

$violations = $validator->validate($product);

if (0 !== count($violations)) {
    // There are errors, handle them
    foreach ($violations as $violation) {
        echo $violation->getMessage(). '\n';
    }
}
```

### Using Groups for Conditional Validation

Sometimes you may want to apply different validation rules under different circumstances, which can be achieved using validation groups:

```php
/**
 * @Assert\NotBlank(groups={"registration"})
 */
public $username;
```

You can specify the group when validating the object:

```php
$violations = $validator->validate($user, null, 'registration');
```

## Conclusion

The Validator Component provides a robust and flexible system for enforcing validation rules in PHP applications. By using this component, developers can ensure data integrity and cleanly separate validation logic from business logic.
