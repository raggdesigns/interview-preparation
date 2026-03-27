Dok se getteri i setteri (metode pristupa i mutacije) uobičajeno koriste u objektno-orijentisanom programiranju za enkapsulaciju podataka, kritikovani su iz više razloga, posebno kada se koriste preterano ili bez odgovarajućeg razmatranja dizajna objekta. Evo zašto se korišćenje gettera i settera može smatrati lošim u određenim kontekstima:

### 1. Kršenje enkapsulacije

Jedna od glavnih kritika je da mogu kršiti princip enkapsulacije. Enkapsulacija se tiče grupiranja podataka i metoda koje operišu na tim podacima unutar jedne jedinice (klase) i ograničavanja pristupa unutrašnjem funkcionisanju te jedinice. Preterana upotreba gettera i settera može pružiti spoljašnji pristup unutrašnjosti klase, efektivno kršeći enkapsulaciju.

### 2. Anemični domenski model

Preterano oslanjanje na getter i setter metode može dovesti do anemičnog domenskog modela, gde domenski objekti postaju puki kontejneri podataka bez smislenog ponašanja. Ovaj pristup može rezultirati proceduralnim stilom programiranja, umesto istinski objektno-orijentisanog, gde se logika koja operišuje nad podacima premešta van domenskih objekata.

### 3. Smanjena održivost

Klase sa mnogo gettera i settera mogu postati teške za održavanje, jer promene unutrašnje strukture mogu zahtevati promene ovih metoda. Ovo može posebno postati problem ako se ove metode koriste ekstenzivno kroz bazu koda, dovodeći do tesnog spajanja između klasa.

### 4. Složenost testiranja

Ekstenzivna upotreba gettera i settera može povećati složenost unit testova, jer stanje objekta treba postaviti kroz ove metode pre nego što se može testirati ponašanje. Ovo može testove učiniti opširnijim i težim za razumevanje.

### 5. Prerana optimizacija

Dodavanje gettera i settera za svako privatno polje "za svaki slučaj" ako budu potrebni u budućnosti je oblik prerane optimizacije. Često je bolje početi sa minimalnim javnim interfejsima i dodavati takve metode samo kada postoji jasan zahtev.

### Primer bez gettera i settera

Umesto korišćenja gettera i settera, možete dizajnirati objekte koji enkapsuliraju ponašanje zajedno sa podacima kojima manipulišu:

```php
class Order {
    private $items = [];
    private $status = 'pending';

    public function addItem($item) {
        if ($this->status === 'pending') {
            $this->items[] = $item;
        }
    }

    public function completeOrder() {
        if (!empty($this->items)) {
            $this->status = 'completed';
            // Further logic to complete the order
        }
    }
}
```

U ovom primeru, klasa `Order` ne izlaže svoje unutrašnje stanje kroz getter i setter metode. Umesto toga, pruža metode koje enkapsuliraju akcije koje možete izvesti na `Order`-u, kao što je dodavanje stavke ili dovršavanje narudžbine. Ovaj pristup održava enkapsulaciju i osigurava da `Order` objekti uvek ostaju u validnom stanju.

### Zaključak

Dok getteri i setteri nisu inherentno loši, njihova zloupotreba može dovesti do lošeg objektno-orijentisanog dizajna. Važno je koristiti ih promišljeno, imajući na umu principe enkapsulacije, i favorizovati izlaganje ponašanja nad unutrašnjim stanjem.
