The Proxy pattern is a structural design pattern that provides an object that acts as a substitute or placeholder for
another object to control access to it. This intermediary can serve various purposes, such as handling expensive object
creation, controlling access to sensitive objects, or adding additional behaviors (such as logging or security checks)
when an object is accessed. The Proxy pattern is particularly useful when you want to add a layer of abstraction over
the actual handling of object interactions.

### Key Concepts of the Proxy Pattern

- **Subject Interface**: Defines the common interface for both the RealSubject and the Proxy, allowing a Proxy to be
  used anywhere a RealSubject is expected.
- **RealSubject**: The actual object that the Proxy represents and controls access to.
- **Proxy**: Maintains a reference to the RealSubject, controls access to it, and may be responsible for its creation
  and deletion. The Proxy often performs additional tasks when it forwards requests to the RealSubject, such as lazy
  initialization, logging, or access control.

### Types of Proxy

- **Virtual Proxy**: Delays the creation and initialization of expensive objects until they are needed.
- **Protective Proxy**: Controls access to sensitive objects by implementing access control.
- **Remote Proxy**: Represents an object in a different address space (e.g., a network server), handling the
  communication required to send requests to the object.
- **Smart Proxy**: Adds additional behaviors (e.g., reference counting or logging) when an object is accessed.

### Example in PHP

Let's consider a simple example where we use a Proxy to control access to a sensitive `BankAccount` object.

```php
interface BankAccount {
    public function deposit($amount);
    public function getBalance();
}

// RealSubject
class RealBankAccount implements BankAccount {
    private $balance = 0;

    public function deposit($amount) {
        $this->balance += $amount;
    }

    public function getBalance() {
        return $this->balance;
    }
}

// Proxy
class BankAccountProxy implements BankAccount {
    private $realBankAccount;
    private $userRole;

    public function __construct($userRole) {
        $this->userRole = $userRole;
        $this->realBankAccount = new RealBankAccount();
    }

    public function deposit($amount) {
        $this->realBankAccount->deposit($amount);
    }

    public function getBalance() {
        if ($this->userRole === 'authorized') {
            return $this->realBankAccount->getBalance();
        } else {
            return "Access denied. User role not authorized to view balance.";
        }
    }
}
```

### Usage

```php
$bankAccount = new BankAccountProxy('unauthorized');
$bankAccount->deposit(100);
echo $bankAccount->getBalance(); // Outputs: Access denied. User role not authorized to view balance.

$authorizedBankAccount = new BankAccountProxy('authorized');
$authorizedBankAccount->deposit(100);
echo $authorizedBankAccount->getBalance(); // Outputs the balance
```

In this example, the `BankAccountProxy` controls access to the `RealBankAccount`'s balance based on the user's role.
This demonstrates how the Proxy pattern can add a layer of security and control over object access, without modifying
the original object's code.
