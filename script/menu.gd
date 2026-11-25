class_name Menu
extends CanvasLayer
# Menu di pausa con le impostazioni. Il gioco sceglie da solo i valori di partenza,
# qui si può cambiare tutto a mano e tornare ai valori consigliati con un tasto.

signal chiuso
signal bot_richiesto

const INDIRIZZO_VERSIONI := "https://api.github.com/repos/vincenzociriello91-hub/NonNarrato/releases/latest"
const PAGINA_VERSIONI := "https://github.com/vincenzociriello91-hub/NonNarrato/releases/latest"
const QUALITA := ["auto", "bassa", "media", "alta"]
const LIMITI_FPS := [0, 30, 60, 90, 120]

var aperto := false
var versione_nuova := ""

var _fondo: ColorRect
var _riprendi: Button
var _qualita: OptionButton
var _fps: OptionButton
var _palette: CheckButton
var _ombre: CheckButton
var _dimensione: HSlider
var _opacita: HSlider
var _vibrazione: CheckButton
var _debug: CheckButton
var _esito: Label
var _aggiorna: Button
var _novita: Label
var _richiesta: HTTPRequest
var _anteprima: TextureRect
var _scelte_oggetto := {}         # posto -> OptionButton
var _scelte_colore := {}          # posto -> OptionButton
var _scelta_mosse: OptionButton
var _griglia_prove: GridContainer
var _azione_in_prova: Label
var tasti_prova := {}             # azione -> Button (li usa anche il bot)
var vetrina: FiguraViva           # figura animata dell'anteprima, anche a gioco in pausa
var _prova_corrente := "fermo"

const AZIONI_DI_GIOCO := [
	["fermo", "Fermo"], ["corsa", "Corsa"], ["salto", "Salto"], ["aria", "In aria"], ["atterra", "Atterraggio"],
	["attacco1", "Attacco 1"], ["attacco2", "Attacco 2"], ["schivata", "Scatto indietro"], ["scatto", "Scatto avanti"],
	["rotolata", "Rotolata"], ["rotolata_indietro", "Rotolo indietro"], ["scavalco", "Scavalcare"],
	["presa", "Afferrare"], ["spinge", "Spingere"], ["tira", "Tirare"], ["usa", "Usare"], ["colpito", "Colpito"], ["morte", "Morte"],
]
var _collegamento := ""
var _in_caricamento := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_costruisci()
	_fondo.visible = false
	Impostazioni.cambiata.connect(func(_chiave: String) -> void: _carica_valori())
	Dispositivo.profilo_cambiato.connect(_carica_valori)
	Equipaggiamento.cambiato.connect(_carica_valori)
	_richiesta = HTTPRequest.new()
	_richiesta.timeout = 8.0
	_richiesta.request_completed.connect(_su_risposta)
	add_child(_richiesta)
	if not Dispositivo.in_prova:
		_cerca_aggiornamenti.call_deferred()


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
	var pannello := PanelContainer.new()
	pannello.custom_minimum_size = Vector2(1120, 0)
	var stile := StyleBoxFlat.new()
	stile.bg_color = Color(0.07, 0.06, 0.11, 0.97)
	stile.border_color = Color(0.33, 0.3, 0.45)
	stile.set_border_width_all(2)
	stile.set_corner_radius_all(18)
	stile.set_content_margin_all(22)
	pannello.add_theme_stylebox_override("panel", stile)
	centro.add_child(pannello)

	var corpo := VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 10)
	pannello.add_child(corpo)
	var titolo := Label.new()
	titolo.text = "NonNarrato — pausa"
	titolo.add_theme_font_size_override("font_size", 30)
	titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	corpo.add_child(titolo)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 22)
	corpo.add_child(riga)

	# A sinistra, sempre visibili: Riprendi e l'anteprima animata del personaggio.
	var sinistra := VBoxContainer.new()
	sinistra.custom_minimum_size = Vector2(300, 0)
	sinistra.add_theme_constant_override("separation", 10)
	riga.add_child(sinistra)
	_riprendi = _pulsante(sinistra, "Riprendi", chiudi)

	var scorri := ScrollContainer.new()
	scorri.custom_minimum_size = Vector2(770, 560)
	scorri.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	riga.add_child(scorri)
	var colonna := VBoxContainer.new()
	colonna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonna.add_theme_constant_override("separation", 10)
	scorri.add_child(colonna)

	_costruisci_aspetto(sinistra, colonna)

	_sezione(colonna, "Grafica")
	_qualita = OptionButton.new()
	for nome in ["Automatica", "Bassa", "Media", "Alta"]:
		_qualita.add_item(nome)
	_qualita.item_selected.connect(func(i: int) -> void: Impostazioni.scrivi("grafica/qualita", QUALITA[i]))
	_riga(colonna, "Qualità", _qualita)
	_fps = OptionButton.new()
	for nome in ["Consigliato", "30", "60", "90", "120"]:
		_fps.add_item(nome)
	_fps.item_selected.connect(func(i: int) -> void: Impostazioni.scrivi("grafica/limite_fps", LIMITI_FPS[i]))
	_riga(colonna, "Limite FPS", _fps)
	_palette = _interruttore(colonna, "Filtro pixel art (palette fissa)", "grafica/palette")
	_ombre = _interruttore(colonna, "Ombre dinamiche", "grafica/ombre")

	_sezione(colonna, "Comandi")
	_dimensione = _cursore(colonna, "Grandezza tasti a schermo", 0.7, 1.8, "controlli/dimensione_touch")
	_opacita = _cursore(colonna, "Visibilità tasti a schermo", 0.2, 1.0, "controlli/opacita_touch")
	_vibrazione = _interruttore(colonna, "Vibrazione", "controlli/vibrazione")

	_sezione(colonna, "Gioco")
	_debug = _interruttore(colonna, "Schermata di debug (FPS e dispositivo)", "gioco/debug")
	_pulsante(colonna, "Ripristina i valori consigliati", Impostazioni.ripristina)

	_sezione(colonna, "Rapporto e aggiornamenti")
	_pulsante(colonna, "Copia il rapporto negli appunti", _copia_rapporto)
	_esito = Label.new()
	_esito.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_esito.add_theme_font_size_override("font_size", 17)
	_esito.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	colonna.add_child(_esito)
	_pulsante(colonna, "Fai giocare il bot", func() -> void:
		chiudi()
		bot_richiesto.emit())
	var spiega := Label.new()
	spiega.text = "Il bot gioca da solo per qualche minuto come una persona: si muove, combatte, muore e affronta la sua nemesi, evita le trappole, risolve gli enigmi, apre i forzieri, prova mosse, aspetti e qualità. Alla fine rimette le tue scelte, i tuoi tesori e i tuoi ricordi, salva il rapporto e chiude il gioco. Premi pausa per fermarlo."
	spiega.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spiega.add_theme_font_size_override("font_size", 17)
	spiega.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	colonna.add_child(spiega)
	_aggiorna = _pulsante(colonna, "Cerca aggiornamenti", _su_aggiorna)
	_novita = Label.new()
	_novita.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_novita.add_theme_font_size_override("font_size", 17)
	_novita.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	colonna.add_child(_novita)


func _costruisci_aspetto(sinistra: VBoxContainer, colonna: VBoxContainer) -> void:
	# Cosa indossa il Non Narrato: per ogni posto un oggetto e un colore. Per ora cambia solo l'aspetto.
	_anteprima = TextureRect.new()
	_anteprima.custom_minimum_size = Vector2(288, 288)
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


func _sezione(dove: Node, testo: String) -> void:
	var e := Label.new()
	e.text = testo
	e.add_theme_font_size_override("font_size", 19)
	e.add_theme_color_override("font_color", Color(0.62, 0.56, 0.85))
	dove.add_child(e)
	dove.add_child(HSeparator.new())


func _pulsante(dove: Node, testo: String, azione: Callable) -> Button:
	var b := Button.new()
	b.text = testo
	b.custom_minimum_size = Vector2(0, 54)
	b.pressed.connect(azione)
	dove.add_child(b)
	return b


func _riga(dove: Node, testo: String, controllo: Control) -> void:
	var riga := HBoxContainer.new()
	var e := Label.new()
	e.text = testo
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	riga.add_child(e)
	controllo.custom_minimum_size = Vector2(250, 50)
	riga.add_child(controllo)
	dove.add_child(riga)


func _interruttore(dove: Node, testo: String, chiave: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = testo
	c.custom_minimum_size = Vector2(0, 48)
	c.toggled.connect(func(acceso: bool) -> void: Impostazioni.scrivi(chiave, acceso))
	dove.add_child(c)
	return c


func _cursore(dove: Node, testo: String, minimo: float, massimo: float, chiave: String) -> HSlider:
	var s := HSlider.new()
	s.min_value = minimo
	s.max_value = massimo
	s.step = 0.05
	s.value_changed.connect(func(v: float) -> void: Impostazioni.scrivi(chiave, v))
	_riga(dove, testo, s)
	return s


# ------------------------------------------------------------------ apertura

func apri() -> void:
	aperto = true
	_prepara_vetrina()
	vetrina.process_mode = Node.PROCESS_MODE_INHERIT
	_anteprima.texture = vetrina.anteprima()
	prova_azione("fermo")
	_carica_valori()
	_fondo.visible = true
	_riprendi.grab_focus()


func chiudi() -> void:
	if not aperto:
		return
	aperto = false
	_fondo.visible = false
	if vetrina != null:
		vetrina.process_mode = Node.PROCESS_MODE_DISABLED  # a menu chiuso non si muove e non disegna
	chiuso.emit()


func _carica_valori() -> void:
	if _in_caricamento or _qualita == null:
		return
	_in_caricamento = true
	_qualita.select(maxi(0, QUALITA.find(Impostazioni.leggi("grafica/qualita"))))
	_qualita.set_item_text(0, "Automatica (%s)" % Dispositivo.livello)
	_fps.select(maxi(0, LIMITI_FPS.find(Impostazioni.leggi("grafica/limite_fps"))))
	_palette.set_pressed_no_signal(Impostazioni.leggi("grafica/palette"))
	_ombre.set_pressed_no_signal(Impostazioni.leggi("grafica/ombre"))
	_dimensione.set_value_no_signal(Dispositivo.scala_touch())
	_opacita.set_value_no_signal(Impostazioni.leggi("controlli/opacita_touch"))
	_vibrazione.set_pressed_no_signal(Impostazioni.leggi("controlli/vibrazione"))
	_debug.set_pressed_no_signal(Impostazioni.leggi("gioco/debug"))
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
	_in_caricamento = false


# ------------------------------------------------------------------ rapporto

func _copia_rapporto() -> void:
	var testo := Rapporto.salva("richiesta")
	DisplayServer.clipboard_set(testo)
	var dove := Rapporto.percorso_download if Rapporto.percorso_download != "" else Rapporto.ultimo_percorso
	_esito.text = "Rapporto copiato negli appunti (%d caratteri): incollalo in chat.\nSalvato anche in: %s" % [testo.length(), dove]


# ------------------------------------------------------------------ aggiornamenti

func _cerca_aggiornamenti() -> void:
	if _richiesta.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var errore := _richiesta.request(INDIRIZZO_VERSIONI, ["Accept: application/vnd.github+json", "User-Agent: NonNarrato"])
	if errore != OK:
		_novita.text = "Controllo aggiornamenti non riuscito."


func _su_aggiorna() -> void:
	if versione_nuova != "":
		OS.shell_open(_collegamento if _collegamento != "" else PAGINA_VERSIONI)
	else:
		_novita.text = "Controllo in corso…"
		_cerca_aggiornamenti()


func _su_risposta(esito: int, codice: int, _intestazioni: PackedStringArray, corpo: PackedByteArray) -> void:
	if esito != HTTPRequest.RESULT_SUCCESS or codice != 200:
		_novita.text = "Nessun collegamento per controllare gli aggiornamenti."
		return
	var dati: Variant = JSON.parse_string(corpo.get_string_from_utf8())
	if typeof(dati) != TYPE_DICTIONARY:
		return
	var ultima := String(dati.get("tag_name", "")).trim_prefix("prova-").trim_prefix("v")
	var attuale := String(ProjectSettings.get_setting("application/config/version", "0"))
	if ultima != "" and _confronta(ultima, attuale) > 0:
		versione_nuova = ultima
		for allegato: Dictionary in dati.get("assets", []):
			if String(allegato.get("name", "")).ends_with(".apk"):
				_collegamento = allegato.get("browser_download_url", "")
		_aggiorna.text = "Scarica la versione %s" % ultima
		_novita.text = "Novità:\n" + String(dati.get("body", "")).left(600)
		Rapporto.evento("aggiornamento_disponibile", {"versione": ultima})
	else:
		_novita.text = "Hai l'ultima versione (%s)." % attuale


func _confronta(a: String, b: String) -> int:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var na := pa[i].to_int() if i < pa.size() else 0
		var nb := pb[i].to_int() if i < pb.size() else 0
		if na != nb:
			return 1 if na > nb else -1
	return 0
