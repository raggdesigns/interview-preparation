GRASP (General Responsibility Assignment Software Patterns) is a set of principles aimed at improving object-oriented
design by providing guidelines on assigning responsibilities to classes. Among these principles, "Low Coupling" and "
High Cohesion" are foundational concepts that help in creating more maintainable, flexible, and understandable designs.

### Low Coupling

Coupling refers to the degree of direct knowledge one class has of another. Low coupling is a design goal that seeks to
reduce the dependencies between classes, making them less interconnected. This simplifies the changes and the
understanding of the system, as modifications in one part of the system have minimal impact on other parts.

**Benefits of Low Coupling**:

- **Ease of Modification**: Changes in one class have a reduced impact on other classes.
- **Reusability**: Classes can be reused in different contexts more easily if they don't heavily depend on other
  specific classes.
- **Testability**: Classes with fewer dependencies are easier to test in isolation.

### High Cohesion

Cohesion refers to how closely related and focused the responsibilities of a single class (or module) are. High cohesion
means that the class is focused on what it should be doing, containing only responsibilities that are closely related to
the purpose of the class. This makes the class more understandable and manageable.

**Benefits of High Cohesion**:

- **Understandability**: Classes with a well-defined focus are easier to understand because their operations are closely
  related.
- **Maintainability**: It's easier to maintain and modify classes when their responsibilities are well-defined and
  concentrated on a single purpose.
- **Reduced Complexity**: High cohesion usually results in simpler classes with fewer methods and attributes, reducing
  overall complexity.

### Example in PHP

To illustrate low coupling and high cohesion, consider a simple user management system:

#### Before (High Coupling and Low Cohesion)

```php
class UserManager {
    public function createUser($userData) {
        // Create user logic
    }

    public function sendEmail($userEmail, $content) {
        // Email sending logic
    }

    // Additional unrelated methods...
}
```

In this example, `UserManager` is handling user creation and email sending, showing low cohesion (mixed
responsibilities) and potentially high coupling if the email sending process relies on specifics of the user management
system.

#### After (Low Coupling and High Cohesion)

```php
class UserManager {
    public function createUser($userData) {
        // Create user logic
    }
}

class EmailService {
    public function sendEmail($recipientEmail, $content) {
        // Email sending logic
    }
}
```

Now, `UserManager` is focused solely on user management (high cohesion), and `EmailService` handles email sending. This
design reduces the coupling between user management and email functionality, as they are now separated into different
classes. Changes in the email service won't affect the user manager, and vice versa.

### Conclusion

In object-oriented design, striving for low coupling and high cohesion helps in creating systems that are easier to
understand, maintain, and extend. These principles guide the structuring of classes and their relationships, leading to
a more robust and flexible design.
