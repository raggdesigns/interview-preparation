Kompozicija i agregacija su dva osnovna koncepta u objektno-orijentisanom dizajnu koji opisuju različite vrste odnosa između objekata. Razumevanje razlike između ovih odnosa može pomoći u projektovanju koherentnijih i fleksibilnijih sistema.

### Kompozicija

Kompozicija je jaka relacija "ima" gde komponovani objekat ne može postojati nezavisno od kompozitnog objekta. Ako se kompozitni objekat uništi, njegovi komponovani objekti se takođe uništavaju. Kompozicija podrazumeva vlasništvo i upravljanje životnim ciklusom komponovanih objekata od strane kompozitnog objekta.

**Karakteristike**:

- **Jako vlasništvo**: Kompozitni objekat ima punu odgovornost za životni ciklus komponovanih objekata.
- **Vreme trajanja**: Životni ciklus komponovanih objekata je vezan za životni ciklus kompozitnog objekta.
- **Jedan vlasnik**: Komponovani objekti se ne dele između kompozitnih objekata.

**Primer u PHP-u**:

```php
class Engine {
    // Engine specific implementation
}

class Car {
    private $engine;

    public function __construct() {
        $this->engine = new Engine(); // Engine is a part of Car
    }

    // Destructor to emphasize ownership and lifecycle management
    public function __destruct() {
        unset($this->engine);
    }
}
```

U ovom primeru, objekat `Car` poseduje objekat `Engine`, a životni ciklus `Engine`-a upravlja `Car` objekat, demonstrirajući kompoziciju.

### Agregacija

Agregacija je slabija relacija "ima" u poređenju sa kompozicijom. Označava odnos gde dete može postojati nezavisno od roditelja. To je oblik asocijacije sa jednosmernim odnosom, implicirajući da je agregatni objekat kolekcija drugih objekata.

**Karakteristike**:

- **Labavo vlasništvo**: Roditeljski objekat nema direktnu kontrolu nad životnim ciklusom dece.
- **Nezavisan životni ciklus**: Deca objekti mogu postojati nezavisno od roditeljskog objekta.
- **Deljeno vlasništvo**: Deca objekti mogu biti povezani sa više roditeljskih objekata.

**Primer u PHP-u**:

```php
class Student {
    // Student specific implementation
}

class Classroom {
    private $students = [];

    public function addStudent(Student $student) {
        $this->students[] = $student; // Student can exist without Classroom
    }
}
```

Ovde, `Student` može pripadati `Classroom`-u, ali `Student` može postojati bez `Classroom`-a, ilustrujući agregaciju.

### Kompozicija vs Agregacija: Ključne Razlike

- **Vlasništvo**: Kompozicija podrazumeva jako vlasništvo i upravljanje životnim ciklusom komponovanog objekta. Agregacija podrazumeva slabiji odnos bez direktne kontrole životnog ciklusa.
- **Vreme trajanja**: U kompoziciji, životni ciklus komponovanih objekata je vezan za životni ciklus kompozitnog objekta. U agregaciji, životni ciklus dece objekata je nezavisan od agregata.
- **Odnos**: Kompozicija se koristi za predstavljanje odnosa celina-deo gde delovi ne mogu postojati bez celine. Agregacija se koristi za predstavljanje odnosa gde delovi mogu postojati nezavisno od celine.

### Zaključak

Izbor između kompozicije i agregacije zavisi od nameravane veze između objekata. Kompozicija treba biti korišćena za jači, zavisni odnos, dok je agregacija pogodna za fleksibilniju asocijaciju gde komponente mogu ostati autonomne.
