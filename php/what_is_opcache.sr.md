# Šta je OPCache

OPCache je ugrađena komponenta PHP engine-a koja skladišti kompajlirane instrukcije skripte u deljenu memoriju.
Bez OPCache-a, PHP parsira i kompajlira fajlove pri mnogo zahteva; sa OPCache-om, većina zahteva preskače taj korak.
Na intervjuima, ova tema testira da li razumete stvarne osnove performansi u produkciji u PHP-u.

## Preduslovi

- Znate da se PHP fajlovi kompajliraju u opkodove pre izvršavanja
- Znate šta `php.ini` kontroliše u ponašanju pri pokretanju
- Razumete osnovni tok uvođenja (novo izdanje, reload, zagrevanje)

## Osnovna ideja

Tok zahteva sa OPCache-om:

1. Prvi zahtev kompajlira PHP fajl i skladišti opkodove u deljenu memoriju.
2. Sledeći zahtevi ponovo koriste cached opkodove.
3. Troškovi procesora i latencija odziva opadaju jer se ponovljeno kompajliranje izbegava.

## Zašto je važno

- Manji procesorski teret na PHP-FPM worker-ima
- Niže prosečno i p95 vreme odziva
- Bolji throughput na istom hardveru

## Primer praktične konfiguracije

```ini
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=50000
opcache.validate_timestamps=1
opcache.revalidate_freq=2
```

Kako brzo objasniti ove opcije:

- `memory_consumption`: veličina cache-a za opkodove
- `max_accelerated_files`: broj cached skripti
- `validate_timestamps` i `revalidate_freq`: kako se detektuju promene koda

## Razmatranja pri uvođenju

- U razvoju, validacija timestamp-a je obično omogućena.
- U produkciji, timovi često smanjuju provere i resetuju cache tokom uvođenja.
- Nakon uvođenja, zagrejte kritične rute da biste izbegli skokove latencije pri prvom pogotku.

## Česte greške

- Previše mali cache uzrokuje česta izbacivanja.
- Velika baza koda sa niskim `max_accelerated_files` smanjuje stopu pogodaka.
- Netačan proces uvođenja može privremeno posluživati zastareli kod.

## Pitanja za intervju

- Šta OPCache tačno optimizuje?
- Koje biste postavke prvo proverili na zauzetom API-ju?
- Zašto strategija uvođenja može uticati na ponašanje OPCache-a?

## Zaključak

OPCache je jedno od poboljšanja performansi PHP-a sa najvećim uticajem i najnižim rizikom.
Ako je ispravno konfigurisano i uvedeno, smanjuje ponovljeni posao kompajliranja i poboljšava konzistentnost latencije zahteva.
