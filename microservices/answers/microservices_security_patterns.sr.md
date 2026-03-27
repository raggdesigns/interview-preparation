## Bezbednosni obrasci u mikroservisima

Obezbedjivanje bezbednosti u arhitekturi mikroservisa podrazumeva zaštitu svakog mikroservisa i komunikacije
izmedju njih. Ovo kompleksno okruženje zahteva sveobuhvatan pristup bezbednosti koji obuhvata nekoliko obrazaca i
praksi.

### Autentikacija i autorizacija

Implementirati robusne mehanizme autentikacije i autorizacije kako za korisnike, tako i za servise. Korišćenje OAuth,
OpenID Connect i JSON Web Tokens (JWT) su uobičajene strategije za obezbedjivanje komunikacije servis-servis i
korisnik-servis.

### API Gateway

Koristiti API gateway za primenu bezbednosnih politika, autentikaciju API zahteva i pružanje jedinstvene ulazne tačke
za spoljne klijente, čime se smanjuje površina napada na mikroservise.

### Enkripcija

Enkriptovati podatke u prenosu izmedju servisa korišćenjem TLS, kao i podatke u mirovanju, radi zaštite osetljivih
informacija i osiguravanja usklađenosti sa privatnošću.

### Service Mesh

Service mesh pruža namjenski infrastrukturni sloj za upravljanje komunikacijom izmedju servisa, omogućavajući
implementaciju konzistentnih bezbednosnih politika, uključujući mutual TLS za enkriptovanu i autentifikovanu
komunikaciju izmedju servisa.

### Upravljanje tajnama

Koristiti alate za upravljanje tajnama radi bezbednog čuvanja, pristupa i upravljanja akreditivima, ključevima i
ostalim osetljivim konfiguracionim detaljima koje zahtevaju mikroservisi.

### Primer: Sistem elektronskih zdravstvenih kartona

Razmotrimo sistem elektronskih zdravstvenih kartona koji koristi mikroservise za bezbedno i efikasno upravljanje
podacima pacijenata:

- **Servis za evidenciju pacijenata**: Upravlja pristupom zdravstvenim kartonima pacijenata.
- **Servis za autentikaciju**: Autentifikuje korisnike i servise, izdajući JWT tokene za ovlašćen pristup.
- **Servis za zakazivanje termina**: Upravlja zakazivanjem i praćenjem pacijentskih termina.
- **Servis za recepte**: Upravlja ljekarskim receptima i evidencijom pacijentskih lekova.

U ovom sistemu, API Gateway funkcioniše kao bezbedna ulazna tačka, primenjujući politike autentikacije i autorizacije
zasnovane na JWT tokenima koje izdaje servis za autentikaciju. Komunikacija izmedju servisa, kao što je pristup
kartonima pacijenata za termin ili generisanje recepta, obezbedjuje se kroz mutual TLS, čime se osigurava da su podaci
u prenosu enkriptovani i dostupni samo autentifikovanim i ovlašćenim servisima. Alati za upravljanje tajnama bezbedno
rukuju akreditivima servisa i ključevima za enkripciju, osiguravajući zaštitu osetljivih informacija.
