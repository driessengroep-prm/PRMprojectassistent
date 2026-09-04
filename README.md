# PRM Projectassistent — overlegruimte

Front-end voor de n8n-workflow *Projectenassistent PRM*. De pagina toont per beurt
jouw vraag, het overleg dat de regisseur op de achtergrond met de specialisten
voerde, en daarna pas zijn advies.

Draait als losse HTML-pagina, zonder build en zonder afhankelijkheden.

## Publiceren

De pagina staat als `index.html` in de root. Zet in **Settings → Pages** de source op
`Deploy from a branch`, branch `main`, folder `/ (root)`. Na een minuut staat hij op:

```
https://driessengroep-prm.github.io/PRMprojectassistent/
```

## Koppelen aan n8n

Nodig is de **production**-URL van de node *When chat message received*
(in n8n zichtbaar als Chat URL, eindigend op `/chat`). Drie manieren om die mee te geven:

1. Plakken in het veld rechtsboven op de pagina.
2. Meegeven in de adresbalk: `...github.io/PRMprojectassistent/?webhook=https://...`
   Handig als bladwijzer.
3. Vastzetten in `index.html`, in `STANDAARD_WEBHOOK` bovenaan het script.
   Alleen doen als deze repository op private staat.

In n8n moet daarnaast:

- de workflow **actief** staan;
- bij de Chat Trigger onder **Allowed Origins (CORS)** de waarde
  `https://driessengroep-prm.github.io` staan (of `*` tijdens testen);
- **Response Mode** op *When Last Node Finishes*;
- de laatste node *Forumweergave* zijn, die `output` en `forum` teruggeeft.

## Toegang beperken

GitHub Pages is openbaar. De pagina zelf bevat niets gevoeligs, maar wie de
webhook-URL heeft, kan de workflow aanroepen en verbruikt jouw executions en tokens.

Zet daarom bij de Chat Trigger **Authentication** op *Basic Auth* en koppel een
credential. De pagina heeft rechtsboven een veld voor gebruikersnaam en wachtwoord;
die worden als `Authorization`-header meegestuurd en nergens opgeslagen — na een
refresh typ je ze opnieuw.

## Twee dingen die het vaakst misgaan

**Mixed content.** GitHub Pages draait op https. Staat n8n op `http://`, dan blokkeert
de browser het verzoek voordat het verstuurd wordt. n8n moet dan achter https.

**Bereikbaarheid.** Het verzoek gaat vanuit de browser van de bezoeker, niet vanuit
GitHub. Een n8n die alleen op het interne netwerk draait, werkt dus prima voor wie op
dat netwerk zit — en voor niemand anders.
