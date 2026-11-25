extends Node
# Prova automatica sul computer: fa giocare il bot (script/bot.gd, lo stesso che gira sul telefono)
# e aggiunge qualche controllo che ha senso solo qui.
#
#   godot --headless --fixed-fps 60 --path . -- --prova                (solo logica, veloce)
#   godot --fixed-fps 60 --path . -- --prova --schermate=/cartella     (con le schermate)
#   ... --solo-foto                                                    (solo qualche schermata)
#   ... --fasi=torre,enigma_cassa                                      (solo alcune fasi del bot, per correggere)
#
# Stampa "PROVA ok/FALLITA ..." per ogni controllo e chiude con "PROVA FINE falliti: N".

const AZIONI: Array[String] = ["sinistra", "destra", "su", "giu", "salta", "attacca", "rotola", "schiva", "tira", "cambia_arma"]

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
	# I nemici nuovi, fermi per la foto, e i tiri in volo.
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		n.set_physics_process(false)
		if (n as Nemico).tipo == "pipistrello" and (n as Node2D).global_position.x > 2400.0:
			(n as Nemico).sprite.riproduci("vola")
			(n as Node2D).position += Vector2(-40.0, -30.0)
	await _sposta(Vector2(2420, Stanza.PAVIMENTO), 1)
	await _fotogrammi(40)
	await _scatta("sala_nemici_nuovi")
	_g().arma_distanza = "frecce"
	Input.action_press("su")
	await _tocca("tira")
	Input.action_release("su")
	await _fotogrammi(22)
	await _scatta("freccia_in_alto")
	await _sposta(Vector2(1950, Stanza.PAVIMENTO), 1)
	_g().arma_distanza = "magia"
	await _fotogrammi(30)
	await _tocca("tira")
	await _fotogrammi(18)
	await _scatta("magia_e_saltatore")
	var pacco := Raccoglibile.new()
	pacco.cosa = "frecce"
	pacco.position = Vector2(620, Stanza.PAVIMENTO)
	_principale.stanza.add_child(pacco)
	await _sposta(Vector2(560, Stanza.PAVIMENTO), 1)
	await _fotogrammi(30)
	await _scatta("munizioni_a_terra")
	for dove: Vector2 in [Vector2(560, Stanza.PAVIMENTO), Vector2(640, 289), Vector2(900, Stanza.PAVIMENTO), Vector2(1180, 383),
			Vector2(1450, Stanza.PAVIMENTO), Vector2(1760, Stanza.PAVIMENTO), Vector2(2050, 312), Vector2(2160, 136),
			Vector2(2440, Stanza.PAVIMENTO), Vector2(2560, 352), Vector2(2520, 120), Vector2(2770, Stanza.PAVIMENTO)]:
		for n: Node in get_tree().get_nodes_in_group("nemici"):
			if (n as Node2D).global_position.distance_to(dove) < 260.0:
				n.queue_free()   # solo per le foto: nessuno disturba
		await _sposta(dove, 1)
		await _fotogrammi(50)
		await _scatta("x%d_y%d" % [int(dove.x), int(dove.y)])
	# La galleria con i meccanismi in azione: grate aperte, bracieri accesi, gradino alzato.
	var stanza: Stanza = _principale.stanza
	(stanza.meccanismi["porta_tesoro"] as Porta).apri()
	(stanza.meccanismi["porta_alcova"] as Porta).apri()
	var enigma := stanza.meccanismi["bracieri"] as EnigmaBracieri
	for i: int in enigma.ordine:
		enigma.accendi(enigma.bracieri[i])
	await _sposta(Vector2(2600, 120), 1)
	await _fotogrammi(150)
	await _scatta("bracieri_accesi")
	await _sposta(Vector2(2660, -48), -1)
	await _fotogrammi(30)
	await _scatta("nicchia")
	await _sposta(Vector2(2650, Stanza.PAVIMENTO), 1)
	await _fotogrammi(60)
	await _scatta("grata_tesoro_aperta")
	# Due aspetti a caso, sempre gli stessi.
	var caso := RandomNumberGenerator.new()
	for seme in [3, 11]:
		caso.seed = seme
		Equipaggiamento.casuale(caso)
		await _sposta(Vector2(420, Stanza.PAVIMENTO), 1)
		await _fotogrammi(30)
		await _scatta("aspetto_%d" % seme)
	Equipaggiamento.ripristina()
	Impostazioni.ripristina()
	print("PROVA FINE falliti: 0")
	get_tree().quit(0)


func _esegui() -> void:
	if OS.get_cmdline_user_args().has("--solo-foto"):
		await _solo_foto()
		return
	await _fotogrammi(10)
	Impostazioni.scrivi("grafica/limite_fps", 120)   # così il bot prova anche la fase col limite di chi gioca
	var prima := {"impostazioni": Impostazioni.tutte(), "aspetto": Equipaggiamento.stato()}
	var bot: Bot = _principale.avvia_bot()
	bot.chiudi_alla_fine = false
	bot.scritta = false
	bot.cartella_foto = _cartella
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fasi="):
			bot.solo_fasi = arg.trim_prefix("--fasi=").split(",")
	bot.avvia()
	var falliti_bot: int = await bot.finito
	_falliti += falliti_bot

	# Un fotogramma lento finisce nel rapporto con il contesto della partita.
	Rapporto.call("_registra_scatto", 0.12, 3)
	var ultimo: Dictionary = {}
	for e: Dictionary in Rapporto.get("_eventi"):
		if e.get("tipo", "") == "scatto":
			ultimo = e
	_verifica("scatto registrato con il contesto", ultimo.get("ms", 0.0) == 120.0 and ultimo.get("shader_nuovi", -1) == 3
			and ultimo.has("stato") and ultimo.has("torce_con_ombra"), str(ultimo))
	var dopo := {"impostazioni": Impostazioni.tutte(), "aspetto": Equipaggiamento.stato()}
	_verifica("il bot rimette impostazioni e aspetto di prima", not FileAccess.file_exists(Bot.SEGNO) and dopo == prima,
			str(dopo) if dopo != prima else "")
	_prova_lezione_fallita()
	await _prova_armi_e_bestione()
	if bot.solo_fasi.is_empty() or bot.solo_fasi.has("prestazioni"):
		_verifica("il bot prova anche il limite FPS di chi gioca", bot.fasi.any(func(f: Dictionary) -> bool: return f["nome"] == "prestazioni_120fps"))
	print("PROVA bot: %d controlli, fasi %s" % [bot.controlli.size(), JSON.stringify(bot.fasi.map(func(f: Dictionary) -> String: return "%s %.0fs" % [f["nome"], f["secondi"]]))])
	Impostazioni.ripristina()
	print("PROVA FINE falliti: %d" % _falliti)
	get_tree().quit(1 if _falliti > 0 else 0)


func _prova_armi_e_bestione() -> void:
	# Munizioni raccolte passandoci sopra, aiuto alla mira, corazza del bestione.
	var g := _g()
	if g.stato == Giocatore.Stato.MORTO:
		await _fotogrammi(200)
		g = _g()
	await _sposta(Vector2(600, Stanza.PAVIMENTO), 1)
	var salvate: Dictionary = g.munizioni.duplicate()
	g.munizioni["dardi"] = 2
	var pacco := Raccoglibile.new()
	pacco.cosa = "dardi"
	pacco.quante = 3
	pacco.position = g.global_position
	_principale.stanza.add_child(pacco)
	await _fotogrammi(6)
	_verifica("passando sopra le munizioni si raccolgono", int(g.munizioni["dardi"]) == 5 and not is_instance_valid(pacco),
			"dardi %d" % g.munizioni["dardi"])
	g.munizioni = salvate

	# Aiuto alla mira: un nemico poco sopra, davanti, viene preso anche tirando dritto; dietro no.
	# (Gli altri nemici, se ce ne sono ancora, per un attimo non contano.)
	var altri := get_tree().get_nodes_in_group("nemici")
	for n: Node in altri:
		n.remove_from_group("nemici")
	var bersaglio := Nemico.new()
	bersaglio.tipo = "arciere"
	bersaglio.position = g.global_position + Vector2(150.0, -40.0)
	bersaglio.set_physics_process(false)
	bersaglio.add_to_group("nemici")
	_principale.stanza.add_child(bersaglio)
	await _fotogrammi(2)
	var dritto := g.bersaglio_tiro(false)
	var direzione := g.direzione_tiro(false)
	bersaglio.position = g.global_position + Vector2(-150.0, -40.0)
	await _fotogrammi(2)
	var dietro := g.bersaglio_tiro(false)
	_verifica("aiuto alla mira: prende il nemico nel cono davanti, non quello alle spalle", dritto == bersaglio and dietro == null
			and direzione.y < -0.05, "direzione %s" % str(direzione))
	bersaglio.queue_free()
	for n: Node in altri:
		if is_instance_valid(n):
			n.add_to_group("nemici")

	# Corazza del bestione: da davanti para la spada, la magia passa; alle spalle la spada passa.
	var bestione := Nemico.new()
	bestione.tipo = "bestione"
	bestione.position = g.global_position + Vector2(80.0, 0.0)
	bestione.set_physics_process(false)
	_principale.stanza.add_child(bestione)
	await _fotogrammi(2)
	bestione.verso = -1
	var parate := Rapporto.contatore("parate_bestione")
	var davanti := bestione.subisci(1, bestione.global_position + Vector2(-30.0, -20.0), 100.0)
	var magia := bestione.subisci(1, bestione.global_position + Vector2(-30.0, -20.0), 100.0, "magia")
	bestione.stato = Nemico.Stato.PATTUGLIA
	var spalle := bestione.subisci(1, bestione.global_position + Vector2(30.0, -20.0), 100.0)
	_verifica("il bestione para da davanti, non la magia né i colpi alle spalle", not davanti and magia and spalle
			and Rapporto.contatore("parate_bestione") == parate + 1, "davanti %s, magia %s, spalle %s" % [davanti, magia, spalle])
	bestione.queue_free()
	await _fotogrammi(2)


func _prova_lezione_fallita() -> void:
	# Una lezione che non funziona mai viene messa da parte: il mago non insiste con la raffica.
	var salvata := Memoria.stato()
	Memoria.ripristina_stato({})
	Memoria.tattiche["mago"] = {"raffica": [9, 0], "anticipo": [3, 1], "dritto": [1, 0]}
	var caso := RandomNumberGenerator.new()
	caso.seed = 7
	var raffiche := 0
	for i in 200:
		if Memoria.scegli_tattica("mago", "arretra", caso) == "raffica":
			raffiche += 1
	_verifica("la lezione che fallisce sempre viene lasciata", raffiche < 30, "raffica %d su 200" % raffiche)
	Memoria.ripristina_stato(salvata)
