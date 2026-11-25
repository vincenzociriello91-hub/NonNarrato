extends Node
# Prova automatica: un bot gioca la stanza e controlla che tutto funzioni.
#
#   godot --headless --fixed-fps 60 --path . -- --prova                (solo logica, veloce)
#   godot --fixed-fps 60 --path . -- --prova --schermate=/cartella     (con le schermate)
#
# Stampa "PROVA ok/FALLITA ..." per ogni controllo e chiude con "PROVA FINE falliti: N".

const AZIONI: Array[String] = ["sinistra", "destra", "su", "giu", "salta", "attacca", "rotola", "schiva"]

var _falliti := 0
var _cartella := ""
var _scatti := 0
var _principale: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--schermate="):
			_cartella = arg.trim_prefix("--schermate=")
	_principale = get_parent()
	_esegui.call_deferred()


# ------------------------------------------------------------------ aiuti

func _g() -> Giocatore:
	return _principale.stanza.giocatore


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


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
	if not riuscita:
		_falliti += 1


func _scatta(nome: String) -> void:
	if _cartella == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_scatti += 1
	var immagine := get_viewport().get_texture().get_image()
	immagine.save_png(_cartella.path_join("%02d_%s.png" % [_scatti, nome]))


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
		await get_tree().physics_frame
	_rilascia_tutto()
	await _fotogrammi(20)


# ------------------------------------------------------------------ prova

func _solo_foto() -> void:
	# Giro breve per guardare la grafica: qualche schermata in punti diversi della stanza.
	Impostazioni.ripristina()
	Impostazioni.scrivi("grafica/qualita", "alta")
	Impostazioni.scrivi("gioco/debug", false)
	await _fotogrammi(70)
	await _scatta("inizio")
	Impostazioni.scrivi("grafica/palette", false)
	await _fotogrammi(6)
	await _scatta("inizio_senza_palette")
	Impostazioni.scrivi("grafica/palette", true)
	for dove: Vector2 in [Vector2(560, Stanza.PAVIMENTO), Vector2(640, 289), Vector2(900, Stanza.PAVIMENTO), Vector2(1180, 383)]:
		await _sposta(dove, 1)
		await _fotogrammi(50)
		await _scatta("x%d" % int(dove.x))
	Impostazioni.ripristina()
	print("PROVA FINE falliti: 0")
	get_tree().quit(0)


func _esegui() -> void:
	if OS.get_cmdline_user_args().has("--solo-foto"):
		await _solo_foto()
		return
	Impostazioni.ripristina()
	Impostazioni.scrivi("grafica/qualita", "alta")
	await _fotogrammi(60)
	var g := _g()
	_verifica("avvio: giocatore a terra", g.is_on_floor() and absf(g.position.y - Stanza.PAVIMENTO) < 2.0, str(g.position))
	_verifica("avvio: qualità alta con ombre", Dispositivo.livello == "alta" and _principale.stanza.torce_con_ombra() > 0,
			"%s, torce con ombra %d" % [Dispositivo.livello, _principale.stanza.torce_con_ombra()])
	await _scatta("inizio")

	# Corsa e salto.
	var x0 := g.position.x
	await _tieni("sinistra", 20)
	_verifica("corsa a sinistra", g.position.x < x0 - 20.0, "%.0f -> %.0f" % [x0, g.position.x])
	await _fotogrammi(20)
	Input.action_press("salta")
	var quota := g.position.y
	for i in 45:
		await get_tree().physics_frame
		quota = minf(quota, g.position.y)
	Input.action_release("salta")
	await _fotogrammi(30)
	_verifica("salto", quota < Stanza.PAVIMENTO - 60.0 and g.is_on_floor(), "apice %.0f px" % (Stanza.PAVIMENTO - quota))

	# Due colpi in fila.
	var colpi := Rapporto.contatore("attacchi")
	await _tocca("attacca")
	await _fotogrammi(8)
	await _tocca("attacca")
	await _fotogrammi(12)
	await _scatta("attacco")
	await _fotogrammi(40)
	_verifica("due colpi in fila", Rapporto.contatore("attacchi") == colpi + 2 and g.stato == Giocatore.Stato.NORMALE,
			"attacchi %d" % (Rapporto.contatore("attacchi") - colpi))

	# Spinta di una cassa.
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

	# Barili da rompere.
	var rotti := Rapporto.contatore("oggetti_rotti")
	await _sposta(Vector2(486, Stanza.PAVIMENTO), -1)
	await _tocca("attacca")
	await _fotogrammi(14)
	await _scatta("barile")
	await _fotogrammi(30)
	_verifica("barile rotto", Rapporto.contatore("oggetti_rotti") > rotti, "rotti %d" % Rapporto.contatore("oggetti_rotti"))

	# Lo scheletro addormentato si risveglia e si combatte.
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

	# Il mago lancia le sue sfere.
	await _sposta(Vector2(596, 289), 1)
	for i in 300:
		if Rapporto.contatore("magie_lanciate") > 0:
			break
		await get_tree().physics_frame
	await _fotogrammi(25)
	await _scatta("mago")
	_verifica("il mago lancia", Rapporto.contatore("magie_lanciate") > 0)
	await _combatti("mago", 900)
	_verifica("mago sconfitto", Rapporto.contatore("nemici_uccisi") >= 2, "uccisi %d" % Rapporto.contatore("nemici_uccisi"))

	# Il cunicolo: si passa solo rotolando.
	await _sposta(Vector2(1078, Stanza.PAVIMENTO), 1)
	await _tieni("destra", 30)
	_verifica("in piedi nel cunicolo non si passa", _g().position.x < 1104.0, "x %.0f" % _g().position.x)
	await _sposta(Vector2(1078, Stanza.PAVIMENTO), 1)
	await _tocca("rotola")
	await _fotogrammi(14)
	await _scatta("cunicolo")
	await _fotogrammi(80)
	g = _g()
	_verifica("rotolata attraverso il cunicolo", g.position.x > 1200.0 and g.stato == Giocatore.Stato.NORMALE,
			"x %.0f stato %s" % [g.position.x, Giocatore.Stato.keys()[g.stato]])
	await _scatta("alcova")
	await _tieni("sinistra", 3)
	await _tocca("rotola")
	await _fotogrammi(95)
	_verifica("ritorno dal cunicolo", _g().position.x < 1104.0, "x %.0f" % _g().position.x)

	# Piattaforme: ci si sta sopra e si scende con giù + salto.
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

	# Schivata a terra (all'indietro) e scatto in aria.
	await _sposta(Vector2(900, Stanza.PAVIMENTO), 1)
	var schivate := Rapporto.contatore("schivate")
	x0 = _g().position.x
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

	# Qualità: bassa senza ombre, alta con le ombre.
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

	# Tasti a schermo: compaiono al tocco e funzionano.
	await _sposta(Vector2(250, Stanza.PAVIMENTO), 1)
	var area := get_viewport().get_visible_rect().size
	_tocco_schermo(0, Vector2(area.x * 0.2, area.y * 0.75), true)
	await _fotogrammi(3)
	_verifica("i tasti a schermo compaiono al tocco", Controlli.touch and _principale.hud.tasti_a_schermo_visibili())
	x0 = _g().position.x
	_trascina(0, Vector2(area.x * 0.2, area.y * 0.75), Vector2(area.x * 0.2 + 90.0, area.y * 0.75))
	await _fotogrammi(30)
	await _scatta("tasti_a_schermo")
	_verifica("la leva a schermo muove il giocatore", _g().position.x > x0 + 20.0, "%.0f -> %.0f" % [x0, _g().position.x])
	colpi = Rapporto.contatore("attacchi")
	var k: float = Impostazioni.leggi("controlli/dimensione_touch")
	var tasto := Vector2(area.x - 96.0 * k, area.y - 96.0 * k)
	_tocco_schermo(1, tasto, true)
	await _fotogrammi(4)
	_tocco_schermo(1, tasto, false)
	_tocco_schermo(0, Vector2(area.x * 0.2 + 90.0, area.y * 0.75), false)
	await _fotogrammi(40)
	_verifica("il tasto Colpo a schermo attacca", Rapporto.contatore("attacchi") == colpi + 1)
	var tasto_fisico := InputEventKey.new()
	tasto_fisico.physical_keycode = KEY_F
	tasto_fisico.pressed = true
	Input.parse_input_event(tasto_fisico)
	await _fotogrammi(3)
	_verifica("con un tasto fisico i tasti a schermo spariscono", not Controlli.touch and not _principale.hud.tasti_a_schermo_visibili())

	# Pausa e menu.
	_principale._alterna_pausa()
	await _fotogrammi(5)
	await _scatta("menu")
	_verifica("pausa: menu aperto e gioco fermo", _principale.menu.aperto and get_tree().paused)
	_principale._alterna_pausa()
	await _fotogrammi(5)
	_verifica("ripresa dal menu", not _principale.menu.aperto and not get_tree().paused)

	# Morte e nuovo sogno.
	var sogno: int = _principale.sogno
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
		await get_tree().physics_frame
	await _fotogrammi(20)
	g = _g()
	_verifica("dopo la morte si rinasce in un nuovo sogno", _principale.sogno == sogno + 1 and g.vita == Giocatore.VITA_MASSIMA
			and g.stato == Giocatore.Stato.NORMALE, "sogno %d, vita %d" % [_principale.sogno, g.vita])
	await _scatta("nuovo_sogno")

	# Comandi a caso per un po': non deve rompersi niente.
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
		await get_tree().physics_frame
		var p := _g().position
		if not (is_finite(p.x) and is_finite(p.y)) or p.x < 40.0 or p.x > Stanza.LARGHEZZA - 40.0 or p.y > Stanza.PAVIMENTO + 2.0 or p.y < -200.0:
			fuori += 1
	_rilascia_tutto()
	await _fotogrammi(30)
	_verifica("comandi a caso: il giocatore resta nella stanza", fuori == 0, "fotogrammi fuori: %d" % fuori)
	await _scatta("fine")

	# Rapporto.
	var testo := Rapporto.salva("prova")
	var dati: Variant = JSON.parse_string(testo)
	var valido: bool = typeof(dati) == TYPE_DICTIONARY and dati.has("dispositivo") and dati.has("fps") and dati.has("partita") \
			and dati.has("eventi") and FileAccess.file_exists(Rapporto.ultimo_percorso)
	_verifica("rapporto salvato e leggibile", valido, "%d caratteri in %s" % [testo.length(), Rapporto.ultimo_percorso])
	if valido:
		print("PROVA partita: ", JSON.stringify(dati["partita"]))
		_verifica("nessun errore del motore", int(dati["errori_motore"]) == 0, "errori: %d" % int(dati["errori_motore"]))
		for riga: String in dati["registro_motore"]:
			print("PROVA registro: ", riga)

	Impostazioni.ripristina()
	print("PROVA FINE falliti: %d" % _falliti)
	get_tree().quit(1 if _falliti > 0 else 0)
