Invariance, Covariance, and Contravariance are terms that describe how the type of objects can be substituted in
relation to their parent or child types, especially in the context of generics, return types, and method overriding.
These concepts are crucial in type theory and help in understanding how type systems work in programming languages.

### Invariance

Invariance means that you can only use the type exactly as declared; no subtype or supertype is allowed. An invariant
type does not change when its generic parameter changes.

**Example**:
In PHP, array types are invariant. If you have a function that accepts an array of `User` objects, you cannot pass an
array of `AdminUser` objects, even if `AdminUser` extends `User`.

### Covariance

Covariance allows a method to return a type more derived than that of the method it overrides. Similarly, a covariant
generic allows substituting a subtype for a supertype.

**Example**:
In PHP (as of PHP 7.4), return types can be covariant. If a parent class method returns a `User`, a child class method
can return `AdminUser`, a subclass of `User`.

```php
class User {}
class AdminUser extends User {}

class UserRepository {
    public function findUser(): User {}
}

class AdminUserRepository extends UserRepository {
    public function findUser(): AdminUser {}
}
```

### Contravariance

Contravariance allows a method to accept parameters of a less derived type than that of the method it overrides.
Similarly, a contravariant generic allows substituting a supertype for a subtype.

**Example**:
In PHP (as of PHP 7.4), method arguments can be contravariant. If a parent class method accepts a `User`, a child class
method can accept `Person`, a superclass of `User`.

```php
class Person {}
class User extends Person {}

class Action {
    public function addUser(User $user) {}
}

class UserAction extends Action {
    public function addUser(Person $person) {}
}
```

### Conclusion

Understanding invariance, covariance, and contravariance is essential for correctly using type systems in programming,
particularly in languages that support strong typing and generic programming. These concepts ensure type safety while
allowing flexibility in how classes and methods can be extended or overridden.
