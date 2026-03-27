# Liskov Substitution Principle (LSP)

Liskov Substitution Principle (LSP) je koncept u objektno-orijentisanom programiranju koji navodi da objekti superklase trebaju biti zamenljivi objektima podklase bez uticaja na ispravnost programa. Suštinski, podklase treba da proširuju bazne klase bez promene njihovog ponašanja.

### Kršenje LSP

Uobičajeno kršenje LSP javlja se kada podklasa redefiniše metodu superklase na način koji ne podržava originalno ponašanje.

```php
class Bird {
    public function fly() {
        echo "Fly high in the sky";
    }
}

class Ostrich extends Bird {
    public function fly() {
        throw new Exception("I can't fly");
    }
}

function letTheBirdFly(Bird $bird) {
    $bird->fly();
}

letTheBirdFly(new Bird()); // Works fine
letTheBirdFly(new Ostrich()); // Throws an exception
```

U ovom primeru, `Ostrich` je podklasa klase `Bird`. Međutim, nisu sve ptice sposobne za let, što čini metodu `fly` neprikladnom za `Ostrich`, čime se krši LSP.

### Refactored kod koji primenjuje LSP

Da bi se poštovao LSP, trebalo bi da redizajniramo hijerarhiju klasa kako bismo osigurali da podklase mogu da se koriste umesto bazne klase.

```php
interface Bird {
    public function eat();
}

interface FlyingBird extends Bird {
    public function fly();
}

class Sparrow implements FlyingBird {
    public function eat() {
        echo "Eat";
    }

    public function fly() {
        echo "Fly high in the sky";
    }
}

class Ostrich implements Bird {
    public function eat() {
        echo "Eat";
    }
}

function letTheBirdFly(FlyingBird $bird) {
    $bird->fly();
}

letTheBirdFly(new Sparrow()); // Works fine
// letTheBirdFly(new Ostrich()); // This will now result in a compile-time error
```

### Objašnjenje

- Odvajanjem interfejsa za `Bird` i `FlyingBird`, osiguravamo da samo ptice koje mogu da lete implementiraju metodu `fly`. Ovo je u skladu sa LSP jer klasa `Ostrich` nije primorana da implementira ponašanje (letenje) koje ne može da ispuni.

- Ovaj pristup čini našu hijerarhiju klasa fleksibilnijom i preciznijom, omogućavajući pticama da proširuju ili implementiraju ponašanje koje im odgovara, osiguravajući zamenljivost bez narušavanja ispravnosti programa.

### Prednosti primene LSP

- **Poboljšana preciznost modela**: Bolje predstavlja scenarije iz stvarnog sveta.
- **Povećana robusnost**: Sistem je manje sklon greškama jer se objekti koriste predvidivije.
- **Poboljšana ponovna upotrebljivost koda**: Jasniji ugovori dovode do komponenti koje je lakše ponovo koristiti.

### Različite definicije LSP

1. **Liskov Substitution Principle (LSP)**: Ovaj princip navodi da objekti superklase trebaju biti zamenljivi objektima podklase bez uticaja na ispravnost programa. Suštinski, podklase treba da proširuju baznu klasu bez promene njenog ponašanja.

2. **Ponašajna podtipabilnost**: Drugi način opisivanja LSP je da definiše da podtip mora biti ponašajno kompatibilan sa svojim supertipom, što znači da korisnik supertipa ne bi trebao moći da razlikuje supertype od podtipa.

3. **Relaksacija jakih preduslova**: LSP tvrdi da preduslovi za bilo koju metodu u podklasi ne trebaju biti jači od onih u superklasi. To znači da podklasa može raditi barem u svim situacijama gde superklasa može.

4. **Slabija garancija postusloova**: Sa perspektive postuslova, LSP zahteva da podklasa osigura barem iste, ako ne i jače, postuslove u poređenju sa superklason. Rezultati ili bočni efekti trebaju biti konzistentni ili precizniji kada se koristi podklasa.

5. **Očuvanje istorijskog ograničenja**: LSP takođe obuhvata "istorijsko ograničenje" koje implicira da podklasa treba da poštuje invarijante i istoriju superklase. To znači da podklasa ne treba da dozvoli promene stanja koje bi bile nemoguće u superklasi.
