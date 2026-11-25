extends Node
# Prova automatica sul computer: fa giocare il bot (script/bot.gd, lo stesso che gira sul telefono)
# e aggiunge qualche controllo che ha senso solo qui.
#
#   godot --headless --fixed-fps 60 --path . -- --prova                (solo logica, veloce)
#   godot --fixed-fps 60 --path . -- --prova --schermate=/cartella     (con le schermate)
#   ... --solo-foto                                                    (solo qualche schermata)
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
	var prima := {"impostazioni": Impostazioni.tutte(), "aspetto": Equipaggiamento.stato()}
	var bot: Bot = _principale.avvia_bot()
	bot.chiudi_alla_fine = false
	bot.scritta = false
	bot.cartella_foto = _cartella
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
	print("PROVA bot: %d controlli, fasi %s" % [bot.controlli.size(), JSON.stringify(bot.fasi.map(func(f: Dictionary) -> String: return "%s %.0fs" % [f["nome"], f["secondi"]]))])
	Impostazioni.ripristina()
	print("PROVA FINE falliti: %d" % _falliti)
	get_tree().quit(1 if _falliti > 0 else 0)
