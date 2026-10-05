# PRM Projectassistent — overlegruimte

Front-end voor de n8n-workflow *Projectenassistent PRM*. De pagina toont per beurt
jouw vraag, het overleg dat de regisseur op de achtergrond met de specialisten
voerde, en daarna pas zijn advies.

Draait als losse HTML-pagina, zonder build en zonder afhankelijkheden.

## Waar de pagina draait

https://prm-projectassistent.driessengroep.nl — alleen voor wie een Driessen-account heeft.
Inloggen gaat via Microsoft; op een werklaptop die al ingelogd is merk je daar niets van.
Lokaal (`file://` of `localhost`) wordt het inloggen overgeslagen.

Het inloggen is een slot in de browser, geen slot op de server: de HTML zelf is voor
iedereen op te vragen. De webhook bewaakt n8n dus nog steeds zelf; zie
[Toegang beperken](#toegang-beperken).

## Publiceren

Een push naar `main` publiceert vanzelf (`.github/workflows/deploy-vm.yml`). Met de hand
kan ook, met SSH-toegang tot de VM:

```bash
./scripts/publiceer.sh
```

Caddy op de buddy-production VM serveert de bestanden uit
`/data/caddy/apps/prm-projectassistent`; er draait daar geen applicatie.

Wat er eenmalig moet staan:

- een A-record `prm-projectassistent.driessengroep.nl` → `40.115.59.118`
- op de VM: `mkdir -p /data/caddy/apps/prm-projectassistent` en dit blok in de Caddyfile
  (daarna Caddy herladen):

  ```
  prm-projectassistent.driessengroep.nl {
  	root * /data/apps/prm-projectassistent
  	encode gzip
  	file_server
  	header /index.html Cache-Control "no-cache"
  	log {
  		output file /var/log/caddy/prm-projectassistent-access.log
  		format json
  	}
  }
  ```

- het repository-secret `VM_SSH_KEY` — een privésleutel waarmee de workflow bij
  `buddy-admin@40.115.59.118` kan, base64-gecodeerd: `base64 -i ~/prm-deploy | pbcopy`
- `https://prm-projectassistent.driessengroep.nl/` als redirect-URI (platform
  *Toepassing met één pagina*) in de Entra-app-registratie
  `cb2c6818-aff1-4b27-b84b-df3373b158a1` — dezelfde die Coco gebruikt
- bij de Chat Trigger in n8n onder **Allowed Origins (CORS)**:
  `https://prm-projectassistent.driessengroep.nl`

Is het subdomein in de lucht, zet GitHub Pages dan uit (**Settings → Pages**). Daar staat
de pagina zonder login.

## Koppelen aan n8n

De pagina gebruikt vier webhook-adressen. Die komen **bij het publiceren** in de
pagina, uit de secrets van GitHub, zodat een collega niets hoeft in te stellen:

| secret | workflow |
|---|---|
| `PRM_WEBHOOK_URL` | PRM 1, de chat trigger (eindigt op `/chat`) |
| `PRM_RESULTAAT_URL` | PRM 3, het resultaat ophalen |
| `PRM_VERWIJDER_URL` | PRM 4, een gesprek verwijderen |
| `PRM_LIJST_URL` | PRM 5, gesprekken teruglezen |

Zet ze onder *Settings → Secrets and variables → Actions*. Ze staan dus **niet**
in deze repository, die openbaar is. Ontbreekt er een, dan blijft dat veld leeg
en meldt het publiceerlogboek welke; de rest werkt gewoon door.

Ze staan wél in de pagina die iedereen kan opvragen. Dat kan, omdat alle vier de
workflows bij Microsoft navragen wie je bent voordat ze iets doen — zie
[Toegang beperken](#toegang-beperken). Zonder die controle is een adres in de
pagina een open uitnodiging om je executions en tokens op te maken.

Je kunt ze altijd overschrijven onder **Instellingen**, rechtsboven op de pagina.
Wat je daar invult wordt in je browser onthouden en wint van wat is meegebakken.
Let op: het wissen van cookies en site-gegevens wist dat ook weer, en dan vallen
de velden terug op de meegebakken adressen.

Meegeven in de adresbalk kan ook:
`prm-projectassistent.driessengroep.nl/?webhook=https://...` wint van allebei.
Handig als bladwijzer of om even een tweede workflow te testen. Dat werkt ook
met `?resultaat=`, `?verwijder=` en `?lijst=`.

In n8n moet daarnaast:

- de workflow **actief** staan;
- bij de Chat Trigger onder **Allowed Origins (CORS)** de waarde
  `https://prm-projectassistent.driessengroep.nl` staan (of `*` tijdens testen);
- **Response Mode** op *When Last Node Finishes*;
- de laatste node *Forumweergave* zijn, die `output` en `forum` teruggeeft.

## Lange vragen

n8n Cloud staat achter een gateway die een verbinding na ongeveer honderd
seconden verbreekt. Een uitgebreide onderzoeksvraag duurt langer, en dan is het
antwoord wél gemaakt maar kan de pagina het niet meer ontvangen.

Vul daarvoor onder **Instellingen** ook een **Resultaat-URL** in. De pagina laat
de verbinding dan los zodra de vraag verstuurd is, en haalt het antwoord daarna
apart op — net zolang tot het klaar staat, tot maximaal tien minuten. Hoe je die
tweede workflow opzet staat in [`n8n/buddy-data/LEESMIJ.md`](n8n/buddy-data/LEESMIJ.md).

Zonder resultaat-URL blijft de pagina gewoon op het antwoord wachten. Dat werkt
prima voor korte vragen.

## Toegang beperken

De webhook-adressen staan in de pagina, en de pagina is op te vragen. Het slot zit
dus niet op het adres maar op de workflow: **alle vier vragen bij Microsoft na wie
je bent** voordat ze iets doen.

De pagina stuurt een token mee dat Microsoft heeft uitgegeven. De workflow vraagt
daarmee bij Microsoft Graph op wie de houder is. Wie het adres vindt maar geen
inlog van Driessen heeft, krijgt een 401 en verder niets.

Dat de browser zegt wie hij is, telt nergens mee. Daardoor kan een nagebootst
verzoek ook niet de gesprekken van een collega opvragen of wissen, en niet
schrijven onder het kenmerk van iemand anders.

Hoe je die controle in PRM 1 hangt staat in
[`n8n/buddy-data/LEESMIJ.md`](n8n/buddy-data/LEESMIJ.md); PRM 4 en PRM 5 hebben
hem al ingebouwd.

Het veld voor gebruiker en wachtwoord rechtsboven blijft bestaan voor *Basic
Auth* op de Chat Trigger. Dat is nu een extra slot en niet meer het enige. Die
gegevens worden nergens opgeslagen — na een refresh typ je ze opnieuw.

## Twee dingen die het vaakst misgaan

**Mixed content.** De pagina draait op https. Staat n8n op `http://`, dan blokkeert
de browser het verzoek voordat het verstuurd wordt. n8n moet dan achter https.

**Bereikbaarheid.** Het verzoek gaat vanuit de browser van de bezoeker, niet vanuit
de server. Een n8n die alleen op het interne netwerk draait, werkt dus prima voor wie op
dat netwerk zit — en voor niemand anders.
