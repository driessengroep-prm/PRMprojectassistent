# Wegschrijven naar Buddy Data

De gesprekken gaan naar het Buddy Data-project `prm_projectassistent`. Dit
beschrijft hoe, en vooral: waar de sleutel wél en niet mag staan.

## De sleutel hoort niet in de pagina

`index.html` is een statisch bestand. De Entra-login bepaalt alleen wat je te
zien krijgt — de broncode zelf is gewoon op te vragen, en dat staat ook al in de
toelichting bovenaan het inlogblok:

> Dit is een slot in de browser, geen slot op de server: de HTML zelf is voor
> iedereen op te vragen.

Een `client_secret` in die pagina is dus leesbaar voor iedere collega met F12,
en geeft lees- én schrijfrechten op de hele database. Een `.env` helpt daar niet
tegen: die wordt niet meegebundeld, maar de browser moet de waarde kennen, dus
staat hij alsnog in de netwerk-tab.

**Daarom schrijft n8n, niet de browser.** De pagina stuurt haar vraag zoals
altijd naar n8n; n8n praat met Buddy Data. De sleutel staat in de credential-kluis
van n8n en komt nergens anders voor — niet in een node, niet in deze repo.

De pagina stuurt sinds deze wijziging wel mee *wie* de vraag stelt:

```json
"gebruiker": { "oid": "...", "naam": "...", "email": "..." }
```

De `oid` uit het Entra-token is het enige kenmerk dat niet verandert; een naam of
e-mailadres kan wijzigen. Koppel daarop. Er gaat bewust géén Microsoft-token mee:
n8n heeft er niets aan en het zou onnodig rondreizen.

## Stap 1 — de tabellen

Tabellen maak je niet via de API maar in het beheerscherm:
**https://buddy.driessengroep.nl/databases/prm_projectassistent**, tabblad
*Tabellen*. `id` en `created_at` komen er vanzelf bij.

Zet bij alle drie de toegang op **Alleen de applicatie**. Niemand praat vanuit de
browser met deze tabellen, alleen n8n. Die keuze is achteraf niet om te zetten.

**`gebruikers`**

| kolom | type | opmerking |
|---|---|---|
| `entra_oid` | text | verplicht, uniek — hierop koppel je |
| `naam` | text | |
| `email` | text | |
| `laatst_actief` | timestamptz | |

**`gesprekken`**

| kolom | type | opmerking |
|---|---|---|
| `sessie_id` | text | verplicht, uniek — de `sessionId` van de pagina |
| `entra_oid` | text | van wie het gesprek is |
| `titel` | text | |
| `bijgewerkt` | timestamptz | |

**`beurten`**

| kolom | type | opmerking |
|---|---|---|
| `beurt_id` | text | verplicht, uniek — de `beurtId` van de pagina |
| `sessie_id` | text | |
| `entra_oid` | text | |
| `vraag` | text | |
| `advies` | text | |
| `forum` | jsonb | het hele overleg |
| `klaar_op` | timestamptz | |

Zet een **index** op `beurten.beurt_id` (daar wordt elke paar seconden op
gezocht tijdens het peilen), op `beurten.sessie_id` en op `gesprekken.entra_oid`.
Zonder index wordt het traag zodra er rijen bij komen.

**Dit vervangt de Excel-werkmap.** De zes `forum1..6`-kolommen waren er alleen
omdat een Excel-cel maximaal 32.767 tekens houdt. Postgres kent die grens niet,
dus het forum gaat in één `jsonb`-kolom en al het knipwerk kan weg.

## Stap 2 — de credential in n8n

Maak **één** credential aan, van het type **OAuth2 API**:

| veld | waarde |
|---|---|
| Grant Type | *Client Credentials* |
| Access Token URL | `https://buddy.driessengroep.nl/api/buddy-data/token` |
| Client ID | `BUDDY_CLIENT_ID` |
| Client Secret | `BUDDY_CLIENT_SECRET` |
| Authentication | *Body* |

Waarom OAuth2 en niet zelf een token halen: n8n bewaart het token dan zelf,
hergebruikt het het uur dat het geldig is, en haalt bij een 401 automatisch een
nieuw exemplaar. Precies wat de Buddy-handleiding voorschrijft, zonder dat je er
een Code-node voor hoeft te schrijven. En het geheim staat versleuteld in de
kluis in plaats van als tekst in een node.

De HTTP Request-nodes zetten daarna **Authentication** op *Generic Credential
Type* → *OAuth2 API* en kiezen deze credential.

## Stap 3 — de nodes

In `nodes.json` staan twee nodes om op het canvas van **PRM 1** te plakken.

- **Gebruiker vastleggen** — achter de Chat Trigger. Houdt `gebruikers` bij.
- **Resultaat klaarzetten (Buddy)** — vervangt de bestaande *Resultaat
  klaarzetten*. Levert nu ook `entra_oid` en `vraag` mee, en knipt het forum niet
  meer in stukken.
- **Beurt wegschrijven** — vervangt *Resultaat wegschrijven* (de Excel-node).

De oude Excel-nodes staan nog in `n8n/nodes-voor-hoofdflow.json`. Die heb ik
bewust niet aangepast: zo blijft de bestaande route werken tot je de Buddy-route
hebt getest.

Op *Gebruiker vastleggen* staat **On Error** op *Continue*. Dat is opzet: gaat
de administratie mis, dan mag dat het antwoord aan de gebruiker nooit kosten.
Op *Beurt wegschrijven* staat dat juist niet — als die rij er niet komt, vindt de
peiling hem nooit en blijft de gebruiker wachten.

## Stap 4 — PRM 3 laten lezen

*Resultaat ophalen* leest nu uit Excel. Vervang de node **Rij zoeken** door een
HTTP Request met dezelfde credential:

```
GET https://buddy.driessengroep.nl/data/beurten?beurt_id=eq.{{ $json.query.beurtId }}&select=advies,forum
Header: Accept-Profile: app_prm_projectassistent
```

Zet **Always Output Data** aan, net als nu: zonder dat stopt de workflow zodra de
rij er nog niet is en krijgt de pagina niets in plaats van `bezig`.

*Antwoord samenstellen* wordt dan eenvoudiger — het forum hoeft niet meer uit zes
kolommen aan elkaar geplakt te worden:

```js
const rij = $input.first()?.json?.[0];      // PostgREST geeft een array terug
if (!rij) { return [{ json: { status: 'bezig' } }]; }
return [{ json: { status: 'klaar', output: rij.advies ?? '', forum: rij.forum ?? [] } }];
```

## Wat hiervan getest is, en wat niet

Getest: dat de pagina de ingelogde gebruiker meestuurt, en dat ze dat veld
weglaat als er niemand is ingelogd (lokaal wordt de login overgeslagen). Beide in
Chromium nagelopen.

**Niet getest: alles wat Buddy Data raakt.** `buddy.driessengroep.nl` is een
intern adres en vanaf de bouwomgeving niet bereikbaar. De opzet hierboven gaat
ervan uit dat Buddy Data **PostgREST** is — de combinatie van `/data/<tabel>`,
`Accept-Profile` en `Content-Profile` is daar kenmerkend voor. Klopt dat, dan
werken ook `?beurt_id=eq.<waarde>` voor filteren en `Prefer:
resolution=merge-duplicates` voor bijwerken-of-invoegen.

Loop daarom deze drie na bij de eerste test:

1. **Het bijwerken van `gebruikers`.** Werkt `Prefer: resolution=merge-duplicates`
   niet, dan is er geen unieke index op `entra_oid`, of doet Buddy Data het
   anders. Terugvaloptie: eerst `GET ...?entra_oid=eq.<oid>`, en dan zelf een
   POST of PATCH.
2. **Het filteren in PRM 3.** Geeft `?beurt_id=eq.<id>` een foutmelding in plaats
   van een array, dan is de filtersyntaxis anders.
3. **De `Content-Profile`-header.** De handleiding noemt dit met zoveel woorden
   de fout die het vaakst gemaakt wordt: zonder die header kom je in het
   verkeerde project uit of krijg je een 404.
