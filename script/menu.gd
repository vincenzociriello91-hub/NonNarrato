class_name Menu
extends CanvasLayer
# Menu di pausa. A sinistra, sempre visibili: Riprendi, l'anteprima animata del personaggio e i tasti
# per l'aspetto, il bot e il rapporto. A destra le impostazioni, divise in cinque schede che si scelgono
# con le linguette in alto: Gioco, Schermo, Grafica, Audio, Accessibilità (con un controller: LB e RB).
# Il gioco sceglie da solo i valori di partenza in base al dispositivo; ogni scheda ha il suo
# "Ripristina i valori consigliati". Le scelte "Automatica" dicono tra parentesi cosa sta usando.

signal chiuso
signal bot_richiesto

const SCHEDE := [["gioco", "Gioco"], ["schermo", "Schermo"], ["grafica", "Grafica"], ["audio", "Audio"], ["accessibilita", "Accessibilità"]]
const QUALITA := ["auto", "bassa", "media", "alta"]
const SI_NO_AUTO := [[-1, "Automatico"], [0, "No"], [1, "Sì"]]

var aperto := false
var scheda := "gioco"

var _fondo: ColorRect
var _pannello: PanelContainer
var _scorri: ScrollContainer
var _riprendi: Button
var _linguette := {}              # scheda -> Button
var _pagine := {}                 # scheda (o "aspetto") -> VBoxContainer
var _controlli := {}              # chiave -> {"tipo", "nodo", "opzioni", ...}
var _info := {}                   # nome -> Label con testo che cambia
var _esito: Label
var _aggiorna: Button
var _stato_aggiornamento: Label
var _novita: Label
var _anteprima: TextureRect
var _scelte_oggetto := {}         # posto -> OptionButton
var _scelte_colore := {}          # posto -> OptionButton
var _scelta_mosse: OptionButton
var _griglia_prove: GridContainer
var _azione_in_prova: Label
var _dote_arma: Label
var _tasto_aspetto: Button
var tasti_prova := {}             # azione -> Button (li usa anche il bot)
var vetrina: FiguraViva           # figura animata dell'anteprima, anche a gioco in pausa
var _prova_corrente := "fermo"

const AZIONI_DI_GIOCO := [
	["fermo", "Fermo"], ["corsa", "Corsa"], ["salto", "Salto"], ["aria", "In aria"], ["atterra", "Atterraggio"],
	["attacco1", "Attacco 1"], ["attacco2", "Attacco 2"], ["schivata", "Scatto indietro"], ["scatto", "Scatto avanti"],
	["rotolata", "Rotolata"], ["rotolata_indietro", "Rotolo indietro"], ["scavalco", "Scavalcare"],
	["presa", "Afferrare"], ["spinge", "Spingere"], ["tira", "Tirare"], ["usa", "Usare"], ["tiro_magia", "Magia"],
	["tiro_dardo", "Dardo"], ["tiro_freccia", "Freccia"], ["colpito", "Colpito"], ["morte", "Morte"],
	["arrampica", "Arrampicata"], ["appeso", "Appeso"], ["nuota", "Nuoto"], ["galleggia", "Galleggia"],
]
var _in_caricamento := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_costruisci()
	_fondo.visible = false
	Impostazioni.cambiata.connect(func(_chiave: String) -> void: _carica_valori())
	Dispositivo.profilo_cambiato.connect(_carica_valori)
	Dispositivo.audio_cambiato.connect(_carica_valori)
	Equipaggiamento.cambiato.connect(_carica_valori)
	Aggiornatore.cambiato.connect(_su_aggiornatore)
	if not Dispositivo.in_prova and Impostazioni.leggi("gioco/controlla_aggiornamenti"):
		Aggiornatore.controlla.call_deferred()


# ------------------------------------------------------------------ costruzione

func _costruisci() -> void:
	_fondo = ColorRect.new()
	_fondo.color = Color(0.01, 0.01, 0.03, 0.72)
	_fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fondo)

	var tema := Theme.new()
	tema.default_font_size = 22
	_fondo.theme = tema

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fondo.add_child(centro)
	_pannello = PanelContainer.new()
	_pannello.custom_minimum_size = Vector2(1180, 0)
	var stile := StyleBoxFlat.new()
	stile.bg_color = Color(0.07, 0.06, 0.11, 0.97)
	stile.border_color = Color(0.33, 0.3, 0.45)
	stile.set_border_width_all(2)
	stile.set_corner_radius_all(18)
	stile.set_content_margin_all(20)
	_pannello.add_theme_stylebox_override("panel", stile)
	centro.add_child(_pannello)

	var corpo := VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 10)
	_pannello.add_child(corpo)
	var titolo := Label.new()
	titolo.text = "NonNarrato — pausa"
	titolo.add_theme_font_size_override("font_size", 28)
	titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	corpo.add_child(titolo)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 20)
	corpo.add_child(riga)

	# A sinistra, sempre visibili.
	var sinistra := VBoxContainer.new()
	sinistra.custom_minimum_size = Vector2(300, 0)
	sinistra.add_theme_constant_override("separation", 8)
	riga.add_child(sinistra)
	_riprendi = _pulsante(sinistra, "Riprendi", chiudi)

	# A destra: linguette e pagina della scheda scelta.
	var destra := VBoxContainer.new()
	destra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destra.add_theme_constant_override("separation", 8)
	riga.add_child(destra)
	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 6)
	destra.add_child(barra)
	var gruppo := ButtonGroup.new()
	var scelta := StyleBoxFlat.new()   # linguetta della scheda aperta: viola, con il bordo chiaro sotto
	scelta.bg_color = Color(0.3, 0.24, 0.5)
	scelta.border_color = Color(0.8, 0.74, 1.0)
	scelta.border_width_bottom = 3
	scelta.set_corner_radius_all(8)
	for coppia: Array in SCHEDE:
		var b := Button.new()
		b.text = coppia[1]
		b.toggle_mode = true
		b.button_group = gruppo
		b.add_theme_stylebox_override("pressed", scelta)
		b.add_theme_stylebox_override("hover_pressed", scelta)
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(func() -> void: Suoni.suona("ui_tocco"))
		b.pressed.connect(mostra_scheda.bind(String(coppia[0])))
		barra.add_child(b)
		_linguette[coppia[0]] = b
	_scorri = ScrollContainer.new()
	_scorri.custom_minimum_size = Vector2(820, 540)
	_scorri.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	destra.add_child(_scorri)
	var pagine := VBoxContainer.new()
	pagine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scorri.add_child(pagine)
	for nome: String in ["gioco", "schermo", "grafica", "audio", "accessibilita", "aspetto"]:
		var p := VBoxContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_theme_constant_override("separation", 8)
		p.visible = false
		pagine.add_child(p)
		_pagine[nome] = p

	_costruisci_aspetto(sinistra, _pagine["aspetto"])
	_tasto_aspetto = _pulsante(sinistra, "Aspetto e mosse", mostra_scheda.bind("aspetto"))
	_pulsante(sinistra, "Fai giocare il bot", func() -> void:
		chiudi()
		bot_richiesto.emit())
	_pulsante(sinistra, "Copia il rapporto", _copia_rapporto)
	_esito = _nota(sinistra, "")

	_costruisci_gioco(_pagine["gioco"])
	_costruisci_schermo(_pagine["schermo"])
	_costruisci_grafica(_pagine["grafica"])
	_costruisci_audio(_pagine["audio"])
	_costruisci_accessibilita(_pagine["accessibilita"])
	mostra_scheda("gioco")


func _costruisci_gioco(p: VBoxContainer) -> void:
	_sezione(p, "Comandi")
	_info["comandi"] = _nota(p, "")
	_scelta(p, "Tipo di comandi", "controlli/modo", [["auto", "Automatico"], ["touch", "Tasti a schermo"], ["controller", "Controller o tastiera"]],
			"Automatico: il gioco passa da solo ai tasti a schermo quando tocchi lo schermo e li nasconde quando usi un controller.")
	_cursore(p, "Grandezza tasti a schermo", "controlli/dimensione_touch", 0.7, 1.8, 0.05, "×%.2f", true)
	_cursore(p, "Visibilità tasti a schermo", "controlli/opacita_touch", 0.2, 1.0, 0.05, "%d%%", false, 100.0)
	_interruttore(p, "Mancini: leva a destra, tasti a sinistra", "controlli/mancino")
	_cursore(p, "Zona morta delle leve", "controlli/zona_morta", 0.15, 0.6, 0.05, "%d%%", false, 100.0,
			"Quanto bisogna spingere la leva prima che il personaggio si muova.")
	_interruttore(p, "Vibrazione", "controlli/vibrazione")
	_cursore(p, "Forza della vibrazione", "controlli/forza_vibrazione", 0.2, 1.0, 0.1, "%d%%", false, 100.0)
	_sezione(p, "Partita")
	_interruttore(p, "Numeri dei danni sopra i nemici", "gioco/numeri_danno")
	_interruttore(p, "Frasi delle nemesi e messaggi della storia", "gioco/messaggi")
	_interruttore(p, "Schermata di debug (FPS e dispositivo)", "gioco/debug")
	_sezione(p, "Aggiornamenti")
	_info["versione"] = _nota(p, "")
	_interruttore(p, "Controlla gli aggiornamenti all'avvio", "gioco/controlla_aggiornamenti")
	_aggiorna = _pulsante(p, "Cerca aggiornamenti", Aggiornatore.aggiorna)
	_stato_aggiornamento = _nota(p, "")
	_novita = _nota(p, "")
	_sezione(p, "Valori consigliati")
	_pulsante(p, "Ripristina i valori consigliati di questa scheda", Impostazioni.ripristina_scheda.bind("gioco"))
	_pulsante(p, "Ripristina tutte le impostazioni", Impostazioni.ripristina)


func _costruisci_schermo(p: VBoxContainer) -> void:
	_sezione(p, "Il tuo schermo")
	_info["schermo"] = _nota(p, "")
	_sezione(p, "Immagine")
	_scelta(p, "Grandezza del mondo", "schermo/scala", [[0, "Automatica"]],
			"Quanti pixel dello schermo fa ogni pixel del gioco: con un numero più piccolo vedi più mondo.")
	_scelta(p, "Adattamento", "schermo/adatta", [["intera", "Pixel perfetti"], ["riempi", "Sempre 360 righe"]],
			"Pixel perfetti: ogni pixel ha la stessa grandezza (consigliato). Sempre 360 righe: si vede la stessa porzione di mondo su ogni telefono; i pixel non sono tutti uguali e conta il filtro di ingrandimento (scheda Grafica).")
	_scelta(p, "Proporzioni", "schermo/proporzioni", [["riempi", "Tutto lo schermo"], ["16:9", "16:9 con bande"]])
	_scelta(p, "Risoluzione del pannello", "schermo/modo", [[0, "Scelta da Android"]],
			"Solo se il telefono ne ha più di una. Il gioco disegna comunque il mondo alla sua risoluzione interna.")
	_sezione(p, "Fluidità")
	_scelta(p, "Limite FPS", "grafica/limite_fps", [[0, "Consigliato"]],
			"Compaiono solo i valori che il tuo schermo regge. Più FPS = più fluido ma più batteria e calore; con il telefono caldo il gioco li abbassa da solo.")
	_interruttore(p, "V-Sync (niente righe spezzate)", "schermo/vsync")
	_sezione(p, "Colori e bordi")
	_cursore(p, "Luminosità", "schermo/luminosita", 0.6, 1.6, 0.05, "%d%%", false, 100.0)
	_cursore(p, "Contrasto", "schermo/contrasto", 0.8, 1.3, 0.05, "%d%%", false, 100.0)
	_cursore(p, "Margini dai bordi", "schermo/margini", 0.0, 0.08, 0.01, "+%d%%", true, 100.0,
			"Automatico: l'interfaccia evita da sola il foro della fotocamera e i bordi curvi.")
	_sezione(p, "Telefono")
	_scelta(p, "Orientamento", "schermo/orientamento", [["sensore", "Si gira da solo"], ["normale", "Orizzontale"], ["capovolto", "Orizzontale capovolto"]])
	_interruttore(p, "Schermo sempre acceso durante il gioco", "schermo/sempre_acceso")
	_pulsante(p, "Ripristina i valori consigliati di questa scheda", Impostazioni.ripristina_scheda.bind("schermo"))


func _costruisci_grafica(p: VBoxContainer) -> void:
	_sezione(p, "Qualità")
	_info["grafica"] = _nota(p, "")
	var q := _scelta(p, "Livello", "grafica/qualita", [["auto", "Automatica"], ["bassa", "Bassa"], ["media", "Media"], ["alta", "Alta"]],
			"Scegliere un livello rimette in automatico tutti i dettagli qui sotto.")
	q["livello"] = true   # vedi _scelta: usa Impostazioni.scegli_qualita
	_interruttore(p, "Riduci da solo la qualità se il gioco va a scatti", "grafica/adattamento")
	_sezione(p, "Dettagli")
	_scelta(p, "Torce con ombra", "grafica/luci_ombra", [[-1, "Automatico"], [0, "Nessuna"], [1, "1"], [2, "2"], [3, "3"], [4, "4"]])
	_scelta(p, "Ombre morbide", "grafica/ombre_morbide", SI_NO_AUTO)
	_scelta(p, "Dettaglio delle ombre", "grafica/atlante_ombre", [[-1, "Automatico"], [512, "Basso"], [1024, "Medio"], [2048, "Alto"]])
	_scelta(p, "Luce di riempimento", "grafica/luci_doppie", SI_NO_AUTO)
	_scelta(p, "Rilievo del personaggio", "grafica/normali_figura", SI_NO_AUTO)
	_scelta(p, "Nebbia", "grafica/nebbia", SI_NO_AUTO)
	_scelta(p, "Sagome in primo piano", "grafica/primo_piano", SI_NO_AUTO)
	_cursore(p, "Particelle", "grafica/particelle", 0.2, 1.0, 0.1, "%d%%", true, 100.0)
	_interruttore(p, "Filtro pixel art (palette fissa)", "grafica/palette")
	_sezione(p, "Ingrandimento (come DLSS e FSR)")
	_nota(p, "Il gioco disegna il mondo a bassa risoluzione e lo ingrandisce: è lo stesso trucco di DLSS e FSR, ma senza perdere nitidezza sulla pixel art. DLSS (solo schede NVIDIA) e FSR 2/3/4 (servono scene 3D) non funzionano su Android con un gioco 2D: qui c'è SGSR di Qualcomm, il loro equivalente per telefoni.")
	_scelta(p, "Risoluzione interna", "grafica/risoluzione", [[1.0, "100% (nitida)"], [0.75, "75%"], [0.5, "50% (massime prestazioni)"]],
			"Sotto il 100% il gioco calcola meno pixel e li ingrandisce col filtro qui sotto: consuma meno, ma i pixel si ammorbidiscono.")
	_scelta(p, "Filtro di ingrandimento", "grafica/filtro", [["nitido", "Nitido"], ["liscio", "Liscio"], ["sgsr", "SGSR (Qualcomm)"]],
			"Serve solo quando l'ingrandimento non è intero (risoluzione interna sotto il 100% o \"Sempre 360 righe\"). A scala intera i pixel pieni sono già perfetti.")
	_cursore(p, "Nitidezza di SGSR", "grafica/nitidezza", 0.0, 1.0, 0.1, "%d%%", false, 100.0)
	_pulsante(p, "Ripristina i valori consigliati di questa scheda", Impostazioni.ripristina_scheda.bind("grafica"))


func _costruisci_audio(p: VBoxContainer) -> void:
	_sezione(p, "Dove ascolti")
	_info["audio"] = _nota(p, "")
	_sezione(p, "Volumi")
	_cursore(p, "Generale", "audio/generale", 0.0, 1.0, 0.05, "%d%%", false, 100.0)
	_cursore(p, "Musica", "audio/musica", 0.0, 1.0, 0.05, "%d%%", false, 100.0)
	_cursore(p, "Effetti", "audio/effetti", 0.0, 1.0, 0.05, "%d%%", false, 100.0)
	_cursore(p, "Ambiente", "audio/ambiente", 0.0, 1.0, 0.05, "%d%%", false, 100.0)
	_cursore(p, "Interfaccia", "audio/interfaccia", 0.0, 1.0, 0.05, "%d%%", false, 100.0)
	_sezione(p, "Suono")
	_scelta(p, "Modalità notte", "audio/notte", SI_NO_AUTO,
			"Avvicina i suoni forti a quelli deboli: utile con l'altoparlante del telefono o a volume basso. Automatico: accesa sull'altoparlante, spenta in cuffia.")
	_scelta(p, "Bassi", "audio/bassi", [[-1, "Automatici"], [0, "Ridotti"], [1, "Normali"], [2, "Forti"]],
			"Automatici: ridotti sull'altoparlante del telefono (non li riproduce bene), normali in cuffia.")
	_interruttore(p, "Mono (stesso suono nelle due orecchie)", "audio/mono")
	_interruttore(p, "Silenzio quando il telefono è silenzioso", "audio/silenzioso")
	_interruttore(p, "Musica più bassa durante la pausa", "audio/pausa_attenua")
	_pulsante(p, "Prova il suono", func() -> void: Suoni.suona("raccogli"))
	_pulsante(p, "Ripristina i valori consigliati di questa scheda", Impostazioni.ripristina_scheda.bind("audio"))


func _costruisci_accessibilita(p: VBoxContainer) -> void:
	_sezione(p, "Difficoltà su misura")
	_cursore(p, "Velocità del gioco", "acc/velocita", 0.5, 1.0, 0.1, "%d%%", false, 100.0,
			"Rallenta tutto (nemici, trappole, personaggio) per avere più tempo per reagire.")
	_scelta(p, "Danni ricevuti", "acc/danni", [[1.0, "Normali"], [0.75, "75%"], [0.5, "Metà"], [0.25, "Un quarto"], [0.0, "Nessuno (invincibile)"]])
	_scelta(p, "Aiuto alla mira", "acc/mira", [[1, "Normale"], [2, "Forte"], [0, "Spento"]])
	_scelta(p, "Tiri da caricare", "acc/carica", [["tieni", "Tieni premuto"], ["alterna", "Premi una volta, poi di nuovo"]])
	_interruttore(p, "Stamina infinita (arrampicarsi senza stancarsi)", "acc/stamina_infinita")
	_interruttore(p, "Respiro infinito sott'acqua", "acc/respiro_infinito")
	_sezione(p, "Vista")
	_cursore(p, "Grandezza di testi e interfaccia", "acc/testo", 0.8, 1.5, 0.05, "%d%%", false, 100.0)
	_cursore(p, "Scosse dello schermo", "acc/scuotimento", 0.0, 1.0, 0.1, "%d%%", false, 100.0)
	_interruttore(p, "Meno lampi (niente fermo immagine, lampi più brevi)", "acc/meno_lampi")
	_interruttore(p, "Contorni chiari attorno a personaggio e nemici", "acc/contorni")
	_scelta(p, "Colori per il daltonismo", "acc/daltonismo", [["no", "Nessuna correzione"], ["protanopia", "Protanopia (rosso)"],
			["deuteranopia", "Deuteranopia (verde)"], ["tritanopia", "Tritanopia (blu)"]])
	_sezione(p, "Udito")
	_interruttore(p, "Didascalie dei suoni importanti", "acc/didascalie")
	_pulsante(p, "Ripristina i valori consigliati di questa scheda", Impostazioni.ripristina_scheda.bind("accessibilita"))


func _costruisci_aspetto(sinistra: VBoxContainer, colonna: VBoxContainer) -> void:
	# Cosa indossa il Non Narrato: per ogni posto un oggetto e un colore. L'arma e la mano sinistra
	# decidono anche come si combatte (vedi Armi): la scritta sotto lo spiega.
	_anteprima = TextureRect.new()
	_anteprima.custom_minimum_size = Vector2(260, 260)
	_anteprima.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_anteprima.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_anteprima.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anteprima.material = FiguraViva.materiale_anteprima()
	_anteprima.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sinistra.add_child(_anteprima)
	_azione_in_prova = Label.new()
	_azione_in_prova.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_azione_in_prova.add_theme_font_size_override("font_size", 17)
	_azione_in_prova.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	_azione_in_prova.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sinistra.add_child(_azione_in_prova)
	_sezione(colonna, "Aspetto")
	_scelta_mosse = OptionButton.new()
	_scelta_mosse.add_item("Automatiche")
	_scelta_mosse.set_item_metadata(0, "auto")
	for id: String in Equipaggiamento.MOSSE:
		_scelta_mosse.add_item(String(Equipaggiamento.MOSSE[id]))
		_scelta_mosse.set_item_metadata(_scelta_mosse.item_count - 1, id)
	_scelta_mosse.item_selected.connect(func(i: int) -> void:
		Equipaggiamento.scegli_mosse(String(_scelta_mosse.get_item_metadata(i))))
	_riga(colonna, "Mosse", _scelta_mosse)
	_dote_arma = _nota(colonna, "")
	_dote_arma.add_theme_color_override("font_color", Color(0.86, 0.8, 0.62))
	for posto in Equipaggiamento.POSTI:
		var riga := HBoxContainer.new()
		riga.add_theme_constant_override("separation", 8)
		var e := Label.new()
		e.text = Equipaggiamento.NOMI_POSTI[posto]
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		e.add_theme_font_size_override("font_size", 19)
		riga.add_child(e)
		var oggetto := OptionButton.new()
		oggetto.custom_minimum_size = Vector2(250, 48)
		oggetto.clip_text = true
		for id: String in Equipaggiamento.oggetti_del_posto(posto):
			oggetto.add_item(Equipaggiamento.nome(id))
			oggetto.set_item_metadata(oggetto.item_count - 1, id)
		oggetto.item_selected.connect(func(i: int) -> void:
			Equipaggiamento.indossa(posto, String(oggetto.get_item_metadata(i))))
		riga.add_child(oggetto)
		var colore := OptionButton.new()
		colore.custom_minimum_size = Vector2(150, 48)
		colore.clip_text = true
		for c: String in Equipaggiamento.COLORI:
			colore.add_item(String(Equipaggiamento.COLORI[c][0]))
			colore.set_item_metadata(colore.item_count - 1, c)
		colore.item_selected.connect(func(i: int) -> void:
			Equipaggiamento.colora(posto, String(colore.get_item_metadata(i))))
		riga.add_child(colore)
		colonna.add_child(riga)
		_scelte_oggetto[posto] = oggetto
		_scelte_colore[posto] = colore
	var tasti := HBoxContainer.new()
	tasti.add_theme_constant_override("separation", 10)
	colonna.add_child(tasti)
	for coppia: Array in [["Casuale", func() -> void: Equipaggiamento.casuale()], ["Ripristina aspetto", Equipaggiamento.ripristina]]:
		var b := _pulsante(tasti, coppia[0], coppia[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_sezione(colonna, "Prova le mosse")
	_griglia_prove = GridContainer.new()
	_griglia_prove.columns = 4
	_griglia_prove.add_theme_constant_override("h_separation", 6)
	_griglia_prove.add_theme_constant_override("v_separation", 6)
	colonna.add_child(_griglia_prove)
	for coppia: Array in AZIONI_DI_GIOCO:
		_tasto_prova(coppia[0], coppia[1])
	# Le azioni extra arrivano dal file della figura, quando la vetrina è pronta (_prepara_vetrina).


func _tasto_prova(azione: String, etichetta: String) -> void:
	var b := Button.new()
	b.text = etichetta
	b.clip_text = true
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(prova_azione.bind(azione))
	_griglia_prove.add_child(b)
	tasti_prova[azione] = b


# ------------------------------------------------------------------ mattoni dell'interfaccia

func _sezione(dove: Node, testo: String) -> void:
	var e := Label.new()
	e.text = testo
	e.add_theme_font_size_override("font_size", 19)
	e.add_theme_color_override("font_color", Color(0.62, 0.56, 0.85))
	dove.add_child(e)
	dove.add_child(HSeparator.new())


func _nota(dove: Node, testo: String) -> Label:
	var e := Label.new()
	e.text = testo
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.add_theme_font_size_override("font_size", 16)
	e.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	e.custom_minimum_size = Vector2(200, 0)
	dove.add_child(e)
	return e


func _pulsante(dove: Node, testo: String, azione: Callable) -> Button:
	var b := Button.new()
	b.text = testo
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(func() -> void: Suoni.suona("ui_tocco"))
	b.pressed.connect(azione)
	dove.add_child(b)
	return b


func _riga(dove: Node, testo: String, controllo: Control) -> void:
	var riga := HBoxContainer.new()
	var e := Label.new()
	e.text = testo
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	riga.add_child(e)
	controllo.custom_minimum_size = Vector2(300, 50)
	riga.add_child(controllo)
	dove.add_child(riga)


func _scelta(dove: Node, testo: String, chiave: String, opzioni: Array, spiega: String = "") -> Dictionary:
	var o := OptionButton.new()
	o.clip_text = true
	var voce := {"tipo": "scelta", "nodo": o, "opzioni": opzioni.duplicate(true)}
	_riempi_scelta(voce)
	o.item_selected.connect(func(i: int) -> void:
		if _in_caricamento:
			return
		Suoni.suona("ui_tocco")
		var elenco: Array = voce["opzioni"]
		if i < 0 or i >= elenco.size():
			return
		if voce.get("livello", false):
			Impostazioni.scegli_qualita(String(elenco[i][0]))
		else:
			Impostazioni.scrivi(chiave, elenco[i][0]))
	_riga(dove, testo, o)
	if spiega != "":
		_nota(dove, spiega)
	_controlli[chiave] = voce
	return voce


func _riempi_scelta(voce: Dictionary) -> void:
	var o: OptionButton = voce["nodo"]
	o.clear()
	for coppia: Array in voce["opzioni"]:
		o.add_item(String(coppia[1]))


func _interruttore(dove: Node, testo: String, chiave: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = testo
	c.custom_minimum_size = Vector2(0, 48)
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.toggled.connect(func(acceso: bool) -> void:
		if _in_caricamento:
			return
		Suoni.suona("ui_tocco")
		Impostazioni.scrivi(chiave, acceso))
	dove.add_child(c)
	_controlli[chiave] = {"tipo": "interruttore", "nodo": c}
	return c


func _cursore(dove: Node, testo: String, chiave: String, minimo: float, massimo: float, passo: float,
		formato: String, con_auto: bool = false, moltiplica: float = 1.0, spiega: String = "") -> HSlider:
	# Un cursore con il valore scritto accanto. con_auto: c'è anche la casella "Auto" (valore -1).
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 8)
	var e := Label.new()
	e.text = testo
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	riga.add_child(e)
	var valore := Label.new()
	valore.custom_minimum_size = Vector2(70, 0)
	valore.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	valore.add_theme_font_size_override("font_size", 18)
	riga.add_child(valore)
	var s := HSlider.new()
	s.min_value = minimo
	s.max_value = massimo
	s.step = passo
	s.custom_minimum_size = Vector2(230 if con_auto else 300, 50)
	riga.add_child(s)
	var auto: CheckBox = null
	if con_auto:
		auto = CheckBox.new()
		auto.text = "Auto"
		riga.add_child(auto)
		auto.toggled.connect(func(si: bool) -> void:
			if _in_caricamento:
				return
			Suoni.suona("ui_tocco")
			Impostazioni.scrivi(chiave, -1.0 if si else s.value))
	s.value_changed.connect(func(v: float) -> void:
		valore.text = formato % (v * moltiplica)
		if not _in_caricamento:
			Impostazioni.scrivi(chiave, v))
	dove.add_child(riga)
	if spiega != "":
		_nota(dove, spiega)
	_controlli[chiave] = {"tipo": "cursore", "nodo": s, "auto": auto, "valore": valore, "formato": formato, "moltiplica": moltiplica}
	return s


func scegli(chiave: String, valore: Variant) -> bool:
	# Usato dal bot: sceglie una voce dal menu come farebbe chi gioca (true se la voce esiste).
	if not _controlli.has(chiave):
		return false
	var voce: Dictionary = _controlli[chiave]
	match voce["tipo"]:
		"scelta":
			var elenco: Array = voce["opzioni"]
			for i in elenco.size():
				if typeof(elenco[i][0]) == typeof(valore) and elenco[i][0] == valore:
					(voce["nodo"] as OptionButton).select(i)
					(voce["nodo"] as OptionButton).item_selected.emit(i)
					return true
			return false
		"interruttore":
			(voce["nodo"] as CheckButton).button_pressed = bool(valore)
			return true
		"cursore":
			(voce["nodo"] as HSlider).value = float(valore)
			return true
	return false


func opzioni_di(chiave: String) -> Array:
	# Le voci di una scelta (valore, scritta): per le prove.
	if not _controlli.has(chiave) or _controlli[chiave]["tipo"] != "scelta":
		return []
	return (_controlli[chiave]["opzioni"] as Array).duplicate(true)


func testo_info(nome: String) -> String:
	return (_info[nome] as Label).text if _info.has(nome) else ""


func controlli_scheda(nome: String) -> int:
	# Quanti controlli ha la pagina di una scheda (per le prove).
	var pagina: VBoxContainer = _pagine.get(nome)
	if pagina == null:
		return 0
	return pagina.find_children("*", "BaseButton", true, false).size() + pagina.find_children("*", "Range", true, false).size()


func pagina_visibile(nome: String) -> bool:
	return _pagine.has(nome) and (_pagine[nome] as Control).visible


func mostra_scheda(nome: String) -> void:
	scheda = nome
	for chiave: String in _pagine:
		(_pagine[chiave] as Control).visible = chiave == nome
	for chiave: String in _linguette:
		(_linguette[chiave] as Button).set_pressed_no_signal(chiave == nome)
	if _tasto_aspetto != null:
		_tasto_aspetto.text = "Aspetto e mosse" if nome != "aspetto" else "Aspetto e mosse ◂"
	if _scorri != null:
		_scorri.scroll_vertical = 0
	_carica_valori()


# ------------------------------------------------------------------ vetrina del personaggio

func prepara_vetrina() -> void:
	_prepara_vetrina()
	vetrina.process_mode = Node.PROCESS_MODE_DISABLED if not aperto else Node.PROCESS_MODE_INHERIT


func _prepara_vetrina() -> void:
	if vetrina != null:
		return
	vetrina = FiguraViva.new()
	vetrina.usa_normali = false
	vetrina.visible = false         # si vede solo nell'anteprima del menu
	add_child(vetrina)
	vetrina.carica("protagonista")
	vetrina.finita.connect(_dopo_prova)
	for coppia: Array in vetrina.prove():
		_tasto_prova(coppia[0], coppia[1])


func prova_azione(azione: String) -> void:
	# L'anteprima ripete l'azione scelta finché non se ne sceglie un'altra.
	if vetrina == null:
		return
	_prova_corrente = azione
	vetrina.riproduci(azione, true)
	var etichetta: String = tasti_prova[azione].text if tasti_prova.has(azione) else azione
	_azione_in_prova.text = "%s · mosse: %s" % [etichetta, Equipaggiamento.MOSSE.get(vetrina.mosse, vetrina.mosse)]
	Rapporto.conta("mosse_provate")


func _dopo_prova(azione: String) -> void:
	await get_tree().create_timer(0.6).timeout
	if aperto and vetrina != null and azione == _prova_corrente and not vetrina.in_corso:
		vetrina.riproduci(azione, true)


# ------------------------------------------------------------------ apertura

func apri() -> void:
	aperto = true
	_prepara_vetrina()
	vetrina.process_mode = Node.PROCESS_MODE_INHERIT
	_anteprima.texture = vetrina.anteprima()
	prova_azione("fermo")
	_adatta_al_display()
	_aggiorna_opzioni_dispositivo()
	_carica_valori()
	_fondo.visible = true
	Suoni.suona("ui_apri")
	_riprendi.grab_focus()


func chiudi() -> void:
	if not aperto:
		return
	aperto = false
	_fondo.visible = false
	Suoni.suona("ui_indietro")
	if vetrina != null:
		vetrina.process_mode = Node.PROCESS_MODE_DISABLED  # a menu chiuso non si muove e non disegna
	chiuso.emit()


func _input(evento: InputEvent) -> void:
	# Con un controller o la tastiera: LB/RB (E/I) cambiano scheda.
	if not aperto or evento.is_echo():
		return
	var verso := 0
	if evento.is_action_pressed("afferra"):
		verso = -1
	elif evento.is_action_pressed("tira"):
		verso = 1
	if verso == 0:
		return
	var nomi: Array = SCHEDE.map(func(c: Array) -> String: return c[0])
	var i := nomi.find(scheda)
	mostra_scheda(nomi[wrapi(i + verso, 0, nomi.size())])
	Suoni.suona("ui_tocco")
	get_viewport().set_input_as_handled()


func _adatta_al_display() -> void:
	# Il pannello sta sempre dentro lo schermo, anche con i testi ingranditi.
	var area := get_viewport().get_visible_rect().size
	_pannello.custom_minimum_size.x = minf(1180.0, area.x - 30.0)
	_scorri.custom_minimum_size = Vector2(maxf(420.0, _pannello.custom_minimum_size.x - 360.0), maxf(260.0, area.y - 190.0))


func _aggiorna_opzioni_dispositivo() -> void:
	# Le voci che dipendono dal telefono: grandezze possibili, limiti FPS, risoluzioni del pannello.
	var finestra := get_window().size
	var area := Dispositivo.area_di_gioco(finestra)
	var consigliata := Dispositivo.scala_consigliata(area)
	var scale: Array = [[0, "Automatica (×%d)" % consigliata]]
	for s: int in Dispositivo.scale_possibili(area):
		scale.append([s, "×%d — %d righe" % [s, roundi(float(area.y) / s)]])
	_imposta_opzioni("schermo/scala", scale)
	var fps: Array = [[0, "Consigliato (60)"]]
	for f: int in Dispositivo.fps_possibili():
		fps.append([f, str(f)])
	_imposta_opzioni("grafica/limite_fps", fps)
	var modi: Array = [[0, "Scelta da Android"]]
	for m: Dictionary in Dispositivo.risoluzioni_schermo():
		modi.append([int(m["id"]), "%d×%d (%d Hz)" % [int(m["w"]), int(m["h"]), roundi(float(m["hz"]))]])
	_imposta_opzioni("schermo/modo", modi)
	(_controlli["schermo/modo"]["nodo"] as OptionButton).disabled = modi.size() <= 2


func _imposta_opzioni(chiave: String, opzioni: Array) -> void:
	var voce: Dictionary = _controlli[chiave]
	voce["opzioni"] = opzioni
	_riempi_scelta(voce)


func _carica_valori() -> void:
	if _in_caricamento or _riprendi == null:
		return
	_in_caricamento = true
	for chiave: String in _controlli:
		var voce: Dictionary = _controlli[chiave]
		var v: Variant = Impostazioni.leggi(chiave)
		match voce["tipo"]:
			"scelta":
				var o: OptionButton = voce["nodo"]
				var elenco: Array = voce["opzioni"]
				var trovato := -1
				for i in elenco.size():
					var x: Variant = elenco[i][0]
					if typeof(x) in [TYPE_FLOAT, TYPE_INT] and typeof(v) in [TYPE_FLOAT, TYPE_INT]:
						if is_equal_approx(float(x), float(v)):
							trovato = i
					elif typeof(x) == typeof(v) and x == v:
						trovato = i
				o.select(maxi(0, trovato))
			"interruttore":
				(voce["nodo"] as CheckButton).set_pressed_no_signal(bool(v))
			"cursore":
				var s: HSlider = voce["nodo"]
				var auto: CheckBox = voce["auto"]
				var automatico := auto != null and float(v) < 0.0
				var mostrato := _valore_automatico(chiave) if automatico else float(v)
				s.set_value_no_signal(mostrato)
				s.editable = not automatico
				(voce["valore"] as Label).text = String(voce["formato"]) % (mostrato * float(voce["moltiplica"]))
				if auto != null:
					auto.set_pressed_no_signal(automatico)
	_etichette_automatiche()
	_testi_informativi()
	_carica_aspetto()
	_su_aggiornatore()
	_in_caricamento = false


func _valore_automatico(chiave: String) -> float:
	match chiave:
		"controlli/dimensione_touch":
			return Dispositivo.scala_touch_consigliata()
		"grafica/particelle":
			return float(Dispositivo.profilo.get("particelle", 1.0))
	return 0.0


func _etichette_automatiche() -> void:
	# Le voci "Automatico" dicono cosa sta usando il gioco in questo momento.
	var profilo := Dispositivo.profilo
	var nomi := {
		"grafica/luci_ombra": "Automatico (%d)" % int(profilo.get("luci_con_ombra", 0)),
		"grafica/ombre_morbide": "Automatico (%s)" % _si_no(profilo.get("ombre_morbide", false)),
		"grafica/atlante_ombre": "Automatico (%s)" % {512: "basso", 1024: "medio", 2048: "alto"}.get(int(profilo.get("atlante_ombre", 1024)), "medio"),
		"grafica/luci_doppie": "Automatico (%s)" % _si_no(profilo.get("luci_doppie", true)),
		"grafica/normali_figura": "Automatico (%s)" % _si_no(profilo.get("figura_normali", true)),
		"grafica/nebbia": "Automatico (%s)" % _si_no(profilo.get("nebbia", true)),
		"grafica/primo_piano": "Automatico (%s)" % _si_no(profilo.get("primo_piano", true)),
		"audio/notte": "Automatico (%s)" % _si_no(Suoni.notte_attiva()),
		"audio/bassi": "Automatici (%s)" % ["ridotti", "normali", "forti"][clampi(Suoni.bassi_scelti(), 0, 2)],
		"controlli/modo": "Automatico (ora: %s)" % _nome_comandi(),
	}
	for chiave: String in nomi:
		if _controlli.has(chiave):
			(_controlli[chiave]["nodo"] as OptionButton).set_item_text(0, nomi[chiave])
	var q: OptionButton = _controlli["grafica/qualita"]["nodo"]
	q.set_item_text(0, "Automatica (%s)" % Dispositivo.livello)
	if Impostazioni.personalizzata():
		q.set_item_text(q.selected, q.get_item_text(q.selected) + " + personalizzata")


func _si_no(v: Variant) -> String:
	return "sì" if bool(v) else "no"


func _nome_comandi() -> String:
	return {"touch": "tasti a schermo", "controller": "controller", "tastiera": "tastiera"}.get(Controlli.nome_modo(), "")


func _testi_informativi() -> void:
	var d := Dispositivo
	var schermo: Array = d.info.get("schermo", [0, 0])
	var interna := d.risoluzione_interna(get_window().size)
	var dim: Vector2i = interna["dimensione"]
	var resa: Vector2i = interna["resa"]
	var testo := "%s · schermo %d×%d · %s Hz · %d dpi%s" % [d.info.get("modello", "?"), schermo[0], schermo[1],
			str(d.info.get("hz", "?")), int(d.info.get("dpi", 0)), " · HDR" if d.hdr else ""]
	testo += "\nMondo di gioco %d×%d ingrandito ×%s" % [dim.x, dim.y, str(snappedf(float(interna["scala"]), 0.01))]
	if resa != dim:
		testo += " (disegnato a %d×%d)" % [resa.x, resa.y]
	if not d.modi_schermo.is_empty():
		var hz: Array = []
		for m: Dictionary in d.modi_schermo:
			if not hz.has(roundi(float(m["hz"]))):
				hz.append(roundi(float(m["hz"])))
		hz.sort()
		testo += "\nFrequenze del pannello: %s Hz" % ", ".join(hz.map(func(h: int) -> String: return str(h)))
	(_info["schermo"] as Label).text = testo
	var calore := "normale" if d.riduzione_caldo == 0 else ("caldo: qualità ridotta" if d.riduzione_caldo == 1 else "molto caldo: qualità ridotta di più")
	(_info["grafica"] as Label).text = "In uso: qualità %s (consigliata per il tuo dispositivo: %s) · obiettivo %d FPS\n%s · calore %s" % [
			d.livello, d.livello_consigliato, d.fps_obiettivo, d.info.get("gpu", "?"), calore]
	var uscite := {"altoparlante": "altoparlante del telefono", "cuffie": "cuffie con il filo", "bluetooth": "dispositivo Bluetooth",
			"usb": "uscita USB", "hdmi": "schermo esterno (HDMI)", "altro": "altra uscita", "": "non rilevata (computer o versione senza plugin)"}
	var suonerie := {0: "silenziosa", 1: "vibrazione", 2: "normale", -1: "non rilevata"}
	var testo_audio := "Il suono esce da: %s · suoneria %s" % [uscite.get(d.uscita_audio, d.uscita_audio), suonerie.get(d.suoneria, "?")]
	if Suoni.silenziato():
		testo_audio += "\nIl telefono è silenzioso: il gioco tace (lo puoi cambiare qui sotto)."
	if d.uscita_audio == "bluetooth":
		testo_audio += "\nCon il Bluetooth i suoni arrivano con un leggero ritardo: dipende dal dispositivo, non dal gioco."
	(_info["audio"] as Label).text = testo_audio
	var comandi := "In uso: %s" % _nome_comandi()
	if Controlli.controller != "":
		comandi += " · controller collegato: %s" % Controlli.controller
	(_info["comandi"] as Label).text = comandi
	(_info["versione"] as Label).text = "Versione installata: %s" % Aggiornatore.versione_attuale


func _carica_aspetto() -> void:
	if _dote_arma != null:
		_dote_arma.text = Armi.descrizione(Equipaggiamento.indossati.get("arma", ""), Equipaggiamento.indossati.get("mano_sinistra", ""))
	for i in _scelta_mosse.item_count:
		if _scelta_mosse.get_item_metadata(i) == Equipaggiamento.mosse_scelte:
			_scelta_mosse.select(i)
	_scelta_mosse.set_item_text(0, "Automatiche (%s)" % Equipaggiamento.MOSSE[Equipaggiamento.mosse_automatiche()])
	if vetrina != null and _azione_in_prova != null:
		var etichetta: String = tasti_prova[_prova_corrente].text if tasti_prova.has(_prova_corrente) else _prova_corrente
		_azione_in_prova.text = "%s · mosse: %s" % [etichetta, Equipaggiamento.MOSSE.get(Equipaggiamento.mosse_attive(), "")]
	for posto: String in _scelte_oggetto:
		var oggetto: OptionButton = _scelte_oggetto[posto]
		for i in oggetto.item_count:
			if oggetto.get_item_metadata(i) == Equipaggiamento.indossati[posto]:
				oggetto.select(i)
		var colore: OptionButton = _scelte_colore[posto]
		for i in colore.item_count:
			var c: String = colore.get_item_metadata(i)
			# I colori rari si vedono solo dopo averli trovati in un forziere d'oro.
			var libero := Equipaggiamento.disponibile(c)
			colore.set_item_disabled(i, not libero)
			colore.set_item_text(i, String(Equipaggiamento.COLORI[c][0]) if libero else "??? (forziere d'oro)")
			if c == Equipaggiamento.colori[posto]:
				colore.select(i)


# ------------------------------------------------------------------ rapporto e aggiornamenti

func _copia_rapporto() -> void:
	var testo := Rapporto.salva("richiesta")
	DisplayServer.clipboard_set(testo)
	var dove := Rapporto.percorso_download if Rapporto.percorso_download != "" else Rapporto.ultimo_percorso
	_esito.text = "Rapporto copiato negli appunti (%d caratteri).\nSalvato anche in: %s" % [testo.length(), dove]


func _su_aggiornatore() -> void:
	if _aggiorna == null:
		return
	_aggiorna.text = Aggiornatore.testo_pulsante()
	_aggiorna.disabled = Aggiornatore.stato in ["controllo", "scarico", "verifica", "installo", "permesso"]
	_stato_aggiornamento.text = Aggiornatore.messaggio
	_novita.text = ("Novità della versione %s:\n%s" % [Aggiornatore.versione_nuova, Aggiornatore.note.left(700)]) \
			if Aggiornatore.versione_nuova != "" and Aggiornatore.note != "" else ""
