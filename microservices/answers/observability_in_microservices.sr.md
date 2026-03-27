## Observability u mikroservisima

Observability je ključni aspekt upravljanja i rada arhitektura mikroservisa. Podrazumeva sposobnost nadzora, logovanja i praćenja unutrašnjosti sistema, što je vitalno za razumevanje njegovog stanja i ponašanja. Ova sveobuhvatna vidljivost je neophodna za dijagnostikovanje problema, razumevanje uskih grla u performansama i osiguranje pouzdanosti sistema.

### Monitoring

Prikupljati metrike o operativnim aspektima mikroservisa, kao što su vreme odgovora, stope grešaka i korišćenje sistemskih resursa. Alati kao što su Prometheus i Grafana se uobičajeno koriste u svrhe monitoringa.

### Logovanje

Agregirati logove svih mikroservisa u centralizovani sistem logovanja radi olakšavanja pretraživanja, analize i upozoravanja. ELK Stack (Elasticsearch, Logstash, Kibana) i Splunk su popularni izbori za centralizovano logovanje.

### Praćenje (Tracing)

Implementirati distribuirano praćenje radi praćenja puta zahteva kroz mikroservise. Ovo pomaže u identifikaciji problema sa kašnjenjem i lociranju uzroka grešaka. OpenTelemetry pruža skup API-ja, biblioteka, agenata i instrumentacije za omogućavanje observability.

### Izazovi

- **Složenost**: Distribuirana priroda mikroservisa uvodi složenost u agregiranju i korelaciji podataka iz više izvora.
- **Obim**: Veliki obim podataka koji generišu mikroservisi može preopteretiti tradicionalne sisteme monitoringa i logovanja.
- **Dinamično okruženje**: Dinamičko skaliranje i deplojment mikroservisa zahteva da se alati za observability automatski prilagodjuju promenama u sistemu.

### Strategije

- **Standardizovati metrike, logove i tragove**: Usvojiti konzistentan format i konvencije za metrike, logove i tragove u svim mikroservisima.
- **Automatizovati otkrivanje anomalija**: Koristiti mašinsko učenje i statističku analizu za automatsko otkrivanje anomalija i potencijalnih problema.
- **Korelisati logove i tragove**: Integrisati sisteme logovanja i praćenja radi korelacije logova sa podacima o tragovima, čime se pojednostavljuje analiza uzroka.

### Primer: Online platni gateway

Razmotrimo online platni gateway koji se sastoji od nekoliko mikroservisa:

- **Servis za transakcije**: Obradjuje platne transakcije.
- **Servis za detekciju prevara**: Analizira transakcije u potrazi za lažnim obrascima.
- **Servis za obaveštenja**: Šalje korisnike obaveštenja o transakcijama.
- **Servis za naloge**: Upravlja korisničkim nalozima i autentikacijom.

Observability u ovom sistemu osigurava da se metrike performansi servisa za transakcije prate u realnom vremenu, omogućavajući trenutnu detekciju problema koji utiču na obradu transakcija. Centralizovano logovanje beleži logove svih servisa, omogućavajući brzu dijagnostiku grešaka ili bezbednosnih incidenata koje detektuje servis za detekciju prevara. Distribuirano praćenje omogućava praćenje toka transakcije korisnika kroz sistem, identifikujući uska grla ili greške koje se javljaju tokom procesa plaćanja.
