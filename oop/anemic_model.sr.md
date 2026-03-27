Anemični domenski model je termin koji je skovao Martin Fowler za opisivanje anti-obrasca u dizajnu softvera gde je domenski model fokusiran isključivo na podatke bez enkapsuliranja ikakve domenske logike. U ovom obrascu, poslovna logika se tipično implementira u posebnim klasama, kao što su servisi, koji manipulišu stanjem domenskih objekata. Ovaj pristup je suprotan bogatom domenskom modelu, gde su logika i podaci kombinovani da bi se bolje modelovale realne poslovne entitete.

### Ključne Karakteristike Anemičnog Domenskog Modela:

- **Entiteti samo sa podacima**: Entiteti u modelu prvenstveno sadrže polja podataka bez ikakve poslovne logike.
- **Poslovna logika u servisnom sloju**: Poslovna logika je implementirana izvan domenskog modela, često u servisnim klasama ili transakcionim skriptama.
- **Odvajanje stanja i ponašanja**: Postoji jasno odvajanje između stanja aplikacije (čuvano u domenskim entitetima) i ponašanja (implementiranog u servisima ili kontrolerima).

### Primer u PHP-u

Razmotrimo aplikaciju za e-commerce sa jednostavnim entitetom `Order`. U anemičnom domenskom modelu, klasa `Order` može izgledati ovako:

```php
class Order {
    public $id;
    public $orderLines = [];
    public $status;

    // Getter and setter methods for the properties
}

class OrderService {
    public function calculateTotal(Order $order) {
        $total = 0;
        foreach ($order->orderLines as $line) {
            $total += $line['quantity'] * $line['price'];
        }
        return $total;
    }

    public function addOrderLine(Order $order, $line) {
        $order->orderLines[] = $line;
    }

    // Other methods manipulating Order
}
```

U ovom primeru, klasa `Order` je čist kontejner podataka bez ikakve poslovne logike. Klasa `OrderService` sadrži sve operacije koje se mogu izvršiti na `Order`-u, kao što je računanje ukupnog iznosa ili dodavanje linije narudžbine.

### Kritike Anemičnog Domenskog Modela:

- **Kršenje principa objektno-orijentisanog dizajna**: Odvajanje stanja i ponašanja je suprotno osnovnim principima OOP-a, gde bi objekti trebalo da enkapsuliraju i podatke i ponašanje.
- **Povećana složenost**: Logika koja je van modela može dovesti do naduvanih servisnih klasa i otežati održavanje i razumevanje baze koda.
- **Poteškoće u primeni poslovnih pravila**: Sa logikom rasprostranjenom po servisima, može postati izazovno osigurati da su sva poslovna pravila dosledno primenjena.

### Zaključak

Dok se anemični domenski model može činiti jednostavnijim i direktnijim na početku, posebno za programere koji dolaze iz proceduralnog programskog okruženja, on često rezultira dizajnom koji je teže održavati i razvijati. Bogati domenski model, gde entiteti enkapsuliraju i podatke i ponašanje, može dovesti do intuitivnijeg i održivijeg dizajna, posebno u složenim aplikacijama sa opsežnom poslovnom logikom.
