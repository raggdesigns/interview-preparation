
# Validator Component

Validator Component je fleksibilan sistem za validaciju PHP objekata prema skupu pravila i ograničenja. Deo je Symfony ekosistema, ali može da se koristi u bilo kom PHP projektu za osiguravanje integriteta podataka i razdvajanje logike validacije od poslovne logike.

## Osnovni koncepti

- **Ograničenja (Constraints)**: Pravila koja opisuju logiku validacije za properties ili getter metode PHP objekata.
- **Validatori ograničenja (Constraint Validators)**: Rukuju logikom validacije za svako ograničenje, proveravajući da li podaci ispunjavaju navedene uslove.
- **Validacione grupe**: Omogućavaju specificiranje grupa ograničenja za uslovno validiranje objekata.
- **Lista kršenja (Violation List)**: Prikuplja i prijavljuje greške validacije.

## Prednosti

- **Odvajanje zavisnosti**: Odvaja logiku validacije od poslovne logike, čineći kod modularnim i lakšim za održavanje.
- **Višekratna upotreba**: Ograničenja i prilagođeni validatori mogu biti ponovo korišćeni u različitim delovima aplikacije ili čak u različitim projektima.
- **Fleksibilnost**: Podržava validaciju javnih properties, getter metoda i prilagođenih scenarija validacije.

## Primer upotrebe

### Definisanje ograničenja

Možete definisati ograničenja direktno na properties entiteta ili modela:

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

### Validacija objekta

Za validaciju objekta, koristite `Validator` servis:

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

### Korišćenje grupa za uslovnu validaciju

Ponekad možda želite da primenite različita pravila validacije u različitim okolnostima, što se može postići korišćenjem validacionih grupa:

```php
/**
 * @Assert\NotBlank(groups={"registration"})
 */
public $username;
```

Možete navesti grupu prilikom validacije objekta:

```php
$violations = $validator->validate($user, null, 'registration');
```

## Zaključak

Validator Component pruža robustan i fleksibilan sistem za sprovođenje pravila validacije u PHP aplikacijama. Korišćenjem ove komponente, programeri mogu da osiguraju integritet podataka i čisto odvoje logiku validacije od poslovne logike.
