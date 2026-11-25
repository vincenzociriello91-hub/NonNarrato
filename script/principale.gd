extends Node
# Scena d'avvio. Il gioco è disegnato in una "tela" a bassa risoluzione (circa 640x360),
# poi ingrandito di un numero intero di volte: così la pixel art resta nitida su ogni schermo.
# L'interfaccia (vita, tasti a schermo, menu) è invece disegnata alla risoluzione piena.

var mondo: SubViewport
var stanza: Stanza
var hud: Hud
var menu: Menu
var sogno := 1
var bot: Bot

var _vista: TextureRect
var _filtro: ColorRect
var _velo: ColorRect
var _scala := 3
var _in_transizione := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().quit_on_go_back = false
	Bot.ripara_se_interrotto()  # se l'ultima volta il bot non ha finito, rimette le scelte di chi gioca

	var fondo := ColorRect.new()
	fondo.color = Color(0.027, 0.024, 0.043)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)

	mondo = SubViewport.new()
	mondo.process_mode = Node.PROCESS_MODE_PAUSABLE
	mondo.disable_3d = true
	mondo.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	mondo.snap_2d_transforms_to_pixel = true
	mondo.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	mondo.gui_disable_input = true
	add_child(mondo)

	_vista = TextureRect.new()
	_vista.texture = mondo.get_texture()
	_vista.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vista.stretch_mode = TextureRect.STRETCH_SCALE
	_vista.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vista)

	# Filtro "palette fissa": ultimo passaggio sulla tela del gioco.
	var strato := CanvasLayer.new()
	strato.layer = 100
	mondo.add_child(strato)
	var materiale := ShaderMaterial.new()
	materiale.shader = load("res://shader/palette.gdshader")
	materiale.set_shader_parameter("lut", load("res://arte/ambiente/lut_palette.png"))
	_filtro = ColorRect.new()
	_filtro.material = materiale
	_filtro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strato.add_child(_filtro)

	hud = Hud.new()
	hud.pausa_richiesta.connect(_pausa_da_utente)
	add_child(hud)

	var strato_velo := CanvasLayer.new()
	strato_velo.layer = 15
	add_child(strato_velo)
	_velo = ColorRect.new()
	_velo.color = Color(0.027, 0.024, 0.043, 1.0)
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strato_velo.add_child(_velo)

	menu = Menu.new()
	menu.chiuso.connect(_riprendi)
	menu.bot_richiesto.connect(avvia_bot)
	add_child(menu)

	get_window().size_changed.connect(_ridimensiona)
	_ridimensiona()
	Dispositivo.profilo_cambiato.connect(_applica_profilo)
	_applica_profilo()
	_nuova_stanza()
	_riscalda()
	Rapporto.contesto = _contesto
	Rapporto.evento("avvio", {"sogno": sogno, "comandi": Controlli.nome_modo()})

	if Dispositivo.in_prova:
		var prova: Node = (load("res://test/prova.gd") as GDScript).new()
		add_child(prova)
	elif OS.get_cmdline_user_args().has("--bot"):
		get_tree().create_timer(1.5).timeout.connect(avvia_bot)

	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(_velo, "color:a", 0.0, 0.6)
	hud.messaggio("Il Dormiente ti sogna.", 2.4)


func _notification(cosa: int) -> void:
	if cosa == NOTIFICATION_WM_GO_BACK_REQUEST:
		_pausa_da_utente()
	elif cosa == NOTIFICATION_APPLICATION_PAUSED:
		# Il gioco va in secondo piano: al ritorno lo si trova in pausa (e il bot si ferma).
		if bot != null and bot.in_corso:
			bot.ferma()
		elif is_node_ready() and not menu.aperto and not Dispositivo.in_prova:
			_alterna_pausa()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("pausa"):
		_pausa_da_utente()
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("debug"):
		Impostazioni.scrivi("gioco/debug", not Impostazioni.leggi("gioco/debug"))


func _pausa_da_utente() -> void:
	# Mentre gioca il bot, la pausa di chi tiene in mano il telefono lo ferma.
	if bot != null and bot.in_corso:
		bot.ferma()
		return
	_alterna_pausa()


func avvia_bot() -> Bot:
	if bot != null and bot.in_corso:
		return bot
	if bot != null:
		bot.queue_free()
	bot = Bot.new()
	add_child(bot)
	if not Dispositivo.in_prova:
		bot.avvia()
	return bot


func ricomincia_stanza() -> void:
	# Stessa stanza da capo (per il bot), senza contare un nuovo sogno.
	_nuova_stanza()


func _alterna_pausa() -> void:
	if menu.aperto:
		menu.chiudi()
	else:
		get_tree().paused = true
		hud.in_pausa(true)
		menu.apri()
		Rapporto.evento("pausa")


func _riprendi() -> void:
	get_tree().paused = false
	hud.in_pausa(false)


func _ridimensiona() -> void:
	var finestra := get_window().size
	if finestra.x <= 0 or finestra.y <= 0:
		return
	var interna := Dispositivo.risoluzione_interna(finestra)
	_scala = interna["scala"]
	var dimensione: Vector2i = interna["dimensione"]
	mondo.size = dimensione
	# Unità dell'interfaccia -> pixel veri dello schermo.
	var visibile := get_viewport().get_visible_rect().size
	var fattore := float(finestra.x) / maxf(1.0, visibile.x)
	_vista.position = Vector2.ZERO
	_vista.size = Vector2(dimensione * _scala) / fattore
	_filtro.position = Vector2.ZERO
	_filtro.size = Vector2(dimensione)
	Rapporto.grafica("finestra", [finestra.x, finestra.y])
	Rapporto.grafica("risoluzione_interna", [dimensione.x, dimensione.y])
	Rapporto.grafica("scala", _scala)
	hud.misure(dimensione, _scala)


func _applica_profilo() -> void:
	_filtro.visible = Dispositivo.profilo.get("palette", true)


func _nuova_stanza() -> void:
	if stanza != null:
		stanza.queue_free()
	stanza = Stanza.new()
	mondo.add_child(stanza)
	stanza.giocatore.morto.connect(_su_morte)
	hud.collega(stanza, sogno)


func _riscalda() -> void:
	# Mostra subito, dietro il velo nero, gli effetti che compariranno più tardi:
	# il dispositivo li prepara ora e non a metà di un combattimento.
	var dove := Stanza.INIZIO + Vector2(0, -130)
	Effetti.scoppio(stanza, dove, Color(1, 0.9, 0.7), 4, 30.0, 0.2, 100.0, true)
	Effetti.scoppio(stanza, dove, Color(0.5, 0.5, 0.5), 4, 30.0, 0.2, 100.0, false)
	var sfera := Proiettile.new()
	sfera.position = dove
	sfera.set("_vita", 0.25)
	stanza.add_child(sfera)
	# Lampo bianco del colpo ricevuto, scia della spada e frammenti dei barili.
	Effetti.lampo(stanza.giocatore.sprite, 0.3)
	stanza.giocatore.call("_fendente")
	var barile := Rompibile.new()
	barile.silenzioso = true
	barile.position = dove + Vector2(40, 0)
	stanza.add_child(barile)
	barile.subisci(9, dove, 0.0)
	# Tutte le torce accese con le ombre per qualche fotogramma, poi si torna alla regola normale.
	stanza.riscalda_luci(0.4)
	# L'anteprima del menu si prepara ora: aprire la pausa la prima volta non dà più uno scatto.
	menu.prepara_vetrina()
	# Tutti i pezzi del manichino per un attimo: i loro shader sono pronti prima di cambiare aspetto.
	if stanza.giocatore.sprite.has_method("riscalda"):
		stanza.giocatore.sprite.call("riscalda")


func _contesto() -> Dictionary:
	# Cosa succede in partita: finisce nel rapporto accanto a ogni fotogramma lento.
	if not is_instance_valid(stanza) or not is_instance_valid(stanza.giocatore):
		return {}
	var g := stanza.giocatore
	return {
		"stato": Giocatore.Stato.keys()[g.stato],
		"x": roundi(g.position.x),
		"y": roundi(g.position.y),
		"torce_con_ombra": stanza.torce_con_ombra(),
		"nemici": get_tree().get_nodes_in_group("nemici").size(),
		"menu": menu.aperto,
		"foto_figura": int(g.sprite.get("disegni")) if "disegni" in g.sprite else 0,
		"bot": bot.fase_nome if bot != null and bot.in_corso else "",
	}


func _su_morte() -> void:
	if _in_transizione:
		return
	_in_transizione = true
	sogno += 1
	Rapporto.evento("nuovo_sogno", {"sogno": sogno})
	var tw := create_tween()
	tw.tween_property(_velo, "color:a", 1.0, 0.6)
	await tw.finished
	hud.messaggio("Il Dormiente ti sogna di nuovo.", 2.2)
	_nuova_stanza()
	var tw2 := create_tween()
	tw2.tween_interval(0.9)
	tw2.tween_property(_velo, "color:a", 0.0, 0.7)
	await tw2.finished
	_in_transizione = false
