
# Lista Symfony Kernel dogadjaja i njihova objašnjenja

Symfony-jev HttpKernel komponent dispečuje nekoliko dogadjaja tokom obrade HTTP zahteva, omogućavajući programerima da se zakače na životni ciklus obrade zahteva radi prilagođenog ponašanja. U nastavku je lista glavnih kernel dogadjaja:

## kernel.request

- **Opis**: Ovaj dogadjaj se dispečuje na samom početku procesa obrade zahteva. Omogućava vam da izmenite zahtev ili vratite odgovor pre nego što se izvrši bilo koja druga logika.
- **Slučaj upotrebe**: Koristan za zadatke poput ranog čitanja i postavljanja atributa zahteva u životnom ciklusu zahteva, kao što su lokalizacija ili bezbednosni tokeni.

## kernel.controller

- **Opis**: Dispečuje se kada je kontroler koji treba da obradi zahtev već odredjen, ali pre nego što je pozvan. Omogućava vam da izmenite kontroler ili argumente koji mu se prosleđuju.
- **Slučaj upotrebe**: Idealan za omotavanje ili zamenu kontrolera, konverziju parametara ili injektovanje dodatnih argumenata u kontroler.

## kernel.controller_arguments

- **Opis**: Nastaje nakon što su argumenti kontrolera razrešeni. Omogućava vam da izmenite argumente koji se prosleđuju kontroleru.
- **Slučaj upotrebe**: Koristan za izmenu razrešenih argumenata kontrolera na osnovu određenih uslova ili dinamičko injektovanje dodatnih argumenata.

## kernel.view

- **Opis**: Okida se kada kontroler vrati vrednost koja nije `Response` objekat, dajući vam mogućnost da kreirate odgovor za nju.
- **Slučaj upotrebe**: Prikladan za transformisanje prilagođenih povratnih vrednosti iz kontrolera u `Response` objekte bez izmene koda kontrolera.

## kernel.response

- **Opis**: Dispečuje se nakon što kontroler vrati odgovor, omogućavajući dalje izmene odgovora pre nego što se pošalje klijentu.
- **Slučaj upotrebe**: Koristan za izmenu odgovora, postavljanje dodatnih zaglavlja ili logiku keširanje.

## kernel.finish_request

- **Opis**: Dispečuje se nakon što je odgovor poslat/obrađen, što ukazuje da je obrada zahteva skoro završena.
- **Slučaj upotrebe**: Idealan za zadatke čišćenja, kao što je zatvaranje konekcija sa bazom podataka ili logovanje metrika obrade zahteva.

## kernel.terminate

- **Opis**: Nastaje nakon što je odgovor poslat klijentu. Okida se samo u okruženjima koja podržavaju "terminaciju kernel-a" (npr. uz PHP-FPM).
- **Slučaj upotrebe**: Pogodan za vremenski zahtevne zadatke koji ne moraju da odlažu odgovor korisniku, kao što je slanje e-mailova ili obrada logova.

## kernel.exception

- **Opis**: Okida se kada dođe do neuhvaćenog izuzetka tokom procesa obrade zahteva, omogućavajući prilagođeno rukovanje izuzecima i generisanje odgovora.
- **Slučaj upotrebe**: Neophodan za implementaciju prilagođenih stranica sa greškama ili transformisanje izuzetaka u specifične formate odgovora (npr. JSON za API-je).

## Zaključak

Razumevanje i korišćenje Symfony kernel dogadjaja može značajno unaprediti vašu aplikaciju omogućavajući vam da intereagujete sa životnim ciklusom zahteva u različitim fazama, što omogućava prilagođenu logiku, rukovanje greškama i izmene odgovora.
