# Refactoring legacy koda: Tehnike, obrasci i pristup

Refactoring legacy koda znači poboljšanje dizajna i održivosti bez promene vidljivog ponašanja.
Na intervjuima, ova tema proverava da li možete smanjiti rizik dok isporučujete poslovnu vrednost, a ne samo predlagati potpuno prepisivanje.

## Preduslovi

- Osnovno znanje automatizovanog testiranja (unit/integracija)
- Sposobnost čitanja logova/metrika za produkcijsko ponašanje
- Osnovno razumevanje dependency injection-a i interfejsa

## Osnovni pristup (Siguran tok refactoring-a)

1. Izaberite jedno bolno žarište (visoka učestalost promena, stopa grešaka ili uticaj na kašnjenje).
2. Zabeležite trenutno ponašanje pre promene koda (karakterizacioni testovi).
3. Kreirajte šavove da bi kod bio testabilan (izvuci metode, omota globalne varijable, injektuj zavisnosti).
4. Primenite male refactoring korake postepeno.
5. Proverite nakon svakog koraka (testovi + metrike izvršavanja).
6. Objavljujte u malim grupama sa opcijom povratka.

Ovaj tok je obično sigurniji od kompletnog prepisivanja.

## Tehnike koje najčešće koristite

- **Karakterizacioni testovi**: prvo zaključajte trenutno ponašanje, posebno za nejasnu legacy logiku.
- **Izvlačenje metode/klase**: podelite velike funkcije/klase u fokusirane jedinice.
- **Inverzija zavisnosti**: zamenite direktne statičke/globalne pozive interfejsima.
- **Uvođenje objekta parametra**: pojednostavite dugačke potpise metoda.
- **Grananje po apstrakciji**: uvedite novu apstrakciju i postepeno migrirajte mesta pozivanja.

## Korisni obrasci tokom refactoring-a

- **Facade**: kreirajte jednu jednostavnu tačku ulaska nad nerednim legacy unutrašnjostima.
- **Adapter**: održavajte stare i nove API-je kompatibilnim tokom migracije.
- **Strategy**: izolirajte promenjiva poslovna pravila iza zamenljivih implementacija.
- **Zamena u stilu Strangler-a**: usmerite deo toka ka novom kodu dok stari kod još uvek radi.

## Praktičan primer (PHP)

### Legacy kod (težak za testiranje i promenu)

```php
class InvoiceService
{
    public function generate(int $orderId): Invoice
    {
        $order = App::get('order_repository')->find($orderId);
        $tax = App::get('tax_calculator')->calculate($order);
        $pdf = App::get('pdf_generator')->generate($order, $tax);

        file_put_contents('/data/invoices/' . $orderId . '.pdf', $pdf);
        App::get('logger')->info('Invoice generated: ' . $orderId);

        return new Invoice($pdf);
    }
}
```

Problemi:

- Skrivene zavisnosti (`App::get(...)`)
- Direktno pisanje na fajl sistem unutar poslovne logike
- Teško unit testiranje

### Refactored verzija (postepeni cilj)

```php
interface InvoiceStorage
{
    public function save(int $orderId, string $pdf): void;
}

final class InvoiceService
{
    public function __construct(
        private OrderRepository $orderRepository,
        private TaxCalculator $taxCalculator,
        private PdfGenerator $pdfGenerator,
        private InvoiceStorage $invoiceStorage,
        private LoggerInterface $logger,
    ) {
    }

    public function generate(int $orderId): Invoice
    {
        $order = $this->orderRepository->find($orderId);
        $tax = $this->taxCalculator->calculate($order);
        $pdf = $this->pdfGenerator->generate($order, $tax);

        $this->invoiceStorage->save($orderId, $pdf);
        $this->logger->info('Invoice generated: ' . $orderId);

        return new Invoice($pdf);
    }
}
```

### Kako bezbedno migrirati

1. Dodajte karakterizacioni test oko izlaza `generate()` i sporednih efekata.
2. Omotajte `file_put_contents` iza `InvoiceStorage` adaptera.
3. Zamenjujte jednu po jednu `App::get(...)` zavisnost sa injektovanjem kroz konstruktor.
4. Držite ponašanje identičnim dok poboljšavate strukturu.

## Kako odrediti prioritete rada na refactoring-u

Koristite jednostavnu 2x2 matricu sa dva pitanja:

- Koliko ovaj deo utiče na poslovanje ako se pokvari?
- Koliko često programeri diraju ovaj deo?

### 1) Visok poslovni uticaj + visoka učestalost promena

- **Šta to znači**: Kritičan kod koji tim često uređuje. Ovde su greške skupe i česte.
- **Primer**: Izračunavanje cene pri plaćanju menja se svaki sprint za promocije, a male greške uzrokuju pogrešne ukupne iznose.
- **Preporučena akcija**: Uradite refactoring prvo. Dodajte testove, podelite velike metode i uklonite rizične zavisnosti pre sledećeg posla na funkcionalnostima.

### 2) Visok poslovni uticaj + niska učestalost promena

- **Šta to znači**: Kritičan kod koji je relativno stabilan. Opasan je kada pogrešno funkcioniše, ali se ne menja svake nedelje.
- **Primer**: Logika mesečnog izvoza faktura izvršava se jednom po ciklusu naplate i utiče na računovodstvo.
- **Preporučena akcija**: Stabilizujte sa karakterizacionim testovima sada, zatim uradite refactoring u malim koracima kada se zatraži poslovna promena.

### 3) Nizak poslovni uticaj + visoka učestalost promena

- **Šta to znači**: Nekritičan kod koji se često dira. Usporava isporuku ali obično ne uzrokuje veće incidente.
- **Primer**: Unutrašnji admin filteri se često menjaju po zahtevima proizvoda, ali kvarovi utiču samo na pogodnost back-office-a.
- **Preporučena akcija**: Radite oportunistički refactoring tokom implementacije funkcionalnosti (preimenkujte nejasan kod, izvucite metode, smanjite duplikaciju).

### 4) Nizak poslovni uticaj + niska učestalost promena

- **Šta to znači**: Retko korišćen i nisko-rizičan kod.
- **Primer**: Legacy izvoz izveštaja koji jedan tim koristi jednom kvartalno.
- **Preporučena akcija**: Odložite. Dodajte kratku belešku u tehnički dug i pregledajte samo ako se upotreba ili rizik povećaju.

## Uobičajena pitanja na intervjuu

### P: Kada radite refactoring nasuprot prepisivanju?

**O:** Uradite refactoring kada trenutni sistem još uvek isporučuje vrednost i ponašanje je uglavnom ispravno, ali kvalitet koda usporava razvoj. Prepisujte samo kada arhitektura blokira osnovne poslovne potrebe i postepeno poboljšanje nije realistično u prihvatljivom vremenu.

- **Primer refactoring-a**: Modul za plaćanje radi u produkciji ali ga je teško menjati zbog velikih klasa i globalnih varijabli. Dodajte testove i poboljšavajte ga korak po korak.
- **Primer prepisivanja**: Monolit ne može ispuniti stroge zahteve multi-tenant izolacije zahtevane novim ugovorima, i ovo se ne može bezbedno dodati malim promenama.

Praktično pravilo: ako možete bezbedno isporučiti vrednost u malim koracima, preferujte refactoring.

### P: Koji je vaš prvi korak ako nema testova?

**O:** Počnite hvatanjem trenutnog ponašanja sa karakterizacionim testovima oko najrizičnijeg toka, pre promene unutrašnjosti.

- Izaberite jedan važan scenario (na primer: `InvoiceService::generate()` za pravu narudžbinu).
- Zabeležite očekivane izlaze i sporedne efekte (sačuvana datoteka, unos u dnevnik, ažuriranje statusa).
- Pišite testove koji zaključavaju ovo ponašanje, čak i ako je unutrašnji kod neredan.

**Primer:** Pre refactoring-a poreske logike, kreirajte testove sa fiksnim ulaznim narudžbinama i očekivanim ukupnim iznosima da biste mogli detektovati slučajne promene ponašanja.

### P: Kako pokazujete da je refactoring proizveo vrednost?

**O:** Pokažite merljive signale pre/posle u oblasti koju ste dirali, a ne samo "čistiji kod".

- **Metrike isporuke**: vreme isporuke za srodne promene, vreme ciklusa pregleda.
- **Metrike kvaliteta**: broj grešaka u tom modulu, stopa povratka, produkcijski incidenti.
- **Metrike izvršavanja**: kašnjenje/stopa grešaka ako je urađen refactoring vezan za performanse.

**Primer:** Nakon refactoring-a generisanja faktura, tim je smanjio vreme isporuke promena sa 3 dana na 1 dan, a incidenti vezani za fakture pali su sa 4 mesečno na 1 mesečno tokom sledećeg kvartala.

## Zaključak

Legacy refactoring je uglavnom upravljanje rizikom sa postepenim poboljšanjem dizajna.
Počnite od bezbednosti ponašanja, primenite male fokusirane tehnike i koristite obrasce migracije za prelazak sa krhkog koda na održiv kod bez zaustavljanja isporuke.

> Vidi takođe: [Service Locator VS Inversion of Control (Dependency Injection) Container](service_locator_vs_di_container.sr.md), [Dependency Injection VS Composition VS Inversion of Control (IoC/DiC)](di_vs_composition_vs_ioc.sr.md), [KISS, DRY, YAGNI - objasni skraćenice](kiss_dry_yagni.sr.md)
