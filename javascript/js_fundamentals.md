JavaScript is a single-threaded, dynamically typed language that runs in the browser and in Node.js. Even as a backend PHP developer, you will encounter JavaScript in interviews — especially closures, arrow functions, and how functions work.

### Function Declaration vs Function Expression

There are two main ways to define a function in JavaScript:

```javascript
// Function declaration — hoisted (can be called before it's defined)
function greet(name) {
    return `Hello, ${name}!`;
}

// Function expression — NOT hoisted (must be defined before use)
const greet = function(name) {
    return `Hello, ${name}!`;
};

// Both are called the same way
greet("Dragan");  // "Hello, Dragan!"
```

**Hoisting** means JavaScript moves function declarations to the top of the scope before executing code:

```javascript
// This works — function declarations are hoisted
sayHello();  // "Hello!"
function sayHello() {
    console.log("Hello!");
}

// This FAILS — function expressions are NOT hoisted
sayHi();  // ReferenceError: Cannot access 'sayHi' before initialization
const sayHi = function() {
    console.log("Hi!");
};
```

### Arrow Functions

Arrow functions are a shorter syntax for function expressions, introduced in ES6 (2015):

```javascript
// Regular function
const add = function(a, b) {
    return a + b;
};

// Arrow function — shorter
const add = (a, b) => {
    return a + b;
};

// Arrow function — even shorter (implicit return for single expression)
const add = (a, b) => a + b;

// Single parameter — parentheses optional
const double = x => x * 2;

// No parameters — parentheses required
const getRandom = () => Math.random();
```

### Arrow Functions vs Regular Functions — Key Differences

The most important difference is how `this` works:

```javascript
// Regular function — `this` depends on HOW the function is called
const user = {
    name: "Dragan",
    greet: function() {
        console.log(`Hello, ${this.name}`);  // `this` = user object
    }
};
user.greet();  // "Hello, Dragan" ✓

// Arrow function — `this` is inherited from the SURROUNDING scope
const user = {
    name: "Dragan",
    greet: () => {
        console.log(`Hello, ${this.name}`);  // `this` = outer scope (window/undefined)
    }
};
user.greet();  // "Hello, undefined" ✗
```

**Rule:** Arrow functions do NOT have their own `this`. They use `this` from the scope where they were **defined**, not where they are **called**.

**Where arrow functions shine:**

```javascript
// Callbacks — arrow functions keep the outer `this`
class UserService {
    constructor() {
        this.users = [];
    }

    fetchUsers() {
        // Arrow function keeps `this` = UserService instance
        fetch('/api/users')
            .then(response => response.json())
            .then(data => {
                this.users = data;  // `this` correctly refers to UserService
            });
    }
}

// With regular function, you'd need to save `this`:
fetchUsers() {
    const self = this;  // Save reference
    fetch('/api/users')
        .then(function(response) { return response.json(); })
        .then(function(data) {
            self.users = data;  // Must use `self`, not `this`
        });
}
```

| Feature | Regular function | Arrow function |
|---------|-----------------|----------------|
| `this` binding | Dynamic (depends on caller) | Lexical (from surrounding scope) |
| `arguments` object | Yes | No |
| Can be constructor | Yes (`new Foo()`) | No |
| Has `prototype` | Yes | No |
| Hoisting | Yes (declarations) | No |

### Closures

A closure is a function that **remembers the variables** from the scope where it was created, even after that scope has finished executing.

```javascript
function createCounter() {
    let count = 0;  // This variable is "closed over"

    return function() {
        count++;        // The inner function still has access to `count`
        return count;
    };
}

const counter = createCounter();
console.log(counter());  // 1
console.log(counter());  // 2
console.log(counter());  // 3

// `count` is not accessible from outside
console.log(count);  // ReferenceError: count is not defined
```

The inner function "closes over" the variable `count` — it keeps a reference to it even after `createCounter()` has returned.

### How Closures Work

```javascript
function outer() {
    const message = "Hello";  // Variable in outer function scope

    function inner() {
        console.log(message);  // Accesses variable from outer scope
    }

    return inner;
}

const fn = outer();  // outer() finishes, but `message` is NOT garbage collected
fn();                // "Hello" — inner function still has access to `message`
```

JavaScript keeps the variable `message` alive because `inner()` has a reference to it. This is the closure — the combination of the function and its surrounding state.

### Practical Closure Examples

**1. Private variables (encapsulation)**

```javascript
function createUser(name) {
    let loginCount = 0;  // Private — cannot be accessed from outside

    return {
        getName: () => name,
        login: () => {
            loginCount++;
            console.log(`${name} logged in. Total: ${loginCount}`);
        },
        getLoginCount: () => loginCount,
    };
}

const user = createUser("Dragan");
user.login();           // "Dragan logged in. Total: 1"
user.login();           // "Dragan logged in. Total: 2"
user.getLoginCount();   // 2
// user.loginCount      // undefined — private!
```

**2. Function factories**

```javascript
function createMultiplier(factor) {
    return (number) => number * factor;
}

const double = createMultiplier(2);
const triple = createMultiplier(3);

double(5);  // 10
triple(5);  // 15
```

**3. Event handlers with state**

```javascript
function createClickHandler(buttonName) {
    let clickCount = 0;

    return function() {
        clickCount++;
        console.log(`${buttonName} clicked ${clickCount} times`);
    };
}

const handleSave = createClickHandler("Save");
const handleDelete = createClickHandler("Delete");

// Each handler has its own independent `clickCount`
handleSave();    // "Save clicked 1 times"
handleSave();    // "Save clicked 2 times"
handleDelete();  // "Delete clicked 1 times"
```

### Common Closure Pitfall — Loop Variable

```javascript
// PROBLEM — all functions share the same `i`
for (var i = 0; i < 3; i++) {
    setTimeout(function() {
        console.log(i);
    }, 1000);
}
// Output: 3, 3, 3  (not 0, 1, 2!)
// Because `var` is function-scoped, all closures share the same `i`
// By the time setTimeout runs, the loop has finished and i = 3

// SOLUTION 1 — use `let` (block-scoped, creates new variable each iteration)
for (let i = 0; i < 3; i++) {
    setTimeout(function() {
        console.log(i);
    }, 1000);
}
// Output: 0, 1, 2  ✓

// SOLUTION 2 — IIFE (Immediately Invoked Function Expression)
for (var i = 0; i < 3; i++) {
    (function(j) {
        setTimeout(function() {
            console.log(j);
        }, 1000);
    })(i);
}
// Output: 0, 1, 2  ✓
```

### Closures Compared to PHP

PHP also has closures, but with a key difference — you must explicitly declare which variables to capture using `use`:

```php
// PHP — explicit capture with `use`
function createCounter(): Closure {
    $count = 0;
    return function() use (&$count) {  // Must use `use` keyword
        $count++;
        return $count;
    };
}

$counter = createCounter();
echo $counter();  // 1
echo $counter();  // 2
```

```javascript
// JavaScript — automatic capture, no special syntax needed
function createCounter() {
    let count = 0;
    return function() {  // Automatically captures `count`
        count++;
        return count;
    };
}
```

### Scope Chain

JavaScript has three levels of scope:

```javascript
const global = "I'm global";  // Global scope

function outer() {
    const outerVar = "I'm outer";  // Function scope

    function inner() {
        const innerVar = "I'm inner";  // Function scope
        
        // inner can access all three:
        console.log(innerVar);   // ✓ own scope
        console.log(outerVar);   // ✓ closure — parent scope
        console.log(global);     // ✓ global scope
    }

    // outer can access two:
    console.log(outerVar);   // ✓ own scope
    console.log(global);     // ✓ global scope
    console.log(innerVar);   // ✗ ReferenceError — inner scope not accessible
}
```

### Conclusion

JavaScript functions can be declared (hoisted) or expressed (not hoisted). Arrow functions provide shorter syntax and inherit `this` from the surrounding scope — making them ideal for callbacks. Closures allow functions to remember variables from their creation scope, enabling private state, function factories, and stateful event handlers. The key difference from PHP closures is that JavaScript captures variables automatically while PHP requires the `use` keyword. Understanding these concepts is essential for working with modern JavaScript and for technical interviews.

> See also: [Async JavaScript — Promises, async/await, fetch](async_javascript.md), [PHP closures](../php/closure_vs_anonymous_function.md)
