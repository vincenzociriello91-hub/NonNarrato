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
var titolo: Titolo

var _vista: TextureRect
var _filtro: ColorRect
var _velo: ColorRect
var _scritta_velo: Label
var _scala := 3.0
var _in_transizione := false
var _materiale_vista: ShaderMaterial
var bagliore: SubViewport               # tela piccola delle parti luminose (vedi shader/bagliore.gdshader)
var _bagliore_quadro: TextureRect
var _ultima_ondata := -1
var _al_titolo := false


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

	# Bagliore: un quarto della tela, legge l'immagine del mondo (del fotogramma prima: niente ritorno su sé stesso,
	# perché il bagliore si somma solo nella vista, dopo).
	bagliore = SubViewport.new()
	bagliore.disable_3d = true
	bagliore.render_target_update_mode = SubViewport.UPDATE_DISABLED
	bagliore.gui_disable_input = true
	add_child(bagliore)
	_bagliore_quadro = TextureRect.new()
	_bagliore_quadro.texture = mondo.get_texture()
	_bagliore_quadro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bagliore_quadro.stretch_mode = TextureRect.STRETCH_SCALE
	_bagliore_quadro.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var materiale_bagliore := ShaderMaterial.new()
	materiale_bagliore.shader = load("res://shader/bagliore.gdshader")
	materiale_bagliore.set_shader_parameter("immagine", mondo.get_texture())
	_bagliore_quadro.material = materiale_bagliore
	bagliore.add_child(_bagliore_quadro)

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
	# La frase del risveglio sta sopra il velo nero: nell'HUD (sotto il velo) non si vedeva mai.
	_scritta_velo = Label.new()
	_scritta_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scritta_velo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scritta_velo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scritta_velo.add_theme_font_size_override("font_size", 34)
	_scritta_velo.add_theme_color_override("font_color", Color(0.82, 0.78, 0.92))
	_scritta_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scritta_velo.modulate.a = 0.0
	strato_velo.add_child(_scritta_velo)

	menu = Menu.new()
	menu.chiuso.connect(_riprendi)
	menu.bot_richiesto.connect(avvia_bot)
	menu.titolo_richiesto.connect(torna_al_titolo)
	add_child(menu)

	titolo = Titolo.new()
	titolo.continua.connect(continua_partita)
	titolo.nuovo_sogno.connect(nuovo_sogno)
	titolo.impostazioni.connect(func() -> void: menu.apri(true))
	titolo.bot.connect(avvia_bot)
	titolo.esci.connect(func() -> void: get_tree().quit())
	add_child(titolo)
	if Partita.esiste():
		sogno = int(Partita.dati.get("sogno", 1))

	_materiale_vista = ShaderMaterial.new()
	_materiale_vista.shader = load("res://shader/vista.gdshader")
	get_window().size_changed.connect(_ridimensiona)
	Impostazioni.cambiata.connect(_su_impostazione)
	_applica_testo()
	_ridimensiona()
	Dispositivo.profilo_cambiato.connect(_applica_profilo)
	_applica_profilo()
	_applica_vista()
	Effetti.applica_velocita()
	_nuova_stanza()
	_riscalda()
	Rapporto.contesto = _contesto
	Rapporto.evento("avvio", {"sogno": sogno, "comandi": Controlli.nome_modo()})

	if Dispositivo.in_prova:
		var prova: Node = (load("res://test/prova.gd") as GDScript).new()
		add_child(prova)
	elif OS.get_cmdline_user_args().has("--bot"):
		get_tree().create_timer(1.5).timeout.connect(avvia_bot)
	else:
		# Chi gioca parte dalla schermata iniziale (Continua / Nuovo sogno). Prima mezzo secondo a gioco acceso
		# dietro il velo nero: gli effetti di _riscalda devono disegnarsi, altrimenti il telefono li prepara a metà partita.
		get_tree().create_timer(0.6).timeout.connect(mostra_titolo)
		return

	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(_velo, "color:a", 0.0, 0.6)
	hud.messaggio("Il Dormiente ti sogna.", 2.4)


func _process(_delta: float) -> void:
	# A ogni nuova ondata la partita si salva (Continua riparte da lì).
	if Partita.attiva and is_instance_valid(stanza) and stanza.ondata != _ultima_ondata:
		_ultima_ondata = stanza.ondata
		Partita.salva(self)


# ------------------------------------------------------------------ schermata iniziale

func mostra_titolo() -> void:
	# Il gioco resta in pausa dietro, in penombra; la musica continua a pieno volume.
	Partita.attiva = false
	get_tree().paused = true
	Suoni.imposta_tensione(0)
	hud.visible = false
	hud.in_pausa(true)
	titolo.mostra()
	var tw := create_tween()
	tw.tween_property(_velo, "color:a", 0.45, 0.8)
	Rapporto.evento("titolo", {"partita": Partita.descrizione()})


func continua_partita() -> void:
	await _entra(true)


func nuovo_sogno() -> void:
	await _entra(false)


func _entra(riprendi: bool) -> void:
	if _in_transizione:
		return
	_in_transizione = true
	titolo.nascondi()
	var tw := create_tween()
	tw.tween_property(_velo, "color:a", 1.0, 0.3)
	await tw.finished
	var frase := "Il Dormiente ti sogna."
	if riprendi and Partita.esiste() and not bool(Partita.dati.get("completato", false)):
		sogno = int(Partita.dati.get("sogno", 1))
		_nuova_stanza(clampi(int(Partita.dati.get("ondata", 1)), 1, Stanza.ONDATE))
		Partita.applica(stanza)
		frase = "Il Dormiente ti sogna ancora."
	else:
		# Nuovo sogno (o quello salvato era già finito): come rinascere, i nemici ricordano.
		if Partita.esiste() or Memoria.sogni > 0:
			sogno = int(Partita.dati.get("sogno", Memoria.sogni)) + 1
			Memoria.nuovo_sogno()
		else:
			sogno = 1
		_nuova_stanza()
	Rapporto.evento("partita", {"riprende": riprendi, "sogno": sogno, "ondata": stanza.ondata})
	get_tree().paused = false
	hud.visible = true
	hud.in_pausa(false)
	Partita.attiva = true
	_ultima_ondata = stanza.ondata
	Partita.salva(self)
	var tw2 := create_tween()
	tw2.tween_property(_velo, "color:a", 0.0, 0.6)
	hud.messaggio(frase, 2.4)
	await tw2.finished
	_in_transizione = false


func torna_al_titolo() -> void:
	# Dal menu di pausa: si salva il sogno e si torna alla schermata iniziale (il gioco resta in pausa).
	if Partita.attiva:
		Partita.salva(self)
	_al_titolo = true
	menu.chiudi()
	_al_titolo = false
	mostra_titolo()


func dopo_il_bot() -> void:
	# Il bot ha finito (o è stato fermato): stanza pulita e di nuovo il titolo, da cui si riprende il proprio sogno.
	if _in_transizione:
		return
	_in_transizione = true
	var tw := create_tween()
	tw.tween_property(_velo, "color:a", 1.0, 0.35)
	await tw.finished
	_nuova_stanza()
	_in_transizione = false
	mostra_titolo()


func _notification(cosa: int) -> void:
	if cosa == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_node_ready() and titolo.visible and not menu.aperto:
			if titolo.indietro():
				get_tree().quit()
			return
		_pausa_da_utente()
	elif cosa == NOTIFICATION_APPLICATION_PAUSED:
		# Il gioco va in secondo piano: al ritorno lo si trova in pausa (e il bot si ferma).
		if bot != null and bot.in_corso:
			bot.ferma()
		elif is_node_ready() and not menu.aperto and not titolo.visible and not Dispositivo.in_prova:
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
	if titolo.visible:
		if menu.aperto:
			menu.chiudi()
		return
	_alterna_pausa()


func avvia_bot() -> Bot:
	if bot != null and bot.in_corso:
		return bot
	if bot != null:
		bot.queue_free()
	if Partita.attiva:
		Partita.salva(self)   # il sogno di chi gioca resta salvato: dopo il bot si riprende dal titolo
	Partita.attiva = false
	if titolo.visible:
		titolo.nascondi()
		get_tree().paused = false
		hud.visible = true
		hud.in_pausa(false)
		create_tween().tween_property(_velo, "color:a", 0.0, 0.4)
	bot = Bot.new()
	add_child(bot)
	if not Dispositivo.in_prova:
		bot.avvia()
	return bot


func ricomincia_stanza() -> void:
	# Stessa stanza da capo (per il bot), senza contare un nuovo sogno.
	_nuova_stanza()


func ricomincia_con_velo(testo: String = "") -> void:
	# Come ricomincia_stanza, ma dietro il velo nero con una scritta: senza, chi guardava il bot lo vedeva
	# "teletrasportarsi" all'inizio della stanza a ogni prova (segnalazione di Vincenzo del 26/11/2026).
	if _in_transizione:
		ricomincia_stanza()
		return
	_in_transizione = true
	var tw := create_tween()
	tw.tween_property(_velo, "color:a", 1.0, 0.35)
	await tw.finished
	_scritta_velo.text = testo
	_scritta_velo.modulate.a = 1.0 if testo != "" else 0.0
	ricomincia_stanza()
	await get_tree().create_timer(0.7).timeout
	var tw2 := create_tween()
	tw2.tween_property(_scritta_velo, "modulate:a", 0.0, 0.3)
	tw2.parallel().tween_property(_velo, "color:a", 0.0, 0.4)
	await tw2.finished
	_in_transizione = false


func _alterna_pausa() -> void:
	if menu.aperto:
		menu.chiudi()
	else:
		get_tree().paused = true
		hud.in_pausa(true)
		Suoni.in_pausa(true)
		menu.apri()
		Rapporto.evento("pausa")


func _riprendi() -> void:
	if titolo.visible or _al_titolo:
		titolo.riprendi_focus()   # menu aperto dalla schermata iniziale: si torna lì, il gioco resta in pausa
		return
	get_tree().paused = false
	hud.in_pausa(false)
	Suoni.in_pausa(false)


func _su_impostazione(chiave: String) -> void:
	if chiave in ["schermo/scala", "schermo/adatta", "schermo/proporzioni", "grafica/risoluzione"]:
		_ridimensiona()
	elif chiave == "acc/testo":
		_applica_testo()
		_ridimensiona()
	if chiave.begins_with("schermo/") or chiave in ["grafica/filtro", "grafica/nitidezza", "acc/daltonismo"]:
		_applica_vista()
	if chiave == "acc/velocita":
		Effetti.applica_velocita()


func _applica_testo() -> void:
	# Grandezza di testi e interfaccia (accessibilità): ingrandisce tutto ciò che non è il mondo di gioco.
	if not Dispositivo.in_prova:
		get_window().content_scale_factor = clampf(Impostazioni.leggi("acc/testo"), 0.8, 1.5)


func _ridimensiona() -> void:
	var finestra := get_window().size
	if finestra.x <= 0 or finestra.y <= 0:
		return
	var interna := Dispositivo.risoluzione_interna(finestra)
	_scala = interna["scala"]
	var dimensione: Vector2i = interna["dimensione"]
	var resa: Vector2i = interna["resa"]
	var area: Vector2i = interna["area"]
	# Il mondo si disegna a "resa" ma mostra sempre "dimensione" pixel di gioco
	# (risoluzione interna più bassa = meno pixel da calcolare, poi il filtro lo ingrandisce).
	mondo.size = resa
	mondo.size_2d_override = dimensione if resa != dimensione else Vector2i.ZERO
	mondo.size_2d_override_stretch = resa != dimensione
	# Unità dell'interfaccia -> pixel veri dello schermo.
	var visibile := get_viewport().get_visible_rect().size
	var fattore := float(finestra.x) / maxf(1.0, visibile.x)
	var mostrata := Vector2(dimensione) * _scala
	var bordo := (Vector2(finestra) - Vector2(area)) * 0.5
	_vista.position = bordo / fattore
	_vista.size = mostrata / fattore
	_filtro.position = Vector2.ZERO
	_filtro.size = Vector2(dimensione)
	bagliore.size = Vector2i(maxi(8, dimensione.x / 4), maxi(8, dimensione.y / 4))
	_bagliore_quadro.size = Vector2(bagliore.size)
	Rapporto.grafica("finestra", [finestra.x, finestra.y])
	Rapporto.grafica("risoluzione_interna", [dimensione.x, dimensione.y])
	Rapporto.grafica("resa", [resa.x, resa.y])
	Rapporto.grafica("scala", snappedf(_scala, 0.01))
	hud.misure(dimensione, _scala)
	_applica_vista()


func _applica_vista() -> void:
	# Filtro di ingrandimento (nitido, liscio, SGSR), luminosità, contrasto e correzione dei colori.
	if _vista == null or _materiale_vista == null:
		return
	var filtro := ["nitido", "liscio", "sgsr"].find(Impostazioni.leggi("grafica/filtro"))
	var intera := is_equal_approx(_scala, roundf(_scala)) and mondo.size_2d_override == Vector2i.ZERO
	if intera:
		filtro = 0   # a scala intera il pixel pieno è già la ricostruzione perfetta: gli altri filtri non servono
	var daltonismo := ["no", "protanopia", "deuteranopia", "tritanopia"].find(Impostazioni.leggi("acc/daltonismo"))
	var luce: float = Impostazioni.leggi("schermo/luminosita")
	var contrasto: float = Impostazioni.leggi("schermo/contrasto")
	var forza_bagliore: int = int(Dispositivo.profilo.get("bagliore", 0))
	var toni: bool = Dispositivo.profilo.get("toni", false)
	var serve := filtro > 0 or daltonismo > 0 or not is_equal_approx(luce, 1.0) or not is_equal_approx(contrasto, 1.0) \
			or forza_bagliore > 0 or toni
	_vista.material = _materiale_vista if serve else null
	bagliore.render_target_update_mode = SubViewport.UPDATE_ALWAYS if forza_bagliore > 0 else SubViewport.UPDATE_DISABLED
	(_bagliore_quadro.material as ShaderMaterial).set_shader_parameter("raggio", 1.6 if forza_bagliore >= 2 else 1.0)
	_materiale_vista.set_shader_parameter("bagliore_tex", bagliore.get_texture())
	_materiale_vista.set_shader_parameter("bagliore", [0.0, 0.9, 1.25][clampi(forza_bagliore, 0, 2)])
	_materiale_vista.set_shader_parameter("toni", toni)
	_materiale_vista.set_shader_parameter("sorgente", mondo.get_texture())
	_materiale_vista.set_shader_parameter("filtro", maxi(0, filtro))
	_materiale_vista.set_shader_parameter("nitidezza", lerpf(1.0, 3.0, Impostazioni.leggi("grafica/nitidezza")))
	_materiale_vista.set_shader_parameter("gamma_scelta", luce)
	_materiale_vista.set_shader_parameter("contrasto", contrasto)
	_materiale_vista.set_shader_parameter("daltonismo", maxi(0, daltonismo))
	Rapporto.grafica("filtro_vista", ["nitido", "liscio", "sgsr"][maxi(0, filtro)] if serve else "nessuno")


func _applica_profilo() -> void:
	_filtro.visible = Dispositivo.profilo.get("palette", true)
	_applica_vista()   # bagliore e colori del film dipendono dal profilo


func _nuova_stanza(ondata_iniziale: int = 1) -> void:
	if stanza != null:
		Suoni.stanza_tolta()
		stanza.queue_free()
	stanza = Stanza.new()
	stanza.ondata = ondata_iniziale   # riprendendo un sogno: i caduti tornano già con l'esperienza di quell'ondata
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
	# Anche i tiri di chi gioca, la freccia dei nemici e le munizioni a terra.
	for i in 4:
		var tiro := Proiettile.new()
		tiro.tipo = ["magia_eroe", "dardo", "freccia_eroe", "freccia"][i]
		tiro.position = dove + Vector2(20.0 + 14.0 * i, 0.0)
		stanza.add_child(tiro)
		tiro.set("_vita", 0.25)   # dopo add_child: _ready dà a ogni tipo la sua durata
	# Catena e attacco della sega a pendolo (linea e poligono illuminati): prima comparivano solo in galleria
	# e il telefono preparava lì il loro disegno, con uno scatto di 133 ms.
	var catena := Line2D.new()
	catena.width = 2.0
	catena.light_mask = Effetti.L_DAVANTI
	catena.points = PackedVector2Array([dove, dove + Vector2(0, 20)])
	var attacco := Polygon2D.new()
	attacco.polygon = PackedVector2Array([dove + Vector2(-7, -4), dove + Vector2(7, -4), dove + Vector2(4, 3)])
	attacco.light_mask = Effetti.L_DAVANTI
	for pezzo: Node2D in [catena, attacco]:
		stanza.add_child(pezzo)
		get_tree().create_timer(0.5).timeout.connect(pezzo.queue_free)
	var pacco := Raccoglibile.new()
	pacco.position = dove + Vector2(-30.0, 0.0)
	stanza.add_child(pacco)
	pacco.set("_t", Raccoglibile.DURATA - 0.3)
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
	_scritta_velo.text = "Il Dormiente ti sogna di nuovo."
	Memoria.nuovo_sogno()
	_nuova_stanza()
	if Partita.attiva:
		_ultima_ondata = stanza.ondata
		Partita.salva(self)
	var tw2 := create_tween()
	tw2.tween_property(_scritta_velo, "modulate:a", 1.0, 0.4)
	tw2.tween_interval(1.1)
	tw2.tween_property(_scritta_velo, "modulate:a", 0.0, 0.4)
	tw2.tween_property(_velo, "color:a", 0.0, 0.7)
	await tw2.finished
	_in_transizione = false
