# NonNarrato

Roguelike d'azione per Android, a scorrimento laterale: pixel art cupa alla Blasphemous, struttura a "run" alla Hades.
Sotto il mondo dorme qualcosa di antico; le leggende di ogni popolo sono le maschere che lo tengono addormentato.
Il protagonista è **il Non Narrato**: l'ultima leggenda, mai finita né raccontata, che prende forma nei sogni del Dormiente
e rinasce a ogni morte.

Nome del gioco e del repository sono provvisori.

## Stato: prototipo (una stanza di prova: cripta, galleria e sotterraneo)

Serve a capire se lo stile e i comandi rendono come vogliamo, prima di costruire mondi e storia.
L'elenco di ciò che c'è è in [distribuzione/NOVITA.md](distribuzione/NOVITA.md).

## Scaricare il gioco

L'ultima versione di prova è sempre qui:
https://github.com/vincenzociriello91-hub/NonNarrato/releases/latest

Si scarica `NonNarrato.apk` e si installa sopra la versione precedente. Dalla versione 0.1.17 il gioco si aggiorna da
solo: menu di pausa, scheda **Gioco**, tasto "Aggiorna". Scarica l'APK da GitHub, controlla l'impronta SHA-256
(`NonNarrato.apk.sha256`, pubblicata con ogni versione), pacchetto e firma, poi lo installa con una sessione di
PackageInstaller. Su Android 12 e successivi un'app che aggiorna sé stessa non deve chiedere conferme: serve solo, la
prima volta, il permesso "Installa app sconosciute". Il lavoro lo fa il plugin Android in `android_plugin/`.

## Comandi

| Azione | Controller | Tasti a schermo | Tastiera |
|---|---|---|---|
| Muoversi | leva sinistra o croce | leva a sinistra | A D / frecce |
| Saltare | A | Salto | Spazio |
| Attaccare (due colpi) | X | Colpo | J |
| Rotolare | B | Rotola | K |
| Schivare / scatto (con la direzione: avanti o indietro); con lo scudo, da fermo: parata | Y | Schiva | L |
| Tirare (magia, dardi, frecce; con su in alto; tenendo premuto: magia caricata, raffica, arco carico) | RB o RT | Tira | I |
| Cambiare arma a distanza | LT | Arma | Q |
| Afferrare una cassa (tenere premuto) | LB | Afferra (solo vicino a una cassa) | E |
| Tirare una leva, aprire un forziere | LB | Leva / Apri (solo accanto) | E |
| Scavalcare un ostacolo basso | su + direzione | leva in diagonale | W + direzione |
| Scendere da una piattaforma | giù + A | giù + Salto | S + Spazio |
| Aggrapparsi a una parete ruvida | in aria verso la parete, o su accanto | come col controller | come col controller |
| Sulla parete: salire, scendere, staccarsi | su / giù; A = balzo via dal muro; direzione opposta = lasciarsi | leva, Salto | W S, Spazio |
| Nuotare; uscire dall'acqua | leva in ogni direzione (senza comandi si torna a galla); A a galla | leva, Salto | W A S D, Spazio |
| Pausa e impostazioni | Start | II | Esc |
| Schermata di debug | Select | dal menu | F3 |

I tasti a schermo compaiono appena si tocca lo schermo e spariscono appena si usa un controller (si può anche fissare
un tipo di comandi nelle impostazioni). Nel menu di pausa LB e RB (E e I) cambiano scheda.

## Impostazioni

Cinque schede nel menu di pausa (`script/menu.gd`, chiavi in `script/impostazioni.gd`, convenzione: -1 o "auto" =
scelta del gioco in base al dispositivo):

- **Gioco**: tipo di comandi, tasti a schermo (grandezza, visibilità, mancini), zona morta, vibrazione, numeri dei
  danni, frasi delle nemesi, debug, aggiornamenti.
- **Schermo**: dati del pannello letti da Android (modi, frequenze, HDR), grandezza del mondo (scala intera), pixel
  perfetti o sempre 360 righe, 16:9, risoluzione del pannello, limite FPS (solo quelli possibili), V-Sync, luminosità,
  contrasto, margini, orientamento, schermo acceso.
- **Grafica**: livello e singoli dettagli (un dettaglio scelto a mano vince sul livello; il calore abbassa comunque),
  riduzione automatica, risoluzione interna (100/75/50%) e filtro di ingrandimento: nitido, liscio, SGSR
  (`shader/vista.gdshader`).
- **Audio**: cinque canali (generale, musica, effetti, ambiente, interfaccia), modalità notte, bassi, mono, silenzio
  con il telefono silenzioso. Uscita (altoparlante, cuffie, Bluetooth, USB) e suoneria li legge il plugin Android.
- **Accessibilità**: velocità, danni ricevuti, mira, tiri da caricare con due tocchi, grandezza dei testi, scosse,
  lampi, contorni chiari, daltonismo, didascalie dei suoni.

## Riconoscimento del dispositivo

`script/dispositivo.gd` legge da Godot schermo, grafica e frequenze, e dal plugin Android memoria, processore,
versione di Android, classe di prestazioni, spazio, sensori e stato dell'energia. Da questi sceglie il livello di
qualità consigliato (`consiglia_da`) e lo abbassa con il caldo, gli scatti, il risparmio energetico o la modalità gioco
"batteria" di Android. Quello che ha riconosciuto si legge nel menu (scheda Gioco) e nel rapporto.

## Suoni

Tutti sintetizzati da `strumenti/genera_suoni.py` (rumore, toni e filtri: nessuna registrazione, CC0), file in
`arte/suoni/`. Li suona l'autoload `Suoni` (`script/suoni.gd`), con suoni posizionali nel mondo e didascalie.

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
  `equipaggiamento.gd`, `bot.gd`, `navigatore.gd`, `nemico.gd`, `memoria.gd`,
  `armi.gd` (attacchi delle armi da mischia), `rompibile.gd`, `proiettile.gd` (colpi dei nemici e tiri di chi gioca), `raccoglibile.gd` (munizioni a terra); meccanismi e trappole della galleria: `porta.gd`, `leva.gd`, `piastra.gd`,
  `forziere.gd`, `spuntoni.gd`, `pendolo.gd`, `balestra.gd`, `piattaforma_mobile.gd`, `piattaforma_fragile.gd`,
  `bracieri.gd`; `dispositivo.gd` (riconoscimento e qualità), `controlli.gd`, `impostazioni.gd`,
  `rapporto.gd`; `hud.gd` e `menu.gd` per l'interfaccia.
- `shader/` — filtro palette e nebbia.
- `arte/` — sprite e grafica d'ambiente; `arte/figure/` le animazioni del protagonista. `modelli/` — il manichino.
  `sorgenti3d/` — modelli originali (non entrano nell'APK).
- `strumenti/` — strumenti di lavoro. `test/` — prova automatica.
- `distribuzione/` — novità e chiave di firma del canale di prova.

## La stanza

Due parti, costruite da codice in `script/stanza.gd`. La **cripta** (piattaforme, cunicolo da passare rotolando, cassa,
barili, scheletri e mago) e, oltre la terrazza, la **galleria** su tre piani: spuntoni a tempo, sega a pendolo,
balestra con piastra, una torre con montacarichi e lastre che crollano, la sala con l'enigma della cassa sulla piastra,
il salone con l'enigma dei bracieri (ordine diverso a ogni sogno) e una nicchia segreta. Sotto la cripta c'è il
**sotterraneo** (da y 600 a 1300): un muro crepato (`script/struttura.gd`) nasconde una stanzetta e il pozzo; sotto,
assi da rompere sopra una fossa, un cunicolo fino a uno stanzino col forziere, un ripiano di legno coi dardi, una vasca
allagata (`script/acqua.gd`) con un arco da passare sott'acqua e un pilastro da scalare fino alla botola dell'alcova.
Pareti scalabili e mensole sono in `Stanza.SCALABILI` e `Stanza.MENSOLE`, l'acqua in `Stanza.ACQUE`. Arrampicarsi
consuma stamina, stare sott'acqua il respiro (`script/giocatore.gd`, stati `ARRAMPICATA` e `NUOTO`). Leve e forzieri si
usano col tasto Afferra. I forzieri danno vita, frammenti della storia e, quello d'oro, colori rari per l'aspetto: i tesori trovati
sono salvati in `user://equipaggiamento.cfg` (sezione `tesori`).

## Nemici e memoria del sogno

`script/memoria.gd` (autoload `Memoria`, file `user://memoria.cfg`) ricorda tre cose: le **nemesi** (chi ti uccide
torna più forte con nome e titolo; chi batti può tornare sfregiato), le **abitudini** di chi gioca e le **tattiche**
che funzionano contro di lui. `script/nemico.gd` usa questi ricordi: vista bloccata dai muri, udito, ricerca
dell'ultima posizione vista, tattiche scelte secondo i risultati (osserva, decide, agisce, verifica, ricorda).
Sei tipi: scheletro, mago, arciere (dardi di balestra), pipistrello (dorme appeso, scende in picchiata), saltatore
(balza da una piattaforma all'altra) e bestione (corazzato: da davanti para la spada, si gira lentamente).

## Armi da mischia

Ogni arma ha la sua combinazione (numero di colpi, danno, portata, tempi) e una dote: `script/armi.gd`.
La mano sinistra aggiunge la parata (scudo) o un colpo in più (seconda arma). Le animazioni restano quelle del
gruppo di mosse, accelerate o rallentate per seguire i tempi dell'arma.

## Ondate e veterani

In ogni sogno, quando la stanza è vuota, i caduti si rialzano per tre volte (quattro ondate in tutto), ogni volta
più forti. Ogni posto della stanza ha un veterano che accumula esperienza a ogni morte (`Memoria.veterani`, in
`user://memoria.cfg`) e cresce piano, nel corso di mesi.

## Bottino e pozioni

`script/bottino.gd` decide cosa lasciano nemici e forzieri. I nemici deboli niente; quelli forti (mago, bestione,
nemesi, chi ha forza 2 o più) quello dell'arma del colpo finale (dardi, frecce, pozione di mana) e a volte pozioni di
salute, stamina e velocità. Le pozioni (piccola, media, grande) si raccolgono passandoci sopra (`Raccoglibile`) e
danno un effetto di qualche secondo che si somma (`Giocatore.bevi`, `effetti`). I forzieri danno oggetti a caso; i due
forzieri "a caso" possono essere mimic (nemico `mimic`, si muove a balzi), che battuti lasciano pozioni migliori.

## Armi a distanza

Magia (energia che si ricarica), dardi e frecce (munizioni da forzieri e barili), in `script/giocatore.gd`
(`ARMI_DISTANZA`). Tasto Tira, con su in alto; tasto Arma per cambiare. Un aiuto alla mira raddrizza il tiro sul
nemico più vicino entro circa 30 gradi (`bersaglio_tiro`). Tenendo premuto: magia caricata che esplode,
raffica di dardi, arco carico che trapassa.

## Bot di prova

Dal menu di pausa, "Fai giocare il bot" (oppure `godot --path . -- --bot` sul computer). `script/bot.gd` prima prova
comandi, menu, armi e qualità a nemici fermi, poi gioca una **partita libera**: osserva (vita, nemici, forzieri,
enigmi, zone da vedere), sceglie l'obiettivo che conviene adesso secondo un carattere diverso a ogni partita e quello
che ha imparato (`user://bot_cervello.cfg`), agisce e ricorda com'è andata. Si muove solo con i comandi (i percorsi
li trova `script/navigatore.gd`, anche su per le pareti, con le soste sulle mensole, e a nuoto sotto l'arco). Alla
fine misura le prestazioni con ogni qualità e scrive tutto nel rapporto.

## Prove

```
godot --headless --path . --import
godot --headless --fixed-fps 60 --path . -- --prova
```

La prova fa giocare lo stesso bot (con un seme fisso: la partita libera va sempre allo stesso modo), poi prova a colpo
sicuro meccanismi, nemesi, veterani, ondate, armi e scudo, e stampa `PROVA ok/FALLITA` per ogni controllo. Con uno
schermo e `--schermate=/cartella` salva anche le immagini. Per correggere più in fretta, `--fasi=armi_a_distanza,partita`
fa giocare al bot solo alcune fasi.

## Pubblicazione

Ogni modifica su `main` fa partire `.github/workflows/android.yml`: prova automatica, plugin Android compilato
(`strumenti/compila_plugin.sh`, finisce in `addons/nonnarrato_android.jar`), APK firmato con la compilazione Gradle
di Godot, impronta SHA-256, nuova versione `prova-0.1.N` nelle Release. Le note della versione sono la prima sezione di `distribuzione/NOVITA.md`.
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
