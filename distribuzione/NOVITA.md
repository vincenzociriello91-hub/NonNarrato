# Novità di NonNarrato

## 0.1 — Schermata iniziale, salvataggi, musica che segue il combattimento

- **Schermata iniziale**: all'avvio trovi il nome del gioco sopra la stanza in penombra e i tasti Continua, Nuovo sogno, Impostazioni e Fai giocare il bot. Il tasto Indietro, premuto due volte, chiude il gioco.
- **Il sogno si salva da solo**: a ogni ondata, ogni 20 secondi, quando passi a un'altra app e quando torni al titolo. Con "Continua" riparti dall'inizio della stanza, all'ondata in cui eri, con la stessa vita, le stesse munizioni e la stessa arma. Nel menu di pausa c'è "Salva e torna al titolo".
- **Salvataggi più sicuri**: impostazioni, aspetto, memoria del Dormiente e partita si scrivono prima su un file a parte e solo alla fine prendono il posto di quello vecchio, di cui resta una copia. Se il telefono si spegne a metà, non si perde niente.
- **Musica nuova a strati**: in esplorazione suona un tappeto cupo con rintocchi lontani; quando ci sono nemici svegli vicino entra un battito con un coro lontano; quando combatti entrano tamburi e corde. Gli strati entrano in fretta ed escono piano, sempre a tempo.
- **Suoni d'ambiente nuovi**: vento e gocce nella cripta, acqua che scorre nel sotterraneo. Sott'acqua tutto si sente ovattato e nella pietra c'è un po' d'eco (l'eco si spegne con la grafica "bassa").
- **Colpi più pesanti**: la scossa dello schermo è più morbida e si somma se i colpi sono tanti; il colpo che uccide un nemico e quello che ricevi fermano il gioco per un istante; atterrando da un salto alto il personaggio si schiaccia un attimo. Le scosse si regolano in Accessibilità, i fermi si tolgono con "meno lampi".

## 0.1 — Niente più strisce dalle torce, il bot non si "teletrasporta"

- **Basta strisce scure dalle torce**: le ombre delle torce sono spente in automatico a ogni livello di grafica, e casse, barili, forzieri, porte, bracieri e muri rompibili non fanno più ombra. Chi le vuole può accenderle a mano in Impostazioni > Grafica > "Torce con ombra" (le fanno solo muri e pilastri).
- **Il bot non sparisce più da un punto per ricomparire all'inizio**: tra una prova e l'altra il bot rimette la stanza com'era (muri rotti, casse spostate, forzieri aperti) e lo riporta all'inizio. Prima succedeva di colpo e sembrava un teletrasporto. Ora lo schermo diventa nero per un attimo, con una scritta che dice cosa sta per provare ("Il bot prova il sotterraneo", "Partita libera: il bot gioca da solo"...). Per spostarsi nella stanza il bot cammina, salta, si arrampica e nuota sempre: non si teletrasporta mai.

## 0.1 — Quando gioca il bot si capisce quali nemici sono in pausa

- **Nemici "bloccati e intoccabili" mentre gioca il bot**: nella prima parte, quella delle prove tecniche (movimento, casse, menu, sotterraneo, bottino...), il bot mette in pausa i nemici apposta per provare le cose con calma. Restavano però congelati a metà passo, sembravano camminare sul posto e si potevano attraversare: sembravano rotti. Ora in pausa stanno fermi in posa di riposo e semitrasparenti, e in alto la scritta del bot dice "nemici in pausa per le prove". Nella partita libera del bot e quando giochi tu i nemici sono sempre normali.

## 0.1 — Nemici che non tremano, ombre pulite, frecce vere

- **I nemici non tremano più** quando urtano te, un compagno, una cassa o un muro: prima si fermavano e ripartivano a ogni fotogramma, come una gif impazzita. Ora, se la strada è chiusa, restano fermi davvero e riprovano dopo un po' (sempre più tardi se la strada resta chiusa).
- **Gli scheletri, i saltatori e i mimic saltano sopra le casse** che li separano da te, invece di sbatterci contro. Il bestione è troppo pesante: aspetta.
- **Niente più strisce scure dalle torce**: le ombre del personaggio, dei nemici e delle balconate viste di taglio diventavano lunghe strisce che partivano dalle fiamme. Ora fanno ombra solo pilastri, casse, barili, forzieri e muri, con ombre più morbide e non nere del tutto.
- **Frecce e dardi volano davvero**: puntano sempre nella direzione in cui vanno (la freccia dell'arciere prima restava orizzontale anche quando scendeva in diagonale) e cadono un po' durante il volo, con una parabola. Chi tira, tu o l'arciere, mira un po' più in alto per arrivare sul bersaglio. La magia vola dritta.

## 0.1 — Corretto: nemici che camminavano sul posto

- **I nemici non camminano più sul posto.** Da quando i corpi sono solidi, alcuni nemici continuavano a camminarti contro (o contro un compagno davanti a loro) senza mai attaccare: il saltatore, che prima ti passava attraverso per prendere la rincorsa, restava incollato a te; chi stava dietro un compagno lo spingeva all'infinito; chi provava a girarti attorno restava bloccato. Ora il saltatore salta indietro e ti balza addosso, chi è chiuso da un compagno o da te aspetta il suo turno, e chi non può girarti attorno combatte da dove si trova.
- **Chi fa la ronda non sfonda più i barili** senza motivo appena inizia il sogno: torna indietro. I barili si rompono ancora quando un nemico ti insegue.
- Un nemico chiuso fra due ostacoli resta fermo invece di girarsi di continuo.
- In più, se per qualunque altro motivo un nemico prova a camminare senza riuscire a spostarsi (contro una cassa, in un angolo), dopo mezzo secondo smette e cambia idea.

## 0.1 — Controllo da giocatore: tante piccole cose sistemate

- **Sott'acqua il personaggio si vede bene**: prima spariva quasi nel velo scuro della vasca; ora resta davanti all'acqua, tinto di blu.
- **Niente più colonne nere in mezzo al sotterraneo**: le sagome in primo piano della stanza cadevano proprio dentro il sotterraneo e coprivano la vista. Ora, quando scendi, lasciano il posto a quelle del sotterraneo, che stanno in basso.
- **I nemici non stanno più dentro forzieri e casse**: il mago della balconata non sta più piantato sopra il forziere, lo scheletro addormentato della galleria non è più steso sopra il forziere accanto, e un nemico fermo si scosta da solo se è finito dentro un forziere o una cassa.
- **Messaggi più comodi**: compaiono più in alto e più piccoli, così non coprono più il personaggio e i nemici. Aprendo un forziere gli oggetti stanno su una riga sola e la frase della storia sotto.
- **Quando un nemico giura vendetta** il messaggio dice con quale nome tornerà, invece della stessa frase ogni volta.
- **Quando muori** la scritta "Il Dormiente ti sogna di nuovo" ora si legge sullo schermo nero (prima restava nascosta).
- **Cuori e scritte in alto a sinistra** hanno un'ombra leggera dietro: si leggono anche davanti a una torcia accesa.
- **Menu**: gli interruttori acceso/spento sono ben visibili (prima erano un pallino grigio quasi invisibile) e le caselle più grandi. Se il telefono non dice la frequenza dello schermo il menu lo scrive a parole invece di "-1 Hz".
- **Il riquadro con i dati tecnici** (FPS e dispositivo) ora parte spento: si accende da Impostazioni → Gioco.

## 0.1 — Niente più corpi che si attraversano

- **Personaggio e nemici sono solidi**: non ti passano più attraverso e tu non passi attraverso loro, si spingono di lato. Il bestione è pesante e quasi non si sposta. Anche i nemici tra loro non stanno più uno dentro l'altro. Per passare oltre un nemico c'è il **rotolo** (o lo scatto): è fatto apposta per schivare.
- **I barili sono ostacoli veri**: non si attraversano più; li rompi con un colpo, e i nemici che ci finiscono contro li sfondano. Il barile che stava nell'alcova non c'è più, perché avrebbe chiuso la risalita dal pilastro.
- **Sulle pareti** mani e piedi toccano la roccia invece di entrarci.
- **Le armi non passano più dentro testa e busto**: l'arma in mano (anche la balestra e i dardi da lanciare) si disegna sempre davanti al corpo, sia per il personaggio sia per i nemici (lama degli scheletri, ascia del bestione, bastone del mago).
- Forzieri, leve e piastre restano oggetti davanti ai quali si passa, disegnati dietro al personaggio.

## 0.1 — Correzione: nemici bloccati dopo il bot

- **Corretto**: se fermavi il bot con la pausa mentre faceva le sue prove, i nemici restavano bloccati: camminavano sul posto, non ti vedevano e non si potevano ferire. Ora, quando il bot si ferma (o finisce), i nemici tornano normali e la stanza ricomincia pulita, senza i muri rotti e le casse spostate dal bot. Non conta come un sogno nuovo.

## 0.1 — Il gioco conosce meglio il tuo telefono

- **Riconoscimento del dispositivo più completo**: oltre a schermo, grafica, suono, batteria e calore, ora il gioco legge anche:
  - memoria totale e libera;
  - processore, col nome commerciale (per esempio "Snapdragon 8 Gen 2"), numero di core e frequenza massima;
  - versione di Android e classe di prestazioni che Android assegna al telefono;
  - spazio libero, giroscopio, tipo di vibrazione.
- **Si regola da solo anche con l'energia**: con il **risparmio energetico** attivo, o con la modalità gioco "batteria" di Android, la qualità automatica scende di un livello e il gioco va a 30 FPS. Se nella modalità gioco di Android scegli "prestazioni", quella vince. Le scelte fatte a mano non vengono toccate.
- **Nel menu**, scheda **Gioco**, la sezione "Il tuo dispositivo" mostra tutto quello che il gioco ha riconosciuto. Nella scheda **Grafica** c'è scritto perché ha scelto quel livello di qualità.
- Tutto finisce anche nel rapporto, per regolare meglio il gioco sui telefoni veri.

## 0.1 — Bottino, pozioni e mimic

- **Bottino dei nemici**: i nemici deboli non lasciano niente. Quelli forti (mago, bestione, le nemesi e chiunque sia cresciuto con le ondate o da veterano) lasciano quello che serve all'arma con cui li hai finiti: **dardi** se con la balestra, **frecce** se con l'arco, **pozioni di mana** se con la magia. A volte lasciano anche pozioni di salute, di stamina e, più di rado, di velocità.
- **Pozioni piccole, medie e grandi**, in quattro colori:
  - rossa: **salute**, ridà vita poco a poco;
  - verde: **stamina**, per arrampicarsi più a lungo;
  - blu: **mana**, ricarica la magia;
  - gialla: **velocità**, corri, sali e nuoti più in fretta, con una scia dorata.
- **Gli effetti si sommano**: ogni pozione dura qualche secondo; se ne prendi un'altra dello stesso tipo mentre la prima è ancora attiva, l'effetto diventa più forte e più lungo. In alto, accanto ai cuori, un cerchio colorato si svuota col tempo e mostra quanto è forte (×2, ×3...).
- **Forzieri con oggetti a caso**: ogni volta un contenuto diverso (vita, dardi, frecce, pozioni che saltano fuori). Se sei ferito ti curano, se hai finito dardi o frecce te ne ridanno. Due forzieri nuovi: uno sulla piattaforma alta della cripta e uno nella galleria.
- **Mimic**: a ogni sogno uno di quei due forzieri può essere un mimic. Lo apri e ringhia, spalanca la bocca piena di denti e ti salta addosso a morsi. Battuto, lascia sempre almeno due pozioni medie o grandi.
- **Suoni nuovi**: sorsi, boccette che cadono, il ringhio e il morso del mimic.
- **Il bot** apre i forzieri, raccoglie le pozioni, batte un mimic (contro i suoi balzi ha imparato a rotolargli attraverso) e nella partita libera va a cercare i forzieri chiusi.

## 0.1 — Il sotterraneo: muri da rompere, pareti da scalare, acqua da attraversare

- **Un sotterraneo sotto la cripta**, tutto da scoprire. La stanza resta di prova, ma ora è un platform su due livelli: sopra la cripta e la galleria, sotto un dedalo di camere collegate da pozzi, cunicoli e una vasca allagata.
- **Muri e legno che si rompono**: il muro crepato sotto il ripiano nasconde una stanzetta con le candele e un pozzo che scende nel buio. Sotto, le assi di legno coprono una fossa: da lì si rotola in un cunicolo fino a uno stanzino con un forziere. Un ripiano di legno in alto regge dei dardi: lo rompi con un tiro verso l'alto e i dardi cadono. Si crepano a ogni colpo (spada o tiri) e, rotti, svelano quello che c'è dietro.
- **Pareti ruvide da scalare**: salta verso la parete (oppure premi su accanto) e ti aggrappi. Su e giù per salire e scendere, salto per staccarti con un balzo, direzione opposta per lasciarti andare. In cima sali sul bordo da solo. A metà delle pareti più alte c'è una mensola: scendi sopra e riprendi fiato.
- **Stamina**: restare appesi stanca, salire stanca di più, il salto dal muro costa. A zero le mani scivolano e cadi; non ti riaggrappi finché non hai ripreso fiato. Torna con i piedi a terra (o a galla). La barra verde compare in alto solo quando serve.
- **Nuoto e respiro**: nella vasca allagata si nuota in ogni direzione; senza comandi si torna a galla. Sotto un arco di roccia si passa solo sott'acqua: con la testa sotto il respiro cala (le bolle in alto), a zero si perde vita. A galla torna in fretta. Con il salto si esce dall'acqua e il bordo si afferra da solo.
- **La telecamera segue** quando scendi: mostra il sotterraneo e torna su quando risali.
- **Suoni nuovi**: presa sulla parete, affanno, tuffo, bolle, respiro ripreso, muro che crolla, legno che si spezza, crepe.
- **Accessibilità**: due interruttori nuovi, **stamina infinita** e **respiro infinito**.
- **Il bot** scopre il sotterraneo da solo: rompe il muro, scende nel pozzo, rompe le assi, rotola fino al forziere, abbatte il ripiano coi dardi, nuota sotto l'arco, risale le pareti fermandosi sulle mensole per riprendere fiato ed esce dalla botola dell'alcova. Nella partita libera, se passa vicino a un muro crepato, la curiosità gli fa venire voglia di romperlo.

## 0.1 — Impostazioni a schede, suoni e aggiornamento dentro il gioco

- **Impostazioni a schede**: nel menu di pausa, in alto, cinque linguette, **Gioco**, **Schermo**, **Grafica**, **Audio** e **Accessibilità**. Con un controller si passa da una all'altra con LB e RB. Ogni scheda ha il suo tasto "Ripristina i valori consigliati". Le voci automatiche dicono tra parentesi cosa sta usando il gioco sul tuo telefono. Aspetto e mosse hanno un tasto a parte, sotto l'anteprima del personaggio.
- **Gioco**:
  - tipo di comandi (automatico, solo tasti a schermo, solo controller);
  - grandezza e visibilità dei tasti a schermo, disposizione per mancini;
  - zona morta delle leve, vibrazione e sua forza;
  - numeri dei danni, frasi delle nemesi, schermata di debug, aggiornamenti.
- **Schermo**, su misura per il tuo telefono:
  - modello, risoluzione, frequenze del pannello e grandezza del mondo di gioco;
  - quanto mondo vedere, pixel perfetti o sempre 360 righe, tutto lo schermo o 16:9;
  - risoluzione del pannello (se ne ha più di una);
  - limite FPS (solo i valori che lo schermo regge) e V-Sync;
  - luminosità, contrasto, margini dai bordi, orientamento, schermo sempre acceso.
- **Grafica**:
  - livello di qualità, e ogni dettaglio a mano: torce con ombra, ombre morbide, dettaglio delle ombre, luce di riempimento, rilievo del personaggio, nebbia, sagome in primo piano, particelle, filtro pixel art;
  - riduzione automatica se il gioco va a scatti, che si può spegnere (il calore abbassa comunque la qualità, per proteggere il telefono).
- **Ingrandimento come DLSS e FSR**: il gioco già disegna il mondo a bassa risoluzione e lo ingrandisce senza perdere nitidezza. Ora puoi scendere al 75% o al 50% di risoluzione interna per consumare meno. Il filtro di ingrandimento può essere nitido, liscio o **SGSR**, l'ingranditore intelligente di Qualcomm pensato per i telefoni. DLSS e FSR 2/3/4 su Android con un gioco 2D non si possono usare.
- **Suoni**: per la prima volta il gioco ha suoni, tutti creati da zero. Passi, salti, colpi delle armi, magie, dardi e frecce, esplosioni, nemici che si svegliano, che caricano il colpo e che muoiono, ruggito del bestione, stridio dei pipistrelli, forzieri, leve, grate, spuntoni, sega a pendolo, crolli, barili, bracieri, corno delle ondate. In più un sottofondo di caverna e una musica cupa.
- **Audio**:
  - volumi separati: generale, musica, effetti, ambiente, interfaccia;
  - modalità notte, bassi e mono;
  - silenzio quando il telefono è silenzioso;
  - musica più bassa in pausa.
  Il gioco riconosce da dove esce il suono (altoparlante, cuffie, Bluetooth, USB) e si regola da solo: sull'altoparlante abbassa i bassi e avvicina i suoni forti a quelli deboli.
- **Accessibilità**:
  - velocità del gioco, danni ricevuti (fino a invincibile), aiuto alla mira (spento, normale, forte);
  - tiri da caricare tenendo premuto oppure con due tocchi;
  - grandezza di testi e interfaccia, scosse dello schermo, meno lampi;
  - contorni chiari attorno a personaggio e nemici;
  - correzione dei colori per tre tipi di daltonismo;
  - didascalie dei suoni importanti, con la direzione da cui arrivano.
- **Aggiornamento dentro il gioco**: nella scheda Gioco il tasto "Aggiorna" scarica la versione nuova, la controlla e la installa da solo. Android chiede solo la prima volta il permesso "Installa app sconosciute". Il gioco poi si chiude da solo e va riaperto. Questa versione va ancora installata come sempre: il tasto funziona per gli aggiornamenti successivi.

## 0.1 — Il bot pensa da solo

- **Il bot non segue più un copione.** Prima fa le prove tecniche (comandi, menu, armi, qualità) a nemici fermi, poi gioca una partita libera di circa 7 minuti. Lì sceglie da solo cosa fare, in base a quello che vede: combattere o ritirarsi se ha poca vita, curarsi a un forziere, risolvere gli enigmi, esplorare le zone che non ha visto, raccogliere munizioni, provare armi nuove, aspettare la prossima ondata.
- **Ogni partita è diversa**: il bot ha un carattere che cambia ogni volta (più coraggioso, più prudente, più curioso, più avido) e un po' di caso nelle scelte.
- **Impara da una partita all'altra**: ricorda quali obiettivi gli riescono, quale arma ha funzionato contro ogni nemico (contro chi para prova le armi che rompono la guardia) e chi lo ha ucciso più spesso, così ci sta più attento.
- **Se resta bloccato si arrangia**: salta, tira da lontano o lascia perdere un nemico che non riesce a raggiungere; una cassa incastrata contro la grata la afferra e la tira invece di spingerla.
- Nel rapporto trovi il suo carattere, il diario delle scelte, cosa è riuscito, quali armi ha provato, chi lo ha ucciso e dove si è fermato a lungo.

## 0.1 — Armi vere, nemici più duri, nemesi che crescono e quattro ondate

- **Ogni arma ha i suoi attacchi**:
  - spada: tre colpi, l'ultimo più forte;
  - ascia: lenta, il secondo colpo rompe le parate;
  - pugnale: quattro colpi rapidissimi, doppio danno alle spalle;
  - spadone: lungo e pesante, rompe le parate;
  - ascia bipenne: la più forte, fa barcollare;
  - bastone e bacchetta: colpi deboli, ma la magia costa meno o parte prima;
  - pugni: rapidissimi, l'ultimo stordisce.
  Con una seconda arma nella mano sinistra la combinazione ha un colpo in più ed è più veloce. Con lo **scudo**, Schiva da fermo **para** i colpi da davanti, e chi ti colpisce resta scoperto. Nel menu, sotto l'aspetto, una scritta spiega l'arma che hai.
- **Le armi a distanza hanno il loro attacco**: tenendo premuto Tira la **magia si carica** e diventa una sfera che esplode e colpisce tutti attorno; i **dardi partono a raffica**; l'**arco va caricato** (più lo tieni, più la freccia è forte e veloce; a carica piena trapassa).
- **Nemici più duri e più furbi**: hanno più vita; chi ti vede chiama i compagni vicini; chi arriva secondo ti gira alle spalle; al massimo due ti attaccano nello stesso momento. Lo scheletro para e può colpire due volte di fila, il bestione fino a tre. Riconoscono la tua arma preferita: contro le armi pesanti arretrano mentre carichi e rispondono subito, contro quelle rapide parano di più.
- **Nemesi che si evolvono**: a ogni ritorno imparano una capacità nuova (parare, colpire due volte, chiamare rinforzi, pelle dura, furia quando sono ferite) e si difendono dall'arma con cui le hai battute. Te lo dicono quando ti rivedono.
- **Quattro ondate**: quando la stanza è vuota i caduti si rialzano, per tre volte, ogni volta più forti. Fra un'ondata e l'altra recuperi due cuori. Dopo la quarta il sogno si quieta.
- **Più vita**: il Non Narrato ora ha 8 cuori (prima 5) e i forzieri ne ridanno 3.
- **Veterani**: ogni nemico accumula esperienza a ogni morte e la conserva. Sale di livello piano piano, nel corso di mesi di gioco: più vita, più velocità, più riflessi, nuove capacità. I veterani esperti hanno gli occhi accesi.
- **Il bot non si fa più uccidere apposta**: muore solo se perde davvero, e se succede a metà di una prova la rifà. Prova tutte le armi con i loro attacchi e affronta le quattro ondate.

## 0.1 — Ingresso in galleria più fluido

- Entrando in galleria il gioco non dà più un piccolo scatto la prima volta che si vede la sega a pendolo: il telefono la prepara all'avvio.

## 0.1 — La galleria: trappole, enigmi, forzieri, armi a distanza e nemici nuovi

- **Una galleria nuova oltre la terrazza**, su tre piani: si scende dalla passerella, si sale su una torre e si arriva fino a un salone in alto.
- **Leve e grate**: una leva sotto la passerella apre la grata dell'alcova, una scorciatoia per tornare nella cripta.
- **Trappole**: spuntoni che escono dal pavimento a tempo (prima tremano), una sega a pendolo da passare al momento giusto, una piastra che fa scattare una balestra nel muro (la freccia si schiva saltando, rotolandole incontro o colpendola). Le trappole feriscono anche i nemici.
- **Piattaforme nuove**: un montacarichi che sale e scende da solo e lastre crepate che crollano poco dopo che ci sali, e poi tornano al loro posto.
- **Due enigmi**: spingi la cassa giù dalla balconata e mettila sulla piastra, così la grata del tesoro resta alzata; nel salone accendi i tre bracieri (colpendoli) nell'ordine della tavoletta incisa per far salire un gradino segreto. L'ordine cambia a ogni sogno.
- **Forzieri**: accanto a un forziere (o a una leva) premi **Afferra**; il tasto a schermo dice cosa fa ("Apri", "Leva"). I forzieri di legno ridanno vita e contengono frammenti della storia del Dormiente; il forziere d'oro nella nicchia segreta regala un **colore nuovo** per l'aspetto (in tutto ce ne sono tre, si trovano uno alla volta e restano per sempre).
- **Tre armi a distanza**: magia (consuma energia, che torna da sola; passa anche le corazze), dardi (veloci) e frecce (lente ma fanno più male). Si tira con **RB** o **RT** sul controller, **I** sulla tastiera, **Tira** sullo schermo. Con **su** si tira in alto.
- **Cambiare arma**: **LT** sul controller, **Q** sulla tastiera, **Arma** sullo schermo. In alto a sinistra vedi l'arma scelta e i colpi rimasti; se è scarica la scritta lampeggia in rosso.
- **Aiuto alla mira**: se un nemico è più o meno nella direzione del tiro, il colpo va dritto su di lui.
- **Munizioni**: i forzieri ridanno dardi e frecce; a volte un barile rotto ne lascia un po' a terra (ci passi sopra e le prendi). I tiri rompono anche i barili e accendono i bracieri.
- **Nemici nuovi in galleria** (oltre a due scheletri e un mago):
  - l'**arciere** sulla balconata, che tira dardi di balestra (dritti, dove andrai o due di fila);
  - i **pipistrelli**, che dormono appesi e poi scendono in picchiata (basta un colpo);
  - il **saltatore**, piccolo e veloce, che ti balza addosso;
  - il **bestione**, lento e corazzato: da davanti para la spada, quindi colpiscilo alle spalle (ci mette un attimo a girarsi), subito dopo un suo colpo, o con la magia. Colpisce forte e carica.
- Anche i nemici nuovi imparano da te: chi capisce che tiri spesso da lontano impara a schivare i tuoi colpi.
- **Schiva** ora è solo su **Y** (RB serve per tirare).
- **Il bot prova tutto**: aspetta le trappole e passa al momento giusto, salta le piastre che non deve calpestare, schiva le frecce, prende il montacarichi, risolve i due enigmi (sbagliando apposta una volta), apre i forzieri, scorre le armi, rompe un barile con una freccia, tira in alto, svuota la faretra e affronta ogni nemico nuovo. Alla fine rimette i tuoi tesori.
- Corretto un difetto del bot: a volte faceva un salto cortissimo invece di uno normale.

## 0.1 — Nemici che cambiano idea

- **Il mago non insiste più con quello che non funziona**: se una tattica imparata fallisce sempre (per esempio la raffica, schivata 9 volte su 9), la mette da parte e prova altro.
- **Il bot prova anche i tuoi FPS**: se hai scelto un limite sopra 60, alla fine il bot gioca anche con quel limite e controlla che il telefono li raggiunga davvero.

## 0.1 — Il sogno ricorda: nemici che imparano e un bot che gioca davvero

- **Nemesi**: il nemico che ti uccide torna nel sogno successivo più forte, con un nome, un titolo ("il Trionfante", "il Tiranno"…), occhi rossi e una frase che ricorda com'è finita. Se lo batti può tornare "lo Sfregiato", in cerca di vendetta; dopo tre sconfitte riposa per sempre. Anche un nemico normale battuto, a volte, giura vendetta.
- **Nemici più svegli**: non vedono attraverso i muri, sentono i rumori (colpi, rotoli, scatti), ti cercano dove ti hanno visto l'ultima volta. Lo scheletro sceglie tra quattro tattiche (diretto, attesa, affondo, finta) e a volte balza indietro quando attacchi; il mago tiene le distanze e mira dritto, dove andrai o a raffica.
- **Imparano da te**: il sogno nota le tue abitudini (rotoli spesso? scatti all'indietro? salti?) e i nemici si adattano, tenendo il conto delle tattiche che funzionano contro di te. Le nemesi ti dicono cosa hanno imparato.
- **Il bot gioca come una persona**: niente più teletrasporti. Cammina, scavalca le casse, salta, si aggrappa ai bordi, scende dalle piattaforme, rotola nel cunicolo e combatte leggendo i colpi dei nemici e schivandoli. Ricorda quali passaggi e quali schivate funzionano e non ripete gli stessi errori. Nel rapporto trovi cosa ha imparato. Alla fine le nemesi create dal bot spariscono: le tue restano.
- Le frasi lunghe a schermo ora vanno a capo.

## 0.1 — 120 FPS e pausa più fluida

- Con il limite a 90 o 120 FPS il gioco ora prova davvero ad andare oltre i 60 (prima lo schermo cambiava frequenza ma il gioco restava a 60).
- La prima apertura del menu di pausa non dà più un piccolo scatto: l'anteprima del personaggio si prepara all'avvio.

## 0.1 — Muoversi nell'ambiente

- **Scavalcare**: contro un ostacolo basso (per esempio una cassa) tieni su + la direzione e ci sali sopra.
- **Aggrapparsi**: saltando verso un bordo o una piattaforma poco più in alto, il personaggio si aggrappa e sale da solo.
- **Scatto in avanti e all'indietro**: Schiva con la direzione in cui guardi = scatto in avanti; con la direzione opposta = scatto all'indietro senza girarti (anche in aria). Senza direzione resta come prima.
- **Rotolo in avanti e all'indietro**: Rotola con la direzione opposta = rotolo all'indietro, continuando a guardare avanti.
- **Afferrare le casse**: accanto a una cassa tieni premuto **Afferra** (compare sullo schermo solo vicino alla cassa; LB sul controller, E sulla tastiera). Muovendoti la spingi o la tiri.
- Le nuove azioni si possono provare anche nel menu, in "Prova le mosse". Il bot ora prova anche tutte queste.

## 0.1 — Mosse da provare e bot che gioca da solo

- **Gruppi di mosse**: una mano, affondi, due mani, doppia arma, scudo, magia, a mani nude. Cambiano posa e attacchi del personaggio e si scelgono da soli in base all'arma (spadone = due mani, bastone = magia, scudo in mano sinistra = scudo…). Nel menu Aspetto puoi anche sceglierli a mano. Per ora cambia solo l'aspetto: i tempi dei colpi restano uguali.
- **Prova le mosse**: nel menu di pausa, l'anteprima del personaggio ora si muove. Con i tasti puoi provare tutte le azioni di gioco e 22 azioni extra (parata, colpo di scudo, colpo rotante, magia, calcio, lancio, saluto, raccogli…). L'anteprima resta sempre visibile a sinistra mentre scorri il menu.
- Nuova arma: "A mani nude".
- **Bot di prova**: nel menu di pausa, "Fai giocare il bot". Per circa 3-4 minuti gioca da solo tutta la stanza, prova ogni mossa, molti aspetti e le tre qualità, e misura la fluidità di ogni parte. Alla fine rimette le tue scelte, salva il rapporto (che arriva su Drive come gli altri) e chiude il gioco. Premi pausa per fermarlo prima.
- Corretto un errore interno del motore che compariva sul telefono quando il personaggio rinasce.

## 0.1 — L'aspetto del Non Narrato

- Nuova sezione **Aspetto** nel menu di pausa: per testa, copricapo, busto, braccia, gambe, mantello, arma e mano sinistra scegli cosa indossare (elmi, corazze, pellicce, vesti, mantelli, spade, asce, bastoni, scudi, grimorio…) e un colore (Cenere, Ossidiana, Sangue, Notte, Oro antico, Muschio, Ossa).
- Il cambio si vede subito addosso, con l'anteprima nel menu, in tutte le animazioni e con le luci delle torce. Ci sono anche "Casuale" e "Ripristina aspetto".
- Per ora cambia solo l'aspetto: armi e armature non cambiano ancora il combattimento.
- Il personaggio ora è "fotografato" mentre giochi, sempre nello stesso stile pixel art: alcune pose (colpito, morte, capriola) sono più pulite di prima.
- L'aspetto scelto viene ricordato e finisce nel rapporto.

## 0.1 — Correzioni dopo le prime prove sul Pixel

- Tasti a schermo grandi quanto serve: il gioco misura lo schermo e li fa di circa 13 mm. Se li hai già regolati a mano resta la tua scelta; "Ripristina i valori consigliati" torna alla misura automatica.
- 90 e 120 FPS: se li scegli nel menu, il gioco ora chiede ad Android di alzare la frequenza dello schermo (sul Pixel serve anche "Display fluido" acceso nelle impostazioni del telefono).
- All'avvio, dietro lo schermo nero, il gioco prepara tutti gli effetti, per evitare piccoli scatti la prima volta che compaiono.
- Il rapporto annota ogni fotogramma lento con cosa stava succedendo, per trovare la causa di eventuali scatti.

## 0.1 — La stanza di prova

Prima versione: una sola stanza, per capire se lo stile rende come vogliamo.

- Il Non Narrato corre, salta, attacca con due colpi in fila, rotola e schiva (a terra balza indietro, in aria scatta in avanti).
- Due nemici con comportamenti diversi: lo scheletro guerriero, che dorme a terra e si risveglia quando ti avvicini, e lo scheletro mago, che lancia sfere di luce da lontano (si possono spezzare con la spada).
- Più piani: piattaforme da cui si scende con giù + salto, un ripiano alto da raggiungere spingendo una cassa, una terrazza e un cunicolo in cui si passa solo rotolando.
- Barili che vanno in pezzi e casse che si spingono.
- Torce con luci e ombre vere, nebbia, pulviscolo e sfondi a più livelli.
- Personaggi e oggetti nascono da modelli 3D trasformati in pixel art.
- Il gioco riconosce il dispositivo, sceglie da solo la qualità e la abbassa se scalda o va a scatti.
- Controller o tasti a schermo: passa da solo dall'uno all'altro.
- Menu di pausa con le impostazioni e il tasto "Ripristina i valori consigliati".
- Schermata di debug con FPS e dati del dispositivo (si spegne dal menu).
- Rapporto completo salvato a ogni chiusura, anche in Download/NonNarrato_report.
- Controllo degli aggiornamenti dal menu.
- Manca ancora l'audio.
