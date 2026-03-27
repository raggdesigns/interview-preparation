
# Dizajn obrasci u Symfony-ju i Doctrine-u

Dizajn obrasci igraju ključnu ulogu u arhitekturi frameworka poput Symfony-ja i Doctrine-a, osiguravajući da je kod održiv, skalabilan i robustan. Evo nekoliko značajnih primera dizajn obrazaca korišćenih u Symfony-ju i Doctrine-u, zajedno sa njihovim primenama.

## Factory obrazac

### Opis

Factory obrazac se koristi za kreiranje objekata bez specificiranja tačne klase objekta koji će biti kreiran.

### Upotreba u Symfony-ju

Symfony koristi Factory obrazac u komponenti formi (`FormFactoryInterface`), koja kreira instance formi. Servisi definisani u `services.yaml` takođe mogu koristiti fabričke metode za instanciranje objekata.

### Upotreba u Doctrine-u

Doctrine koristi Factory obrazac za kreiranje entiteta ili repozitorijuma, na primer kroz fabriku repozitorijuma `EntityManager`-a.

## Observer obrazac

### Opis

Observer obrazac definiše zavisnost jedan-prema-mnogo između objekata tako da kada jedan objekat promeni stanje, svi njegovi zavisnici budu automatski obavešteni i ažurirani.

### Upotreba u Symfony-ju

EventDispatcher komponenta Symfony-ja je odličan primer Observer obrasca, gde se događaji (promene stanja) šalju registrovanim listenerima ili subscriberima koji zatim reaguju na ove događaje.

## Strategy obrazac

### Opis

Strategy obrazac se koristi za definisanje porodice algoritama, enkapsuliranje svakog od njih i čini ih zamenljivim. Strategy omogućava algoritmu da varira nezavisno od klijenata koji ga koriste.

### Upotreba u Symfony-ju

Strategy obrazac je evidentan u HTTP Kernel komponenti Symfony-ja, gde se mogu definisati i menjati različiti handleri zahteva (`HttpKernelInterface`) na osnovu potreba aplikacije.

## Data Mapper obrazac

### Opis

Data Mapper obrazac uključuje sloj mapera koji premešta podatke između objekata i baze podataka, čuvajući ih nezavisnim jedne od drugih i od samog mapera.

### Upotreba u Doctrine-u

Doctrine ORM je odličan primer Data Mapper obrasca, gde se entiteti (objekti u memoriji) mapiraju na tabele baze podataka. Doctrine-ov `EntityManager` i repozitorijumi deluju kao maperski sloj, transparentno rukujući mapiranjem objekat-baza podataka.

## Dependency Injection obrazac

### Opis

Dependency Injection je tehnika gde jedan objekat obezbeđuje zavisnosti drugog objekta, smanjujući sprezanje između komponenti i povećavajući fleksibilnost.

### Upotreba u Symfony-ju

Symfony-jev Dependency Injection kontejner je fundamentalni deo frameworka, omogućavajući injektovanje servisa u klase umesto da klase same kreiraju zavisnosti.

## Proxy obrazac

### Opis

Proxy obrazac pruža zamenu ili mesto za drugi objekat radi kontrole pristupa njemu, često se koristi za lazy loading ili kontrolu objekta.

### Upotreba u Doctrine-u

Doctrine koristi Proxy obrazac za entitete pri radu sa lazy loadingom. Proxy-ji su automatski generisane klase koje proširuju entitete radi dodavanja mogućnosti lazy loadinga.

## Zaključak

Symfony i Doctrine koriste ove dizajn obrasce da bi pružili robustan, fleksibilan i održiv framework za razvoj web aplikacija. Razumevanje ovih obrazaca i njihove primene unutar Symfony-ja i Doctrine-a može značajno poboljšati vašu sposobnost da efektivno koristite ove alate.

## Dodatni dizajn obrasci u Symfony-ju i Doctrine-u

### Symfony

- **Singleton**: Kontejner servisa deluje slično Singletonu unutar opsega svakog zahteva.
- **Service Locator**: Koristi se unutar `\Symfony\Component\DependencyInjection\ServiceLocator` za dinamičko preuzimanje servisa.
- **Decorator**: Klase koje se mogu pratiti kao `TraceableEventDispatcher` implementiraju Decorator obrazac za poboljšanu funkcionalnost.
- **Adapter**: Apstrahuje razlike u drajverima keša, omogućavajući uniformno upravljanje kešom kroz različite pozadine.
- **Observer+Mediator**: `EventDispatcher` kombinuje ove obrasce za rukovanje događajima i komunikaciju servisa.
- **Command Bus**: Messenger komponenta služi kao command bus, rukujući slanjem i obradom komandi.
- **Factory**: Ekstenzivno se koristi za kreiranje i konfiguraciju servisa, kao u `ArgumentMetadataFactory`.
- **Composite**: Komponenta formi koristi Composite obrazac za uniformno rukovanje i renderovanje polja formi.

### Doctrine

- **Unit Of Work**: Upravlja promenama objekata i upisuje ih kao jednu transakciju.
- **Facade**: `EntityManager` pruža pojednostavljen interfejs za ORM funkcionalnosti.
- **Identity Map**: Osigurava da se svaki entitet učita samo jednom po transakciji radi održavanja konzistentnosti.
- **Data Mapper**: Razdvaja objektnu reprezentaciju od šeme baze podataka, koristeći entitete mapirane na tabele baze podataka.
- **Proxy**: Omogućava lazy loading entiteta kroz automatski generisane proxy klase.
- **Fluent Interface**: Koristi se u `QueryBuilder`-u i setter metodama entiteta za čitljiviji i ulančan stil pozivanja metoda.
- **Builder**: `QueryBuilder` exemplifikuje Builder obrazac, omogućavajući konstruisanje složenih upita.

[Dokumentacija i dodatni resursi](https://symfony.com/doc/current/service_container/factories.html)
