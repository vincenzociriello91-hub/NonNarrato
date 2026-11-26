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
	# Scudo alzato e magia caricata.
	Equipaggiamento.indossa("mano_sinistra", "scudo_tondo")
	await _sposta(Vector2(1950, Stanza.PAVIMENTO), 1)
	await _fotogrammi(20)
	_g().call("_inizia_parata")
	await _fotogrammi(4)
	await _scatta("parata_con_scudo")
	Equipaggiamento.indossa("mano_sinistra", "mano_vuota")
	await _fotogrammi(30)
	_g().energia = Giocatore.ENERGIA_MASSIMA
	Input.action_press("tira")
	await _fotogrammi(60)
	Input.action_release("tira")
	await _fotogrammi(14)
	await _scatta("magia_caricata")
	await _fotogrammi(40)
	await _scatta("esplosione")
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
	bot.seme = 4242   # sul computer la partita libera va sempre allo stesso modo (sul telefono no)
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
	await _prova_nemesi_e_veterani()
	await _prova_meccanismi()
	await _prova_ondate()
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
	var rotta := bestione.subisci(1, bestione.global_position + Vector2(-30.0, -20.0), 100.0, "mischia", {"rompe": true})
	_verifica("lo spadone e le asce rompono la corazza del bestione", rotta)
	_verifica("il bestione para da davanti, non la magia né i colpi alle spalle", not davanti and magia and spalle
			and Rapporto.contatore("parate_bestione") == parate + 1, "davanti %s, magia %s, spalle %s" % [davanti, magia, spalle])
	bestione.queue_free()
	await _fotogrammi(2)

	# Scudo: da davanti para (e chi colpisce barcolla), da dietro no.
	Equipaggiamento.indossa("mano_sinistra", "scudo_tondo")
	g = _g()
	var vita := g.vita
	g.call("_inizia_parata")
	var colpito_davanti := g.subisci(1, g.global_position + Vector2(g.verso * 30.0, -20.0), 100.0)
	g.call("_inizia_parata")
	var colpito_dietro := g.subisci(1, g.global_position + Vector2(-g.verso * 30.0, -20.0), 100.0)
	_verifica("lo scudo para i colpi da davanti, non quelli alle spalle", not colpito_davanti and colpito_dietro,
			"vita %d -> %d" % [vita, g.vita])
	Equipaggiamento.indossa("mano_sinistra", "mano_vuota")
	g.vita = Giocatore.VITA_MASSIMA
	await _fotogrammi(60)
	# Le combinazioni: la seconda arma aggiunge un colpo ed è più veloce.
	var spada: Array = Armi.colpi("spada", "mano_vuota")
	var doppia: Array = Armi.colpi("spada", "seconda_spada")
	_verifica("seconda arma: un colpo in più e più veloce", doppia.size() == spada.size() + 1
			and float(doppia[0]["t"]) < float(spada[0]["t"]))


func _prova_nemesi_e_veterani() -> void:
	# Il bot non muore più apposta: qui si prova sul computer che chi ti uccide diventa nemesi, che a ogni
	# ritorno impara qualcosa, che ricorda l'arma che l'ha battuta, e che i veterani salgono di livello.
	var salvata := Memoria.stato()
	Memoria.ripristina_stato({})
	var finto := Nemico.new()
	finto.tipo = "scheletro"
	finto.id_posto = "prova@1"
	Memoria.nemico_ha_ucciso(finto)
	var rec: Array = Memoria.nemesi_per("scheletro")
	_verifica("chi ti uccide diventa una nemesi", rec.size() == 1 and int(rec[0]["vittorie"]) == 1)
	finto.nemesi = (rec[0] as Dictionary).duplicate()
	Memoria.nemico_ha_ucciso(finto)
	rec = Memoria.nemesi_per("scheletro")
	_verifica("la nemesi che vince ancora cresce e impara una capacità", int(rec[0]["potere"]) >= 2
			and (rec[0]["capacita"] as Array).size() == 1, str(rec[0]))
	finto.nemesi = (rec[0] as Dictionary).duplicate()
	Memoria.nemico_sconfitto(finto, "ascia")
	rec = Memoria.nemesi_per("scheletro")
	_verifica("battuta, la nemesi ricorda l'arma e impara ancora", rec[0]["arma_nemica"] == "ascia"
			and (rec[0]["capacita"] as Array).size() == 2 and String(Memoria.incontro(rec[0])).contains("ascia"), str(rec[0]))
	# La nemesi in stanza: più vita del normale, e para spesso l'arma che l'ha battuta.
	var forte := Nemico.new()
	forte.tipo = "scheletro"
	forte.nemesi = (rec[0] as Dictionary).duplicate()
	forte.set_physics_process(false)
	_principale.stanza.add_child(forte)
	await _fotogrammi(2)
	_verifica("la nemesi torna più forte", forte.vita > int(Nemico.TIPI["scheletro"]["vita"]), "vita %d" % forte.vita)
	forte.queue_free()
	# Veterani: ogni morte dà esperienza, il livello sale piano.
	for i in 10:
		Memoria.veterano_morto("prova@1", 6.0, 2)
	var livello := Memoria.livello_veterano("prova@1")
	var veterano := Nemico.new()
	veterano.tipo = "scheletro"
	veterano.id_posto = "prova@1"
	veterano.ondata = 3
	veterano.set_physics_process(false)
	_principale.stanza.add_child(veterano)
	await _fotogrammi(2)
	_verifica("i veterani salgono di livello e tornano più forti", livello >= 2 and veterano.livello == livello
			and veterano.vita > int(Nemico.TIPI["scheletro"]["vita"]), "livello %d, vita %d" % [livello, veterano.vita])
	veterano.queue_free()
	finto.free()   # mai entrato nella scena
	await _fotogrammi(2)
	Memoria.ripristina_stato(salvata)


func _prova_meccanismi() -> void:
	# Il bot ora gioca libero (risolve enigmi e apre forzieri solo se gli va): qui ogni meccanismo
	# della galleria si prova a colpo sicuro, in una stanza nuova a nemici fermi.
	var salvati := Equipaggiamento.stato()
	Equipaggiamento.azzera_tesori()
	_principale.ricomincia_stanza()
	await _fotogrammi(30)
	var stanza: Stanza = _principale.stanza
	var m := stanza.meccanismi
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		(n as Nemico).tregua(true)
	stanza.ondate_attive = false
	var g := _g()
	# Leva e grata, forziere (vita, frecce, frammento).
	(m["leva_alcova"] as Leva).interagisci(g)
	await _fotogrammi(80)
	_verifica("la leva apre la grata dell'alcova", (m["porta_alcova"] as Porta).del_tutto_aperta())
	g.vita = 3
	g.munizioni["frecce"] = 0
	var forziere := m["forziere_alcova"] as Forziere
	forziere.interagisci(g)
	await _fotogrammi(40)   # il coperchio si apre, poi esce il premio
	_verifica("il forziere cura, ridà le frecce e ha un frammento", forziere.aperto and g.vita > 3
			and int(g.munizioni["frecce"]) > 0 and forziere.contenuto.has("frammento"), str(forziere.contenuto))
	# Piastra e balestra.
	var scoccate := Rapporto.contatore("frecce_scoccate")
	await _sposta(Vector2((m["piastra_freccia"] as Node2D).global_position.x, Stanza.PAVIMENTO), -1)
	await _fotogrammi(60)
	_verifica("la piastra fa scattare la balestra", Rapporto.contatore("frecce_scoccate") > scoccate)
	# Spuntoni: chi ci resta sopra si ferisce.
	g.vita = Giocatore.VITA_MASSIMA
	var subite := Rapporto.contatore("trappole_subite")
	await _sposta(Vector2((m["spuntoni"] as Node2D).global_position.x, Stanza.PAVIMENTO), 1)
	_rilascia_tutto()
	for i in 300:
		if Rapporto.contatore("trappole_subite") > subite:
			break
		await _fotogrammi(1)
	_verifica("gli spuntoni feriscono chi ci resta sopra", Rapporto.contatore("trappole_subite") > subite)
	await _sposta(Vector2(1500, Stanza.PAVIMENTO), 1)
	await _fotogrammi(60)
	g.vita = Giocatore.VITA_MASSIMA
	# Lastra fragile: crolla poco dopo che ci si sale, poi torna.
	var lastra := m["crollo1"] as PiattaformaFragile
	var crolli := Rapporto.contatore("piattaforme_crollate")
	await _sposta(lastra.global_position + Vector2(PiattaformaFragile.LARGHEZZA * 0.5, -2.0), 1)
	_rilascia_tutto()
	await _fotogrammi(150)
	var crollata := Rapporto.contatore("piattaforme_crollate") > crolli
	await _sposta(Vector2(1900, Stanza.PAVIMENTO), 1)
	await _fotogrammi(240)
	_verifica("la lastra fragile crolla e poi torna", crollata and lastra.presente)
	# Montacarichi: sale e scende da solo.
	var montacarichi := m["montacarichi"] as Node2D
	var quote := {}
	for i in 12:
		quote[roundi(montacarichi.global_position.y / 40.0)] = true
		await _fotogrammi(40)
	_verifica("il montacarichi sale e scende", quote.size() >= 3, str(quote.keys()))
	# Cassa sulla piastra: la grata del tesoro resta alzata.
	var cassa := m["cassa_enigma"] as RigidBody2D
	var piastra := m["piastra_tesoro"] as Piastra
	cassa.global_position = Vector2(piastra.global_position.x, Stanza.PAVIMENTO - 2.0)
	cassa.linear_velocity = Vector2.ZERO
	await _fotogrammi(120)
	_verifica("la cassa sulla piastra tiene alzata la grata del tesoro", piastra.da_cassa and (m["porta_tesoro"] as Porta).del_tutto_aperta())
	# Bracieri: ordine sbagliato si spengono; ordine giusto alza il gradino; il forziere d'oro dà un colore.
	var enigma := m["bracieri"] as EnigmaBracieri
	var sbagli := Rapporto.contatore("enigmi_sbagliati")
	var sbagliato: int = enigma.ordine[1]
	enigma.accendi(enigma.bracieri[sbagliato])
	await _fotogrammi(90)
	_verifica("bracieri: nell'ordine sbagliato si spengono", Rapporto.contatore("enigmi_sbagliati") > sbagli and enigma.accesi.is_empty())
	for i: int in enigma.ordine:
		enigma.accendi(enigma.bracieri[i])
	await _fotogrammi(160)
	_verifica("bracieri: nell'ordine giusto si alza il gradino segreto", enigma.soluzione and (m["gradino"] as Porta).del_tutto_aperta())
	var oro := m["forziere_oro"] as Forziere
	oro.interagisci(g)
	await _fotogrammi(40)
	_verifica("il forziere d'oro dà un colore nuovo", oro.aperto and oro.contenuto.has("colore"), str(oro.contenuto))
	Equipaggiamento.ripristina_stato(salvati)
	g.vita = Giocatore.VITA_MASSIMA


func _prova_ondate() -> void:
	# Stanza vuota -> i caduti si rialzano (più forti), quattro volte; dopo la quarta il sogno si quieta.
	var salvata := Memoria.stato()
	_principale.ricomincia_stanza()   # una stanza nuova: si parte dalla prima ondata
	await _fotogrammi(30)
	var stanza: Stanza = _principale.stanza
	var ondata_prima := stanza.ondata
	var forze: Array = []
	for giro in Stanza.ONDATE:
		if stanza.sogno_completato:
			break
		for n: Node in get_tree().get_nodes_in_group("nemici"):
			var nemico := n as Nemico
			if nemico.get_parent() == stanza and nemico.stato != Nemico.Stato.MORTO:
				nemico.vita = 0
				nemico.call("_muori", 1.0)
		_g().vita = Giocatore.VITA_MASSIMA
		await _fotogrammi(int((Stanza.ATTESA_ONDATA + 1.0) * 60.0))
		var massima := 0
		for n: Node in get_tree().get_nodes_in_group("nemici"):
			if (n as Nemico).stato != Nemico.Stato.MORTO:
				massima = maxi(massima, int(n.get("_forza")))
		forze.append(massima)
	_verifica("ondate: i caduti tornano, ogni volta più forti, e dopo la quarta il sogno si quieta",
			stanza.sogno_completato and stanza.ondata == Stanza.ONDATE and stanza.nemici_vivi() == 0
			and forze.size() >= 3 and int(forze[1]) > int(forze[0]) and int(forze[2]) > int(forze[1]),
			"ondata %d -> %d, forza per ondata %s" % [ondata_prima, stanza.ondata, str(forze)])
	Memoria.ripristina_stato(salvata)


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
