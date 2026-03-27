Domain Events su ključni koncept u Domain-Driven Design-u (DDD) koji predstavlja nešto smisleno što se desilo unutar domene. Koriste se za komunikaciju promena ili značajnih dešavanja unutar sistema, omogućavajući različitim delovima sistema da reaguju na te promene na dekouplovan način. U suštini, Domain Events enkapsuliraju ideju arhitekture vođene događajima unutar konteksta DDD-a, promovišući:
  * slabo sprezanje
  * povećanje reaktivnosti sistema
  * fleksibilnost

### Karakteristike Domain Events:

- **Nepromenljivi**: Jednom kada je Domain Event kreiran, njegovo stanje se ne menja. Ova nepromenljivost osigurava pouzdanost događaja dok se propagira kroz sistem.
- **Naziv događaja**: Opisuje šta se desilo, obično u prošlom vremenu (npr. OrderPlaced, ItemShipped).
- **Podaci događaja**: Sadrži detalje relevantne za događaj, kao što su ID-evi entiteta, vremenske oznake i druge pertinentne informacije.

### Primer Domain Events

Zamisli e-commerce sistem sa kontekstom obrade narudžbina. U takvom sistemu, događaji kao što su postavljanje narudžbine ili slanje predmeta su značajna dešavanja. Ovi se mogu modelovati kao Domain Events.

#### OrderPlaced događaj

Ovaj događaj označava da je kupac postavio narudžbinu. Može uključivati informacije kao što su ID narudžbine, ID kupca, datum narudžbine i lista naručenih artikala.

#### ItemShipped događaj

Ovaj događaj ukazuje da je artikal iz narudžbine poslat. Može sadržati detalje poput ID-a narudžbine, ID-a artikla, datuma pošiljke i broja za praćenje.

#### Implementacija Domain Events u PHP-u

Pojednostavljena PHP implementacija OrderPlaced događaja može izgledati ovako:

```
class OrderPlaced {
    private $orderId;
    private $customerId;
    private $orderDate;
    private $items;

    public function __construct($orderId, $customerId, $orderDate, array $items) {
        $this->orderId = $orderId;
        $this->customerId = $customerId;
        $this->orderDate = $orderDate;
        $this->items = $items;
    }

    // Getteri za svojstva...
}
```

Za rukovanje ovim događajem, kreirao bi se event listener ili subscriber koji reaguje kad god je `OrderPlaced` događaj objavljen. Ovo može uključivati slanje email potvrde kupcu, ažuriranje nivoa zaliha ili pokretanje procesa plaćanja.

### Zaključak

Domain Events igraju ključnu ulogu u dizajniranju reaktivnih, fleksibilnih i dekovuplanih sistema u DDD-u. Omogućavaju različitim delovima sistema da odgovore na značajne promene ili dešavanja unutar domene, bez čvrstog sprezanja sa komponentama gde te promene potiču. Ovo olakšava modularnu arhitekturu, gde komponente sistema mogu evoluirati nezavisno dok još uvek efikasno sarađuju.
