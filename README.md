# NonNarrato

Roguelike d'azione per Android, a scorrimento laterale: pixel art cupa alla Blasphemous, struttura a "run" alla Hades.
Sotto il mondo dorme qualcosa di antico; le leggende di ogni popolo sono le maschere che lo tengono addormentato.
Il protagonista è **il Non Narrato**: l'ultima leggenda, mai finita né raccontata, che prende forma nei sogni del Dormiente
e rinasce a ogni morte.

Nome del gioco e del repository sono provvisori.

## Stato: prototipo (una stanza di prova)

Serve a capire se lo stile e i comandi rendono come vogliamo, prima di costruire mondi e storia.
L'elenco di ciò che c'è è in [distribuzione/NOVITA.md](distribuzione/NOVITA.md).

## Scaricare il gioco

L'ultima versione di prova è sempre qui:
https://github.com/vincenzociriello91-hub/NonNarrato/releases/latest

Si scarica `NonNarrato.apk` e si installa sopra la versione precedente. Dal menu di pausa il gioco stesso avvisa
quando c'è una versione nuova.

## Comandi

| Azione | Controller | Tasti a schermo | Tastiera |
|---|---|---|---|
| Muoversi | leva sinistra o croce | leva a sinistra | A D / frecce |
| Saltare | A | Salto | Spazio |
| Attaccare (due colpi) | X | Colpo | J |
| Rotolare | B | Rotola | K |
| Schivare / scatto (con la direzione: avanti o indietro) | Y o RB | Schiva | L |
| Afferrare una cassa (tenere premuto) | LB | Afferra (solo vicino a una cassa) | E |
| Scavalcare un ostacolo basso | su + direzione | leva in diagonale | W + direzione |
| Scendere da una piattaforma | giù + A | giù + Salto | S + Spazio |
| Pausa e impostazioni | Start | II | Esc |
| Schermata di debug | Select | dal menu | F3 |

I tasti a schermo compaiono appena si tocca lo schermo e spariscono appena si usa un controller.

## Come nasce la grafica

Il metodo è quello di Dead Cells: i personaggi sono **modelli 3D animati**, fotografati di lato a bassa risoluzione
e salvati come fogli di sprite, ciascuno con la sua **mappa delle normali**. Nel gioco sono normali sprite 2D,
ma le torce li illuminano come se avessero volume. Un ultimo filtro porta i colori verso una palette fissa.

1. `python3 strumenti/genera_arte.py` — texture ricolorate dei modelli, palette, nebbia, icone.
2. `godot --path . -s res://strumenti/render_sprite.gd -- strumenti/render_sprite.json` — dai modelli in `sorgenti3d/`
   ai fogli in `arte/sprite/` (serve uno schermo, anche virtuale). Cosa renderizzare è scritto in `strumenti/render_sprite.json`.

I fogli già pronti sono nel repository: questi due passaggi servono solo quando si cambia un personaggio o un oggetto.

Il protagonista è diverso: cambia aspetto con l'equipaggiamento e ha più **gruppi di mosse** (una mano, affondi,
due mani, doppia arma, scudo, magia, a mani nude) scelti dall'arma o a mano. Le clip di ogni gruppo e le azioni da
provare nel menu sono in `arte/figure/protagonista.json`; i tempi di gioco restano nel codice.
Il resto funziona così: cambia aspetto con l'equipaggiamento, quindi non ha un foglio già pronto.
Tutti i personaggi KayKit hanno lo stesso scheletro, così teste, busti, braccia, gambe, mantelli, copricapi e armi
si possono scambiare. `strumenti/crea_manichino.gd` li mette tutti su un unico **manichino** (`modelli/manichino.scn`)
e nel gioco `script/figura_viva.gd` lo fotografa in tempo reale, nello stesso stile dei fogli (colore, normali, contorno),
solo quando cambia il fotogramma o l'aspetto. Gli oggetti indossabili e i colori sono in `script/equipaggiamento.gd`;
si scelgono dal menu di pausa, sezione Aspetto.

## Cartelle

- `script/` — il gioco. `principale.gd` avvia tutto; `stanza.gd` costruisce la stanza; `giocatore.gd`, `figura_viva.gd`,
  `equipaggiamento.gd`, `bot.gd`, `nemico.gd`,
  `rompibile.gd`, `proiettile.gd`; `dispositivo.gd` (riconoscimento e qualità), `controlli.gd`, `impostazioni.gd`,
  `rapporto.gd`; `hud.gd` e `menu.gd` per l'interfaccia.
- `shader/` — filtro palette e nebbia.
- `arte/` — sprite e grafica d'ambiente; `arte/figure/` le animazioni del protagonista. `modelli/` — il manichino.
  `sorgenti3d/` — modelli originali (non entrano nell'APK).
- `strumenti/` — strumenti di lavoro. `test/` — prova automatica.
- `distribuzione/` — novità e chiave di firma del canale di prova.

## Nemici e memoria del sogno

`script/memoria.gd` (autoload `Memoria`, file `user://memoria.cfg`) ricorda tre cose: le **nemesi** (chi ti uccide
torna più forte con nome e titolo; chi batti può tornare sfregiato), le **abitudini** di chi gioca e le **tattiche**
che funzionano contro di lui. `script/nemico.gd` usa questi ricordi: vista bloccata dai muri, udito, ricerca
dell'ultima posizione vista, tattiche scelte secondo i risultati (osserva, decide, agisce, verifica, ricorda).

## Bot di prova

Dal menu di pausa, "Fai giocare il bot" (oppure `godot --path . -- --bot` sul computer). `script/bot.gd` gioca da solo
la stanza come una persona (solo comandi, nessun teletrasporto: i percorsi li trova `script/navigatore.gd`, che
ricorda quali passaggi falliscono), combatte schivando, muore contro uno scheletro e affronta la sua nemesi, prova mosse,
aspetti e qualità, misura la fluidità di ogni fase, rimette le scelte di chi gioca, salva il
rapporto con la sezione `bot` e chiude il gioco. Se il gioco si chiude a metà, al riavvio le scelte vengono rimesse.

## Prove

```
godot --headless --path . --import
godot --headless --fixed-fps 60 --path . -- --prova
```

La prova fa giocare lo stesso bot (corsa, salto, colpi, cassa, barili, nemici, cunicolo, piattaforme, tasti a schermo,
menu, aspetto, mosse, morte, comandi a caso, qualità) e stampa `PROVA ok/FALLITA` per ogni controllo. Con uno schermo e `--schermate=/cartella` salva anche le immagini.

## Pubblicazione

Ogni modifica su `main` fa partire `.github/workflows/android.yml`: prova automatica, APK firmato, nuova versione
`prova-0.1.N` nelle Release. Le note della versione sono la prima sezione di `distribuzione/NOVITA.md`.
I registri dell'ultima compilazione sono nel ramo `log-compilazione`.

### Firma

Le versioni di prova sono firmate con `distribuzione/chiave_prova.keystore`, che sta nel repository pubblico
insieme alla sua password: serve solo a installare ogni versione sopra la precedente durante i test.
Non va usata per una pubblicazione vera. Se nel repository esistono i segreti `RELEASE_KEYSTORE_BASE64`,
`RELEASE_KEYSTORE_ALIAS` e `RELEASE_KEYSTORE_PASSWORD`, la compilazione usa quelli al posto della chiave di prova.

## Rapporti

A ogni chiusura (e ogni 30 secondi, per sicurezza) il gioco salva un rapporto completo: dispositivo, qualità scelta,
FPS secondo per secondo, temperatura, comandi usati, eventi della partita ed errori del motore.
Su Android una copia va in `Download/NonNarrato_report/`. Dal menu si può anche copiare negli appunti.
I rapporti non contengono dati personali.

## Crediti

Vedi [CREDITS.md](CREDITS.md).
