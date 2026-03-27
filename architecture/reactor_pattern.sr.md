Reactor pattern je dizajn pattern za konkurentnost koji se koristi za efikasno rukovanje višestrukim simultanim I/O operacijama na neblokirajući način. Razdvaja rukovanje mrežom ili I/O operacijama od aplikacione logike, omogućavajući jednoj niti da upravlja višestrukim I/O operacijama. Pattern se često koristi u serverima i aplikacijama koje zahtevaju visoku skalabilnost i responzivnost.

### Ključne komponente:

- **Reactor**: Komponenta koja demultipleksira i prosleđuje I/O događaje odgovarajućem handler-u.
- **Handlers**: Komponente odgovorne za rukovanje I/O događajima. Handler-i obavljaju neblokirajuće operacije ili zadatke.
- **Event Demultiplexer**: Sistemski poziv koji blokira čekanje I/O događaja i obaveštava reactor kada se dogodi jedan ili više događaja.
- **Synchronous Event Demultiplexer**: Mehanizam koji reactor koristi da blokira i čeka događaje, a zatim ih prosleđuje odgovarajućim handler-ima.

### Kako funkcioniše:

1. Aplikacija registruje interes za određene I/O operacije kod reactor-a, specificirajući handler koji treba biti pozvan kada je operacija spremna.
2. Reactor koristi event demultiplexer da blokira i čeka da se dogodi neka od registrovanih operacija.
3. Kada je I/O operacija spremna, demultiplexer obaveštava reactor.
4. Reactor zatim prosleđuje kontrolu odgovarajućem handler-u.
5. Handler obrađuje događaj bez blokiranja i vraća kontrolu reactor-u.

### Prednosti:

- **Skalabilnost**: Omogućava rukovanje hiljadama istovremenih konekcija u jednoj niti, izbegavajući troškove prebacivanja konteksta niti.
- **Responzivnost**: Poboljšava responzivnost aplikacije korišćenjem neblokirajućih I/O operacija.
- **Iskorišćenost resursa**: Efikasno korišćenje resursa, jer manji broj niti može upravljati mnogim konekcijama.

### Primer u PHP-u:

PHP biblioteke zasnovane na događajima poput ReactPHP implementiraju Reactor pattern, pružajući event loop za asinhronо rukovanje I/O operacijama.

```php
use React\EventLoop\Factory;
use React\Stream\ReadableResourceStream;

$loop = Factory::create();

// Open an input stream (STDIN)
$stream = new ReadableResourceStream(STDIN, $loop);
$stream->on('data', function ($data) {
    echo "You typed: " . $data;
});

$loop->run();
```

U ovom primeru, `ReadableResourceStream` je handler koji reaguje na 'data' događaje (unos sa STDIN) i ispisuje unos. Event loop (`$loop`) deluje kao reactor, upravljajući životnim ciklusom događaja.

### Zaključak

Reactor pattern je moćan arhitekturalni pattern za izgradnju skalabilnih i responzivnih aplikacija koje rukuju višestrukim istovremenim I/O operacijama. Razdvajanjem nadležnosti između rukovanja događajima i poslovne logike, omogućava programerima da pišu jednostavniji, neblokirajući aplikacioni kod.
