class_name Bot
extends Node
# Il bot di prova: gioca da solo la stanza come farebbe chi gioca (corsa, salti, colpi, cassa,
# barili, nemici, cunicolo, piattaforme, schivate, tasti a schermo, menu), prova ogni gruppo di mosse,
# ogni azione del menu, molti aspetti e le tre qualità, e misura la fluidità di ogni fase.
# Alla fine rimette impostazioni e aspetto di chi gioca e salva il rapporto (che finisce in
# Download/NonNarrato_report e da lì su Drive). Sul telefono poi chiude il gioco.
# Lo usa anche la prova automatica sul computer (test/prova.gd).

signal finito(falliti: int)
signal _mai                                 # non arriva mai: tiene ferma la sequenza dopo uno stop

const SEGNO := "user://bot_in_corso.txt"   # stato di chi gioca, se il gioco si chiude a metà
const AZIONI: Array[String] = ["sinistra", "destra", "su", "giu", "salta", "attacca", "rotola", "schiva"]
const LENTO_MS := 33.4                      # sotto i 30 FPS
const MOLTO_LENTO_MS := 50.0                # sotto i 20 FPS

var chiudi_alla_fine := true     # sul telefono: chiude il gioco dopo aver salvato il rapporto
var scritta := true              # la scritta "Bot in azione" in alto
var cartella_foto := ""          # solo nelle prove sul computer
var falliti := 0
var controlli: Array = []
var fasi: Array = []
var in_corso := false
var fase_nome := ""

var _principale: Node
var _fase := {}
var _etichetta: Label
var _stato_utente := {}
var _fermato := false
var _inizio_ms := 0
var _scatti := 0
var _numero_fase := 0


static func ripara_se_interrotto() -> void:
	# All'avvio: se l'ultima volta il bot non ha finito, rimette impostazioni e aspetto di chi gioca.
	if not FileAccess.file_exists(SEGNO):
		return
	var stato: Variant = str_to_var(FileAccess.get_file_as_string(SEGNO))
	if typeof(stato) == TYPE_DICTIONARY:
		_rimetti(stato)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SEGNO))
	Rapporto.evento("bot_ripristino_dopo_interruzione")


static func _rimetti(stato: Dictionary) -> void:
	var imp: Dictionary = stato.get("impostazioni", {})
	for chiave: String in imp:
		Impostazioni.scrivi(chiave, imp[chiave])
	Equipaggiamento.ripristina_stato(stato.get("aspetto", {}))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_principale = get_parent()


func avvia() -> void:
	if in_corso:
		return
	in_corso = true
	_inizio_ms = Time.get_ticks_msec()
	_stato_utente = {"impostazioni": Impostazioni.tutte(), "aspetto": Equipaggiamento.stato()}
	var f := FileAccess.open(SEGNO, FileAccess.WRITE)
	if f != null:
		f.store_string(var_to_str(_stato_utente))
		f.close()
	Dispositivo.bot_attivo = true
	Rapporto.evento("bot_inizio")
	if scritta:
		_crea_scritta()
	_esegui()


func ferma() -> void:
	# Chi gioca ha premuto pausa (o è uscito dal gioco): il bot si ferma e salva quello che ha.
	if not in_corso or _fermato:
		return
	_fermato = true
	_rilascia_tutto()
	_chiudi_fase()
	_verifica("bot fermato da chi gioca", true)
	await _concludi("bot_fermato")


# ------------------------------------------------------------------ aiuti

func _g() -> Giocatore:
	return _principale.stanza.giocatore


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		if _fermato:
			await _mai
			return


func _fotogrammi_in_pausa(n: int) -> void:
	# A gioco in pausa i giri della fisica si fermano: conto quelli dello schermo.
	for i in n:
		await get_tree().process_frame
		if _fermato:
			await _mai
			return


func _attendi_in_pausa(secondi: float) -> void:
	await get_tree().create_timer(secondi, true).timeout
	if _fermato:
		await _mai


func _tieni(azione: String, n: int) -> void:
	Input.action_press(azione)
	await _fotogrammi(n)
	Input.action_release(azione)


func _tocca(azione: String) -> void:
	Input.action_press(azione)
	await _fotogrammi(2)
	Input.action_release(azione)
	await _fotogrammi(1)


func _rilascia_tutto() -> void:
	for azione in AZIONI:
		Input.action_release(azione)


func _sposta(dove: Vector2, verso: int = 1) -> void:
	_rilascia_tutto()
	var g := _g()
	g.position = dove
	g.velocity = Vector2.ZERO
	g.camera.reset_smoothing()
	await _fotogrammi(4)
	await _tieni("destra" if verso > 0 else "sinistra", 2)
	await _fotogrammi(3)


func _verifica(nome: String, riuscita: bool, dettaglio: String = "") -> void:
	print("PROVA %s: %s %s" % ["ok" if riuscita else "FALLITA", nome, dettaglio])
	controlli.append({"nome": nome, "ok": riuscita, "dettaglio": dettaglio.left(200), "fase": fase_nome,
			"t": snappedf((Time.get_ticks_msec() - _inizio_ms) / 1000.0, 0.1)})
	if not riuscita:
		falliti += 1


func _scatta(nome: String) -> void:
	if cartella_foto == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_scatti += 1
	var immagine := get_viewport().get_texture().get_image()
	immagine.save_png(cartella_foto.path_join("%02d_%s.png" % [_scatti, nome]))


func _tocco_schermo(indice: int, dove: Vector2, premuto: bool) -> void:
	# "dove" è in unità dell'interfaccia: lo porto in pixel veri della finestra.
	var fattore := float(get_window().size.x) / maxf(1.0, get_viewport().get_visible_rect().size.x)
	var e := InputEventScreenTouch.new()
	e.index = indice
	e.position = dove * fattore
	e.pressed = premuto
	Input.parse_input_event(e)


func _trascina(indice: int, da: Vector2, a: Vector2) -> void:
	var fattore := float(get_window().size.x) / maxf(1.0, get_viewport().get_visible_rect().size.x)
	var e := InputEventScreenDrag.new()
	e.index = indice
	e.position = a * fattore
	e.relative = (a - da) * fattore
	Input.parse_input_event(e)


func _nemico_vivo(tipo: String) -> Nemico:
	var scelto: Nemico = null
	var minima := INF
	for n: Nemico in get_tree().get_nodes_in_group("nemici"):
		if n.tipo != tipo or n.stato == Nemico.Stato.MORTO or n.stato == Nemico.Stato.DORME:
			continue
		var d := absf(n.position.x - _g().position.x) + absf(n.position.y - _g().position.y)
		if d < minima:
			minima = d
			scelto = n
	return scelto


func _combatti(tipo: String, massimo: int) -> void:
	# Va verso il nemico più vicino di quel tipo e lo colpisce finché non cade.
	var uccisi := Rapporto.contatore("nemici_uccisi")
	for i in massimo:
		var g := _g()
		var n := _nemico_vivo(tipo)
		if n == null or Rapporto.contatore("nemici_uccisi") > uccisi or g.stato == Giocatore.Stato.MORTO:
			break
		var dx := n.position.x - g.position.x
		Input.action_release("sinistra")
		Input.action_release("destra")
		if absf(dx) > 30.0:
			Input.action_press("destra" if dx > 0.0 else "sinistra")
			Input.action_release("attacca")
		elif i % 8 < 2:
			Input.action_press("destra" if dx > 0.0 else "sinistra")
			Input.action_press("attacca")
		else:
			Input.action_release("attacca")
		await _fotogrammi(1)
	_rilascia_tutto()
	await _fotogrammi(20)


func _pezzi_attesi() -> Array:
	var attesi: Array = []
	for posto in Equipaggiamento.POSTI:
		attesi.append_array(Equipaggiamento.pezzi(Equipaggiamento.indossati[posto]))
	attesi.sort()
	return attesi


func _pezzi_figura() -> Array:
	var visti: Array = (_g().sprite as FiguraViva).pezzi_visibili()
	visti.sort()
	return visti


func _pixel_pieni(img: Image) -> int:
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			if img.get_pixel(x, y).a >= 0.5:
				n += 1
	return n


# ------------------------------------------------------------------ fasi e fluidità

func _nuova_fase(nome: String) -> void:
	_chiudi_fase()
	_numero_fase += 1
	fase_nome = nome
	_fase = {"nome": nome, "fotogrammi": 0, "tempo": 0.0, "peggiore_ms": 0.0, "lenti": 0, "molto_lenti": 0,
			"qualita": Dispositivo.livello}
	if _etichetta != null:
		_etichetta.text = "Bot in azione · %s (%d) · premi pausa per fermarlo" % [nome.replace("_", " "), _numero_fase]


func _chiudi_fase() -> void:
	if _fase.is_empty():
		return
	var t: float = _fase["tempo"]
	fasi.append({
		"nome": _fase["nome"],
		"secondi": snappedf(t, 0.1),
		"fps_medio": snappedf(float(_fase["fotogrammi"]) / t, 0.1) if t > 0.0 else 0.0,
		"ms_peggiore": snappedf(_fase["peggiore_ms"], 0.1),
		"sotto_30_fps": _fase["lenti"],
		"sotto_20_fps": _fase["molto_lenti"],
		"qualita": _fase["qualita"],
	})
	_fase = {}


func _process(delta: float) -> void:
	if _fase.is_empty() or (get_tree().paused and fase_nome != "menu_mosse"):
		return
	var ms := delta * 1000.0
	_fase["fotogrammi"] += 1
	_fase["tempo"] += delta
	_fase["peggiore_ms"] = maxf(_fase["peggiore_ms"], ms)
	if ms > LENTO_MS:
		_fase["lenti"] += 1
	if ms > MOLTO_LENTO_MS:
		_fase["molto_lenti"] += 1


func _crea_scritta() -> void:
	var strato := CanvasLayer.new()
	strato.layer = 25
	add_child(strato)
	_etichetta = Label.new()
	_etichetta.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_etichetta.position.y = 6.0
	_etichetta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etichetta.add_theme_font_size_override("font_size", 20)
	_etichetta.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	_etichetta.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	_etichetta.add_theme_constant_override("outline_size", 6)
	_etichetta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strato.add_child(_etichetta)


# ------------------------------------------------------------------ partita

func _esegui() -> void:
	# Si parte sempre dalla stessa stanza e dagli stessi valori: i risultati sono confrontabili.
	if _principale.menu.aperto:
		_principale.menu.chiudi()
	Impostazioni.ripristina()
	Equipaggiamento.ripristina()
	Impostazioni.scrivi("grafica/qualita", "alta")
	Impostazioni.scrivi("controlli/vibrazione", false)
	_principale.ricomincia_stanza()
	_nuova_fase("avvio")
	await _fotogrammi(60)
	var g := _g()
	_verifica("avvio: giocatore a terra", g.is_on_floor() and absf(g.position.y - Stanza.PAVIMENTO) < 2.0, str(g.position))
	_verifica("avvio: qualità alta con ombre", Dispositivo.livello == "alta" and _principale.stanza.torce_con_ombra() > 0,
			"%s, torce con ombra %d" % [Dispositivo.livello, _principale.stanza.torce_con_ombra()])
	await _scatta("inizio")

	await _movimento()
	await _oggetti()
	await _nemici()
	await _percorso()
	await _qualita()
	await _tasti_a_schermo()
	await _menu_e_aspetto()
	await _mosse_in_partita()
	await _morte()
	await _comandi_a_caso()
	await _prestazioni()
	_chiudi_fase()
	await _concludi("bot")


func _movimento() -> void:
	_nuova_fase("movimento")
	var g := _g()
	var x0 := g.position.x
	await _tieni("sinistra", 20)
	_verifica("corsa a sinistra", g.position.x < x0 - 20.0, "%.0f -> %.0f" % [x0, g.position.x])
	await _fotogrammi(20)
	Input.action_press("salta")
	var quota := g.position.y
	for i in 45:
		await _fotogrammi(1)
		quota = minf(quota, g.position.y)
	Input.action_release("salta")
	await _fotogrammi(30)
	_verifica("salto", quota < Stanza.PAVIMENTO - 60.0 and g.is_on_floor(), "apice %.0f px" % (Stanza.PAVIMENTO - quota))

	_nuova_fase("attacchi")
	var colpi := Rapporto.contatore("attacchi")
	await _tocca("attacca")
	await _fotogrammi(8)
	await _tocca("attacca")
	await _fotogrammi(12)
	await _scatta("attacco")
	await _fotogrammi(40)
	_verifica("due colpi in fila", Rapporto.contatore("attacchi") == colpi + 2 and g.stato == Giocatore.Stato.NORMALE,
			"attacchi %d" % (Rapporto.contatore("attacchi") - colpi))


func _oggetti() -> void:
	_nuova_fase("cassa_e_barili")
	var cassa: RigidBody2D = null
	for c: RigidBody2D in get_tree().get_nodes_in_group("casse"):
		if cassa == null or c.position.x < cassa.position.x:
			cassa = c
	await _sposta(Vector2(300, Stanza.PAVIMENTO), 1)
	var cassa_x := cassa.position.x
	await _tieni("destra", 70)
	await _scatta("cassa")
	await _fotogrammi(20)
	_verifica("cassa spinta", cassa.position.x > cassa_x + 12.0, "%.0f -> %.0f" % [cassa_x, cassa.position.x])

	var rotti := Rapporto.contatore("oggetti_rotti")
	await _sposta(Vector2(486, Stanza.PAVIMENTO), -1)
	await _tocca("attacca")
	await _fotogrammi(14)
	await _scatta("barile")
	await _fotogrammi(30)
	_verifica("barile rotto", Rapporto.contatore("oggetti_rotti") > rotti, "rotti %d" % Rapporto.contatore("oggetti_rotti"))


func _nemici() -> void:
	_nuova_fase("scheletro")
	await _sposta(Vector2(556, Stanza.PAVIMENTO), 1)
	await _fotogrammi(30)
	var sveglio := false
	for n: Nemico in get_tree().get_nodes_in_group("nemici"):
		if n.stato == Nemico.Stato.RISVEGLIO or (n.tipo == "scheletro" and n.position.x < 700.0 and n.stato == Nemico.Stato.INSEGUE):
			sveglio = true
	_verifica("lo scheletro si risveglia", sveglio)
	await _scatta("risveglio")
	await _fotogrammi(100)
	await _scatta("scheletro")
	await _combatti("scheletro", 1500)
	_verifica("scheletro sconfitto", Rapporto.contatore("nemici_uccisi") >= 1, "uccisi %d, vita %d" % [Rapporto.contatore("nemici_uccisi"), _g().vita])
	await _scatta("dopo_scheletro")

	_nuova_fase("mago")
	await _sposta(Vector2(596, 289), 1)
	for i in 300:
		if Rapporto.contatore("magie_lanciate") > 0:
			break
		await _fotogrammi(1)
	await _fotogrammi(25)
	await _scatta("mago")
	_verifica("il mago lancia", Rapporto.contatore("magie_lanciate") > 0)
	await _combatti("mago", 900)
	_verifica("mago sconfitto", Rapporto.contatore("nemici_uccisi") >= 2, "uccisi %d" % Rapporto.contatore("nemici_uccisi"))


func _percorso() -> void:
	_nuova_fase("cunicolo")
	await _sposta(Vector2(1078, Stanza.PAVIMENTO), 1)
	await _tieni("destra", 30)
	_verifica("in piedi nel cunicolo non si passa", _g().position.x < 1104.0, "x %.0f" % _g().position.x)
	await _sposta(Vector2(1078, Stanza.PAVIMENTO), 1)
	await _tocca("rotola")
	await _fotogrammi(14)
	await _scatta("cunicolo")
	await _fotogrammi(80)
	var g := _g()
	_verifica("rotolata attraverso il cunicolo", g.position.x > 1200.0 and g.stato == Giocatore.Stato.NORMALE,
			"x %.0f stato %s" % [g.position.x, Giocatore.Stato.keys()[g.stato]])
	await _scatta("alcova")
	await _tieni("sinistra", 3)
	await _tocca("rotola")
	await _fotogrammi(95)
	_verifica("ritorno dal cunicolo", _g().position.x < 1104.0, "x %.0f" % _g().position.x)

	_nuova_fase("piattaforme")
	await _sposta(Vector2(360, 410), 1)
	await _fotogrammi(12)
	g = _g()
	_verifica("in piedi sulla piattaforma", g.is_on_floor() and absf(g.position.y - 412.0) < 2.0, "y %.0f" % g.position.y)
	await _scatta("piattaforma")
	Input.action_press("giu")
	await _tocca("salta")
	await _fotogrammi(30)
	Input.action_release("giu")
	_verifica("discesa dalla piattaforma", _g().position.y > 430.0, "y %.0f" % _g().position.y)

	_nuova_fase("schivate")
	await _sposta(Vector2(900, Stanza.PAVIMENTO), 1)
	var schivate := Rapporto.contatore("schivate")
	var x0 := _g().position.x
	await _tocca("schiva")
	await _fotogrammi(20)
	_verifica("schivata all'indietro", Rapporto.contatore("schivate") == schivate + 1 and _g().position.x < x0 - 15.0,
			"%.0f -> %.0f" % [x0, _g().position.x])
	await _fotogrammi(25)
	Input.action_press("salta")
	await _fotogrammi(14)
	x0 = _g().position.x
	await _tocca("schiva")
	await _fotogrammi(10)
	Input.action_release("salta")
	_verifica("scatto in aria", Rapporto.contatore("schivate") == schivate + 2 and _g().position.x > x0 + 20.0,
			"%.0f -> %.0f" % [x0, _g().position.x])
	await _fotogrammi(40)


func _qualita() -> void:
	_nuova_fase("qualita")
	Impostazioni.scrivi("grafica/qualita", "bassa")
	await _fotogrammi(30)
	await _scatta("qualita_bassa")
	_verifica("qualità bassa: niente ombre", Dispositivo.livello == "bassa" and _principale.stanza.torce_con_ombra() == 0)
	Impostazioni.scrivi("grafica/qualita", "alta")
	Impostazioni.scrivi("grafica/palette", false)
	await _fotogrammi(30)
	await _scatta("senza_palette")
	Impostazioni.scrivi("grafica/palette", true)
	await _fotogrammi(10)
	_verifica("qualità alta: ombre accese", _principale.stanza.torce_con_ombra() > 0)


func _tasti_a_schermo() -> void:
	_nuova_fase("tasti_a_schermo")
	await _sposta(Vector2(250, Stanza.PAVIMENTO), 1)
	var area := get_viewport().get_visible_rect().size
	var leva := Vector2(area.x * 0.2, area.y * 0.75)
	_tocco_schermo(0, leva, true)
	await _fotogrammi(3)
	_verifica("i tasti a schermo compaiono al tocco", Controlli.touch and _principale.hud.tasti_a_schermo_visibili())
	var x0 := _g().position.x
	_trascina(0, leva, leva + Vector2(90.0, 0.0))
	await _fotogrammi(30)
	await _scatta("tasti_a_schermo")
	_verifica("la leva a schermo muove il giocatore", _g().position.x > x0 + 20.0, "%.0f -> %.0f" % [x0, _g().position.x])
	var colpi := Rapporto.contatore("attacchi")
	var tasto: Vector2 = _principale.hud.centro_tasto("attacca")
	_tocco_schermo(1, tasto, true)
	await _fotogrammi(4)
	_tocco_schermo(1, tasto, false)
	_tocco_schermo(0, leva + Vector2(90.0, 0.0), false)
	await _fotogrammi(40)
	_verifica("il tasto Colpo a schermo attacca", Rapporto.contatore("attacchi") == colpi + 1)
	var tasto_fisico := InputEventKey.new()
	tasto_fisico.keycode = KEY_J
	tasto_fisico.physical_keycode = KEY_J
	tasto_fisico.pressed = true
	Input.parse_input_event(tasto_fisico)
	await _fotogrammi(2)
	tasto_fisico.pressed = false
	Input.parse_input_event(tasto_fisico)
	await _fotogrammi(3)
	_verifica("con un tasto fisico i tasti a schermo spariscono", not Controlli.touch and not _principale.hud.tasti_a_schermo_visibili())
	# Grandezza dei tasti: adatta allo schermo finché non si sceglie a mano.
	var automatica := Dispositivo.scala_touch()
	Impostazioni.scrivi("controlli/dimensione_touch", 1.45)
	_verifica("grandezza tasti: automatica e poi scelta a mano",
			automatica >= 1.0 and automatica <= 1.6 and is_equal_approx(Dispositivo.scala_touch(), 1.45),
			"auto %.2f, scelta %.2f" % [automatica, Dispositivo.scala_touch()])
	Impostazioni.scrivi("controlli/dimensione_touch", -1.0)


func _menu_e_aspetto() -> void:
	# Pausa, aspetto scelto dal menu, anteprima animata con tutte le azioni da provare.
	_nuova_fase("menu")
	_principale._alterna_pausa()
	await _fotogrammi_in_pausa(5)
	await _scatta("menu")
	_verifica("pausa: menu aperto e gioco fermo", _principale.menu.aperto and get_tree().paused)
	var figura := _g().sprite as FiguraViva
	_verifica("aspetto: il protagonista è una figura viva", figura != null)
	if figura == null:
		return
	_verifica("aspetto: pezzi predefiniti addosso", _pezzi_figura() == _pezzi_attesi(), str(_pezzi_figura()))
	var con_immagini := DisplayServer.get_name() != "headless"
	var prima := Image.new()
	if con_immagini:
		prima = figura.immagine()
		_verifica("aspetto: la figura è disegnata", _pixel_pieni(prima) > 120, "pixel %d" % _pixel_pieni(prima))
	var menu: Menu = _principale.menu
	var scelta: OptionButton = menu.get("_scelte_oggetto")["copricapo"]
	var foto := figura.disegni
	for i in scelta.item_count:
		if scelta.get_item_metadata(i) == "elmo_cavaliere":
			scelta.select(i)
			scelta.item_selected.emit(i)
	await _fotogrammi_in_pausa(3)
	if con_immagini:
		await RenderingServer.frame_post_draw
	_verifica("aspetto: elmo scelto dal menu", Equipaggiamento.indossati["copricapo"] == "elmo_cavaliere"
			and _pezzi_figura().has("Cavaliere__Knight_Helmet"), str(_pezzi_figura()))
	_verifica("aspetto: nuova foto anche in pausa", figura.disegni > foto, "foto %d -> %d" % [foto, figura.disegni])
	if con_immagini:
		_verifica("aspetto: l'immagine cambia con l'elmo", figura.immagine().get_data() != prima.get_data())
	await _scatta("menu_aspetto")

	var colore: OptionButton = menu.get("_scelte_colore")["mantello"]
	for i in colore.item_count:
		if colore.get_item_metadata(i) == "sangue":
			colore.select(i)
			colore.item_selected.emit(i)
	await _fotogrammi_in_pausa(2)
	var mantello: String = Equipaggiamento.pezzi(Equipaggiamento.indossati["mantello"])[0]
	var mi: MeshInstance3D = figura.get("_pezzi")[mantello][0]
	var tinta: Color = (mi.material_override as ShaderMaterial).get_shader_parameter("tinta")
	_verifica("aspetto: mantello color sangue", Equipaggiamento.colori["mantello"] == "sangue"
			and tinta.is_equal_approx(Equipaggiamento.COLORI["sangue"][1]), str(tinta))

	# Ogni azione da provare, sull'anteprima del menu (gioco in pausa).
	_nuova_fase("menu_mosse")
	var vetrina: FiguraViva = menu.vetrina
	_verifica("mosse: anteprima animata pronta", vetrina != null and menu.tasti_prova.size() >= 30, "tasti %d" % menu.tasti_prova.size())
	var non_partite: Array = []
	var scorri := menu.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	for azione: String in menu.tasti_prova:
		scorri.ensure_control_visible(menu.tasti_prova[azione])  # come farebbe chi gioca
		(menu.tasti_prova[azione] as Button).pressed.emit()
		await _fotogrammi_in_pausa(3)
		if vetrina.animazione != azione:
			non_partite.append(azione)
		await _attendi_in_pausa(minf(vetrina.durata(azione), 2.5) + 0.1)
		if azione in ["colpo_rotante", "saluto", "attacco1"]:
			await _scatta("prova_" + azione)
	_verifica("mosse: ogni azione del menu si vede nell'anteprima", non_partite.is_empty(), str(non_partite))

	var caso := RandomNumberGenerator.new()
	caso.seed = 5
	var validi := true
	for giro in 12:
		Equipaggiamento.casuale(caso)
		await _fotogrammi_in_pausa(1)
		for posto in Equipaggiamento.POSTI:
			var id: String = Equipaggiamento.indossati[posto]
			if not Equipaggiamento.OGGETTI.has(id) or Equipaggiamento.OGGETTI[id][0] != posto:
				validi = false
		if _pezzi_figura() != _pezzi_attesi():
			validi = false
	_verifica("aspetto: 12 combinazioni a caso tutte addosso", validi, str(Equipaggiamento.descrizione()))
	var cfg := ConfigFile.new()
	var salvato := cfg.load(Equipaggiamento.PERCORSO) == OK
	for posto in Equipaggiamento.POSTI:
		salvato = salvato and cfg.get_value("oggetti", posto, "") == Equipaggiamento.indossati[posto] \
				and cfg.get_value("colori", posto, "") == Equipaggiamento.colori[posto]
	_verifica("aspetto: salvato su file", salvato)
	var tutti_presenti := true
	for p: String in Equipaggiamento.tutti_i_pezzi():
		if not figura.get("_pezzi").has(p):
			tutti_presenti = false
			print("PROVA pezzo mancante nel manichino: ", p)
	_verifica("aspetto: ogni oggetto ha i suoi pezzi nel manichino", tutti_presenti)
	var gruppi_mancanti: Array = []
	for id: String in Equipaggiamento.MOSSE:
		if not figura.gruppi_di_mosse().has(id):
			gruppi_mancanti.append(id)
	_verifica("mosse: ogni gruppo ha le sue animazioni", gruppi_mancanti.is_empty(), str(gruppi_mancanti))
	Equipaggiamento.ripristina()
	await _fotogrammi_in_pausa(2)
	_verifica("aspetto: ripristino", Equipaggiamento.indossati == Equipaggiamento.PREDEFINITO and _pezzi_figura() == _pezzi_attesi())
	_principale._alterna_pausa()
	await _fotogrammi(5)
	_verifica("ripresa dal menu", not _principale.menu.aperto and not get_tree().paused)


func _mosse_in_partita() -> void:
	# Ogni gruppo di mosse in partita: si corre, si attacca due volte, si rotola.
	_nuova_fase("mosse")
	var attese := {"spadone": "due_mani", "bastone": "magia", "pugnale": "affondi", "mani_nude": "mani_nude"}
	var sbagliate: Array = []
	for arma: String in attese:
		Equipaggiamento.ripristina()
		Equipaggiamento.indossa("arma", arma)
		if Equipaggiamento.mosse_automatiche() != attese[arma]:
			sbagliate.append("%s->%s" % [arma, Equipaggiamento.mosse_automatiche()])
	var attese_mano := {"scudo_torre": "scudo", "seconda_spada": "doppia"}
	for mano: String in attese_mano:
		Equipaggiamento.ripristina()
		Equipaggiamento.indossa("mano_sinistra", mano)
		if Equipaggiamento.mosse_automatiche() != attese_mano[mano]:
			sbagliate.append("%s->%s" % [mano, Equipaggiamento.mosse_automatiche()])
	_verifica("mosse: scelta automatica dall'arma e dalla mano sinistra", sbagliate.is_empty(), str(sbagliate))

	var equip := {
		"una_mano": {}, "affondi": {"arma": "pugnale"}, "due_mani": {"arma": "spadone"},
		"doppia": {"arma": "spada_cavaliere", "mano_sinistra": "seconda_spada"},
		"scudo": {"arma": "spada_cavaliere", "mano_sinistra": "scudo_stemma", "copricapo": "elmo_cavaliere"},
		"magia": {"arma": "bastone", "copricapo": "cappello_eremita"}, "mani_nude": {"arma": "mani_nude"},
	}
	var non_applicate: Array = []
	var attacchi_mancati: Array = []
	for id: String in Equipaggiamento.MOSSE:
		Equipaggiamento.ripristina()
		var pezzi: Dictionary = equip.get(id, {})
		for posto: String in pezzi:
			Equipaggiamento.indossa(posto, pezzi[posto])
		await _sposta(Vector2(420, Stanza.PAVIMENTO), 1)
		var figura := _g().sprite as FiguraViva
		if figura.mosse != id:
			non_applicate.append("%s (%s)" % [id, figura.mosse])
		await _tieni("destra", 25)
		await _fotogrammi(6)
		var colpi := Rapporto.contatore("attacchi")
		await _tocca("attacca")
		await _fotogrammi(8)
		await _tocca("attacca")
		await _fotogrammi(10)
		if id in ["due_mani", "magia", "scudo"]:
			await _scatta("mosse_" + id)
		await _fotogrammi(30)
		if Rapporto.contatore("attacchi") != colpi + 2:
			attacchi_mancati.append(id)
		await _tocca("rotola")
		await _fotogrammi(40)
	_verifica("mosse: ogni gruppo si applica in partita", non_applicate.is_empty(), str(non_applicate))
	_verifica("mosse: due colpi con ogni gruppo", attacchi_mancati.is_empty(), str(attacchi_mancati))
	# Scelta a mano: vale anche con un'arma diversa.
	Equipaggiamento.ripristina()
	Equipaggiamento.scegli_mosse("due_mani")
	await _fotogrammi(3)
	_verifica("mosse: scelta a mano", (_g().sprite as FiguraViva).mosse == "due_mani")
	Equipaggiamento.ripristina()
	await _fotogrammi(3)


func _morte() -> void:
	_nuova_fase("morte")
	var sogno: int = _principale.sogno
	var g := _g()
	for i in 8:
		g = _g()
		if g.stato == Giocatore.Stato.MORTO:
			break
		g.subisci(1, g.position + Vector2(10, 0), 120.0)
		await _fotogrammi(62)
	await _scatta("morte")
	for i in 400:
		if _principale.sogno > sogno and not _principale._in_transizione:
			break
		await _fotogrammi(1)
	await _fotogrammi(20)
	g = _g()
	_verifica("dopo la morte si rinasce in un nuovo sogno", _principale.sogno == sogno + 1 and g.vita == Giocatore.VITA_MASSIMA
			and g.stato == Giocatore.Stato.NORMALE, "sogno %d, vita %d" % [_principale.sogno, g.vita])
	await _scatta("nuovo_sogno")


func _comandi_a_caso() -> void:
	_nuova_fase("comandi_a_caso")
	var caso := RandomNumberGenerator.new()
	caso.seed = 7
	var fuori := 0
	for i in 1500:
		if i % 5 == 0:
			var azione := AZIONI[caso.randi() % AZIONI.size()]
			if caso.randf() < 0.55:
				Input.action_press(azione)
			else:
				Input.action_release(azione)
		if i % 300 == 150:
			Equipaggiamento.casuale(caso)  # ogni tanto un aspetto nuovo mentre si gioca
		await _fotogrammi(1)
		var p := _g().position
		if not (is_finite(p.x) and is_finite(p.y)) or p.x < 40.0 or p.x > Stanza.LARGHEZZA - 40.0 or p.y > Stanza.PAVIMENTO + 2.0 or p.y < -200.0:
			fuori += 1
	_rilascia_tutto()
	Equipaggiamento.ripristina()
	await _fotogrammi(30)
	_verifica("comandi a caso: il giocatore resta nella stanza", fuori == 0, "fotogrammi fuori: %d" % fuori)
	await _scatta("fine")


func _prestazioni() -> void:
	# La stessa corsa con colpi per ogni qualità: dice quanto regge il telefono.
	for q in ["bassa", "media", "alta"]:
		Impostazioni.scrivi("grafica/qualita", q)
		await _sposta(Vector2(300, Stanza.PAVIMENTO), 1)
		await _fotogrammi(20)
		_nuova_fase("prestazioni_" + q)
		for giro in 3:
			for verso in ["destra", "sinistra"]:
				Input.action_press(verso)
				for i in 5:
					await _tocca("attacca")
					await _fotogrammi(9)
				Input.action_release(verso)
				await _tocca("rotola")
				await _fotogrammi(20)
		_rilascia_tutto()
	_chiudi_fase()
	Impostazioni.scrivi("grafica/qualita", "auto")
	await _fotogrammi(10)


# ------------------------------------------------------------------ fine

func _concludi(motivo: String) -> void:
	_rilascia_tutto()
	if get_tree().paused and _principale.menu.aperto:
		_principale.menu.chiudi()
	# Impostazioni e aspetto tornano come li aveva chi gioca.
	if not _stato_utente.is_empty():
		_rimetti(_stato_utente)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SEGNO))
	Dispositivo.bot_attivo = false
	Rapporto.sezione("bot", _esito(motivo))
	Rapporto.evento("bot_fine", {"falliti": falliti, "controlli": controlli.size()})
	var testo := Rapporto.salva(motivo)
	var dati: Variant = JSON.parse_string(testo)
	_verifica("rapporto salvato e leggibile", typeof(dati) == TYPE_DICTIONARY and dati.has("bot") and dati.has("aspetto")
			and FileAccess.file_exists(Rapporto.ultimo_percorso), "%d caratteri" % testo.length())
	if typeof(dati) == TYPE_DICTIONARY:
		_verifica("nessun errore del motore", int(dati["errori_motore"]) == 0, "errori: %d" % int(dati["errori_motore"]))
		for riga: String in dati["registro_motore"]:
			print("PROVA registro: ", riga)
	# Il rapporto definitivo contiene anche questi ultimi due controlli.
	Rapporto.sezione("bot", _esito(motivo))
	Rapporto.salva(motivo)
	in_corso = false
	if _etichetta != null:
		_etichetta.text = "Bot finito: %d controlli, %d non riusciti. Rapporto salvato." % [controlli.size(), falliti]
	finito.emit(falliti)
	if chiudi_alla_fine and motivo == "bot":
		await get_tree().create_timer(3.0).timeout
		get_tree().quit()
	elif _etichetta != null:
		await get_tree().create_timer(4.0).timeout
		_etichetta.get_parent().queue_free()


func _esito(motivo: String) -> Dictionary:
	return {
		"motivo": motivo,
		"durata_s": snappedf((Time.get_ticks_msec() - _inizio_ms) / 1000.0, 0.1),
		"controlli_totali": controlli.size(),
		"falliti": falliti,
		"elenco_falliti": controlli.filter(func(c: Dictionary) -> bool: return not c["ok"]),
		"fasi": fasi,
		"controlli": controlli,
		"gruppi_di_mosse": Equipaggiamento.MOSSE.keys(),
		"azioni_provate": (_principale.menu.tasti_prova as Dictionary).keys(),
	}
