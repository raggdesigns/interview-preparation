Demeterov zakon, poznat i kao Zakon Demetre (Law of Demeter, LoD) ili Princip minimalnog znanja, je smernica dizajnirana da promoviše labavo spajanje u softverskim dizajnima. Formulisan je na Northeastern University krajem 1980-ih, nazvan po grčkoj boginji Demetri, kao šaljivi nagoveštaj svog porekla. Princip naglašava da bi dati objekat trebalo da pretpostavi što manje o strukturi ili svojstvima svega ostalog sa čime interaguje, uključujući svoje podkomponente.

### Ključne tačke Demetrovog zakona

- **Razgovaraj samo sa svojim neposrednim prijateljima**: Objekti bi trebalo da pozivaju metode samo na:
  - Sebi
  - Objektima prosleđenim kao parametar metodi
  - Bilo kom objektu koji kreiraju ili instanciraju
  - Bilo kojim komponentama (objektima) koji se čuvaju u promenljivama instance

Pridržavanjem ovih ograničenja, princip ima za cilj smanjenje zavisnosti između komponenti, čineći sistem više održivim i prilagodljivim promenama.

### Uobičajeni primeri upotrebe

Primena Demetrovog zakona u objektno-orijentisanom programiranju obično znači izbegavanje "sudara vozova" – lanaca poziva metoda koji prodiru u unutrašnju strukturu objekta – i umesto toga zahtevanje da interakcije prolaze kroz dobro definisane interfejse.

#### Pre primene Demetrovog zakona

Razmotrimo primer korpe za kupovinu gde stavke u korpi imaju politiku popusta i želite da izračunate cenu nakon popusta:

```php
class ShoppingCart {
    public function calculateTotal() {
        $total = 0;
        foreach ($this->items as $item) {
            // Violates Demeter's Law
            $discount = $item->getDiscountPolicy()->getDiscountRate();
            $total += $item->getPrice() - ($item->getPrice() * $discount);
        }
        return $total;
    }
}
```

U ovom primeru, `calculateTotal` krši Demetrov zakon navigirajući kroz `item` do njegovog `discountPolicy` da bi dobio `discountRate`, što ukazuje na visok nivo spajanja.

#### Nakon primene Demetrovog zakona

Bolji pristup bi bio enkapsuliranje izračunavanja popusta unutar klase stavke ili politike popusta:

```php
class Item {
    public function getDiscountedPrice() {
        $discount = $this->discountPolicy->getDiscountRate();
        return $this->price - ($this->price * $discount);
    }
}

class ShoppingCart {
    public function calculateTotal() {
        $total = 0;
        foreach ($this->items as $item) {
            // Complies with Demeter's Law
            $total += $item->getDiscountedPrice();
        }
        return $total;
    }
}
```

U revidiranom primeru, `ShoppingCart` interaguje samo sa `Item`, a logika za primenu popusta je enkapsulirana unutar `Item`, pridržavajući se Demetrovog zakona. Ovo smanjuje spajanje između `ShoppingCart` i implementacije politike popusta.

### Zaključak

Demetrov zakon podstiče površnu, a ne duboku interakciju između objekata, smanjujući zavisnosti i olakšavajući ukupno održavanje sistema. Međutim, kao i svaki princip, treba ga primenjivati promišljeno i ne tretirati kao apsolutno pravilo. Prekomerno pridržavanje Demetrovog zakona ponekad može dovesti do eksplozije metoda omotača koje samo delegiraju drugim metodama, dodajući nepotrebnu složenost. Ključ je pronalaženje ravnoteže koja smanjuje spajanje bez prekomernog komplikovanja koda.
