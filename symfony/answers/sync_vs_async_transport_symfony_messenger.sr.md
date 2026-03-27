
# Sinhroni vs asinhroni transport u Symfony Messenger-u

Symfony Messenger komponent pruža moćne mogućnosti razmene poruka za vaše aplikacije, omogućavajući odvajanje komponenti prosleđivanjem poruka između njih. Jedna od ključnih odluka pri korišćenju Messenger-a je izbor između sinhronog (sync) i asinhronog (async) transporta za obradu poruka.

## Sinhroni (Sync) transport

Kod sinhronog transporta, poruke se obrađuju odmah čim se dispečuju. To znači da pošiljalac poruke čeka da handler obradi poruku pre nego što nastavi. Sinhroni transport je sličan direktnom pozivu metode, ali umotanom u logiku obrade poruka Messenger-a.

### Slučajevi upotrebe sinhronog transporta

- **Neophodna neposredna povratna informacija**: Kada je potrebna trenutna obrada i povratna informacija korisniku ili sistemu.
- **Jednostavni radni tokovi**: U aplikacijama gde su radni tokovi direktni i ne zahtevaju pozadinsku obradu.

## Asinhroni (Async) transport

Asinhroni transport odlaže obradu poruka. Kada se poruka dispečuje, šalje se u red čekanja, a pošiljalac nastavlja bez čekanja da poruka bude obrađena. Poseban proces čita poruke iz reda čekanja i obrađuje ih, potencijalno mnogo kasnije.

### Slučajevi upotrebe asinhronog transporta

- **Pozadinska obrada**: Idealan za zadatke koji zahtevaju mnogo vremena, kao što su slanje e-mailova, generisanje izveštaja ili obrada otpremanja fajlova.
- **Skalabilnost**: Pomaže aplikacijama da se skaliraju prenosom teške obrade na pozadinske radnike, poboljšavajući propusnost zahteva.
- **Pouzdanost**: Povećava pouzdanost aplikacije omogućavanjem ponovnih pokušaja i odložene obrade u slučaju privremenih kvarova.

## Konfigurisanje sinhronog i asinhronog transporta

### Instalacija

Uverite se da imate instaliran Messenger komponent:

```bash
composer require symfony/messenger
```

### Konfiguracija

U `config/packages/messenger.yaml`, možete konfigurisati transporte i definisati koji transport treba da koristi poruka.

```yaml
framework:
    messenger:
        transports:
            async: '%env(MESSENGER_TRANSPORT_DSN)%'
            sync: 'sync://'

        routing:
            'App\Message\YourAsyncMessage': async
            'App\Message\YourSyncMessage': sync
```

U ovoj konfiguraciji:

- **Asinhroni transport**: Poruke tipa `YourAsyncMessage` se usmeravaju na asinhroni transport (npr. RabbitMQ, Redis).
- **Sinhroni transport**: Poruke tipa `YourSyncMessage` se obrađuju sinhrono korišćenjem `sync://` transporta.

## Zaključak

Izbor između sinhronog i asinhronog transporta u Symfony Messenger-u zavisi od specifičnih potreba vaše aplikacije, kao što su potreba za trenutnom obradom, izvršavanjem pozadinskih zadataka, skalabilnošću i pouzdanošću. Pravilno konfigurisanje i korišćenje ovih transporta može značajno poboljšati performanse vaše aplikacije i korisničko iskustvo.
