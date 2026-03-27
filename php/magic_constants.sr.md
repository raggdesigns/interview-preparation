PHP pruža skup posebnih predefinisanih konstanti poznatih kao "magične konstante" koje se menjaju u zavisnosti od konteksta. Počinju i završavaju se sa dve donje crte (`__`). Vrednost magične konstante zavisi od mesta gde se koristi u skripti, čineći ih kontekstno-zavisnim. Sledi lista magičnih konstanti i kako se njihove vrednosti menjaju u zavisnosti od mesta upotrebe:

### Lista magičnih konstanti

- `__LINE__`: Trenutni broj linije fajla.
- `__FILE__`: Puna putanja i naziv fajla. Ako se koristi unutar include-a, vraća se naziv uključenog fajla.
- `__DIR__`: Direktorijum fajla. Ekvivalentno sa `dirname(__FILE__)`. Ovaj direktorijum se definiše pri kompajliranju.
- `__FUNCTION__`: Naziv funkcije, ili `{closure}` za anonimne funkcije.
- `__CLASS__`: Naziv klase uključujući namespace u kome je deklarisana (npr. `Namespace\ClassName`).
- `__TRAIT__`: Naziv trait-a uključujući namespace u kome je deklarisan (npr. `Namespace\TraitName`).
- `__METHOD__`: Naziv metode klase (npr. `ClassName::methodName`).
- `__NAMESPACE__`: Naziv trenutnog namespace-a.
- `__COMPILER_HALT_OFFSET__`: Bajt offset u fajlu gde je pozvan `__halt_compiler()`. Retko se koristi, ali je korisno u nekim kontekstima kao što je kreiranje izvršnih PHP arhiva.

### Zavisnost od lokacije

Da, vrednost većine magičnih konstanti se menja u zavisnosti od mesta pozivanja u kodu:

- Za `__LINE__`, vrednost se menja sa brojem linije gde se koristi.
- Vrednosti `__FILE__` i `__DIR__` zavise od putanje do trenutnog fajla.
- Vrednosti `__FUNCTION__`, `__CLASS__`, `__TRAIT__` i `__METHOD__` se menjaju u zavisnosti od namespace-a, klase, trait-a ili metode unutar koje se pozivaju.
- `__NAMESPACE__` odražava trenutni namespace koda gde se koristi.

Ovo kontekstno-zavisno ponašanje omogućava programerima da dinamički dobijaju informacije o strukturi koda, što olakšava debagovanje, prijavljivanje grešaka i ponekad samu logiku aplikacije.

**Primer upotrebe**:

```php
namespace MyNamespace;
class MyClass {
    public function myMethod() {
        echo __CLASS__; // Outputs "MyNamespace\MyClass"
        echo __METHOD__; // Outputs "MyClass::myMethod"
    }
}

function myFunction() {
    echo __FUNCTION__; // Outputs "myFunction"
    echo __LINE__; // Outputs the line number where it's called
}
```

U ovom primeru, vrednost `__CLASS__` i `__METHOD__` se određuje prema kontekstu u kome se koriste (tj. unutar klase `MyClass` i metode `myMethod`). Slično tome, `__FUNCTION__` i `__LINE__` odražavaju njihovu upotrebu unutar `myFunction` i specifičan broj linije.

### Zaključak

Magične konstante u PHP-u su jedinstvene po tome što se njihove vrednosti određuju prema kontekstu u kome se koriste, što ih čini moćnim alatima za introspekciju i dinamičko ponašanje koda. Posebno su korisne u svrhe debagovanja i pisanja adaptivnijeg koda.
