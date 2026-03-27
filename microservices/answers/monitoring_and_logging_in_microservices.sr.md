## Monitoring i logovanje u mikroservisima

Efikasan monitoring i logovanje su kritični za upravljanje arhitekturama mikroservisa u velikom obimu. Oni pružaju uvid
u zdravlje, performanse i ponašanje servisa, olakšavajući rešavanje problema i operativnu efikasnost.

### Centralizovano logovanje

Agregirati logove svih mikroservisa u centralizovanu platformu za logovanje radi omogućavanja efikasnog pretraživanja,
vizualizacije i analize. Alati kao što su ELK Stack (Elasticsearch, Logstash, Kibana) ili Splunk se uobičajeno
koriste.

### Distribuirano praćenje (Distributed Tracing)

Implementirati distribuirano praćenje radi praćenja zahteva dok prolaze kroz više mikroservisa. Ovo pomaže u
identifikaciji uskih grla, grešaka i zavisnosti. OpenTracing i OpenTelemetry su popularni okviri za distribuirano
praćenje.

### Prikupljanje metrika

Prikupljati i analizirati metrike svakog mikroservisa, uključujući vreme odgovora, stope grešaka i korišćenje
resursa. Prometheus, zajedno sa Grafanom za vizualizaciju, je široko usvojen za prikupljanje i monitoring metrika.

### Provere zdravlja

Implementirati provere zdravlja (health checks) za svaki mikroservis radi nadzora dostupnosti i funkcionalnosti. Ove
provere se mogu koristiti za automatizovano otkrivanje servisa i donošenje odluka o orkestiranju.

### Upozoravanja (Alerting)

Podesiti upozoravanja zasnovana na logovima, metrikama i proverama zdravlja kako bi se timovi obaveštavali o
potencijalnim problemima pre nego što utiču na korisnike. Pravila upozoravanja treba fino podešavati kako bi se
izbegao umor od upozorenja.

### Primer: Online servis za strimovanje videa

Razmotrimo online servis za strimovanje videa dizajniran sa mikroservisima:

- **Servis za otkrivanje sadržaja**: Pomaže korisnicima da pronalaze video zapise i serije.
- **Servis za strimovanje**: Upravlja strimovanjem videa korisnicima.
- **Servis za korisničke profile**: Čuva korisničke preference i istoriju gledanja.
- **Servis za analitiku**: Prikuplja statistike gledanja i ponašanje korisnika.

Za ovaj servis, centralizovano logovanje omogućava agregaciju logova svih servisa radi dijagnostikovanja problema kroz
korisničko iskustvo otkrivanja i gledanja videa. Distribuirano praćenje pruža vidljivost celokupnog toka zahteva, od
otkrivanja sadržaja do strimovanja videa, omogućavajući identifikaciju problema sa kašnjenjem ili greškama u lancu
zahteva. Metrike o kvalitetu strimovanja, opterećenju korisnika i zdravlju servisa se prate u realnom vremenu, uz
upozorenja podešena za obaveštavanje operativnog tima o bilo kakvom degradiranju servisa ili ispadima. Provere
zdravlja osiguravaju da svaki servis funkcioniše kako se očekuje, a alati za orkestiranje automatski zamenjuju
nezdrave instance radi održavanja dostupnosti servisa.
