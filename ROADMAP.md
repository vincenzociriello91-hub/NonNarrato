# Roadmap di NonNarrato

Decisa da Vincenzo nella chat con Claude (27/11/2026). Chi lavora sul progetto (Claude Code, anche su GitHub con
"@claude") legge prima `CLAUDE.md` e questo file, e lavora **un punto per volta, una versione per punto**,
solo sul punto indicato nella richiesta. Prima di ogni lavoro grosso serve il "via" di Vincenzo: su GitHub il via
è la richiesta stessa che nomina il punto.

Riferimenti: **Dead Cells** come base (stesso metodo: modelli 3D trasformati in pixel art), **Blasphemous** per peso
e cupezza dei movimenti, **Prince of Persia** (il primo) per arrampicate e aggrappi.
Dispositivo più debole su cui deve girare bene: **Pixel 8 Pro**. Livelli in più per i dispositivi più potenti.
Si possono scaricare e installare risorse CC0 e librerie (solo licenze compatibili con un repository pubblico).

## 1. Ombre giuste, senza coni neri — fatto (0.1.31 corpi, 0.1.32 muri e pilastri)
Oggetti, personaggio e nemici devono avere di nuovo un'ombra (dalla 0.1.28 erano state tolte: errore).
Corte e sfumate, dai piedi, dalla parte opposta alla torcia più vicina, più deboli lontano dalla luce.
Niente coni neri lunghi che partono dalle torce e attraversano il muro.

## 2. Regola: si corregge il difetto, non si toglie ciò che funziona — fatto (0.1.32)
Scriverla in `CLAUDE.md` (fatto il 27/11/2026) e rispettarla: prima di togliere qualcosa ci si chiede se il
problema è la cosa o solo il difetto, e si confronta con Dead Cells e Blasphemous. Si toglie solo se lì non c'è.

## 3. Movimenti fluidi e naturali per tutti — fatto (0.1.34 e 0.1.35)
Personaggio (lo stesso del bot) e ogni tipo di nemico. Oggi l'arrampicata sembra "Pinocchio, un burattino".
- piedi che non scivolano: camminata, corsa, nuoto e salita al passo con lo spostamento vero;
- niente scatti tra un'azione e l'altra (fermarsi, girarsi, attaccare, atterrare, rialzarsi, aggrapparsi,
  scavalcare in cima, lasciarsi andare): pose di passaggio;
- peso: preparazione prima di salti e colpi, ritorno dopo, corpo che si piega e oscilla;
- arrampicata: ciclo più lungo, mano e piede opposti insieme, spinta a ogni presa;
- controllo con foto fotogramma per fotogramma, confrontate con i riferimenti.

Fatto nella 0.1.34 (lavoro della 0.1.33, uscito con la compilazione 34): tutte le animazioni ad almeno 24 fotogrammi
al secondo (personaggio e nemici, stesse durate); corsa e camminata al passo con lo spostamento; salto ad arco guidato
dalla velocità con sospensione in cima; spigoli scansati; inclinazione nello slancio e nella frenata; issata dal bordo
(appeso, trazione, ginocchio, in piedi); nemici che partono e frenano senza scatti, senza passettini sul posto.
Resta: ciclo dell'arrampicata (più lungo, mano e piede opposti, spinta a ogni presa), nuoto al passo, pose di passaggio
(girarsi, attaccare, atterrare, rialzarsi, lasciarsi andare), preparazione e ritorno di salti e colpi.

Fatto nella 0.1.35: arrampicata con un ciclo vero (mano e piede opposti, spinta a ogni presa, mani ferme sulla roccia),
pose di passaggio fra tutte le azioni del personaggio, mezzo giro di personaggio e nemici, slancio e schiacciamento nei
salti, nuoto al passo.

## 4. Grafica di qualità più alta — in corso
"Sembra ancora tutto fatto male": più accattivante e di qualità.
- personaggi e nemici più dettagliati (modelli CC0 migliori, per esempio Quaternius), più pixel per figura;
- animazioni da archivi gratuiti di motion capture (aiutano anche il punto 3);
- ambienti più ricchi: sfondi su più strati, pietre, muri e decorazioni curati;
- luce e atmosfera: bagliore di fiamme e magie, nebbia e polvere in movimento, raggi di luce, colori più cupi e
  uniformi, le ombre del punto 1;
- livello "ultra" per i dispositivi sopra il Pixel.
A tappe: una versione per passo, Vincenzo controlla sul Pixel prima di andare avanti.

Tappa 1 fatta nella 0.1.36: bagliore di fiamme e magie, raggi di luce dalle finestre con la polvere, colori del film,
livello "ultra".
Tappa 2, prima parte, fatta nella 0.1.37: personaggio e nemici in doppia definizione (il doppio dei pixel), mondo
disegnato al doppio in "alta" e "ultra", fogli ritagliati.
Decisione di Vincenzo (27/11/2026, dopo le foto di confronto): stile Quaternius con proporzioni vere per tutto il
gioco, coerente e omogeneo, con la libreria più ampia possibile (siti CC0 aperti: vedi CLAUDE.md).
Tappa 2, seconda parte, fatta nella 0.1.38: il Non Narrato col corpo Quaternius, vestiti modulari, mantelli generati,
animazioni UAL e KayKit adattate. Tappa 2, terza parte, fatta nella 0.1.39: i nemici con gli stessi pezzi e le stesse
animazioni del protagonista (sepolto risorto, mago, balestriere, bestione incappucciato, ghoul). Pipistrello e mimic
restano: il mimic nasce dal forziere e cambierà con gli ambienti. Tappa 2, quarta parte, fatta nella 0.1.40: armi, scudi, elmi, pozioni, pipistrello e munizioni dalle fonti CC0 verificate
(dieci giri di ricerca). Tappa 2, quinta parte, fatta nella 0.1.41: gli ambienti (muri, pavimenti, colonne, casse, barili,
forzieri e mimic, torce, bracieri, montacarichi, leve e balestre murate) e gli arredi (catene, gabbie, lampadario, stendardi,
libri, statua, sarcofago, ossa, rocce, monete, edera). Restano a forme semplici le grate, gli spuntoni e la sega del pendolo.

Spada capovolta (issue #1, priorità): corretta nella 0.1.42. Spade, pugnali e bacchetta si tengono dal manico, il verso
della punta è scritto per ogni arma e una prova automatica controlla armi e armature.

---

Punti dal 5 al 9: comando di Vincenzo del 28/11/2026 (issue #1, "riferisci"). Regola "una stanza perfetta, poi si
cresce": prima tutto nella stanza di prova; mondi veri, boss dei mondi, NPC e storia vengono dopo la base. Dove una cosa
esiste già in parte (trappole, accessibilità, nemesi, calore, vibrazione) si completa e si migliora, non si rifà.
Prima di ogni fase: impegno, modello, Ricerca (dieci giri quando servono fonti nuove) e il "via" di Vincenzo.

## 5. Combattimento che si sente
- Fase 5.1, suoni veri: pacchetti CC0 (per esempio Kenney) per colpi, passi, ossa, acqua, al posto di quelli fatti al
  computer; musica che segue le azioni (tamburi sui colpi riusciti, suono grave quando si è quasi morti).
- Fase 5.2, colpi (FATTA nella 0.1.43): parata al momento giusto che apre la guardia (Blasphemous), colpi caricati con la luce che cresce e
  sfondano le difese, esecuzioni sui nemici storditi, schizzi e scintille diversi per ossa, pietra e legno, barcollare
  diverso secondo l'arma, vibrazione sul Pixel per colpi, atterraggi e danni (c'è già: completare), telecamera da regista
  (zoom sui colpi forti, rallentatore sull'ultimo nemico dell'ondata, inquadratura larga nelle stanze grandi).
- Fase 5.3, ambiente come arma: trappole usate contro i nemici (spuntoni, lame, pavimenti che crollano: già li feriscono,
  completare), colpo critico al nemico spinto in acqua, sugli spuntoni o giù da una piattaforma, torce che si spengono con
  colpi o acqua (al buio si vede meno, nemici compresi).
- Fase 5.4, rifiniture: accessibilità completa (daltonismo, sottotitoli dei suoni, mira assistita, velocità: c'è già in
  parte), adattamento al telefono senza scatti con calore o batteria bassa (c'è già: completare).

## 6. Intelligenza e memoria di tutti
- Fase 6.1, quaderno di regole: dal bot di Minecraft le regole scritte dopo ogni scontro ("contro questo giocatore la
  schivata a sinistra fallisce"), rilette e usate la volta dopo; dal Nemesis System memoria personale, rancori, cicatrici,
  crescita. Un quaderno per ogni personaggio (protagonista, nemici semplici, più avanti mid boss, boss, NPC), mai
  cancellato, unito alla `Memoria` di adesso.
- Fase 6.2, nemici che si comportano da gruppo: arciere indietro mentre lo scheletro blocca, mago che cura i feriti, paura
  (i deboli soli o feriti scappano e tornano con rinforzi), osservatori che scappano a "riferire", rivalità (chi è stato
  abbandonato non protegge il compagno).
- Fase 6.3, nemesi più profonde: prede che diventano predatori (chi ti uccide più volte sale di grado, cambia aspetto,
  diventa mini-boss con nome e cicatrice), vendette su misura (arma che contrasta la tua, evita il fuoco se l'hai bruciato),
  ferite che restano (protezione o meno uso della parte colpita, cicatrici visibili), leggende di chi gioca (dopo imprese
  rare alcuni nemici scappano al primo sguardo).
- Fase 6.4, il protagonista impara: contro i nemici battuti spesso colpisce un po' più forte e legge prima i loro
  attacchi; il gioco mostra, senza numeri, quali mosse di chi gioca sono prevedibili.

## 7. Crescita del protagonista
Obiettivo: nemici intelligenti e duri, il gioco non si finisce alla prima partita, ma chi gioca cresce e combatte alla pari.
- Fase 7.1, essenza e livelli: essenza dai nemici (di più da nemesi e boss), livelli e punti in vita, forza, agilità,
  resistenza, mente. Alla morte restano livelli, statistiche, abilità, magie e miglioramenti fissi; si perdono pozioni,
  reliquie, potenziamenti temporanei ed essenza non spesa, che resta dove si è morti: ritrovata, si recupera tutta oppure
  si libera il fantasma del Non Narrato (forza in proporzione all'essenza, combatte con lo stile imparato dalle partite e
  dal bot, si può tenere da parte e chiamare dopo, per esempio contro il boss).
- Fase 7.2, albero delle abilità: rami guerriero, cacciatore con l'arco, mistico, acrobata, mescolabili; armi che si
  evolvono con l'uso (mosse nuove).
- Fase 7.3, oggetti: armi e armature migliorate coi materiali dei nemici, effetti (fuoco, sanguinamento, veleno), magie
  trovate che crescono con l'uso, reliquie a scelta che cambiano le regole del sogno (Hades), altari del patto (vita
  massima in cambio di un potere forte).
- Equilibrio: più si cresce, più i nemici si adattano; il gioco non diventa mai facile, ma la crescita si sente.

## 8. Il livello di prova completo
- Fase 8.1, mid boss alla fine della quarta ondata.
- Fase 8.2, segreti: un esempio del sistema dei boss segreti (un frammento di sigillo nascosto con il suo indizio e una
  porta segreta che si accende), mappa dei segreti che si disegna esplorando e segna i muri sospetti, stanze sfida (a
  tempo, senza danni, solo con l'arco) con ricompense rare.
- Fase 8.3, il sogno: statistiche di fine sogno (come sei morto, chi ti ha ucciso, cosa hanno imparato i nemici), diario
  del Non Narrato che si scrive da solo, meteo dei sogni (nebbia, pioggia, sangue, silenzio), il Dormiente che si agita
  (più resti, più il mondo trema e arrivano nemici strani), bot spettatore (replica accelerata con le scritte delle sue
  decisioni).

## 9. Dopo la base: mondi, boss, NPC
- Mondi veri, ognuno col suo boss e un boss segreto. Boss segreti stile Final Fantasy X: tre frammenti di sigillo per mondo
  in tre stanze segrete diverse (dietro un muro da rompere, in un passaggio sommerso, dopo una stanza sfida), ognuno con un
  indizio (filastrocca o leggenda); porta sigillata visibile subito, un simbolo si accende a ogni frammento; il boss segreto
  è la leggenda del mondo "riscritta" dal Dormiente, più forte di tutto il resto; ricompensa: arma o reliquia unica e una
  pagina segreta del diario sul Dormiente.
- Final boss (finale normale) e secret final boss (finale vero), due boss diversi: il secondo si apre battendo tutti i boss
  segreti.
- Boss preparati (leggono le regole imparate dai nemici del loro mondo), alleanze fra boss (un boss segreto lasciato in vita
  compare nello scontro del mondo dopo).
- NPC con memoria: mercanti (prezzi che cambiano se torni spesso), missioni (sanno se li hai traditi), NPC salvati che
  aiutano contro un boss, voci di corridoio su chi ti dà la caccia, mercante della nemesi che vende informazioni.
- Salvataggio nel cloud fra dispositivi: per ora solo predisposizione (la Odin non si considera).

## 10. Guida di stile (issue #2, decisione di Vincenzo del 28/11/2026)
Riferimento: 52 brevi clip dark fantasy mandate da Vincenzo (non nel repository e mai da mettere: sono di altri). Solo
ispirazione: niente copie, niente personaggi riconoscibili. Vale per tutti i punti, dal 5 in poi.
- Cosa hanno in comune: quasi in bianco e nero (34 su 52) o con un solo colore dominante (blu notte, arancio di fuoco,
  qualche fiamma verde malata o rosa); buio quasi totale, contrasto forte, luce di taglio sui bordi dell'armatura, figure
  lette dalla sagoma; movimento lento e solenne (mantelli, capelli, cenere, neve, braci, corvi); tono sacro e decaduto,
  lutto, penitenza, regalità corrotta, silenzio.
- Nel gioco (pixel art a circa 640x360: si traducono colori, sagome e luce, non il fotorealismo):
  - ambienti: base grigia desaturata e un solo colore d'accento per zona o per meteo dei sogni (blu notte, arancio fuoco,
    verde malato per il Dormiente); nebbia a strati, rovine, campi di spade conficcate, corvi, cenere che cade;
  - protagonista: armatura scura e logora con mantello, sagoma leggibile, luce di taglio dalle normali; posa in ginocchio
    appoggiato alla spada per la rinascita, il riposo e la schermata iniziale;
  - bot: stesso stile del protagonista; come fantasma (dell'essenza, delle partite passate) sagoma pallida che si dissolve
    in polvere;
  - nemici: cavalieri caduti in armatura pesante e figure incappucciate; morendo si dissolvono in cenere o polvere;
  - boss, mid boss e boss segreti ("leggende corrotte"): corone di spine o di punte, maschere di pietra spaccata, aureole
    spezzate, fiamme di colore innaturale (verde, rosa);
  - NPC: figure velate o incappucciate, penitenti e pellegrini, sagome tranquille e palette più calda (una candela, una
    lanterna) per distinguerli dai nemici;
  - interfaccia e titolo: nero, argento consumato, un solo colore d'accento, scritte sobrie;
  - suoni e musica: bordoni gravi, cori lontani, campane, archi bassi, metallo che stride, vento, braci; il silenzio come
    strumento (la musica sparisce prima dei momenti forti); solo CC0 o generato nel codice;
  - particelle: cenere, braci, neve, corvi, polvere di dissoluzione, legate a `Dispositivo.profilo`.
- Fase 10.1, atmosfera della stanza di prova: tinta d'accento per zona (cripta, galleria, sotterraneo), desaturazione dei
  colori del film, cenere e corvi, interfaccia e titolo in nero e argento.
- Fase 10.2, figure: posa in ginocchio (rinascita, titolo), nemici che muoiono dissolvendosi in cenere, luce di taglio più
  marcata sui bordi delle armature. Le figure dei boss e degli NPC vanno con i punti 8 e 9.
- Controllo: a ogni versione grafica, foto confrontate con questa guida (vedi CLAUDE.md, controllo da giocatore).
