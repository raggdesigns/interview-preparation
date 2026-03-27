# Sharding

Sharding znači raspodelu podataka po više servera baze podataka kako jedan server ne bi postao usko grlo.
Na intervjuima, obično se očekuje da objasniš kada je sharding potreban, kako odabrati shard ključ i koji kompromisi dolaze sa njim.

## Preduslovi

- Razumeš ograničenja skaliranja jedne baze podataka (CPU, skladište, IOPS)
- Poznaješ osnovne koncepte indeksiranja i particionisanja
- Znaš da su cross-shard transakcije teže od transakcija na jednom čvoru

## Osnovna ideja

Postoje dva uobičajena obrasca:

- Vertikalni sharding: podeli po funkcionalnosti ili grupi tabela.
- Horizontalni sharding: podeli redove iste tabele po shard ključu.

## Vertikalni sharding

Premeštaš različite domene u različite baze podataka.

Primer:

- `users` i `profiles` u jednoj bazi podataka
- `orders` i `payments` u drugoj bazi podataka

Dobro kada su timovi i opterećenja jasno razdvojena.
Rizik: poslovni tokovi mogu zahtevati cross-database join-ove ili distribuirane transakcije.

## Horizontalni sharding

Zadržavaš istu shemu na svakom shard-u, ali svaki shard čuva samo deo redova.

Primer sa tabelom `users`:

- Shard 0 čuva korisnike gde je `user_id % 4 = 0`
- Shard 1 čuva korisnike gde je `user_id % 4 = 1`
- Shard 2 čuva korisnike gde je `user_id % 4 = 2`
- Shard 3 čuva korisnike gde je `user_id % 4 = 3`

Dobro za veoma veliki broj redova i visok volumen pisanja.
Rizik: loš odabir shard ključa kreira vruće shard-ove.

## Kako odabrati shard ključ

Odaberi ključ koji:

- Je prisutan u većini upita čitanja i pisanja
- Ravnomerno distribuira saobraćaj
- Se ne menja često

Uobičajeni izbori: `user_id`, `tenant_id`, region ili vremenski bucket (sa oprezom zbog hotspot-ova).

## Praktičan primer rutiranja

```php
<?php

final class ShardRouter
{
    public function shardForUser(int $userId, int $shardCount): int
    {
        return $userId % $shardCount;
    }
}
```

Tok aplikacije:

1. Pročitaj `user_id` iz konteksta zahteva.
2. Izračunaj broj shard-a.
3. Pošalji upit samo na taj shard.

## Kompromisi za pominjanje na intervjuu

- Rebalansiranje je operativno skupo.
- Cross-shard upiti i join-ovi su složeni.
- Jedinstvena ograničenja po svim shard-ovima su teža za sprovođenje.
- Backup-ovi i failover postaju operacije na više čvorova.

## Zaključak

Sharding rešava ograničenja skaliranja jedne baze podataka, ali dodaje složenost aplikacije i operacija.
Koristi ga kada vertikalno skaliranje, indeksiranje i podešavanje upita više nisu dovoljni, i jasno objasni strategiju shard ključa.
