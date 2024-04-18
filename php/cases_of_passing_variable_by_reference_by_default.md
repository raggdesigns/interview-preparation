In PHP, variables are passed by value by default, meaning that a copy of the variable is made in the function's scope, and changes to the variable within the function do not affect the original variable outside of the function. However, PHP also supports passing variables by reference, allowing functions to modify the original variable. By default, PHP passes variables by value, but there are specific cases where variables are passed by reference:

### 1. Assignment by Reference

You can explicitly create a reference to a variable by using the reference operator (`&`) in an assignment.

```php
$a = 10;
$b = &$a; // $b is a reference to $a.
$b = 20;
echo $a; // Outputs: 20
```

### 2. Function Arguments by Reference

Function arguments can be passed by reference by prefixing the parameter with an ampersand (`&`). This means any changes to the parameter within the function will reflect on the original variable.

```php
function increment(&$value) {
    $value++;
}

$count = 1;
increment($count);
echo $count; // Outputs: 2
```

### 3. Returning References

A function can return a reference to a variable by using the `&` operator both in the function declaration and when calling the function.

```php
function &getValue() {
    static $value = 100;
    return $value;
}

$newVal = &getValue();
$newVal = 200;
echo getValue(); // Outputs: 200
```

### 4. Foreach Loop

When iterating over arrays using the `foreach` loop, you can iterate by reference to modify the original array elements.

```php
$arr = [1, 2, 3];
foreach ($arr as &$value) {
    $value = $value * 2;
}
unset($value); // Break the reference with the last element
print_r($arr); // Outputs: Array ( [0] => 2 [1] => 4 [2] => 6 )
```

### 5. Default By-Reference Passing in Certain Built-in PHP Functions

Some built-in PHP functions and methods use references by default. A common example is the use of `preg_match` where matches are passed by reference to be populated by the function.

```php
$str = "PHP is great";
preg_match('/is/', $str, $matches);
print_r($matches); // $matches is filled by reference.
```

### Conclusion

While PHP passes variables by value by default, passing by reference is explicitly done using the `&` operator. This is useful in situations where you want to allow a function to modify its arguments directly or to avoid copying large amounts of data for performance reasons. It's important to use references cautiously, as they can lead to code that is harder to understand and maintain.
