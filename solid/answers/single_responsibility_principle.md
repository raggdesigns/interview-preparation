# Single Responsibility Principle (SRP)

The Single Responsibility Principle (SRP), one of the SOLID principles of object-oriented design, states that a class
should have only one reason to change. This means each class should be responsible for a single part of the
functionality provided by the software, and that responsibility should be entirely encapsulated by the class.

## Workflow Mindset

- Gather together the things that change for the same reason.
- Separate those things that change for different reasons.
- Keep only the related things together

## Violating SRP

Consider a PHP class that handles both user data management and user notifications. This class violates the SRP because
it has more than one reason to change - changes to the user management logic and changes to how notifications are sent.

```php
class UserManager {
    public function createUser($userData) {
        // Logic to create a user
        echo "User created\n";
    }

    public function sendEmail($user) {
        // Logic to send an email to the user
        echo "Email sent to user\n";
    }
}

$userManager = new UserManager();
$userManager->createUser(['name' => 'John Doe']);
$userManager->sendEmail('john.doe@example.com');
```

## Refactored Code Applying SRP

```text
class UserManager {
    public function createUser($userData) {
        // Logic to create a user
        echo "User created\n";
        // Delegate email sending to UserNotifier
        (new UserNotifier())->sendEmail($userData['email']);
    }
}

class UserNotifier {
    public function sendEmail($email) {
        // Logic to send an email
        echo "Email sent to $email\n";
    }
}

$userManager = new UserManager();
$userManager->createUser(['name' => 'John Doe', 'email' => 'john.doe@example.com']);
```

To adhere to the SRP, we can refactor the above scenario by splitting it into two classes: one for managing user
data (`UserManager`) and another for handling user notifications (`UserNotifier`).

## Explanation

By refactoring the code, we now have two classes each with a single responsibility. `UserManager` is only responsible
for user management tasks, and `UserNotifier` takes care of sending notifications to users. This adheres to the SRP and
makes our code more modular, easier to understand, and maintain.

## Benefits of Applying SRP

- **Improved Modularity**: Each class has a clear, singular focus, making it easier to understand and modify.
- **Ease of Testing**: Smaller classes with a single responsibility are easier to unit test.
- **Lower Coupling**: Decoupling classes leads to more flexible and maintainable code.
- **Easier Refactoring and Feature Addition**: With responsibilities well-separated, adding new features or changing
  existing behavior becomes less risky and complex.
