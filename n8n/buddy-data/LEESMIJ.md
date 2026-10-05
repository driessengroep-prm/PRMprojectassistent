# Opslag in Buddy Data

De gesprekken gaan naar het Buddy Data-project `prm_projectassistent`. Dit
vervangt de Excel-werkmap.

## Waarom niet langer Excel

De werkmap hing aan een persoonlijke OneDrive, en dat alleen al is voor productie
onhandig genoeg. Maar ook op een teamlocatie blijven drie dingen wringen:

- **32.767 tekens per cel.** Daarom bestonden de kolommen `forum1` tot en met
  `forum6`: dat knipwerk was er puur om Excel. Postgres kent die grens niet.
- **Elke peiling is een aanroep van de Graph-API.** Een vraag van drie minuten
  doet er zo'n veertien. Traag, en het loopt tegen snelheidslimieten aan.
- **Geen gelijktijdigheid.** Twee collega's die tegelijk antwoord krijgen,
  schrijven tegelijk in hetzelfde bestand.

En de koppeling hing niet aan de locatie maar aan de credential: een persoonlijk
Microsoft-account. Verhuizen naar SharePoint lost dat niet op.

## De sleutel hoort niet in de pagina

`index.html` is een statisch bestand. De Entra-login bepaalt wat je te zien
krijgt, niet wat je kunt opvragen — dat staat ook in de toelichting bij het
inlogblok. Een `client_secret` daarin is leesbaar voor iedere collega met F12.

**Daarom schrijft n8n, niet de browser.** Het geheim staat in de credential-kluis
van n8n en komt nergens anders voor, ook niet in deze repository.

## Stap 1 — de tabellen

Tabellen maak je in het beheerscherm:
**https://buddy.driessengroep.nl/databases/prm_projectassistent**, tabblad
*Tabellen*. `id` en `created_at` komen er vanzelf bij.

Zet bij alle drie de toegang op **Alleen de applicatie**. Dat is niet zomaar de
veilige keuze maar precies wat er is afgesproken: een collega mag de gesprekken
van een ander niet inzien. Met deze stand is er vanuit de browser überhaupt geen
weg naar deze tabellen; alles loopt via n8n. De afscherming zit daarmee in de
database zelf en niet in een filter dat iemand kan omzeilen. **Achteraf is dit
niet meer om te zetten**, dus kies hem meteen goed.

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
| `titel` | text | de eerste vraag, afgekapt |
| `bijgewerkt` | timestamptz | |

**`beurten`**

| kolom | type | opmerking |
|---|---|---|
| `beurt_id` | text | verplicht, uniek — de `beurtId` van de pagina |
| `sessie_id` | text | |
| `entra_oid` | text | |
| `vraag` | text | |
| `modus` | text | snel of grondig |
| `advies` | text | |
| `forum` | jsonb | het hele overleg |
| `klaar_op` | timestamptz | |

Zet een **index** op `beurten.beurt_id` (daar wordt elke paar seconden op
gezocht tijdens het peilen), op `beurten.sessie_id` en op `gesprekken.entra_oid`.

Wat er bewust **niet** in gaat: de tekst van meegestuurde bestanden. Die hoort bij
die ene vraag en heeft in een archief niets te zoeken.

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
nieuw exemplaar. Precies wat de Buddy-handleiding voorschrijft, zonder Code-node.
En het geheim staat versleuteld in de kluis in plaats van als tekst in een node.

De HTTP Request-nodes zetten **Authentication** op *Generic Credential Type* →
*OAuth2 API* en kiezen deze credential.

## Stap 3 — de nodes

In `nodes.json` staan vier nodes om op het canvas van **PRM 1** te plakken.
*Resultaat klaarzetten (Buddy)* komt achter *Forumweergave*; de drie schrijfnodes
hangen daar alle drie achter en draaien naast elkaar.

| node | vervangt / doet |
|---|---|
| **Resultaat klaarzetten (Buddy)** | vervangt *Resultaat klaarzetten* |
| **Beurt wegschrijven** | vervangt *Resultaat wegschrijven* (de Excel-node) |
| **Gebruiker vastleggen** | houdt `gebruikers` bij |
| **Gesprek bijwerken** | houdt `gesprekken` bij |

Op *Gebruiker vastleggen* en *Gesprek bijwerken* staat **On Error** op
*Continue*. Dat is opzet: gaat de administratie mis, dan mag dat het antwoord aan
de gebruiker nooit kosten. Op *Beurt wegschrijven* staat dat juist níét — als die
rij er niet komt, vindt de peiling hem nooit en blijft de gebruiker wachten.

Verwijder daarna de oude Excel-nodes en de werkmap.

## Stap 4 — PRM 3 laten lezen

*Resultaat ophalen* leest nu uit Excel. Vervang de node **Rij zoeken** door een
HTTP Request met dezelfde credential:

```
GET https://buddy.driessengroep.nl/data/beurten?beurt_id=eq.{{ $json.query.beurtId }}&select=beurt_id,advies,forum
Header: Accept-Profile: app_prm_projectassistent
```

Vraag `beurt_id` expliciet op in de selectie. Daarmee kun je straks zien of er
werkelijk een rij is: een advies kan leeg zijn, een gevuld `beurt_id` niet.

Zet **Always Output Data** aan. Dat is hier geen detail maar de kern. PostgREST
geeft een lege lijst terug zolang de rij er nog niet is, en n8n maakt van een
lege lijst nul items — dan stopt de workflow, komt de Respond-node niet aan de
beurt, en krijgt de pagina niets in plaats van `bezig`. Met Always Output Data
levert de node een leeg item en loopt het door.

*Antwoord samenstellen* wordt eenvoudiger — het forum hoeft niet meer uit zes
kolommen aan elkaar geplakt te worden:

```js
// Hoe n8n een lijst teruggeeft verschilt per versie: soms een item per rij,
// soms één item met de hele lijst erin. Daarom vangen we beide vormen op.
const binnen = $input.first()?.json ?? {};
const rij = Array.isArray(binnen) ? binnen[0] : binnen;

if (!rij || !rij.beurt_id) { return [{ json: { status: 'bezig' } }]; }

return [{
  json: { status: 'klaar', output: rij.advies ?? '', forum: rij.forum ?? [] },
}];
```

## Wat hierna nog komt

**De zijbalk leest nog uit de browser.** De gesprekken staan straks in Buddy Data,
maar de pagina haalt ze nog uit localStorage. Een terugleesroute is een volgende
stap, en die vraagt iets extra's: de pagina moet haar Entra-token meesturen en
n8n moet dat controleren. Zonder die controle zou iemand die het verzoek nabootst
de gesprekken van een collega kunnen opvragen — wat de browser beweert over wie
hij is, mag je niet geloven.

Daarom gaat er nu bewust **géén token** mee: er is nog niets dat het controleert,
en het zou in de uitvoeringslogboeken van n8n belanden.

**Opruimen.** Zonder bewaartermijn groeit de tabel oneindig. Een workflow met een
Schedule Trigger die alles ouder dan X maanden verwijdert, volstaat.

## Wat getest is, en wat niet

Getest: dat de pagina de ingelogde gebruiker meestuurt, en dat ze dat veld weglaat
als er niemand is ingelogd (lokaal wordt de login overgeslagen).

**Niet getest: alles wat Buddy Data raakt.** `buddy.driessengroep.nl` is een
intern adres en vanaf de bouwomgeving niet bereikbaar. De opzet gaat ervan uit dat
Buddy Data **PostgREST** is — de combinatie van `/data/<tabel>`, `Accept-Profile`
en `Content-Profile` is daar kenmerkend voor. Klopt dat, dan werken ook
`?beurt_id=eq.<waarde>` voor filteren en `Prefer: resolution=merge-duplicates`
voor bijwerken-of-invoegen.

Loop daarom deze drie na bij de eerste test:

1. **Het bijwerken van `gebruikers` en `gesprekken`.** Werkt
   `Prefer: resolution=merge-duplicates` niet, dan ontbreekt een unieke index op
   `entra_oid` respectievelijk `sessie_id`, of doet Buddy Data het anders.
   Terugvaloptie: eerst een GET, dan zelf een POST of PATCH.
2. **Het filteren in PRM 3.** Geeft `?beurt_id=eq.<id>` een foutmelding in plaats
   van een array, dan is de filtersyntaxis anders.
3. **De `Content-Profile`-header.** De handleiding noemt dit met zoveel woorden de
   fout die het vaakst gemaakt wordt: zonder die header kom je in het verkeerde
   project uit of krijg je een 404.
