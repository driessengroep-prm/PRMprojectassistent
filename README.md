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

Nodig is de **production**-URL van de node *When chat message received*
(in n8n zichtbaar als Chat URL, eindigend op `/chat`).

Plak die één keer in het veld onder **Instellingen**, rechtsboven op de pagina.
De browser onthoudt hem, dus bij een volgend bezoek staat hij er al. Gebruiker en
wachtwoord worden bewust *niet* bewaard; die typ je na een refresh opnieuw.

Onthouden gebeurt per browser en per apparaat. Een collega die de pagina voor het
eerst opent, plakt de URL dus zelf één keer.

Twee alternatieven:

1. Meegeven in de adresbalk: `prm-projectassistent.driessengroep.nl/?webhook=https://...`
   Dat wint van wat er onthouden is. Handig als bladwijzer of om even een tweede
   workflow te testen.
2. Vastzetten in `index.html`, in `STANDAARD_WEBHOOK` bovenaan het script. Dan
   werkt de pagina meteen voor iedereen — maar **deze repository staat op public**,
   dus de URL is dan voor iedereen leesbaar. Wie hem heeft kan de workflow
   aanroepen en verbruikt jouw executions en tokens. Doe dit alleen met *Basic
   Auth* aan op de Chat Trigger; zie [Toegang beperken](#toegang-beperken).

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
tweede workflow opzet staat in [`n8n/LEESMIJ.md`](n8n/LEESMIJ.md).

Zonder resultaat-URL blijft de pagina gewoon op het antwoord wachten. Dat werkt
prima voor korte vragen.

## Toegang beperken

De pagina zelf bevat niets gevoeligs, maar wie de
webhook-URL heeft, kan de workflow aanroepen en verbruikt jouw executions en tokens.

Zet daarom bij de Chat Trigger **Authentication** op *Basic Auth* en koppel een
credential. De pagina heeft rechtsboven een veld voor gebruikersnaam en wachtwoord;
die worden als `Authorization`-header meegestuurd en nergens opgeslagen — na een
refresh typ je ze opnieuw.

## Twee dingen die het vaakst misgaan

**Mixed content.** De pagina draait op https. Staat n8n op `http://`, dan blokkeert
de browser het verzoek voordat het verstuurd wordt. n8n moet dan achter https.

**Bereikbaarheid.** Het verzoek gaat vanuit de browser van de bezoeker, niet vanuit
de server. Een n8n die alleen op het interne netwerk draait, werkt dus prima voor wie op
dat netwerk zit — en voor niemand anders.
