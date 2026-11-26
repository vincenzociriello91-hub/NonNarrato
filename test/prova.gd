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
	# Ingrandimento: risoluzione interna al 50% con i tre filtri, poi contorni, didascalie e numeri dei danni.
	await _sposta(Vector2(420, Stanza.PAVIMENTO), 1)
	await _fotogrammi(20)
	Impostazioni.scrivi("grafica/risoluzione", 0.5)
	for filtro in ["nitido", "liscio", "sgsr"]:
		Impostazioni.scrivi("grafica/filtro", filtro)
		await _fotogrammi(4)
		await _scatta("risoluzione_50_" + filtro)
	Impostazioni.ripristina_scheda("grafica")
	Impostazioni.scrivi("grafica/qualita", "alta")
	Impostazioni.scrivi("schermo/adatta", "riempi")
	Impostazioni.scrivi("grafica/filtro", "sgsr")
	await _fotogrammi(4)
	await _scatta("sempre_360_righe_sgsr")
	Impostazioni.ripristina_scheda("schermo")
	Impostazioni.scrivi("acc/contorni", true)
	Impostazioni.scrivi("acc/didascalie", true)
	Impostazioni.scrivi("gioco/numeri_danno", true)
	await _sposta(Vector2(1950, Stanza.PAVIMENTO), 1)
	await _fotogrammi(10)
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		var nemico := n as Nemico
		if nemico.global_position.distance_to(_g().global_position) < 260.0:
			nemico.subisci(1, _g().global_position, 0.0)
	Suoni.suona("ruggito", _g().global_position + Vector2(160, 0))
	await _fotogrammi(8)
	await _scatta("contorni_didascalie_danni")
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
		if arg.begins_with("--foto-ogni="):
			bot.foto_ogni = int(arg.trim_prefix("--foto-ogni="))
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
	# Bot fermato durante le prove tecniche: i nemici non devono restare fermi e intoccabili.
	_principale.ricomincia_stanza()
	await _fotogrammi(30)
	bot.call("_tregua", true)
	await _fotogrammi(2)
	bot.call("_lascia_la_stanza_a_chi_gioca")
	await _fotogrammi(4)
	var fermi: Array = []
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		var nemico := n as Nemico
		if nemico.stato != Nemico.Stato.MORTO and (not nemico.is_physics_processing()
				or (nemico.stato not in [Nemico.Stato.DORME, Nemico.Stato.RISVEGLIO] and not nemico.bersagliabile())):
			fermi.append("%s %s" % [nemico.tipo, nemico.global_position])
	_verifica("bot fermato: i nemici tornano a muoversi e a farsi colpire", fermi.is_empty(), str(fermi))
	await _prova_impostazioni_suoni_aggiornamenti()
	await _prova_dispositivo()
	await _prova_compenetrazioni()
	await _prova_da_giocatore()
	await _prova_sotterraneo()
	await _prova_bottino()
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


func _prova_impostazioni_suoni_aggiornamenti() -> void:
	# Impostazioni (schede, valori consigliati, effetti sul gioco), suoni e aggiornamento dall'app.
	Impostazioni.ripristina()
	var senza_scheda: Array = []
	for chiave: String in Impostazioni.PREDEFINITE:
		if Impostazioni.scheda_di(chiave) == "":
			senza_scheda.append(chiave)
	_verifica("impostazioni: ogni chiave sta in una scheda", senza_scheda.is_empty(), str(senza_scheda))
	var menu: Menu = _principale.menu
	var senza_controllo: Array = []
	for chiave: String in Impostazioni.PREDEFINITE:
		if not (menu.get("_controlli") as Dictionary).has(chiave):
			senza_controllo.append(chiave)
	_verifica("impostazioni: ogni chiave ha il suo controllo nel menu", senza_controllo.is_empty(), str(senza_controllo))
	Impostazioni.scrivi("audio/musica", 0.1)
	Impostazioni.scrivi("acc/danni", 0.5)
	Impostazioni.ripristina_scheda("audio")
	_verifica("impostazioni: il ripristino di una scheda tocca solo quella", is_equal_approx(Impostazioni.leggi("audio/musica"), 0.55)
			and is_equal_approx(Impostazioni.leggi("acc/danni"), 0.5))
	# Danni ricevuti a metà: due colpi da 1 tolgono un cuore solo.
	var g := _g()
	if g.stato == Giocatore.Stato.MORTO:
		await _fotogrammi(200)
		g = _g()
	await _sposta(Vector2(600, Stanza.PAVIMENTO), 1)
	g.vita = Giocatore.VITA_MASSIMA
	g.set("_resto_danni", 0.0)
	g.subisci(1, g.global_position + Vector2(30, 0), 0.0)
	g.set("_t_protetto", 0.0)
	g.stato = Giocatore.Stato.NORMALE
	g.subisci(1, g.global_position + Vector2(30, 0), 0.0)
	_verifica("accessibilità: danni a metà", g.vita == Giocatore.VITA_MASSIMA - 1, "vita %d" % g.vita)
	Impostazioni.scrivi("acc/danni", 0.0)
	g.set("_t_protetto", 0.0)
	g.stato = Giocatore.Stato.NORMALE
	g.subisci(3, g.global_position + Vector2(30, 0), 0.0)
	_verifica("accessibilità: invincibile", g.vita == Giocatore.VITA_MASSIMA - 1, "vita %d" % g.vita)
	Impostazioni.ripristina_scheda("accessibilita")
	g.vita = Giocatore.VITA_MASSIMA
	g.vita_cambiata.emit(g.vita, Giocatore.VITA_MASSIMA)
	await _fotogrammi(40)
	Impostazioni.scrivi("acc/mira", 0)
	_verifica("accessibilità: mira assistita spenta", g.cono_mira() == 0.0 and g.bersaglio_tiro(false) == null)
	Impostazioni.scrivi("acc/mira", 2)
	_verifica("accessibilità: mira assistita forte", g.cono_mira() > Giocatore.MIRA_CONO)
	Impostazioni.scrivi("acc/contorni", true)
	var senza_contorno := 0
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		if (n as Nemico).stato != Nemico.Stato.MORTO and (n as Nemico).sprite.material == null:
			senza_contorno += 1
	_verifica("accessibilità: contorni chiari sui nemici", senza_contorno == 0, "senza contorno %d" % senza_contorno)
	Impostazioni.ripristina_scheda("accessibilita")
	# Risoluzione interna e grandezza del mondo.
	var finestra := Vector2i(2992, 1344)
	var base := Dispositivo.risoluzione_interna(finestra)
	_verifica("schermo: Pixel 8 Pro a ×4 come prima", int(base["scala"]) == 4 and base["dimensione"] == Vector2i(748, 336), str(base))
	Impostazioni.scrivi("schermo/scala", 3)
	var tre := Dispositivo.risoluzione_interna(finestra)
	_verifica("schermo: grandezza ×3 scelta a mano", int(tre["scala"]) == 3 and (tre["dimensione"] as Vector2i).y == 448, str(tre))
	Impostazioni.scrivi("schermo/proporzioni", "16:9")
	var bande := Dispositivo.risoluzione_interna(finestra)
	_verifica("schermo: 16:9 con bande", (bande["area"] as Vector2i) == Vector2i(2389, 1344), str(bande))
	Impostazioni.scrivi("grafica/risoluzione", 0.5)
	var meta := Dispositivo.risoluzione_interna(finestra)
	_verifica("grafica: risoluzione interna 50%", (meta["resa"] as Vector2i) * 2 - (meta["dimensione"] as Vector2i) == Vector2i.ZERO
			or ((meta["resa"] as Vector2i) * 2 - (meta["dimensione"] as Vector2i)).length() <= 2.0, str(meta))
	Impostazioni.ripristina_scheda("schermo")
	Impostazioni.ripristina_scheda("grafica")
	_verifica("schermo: limiti FPS sempre con 30 e 60", Dispositivo.fps_possibili().has(30) and Dispositivo.fps_possibili().has(60))
	# Suoni: ogni file c'è, i canali esistono, suonare conta, le didascalie compaiono.
	var mancanti: Array = []
	for nome in ["passo", "salto", "fendente", "colpo", "colpito", "magia", "esplosione", "forziere", "porta", "ondata", "musica", "ambiente", "ui_tocco"]:
		if not ResourceLoader.exists(Suoni.CARTELLA + nome + ".wav"):
			mancanti.append(nome)
	_verifica("suoni: file presenti", mancanti.is_empty(), str(mancanti))
	var canali := ["Musica", "Effetti", "Ambiente", "Interfaccia"].all(func(b: String) -> bool: return AudioServer.get_bus_index(b) > 0)
	_verifica("suoni: canali musica, effetti, ambiente, interfaccia", canali)
	var prima: int = Suoni.suonati
	await _tocca("salta")
	await _fotogrammi(30)
	g.position.x += 1.0
	Suoni.suona("forziere", g.global_position)
	_verifica("suoni: si sentono salto e forziere", Suoni.suonati > prima and Suoni.ultimi.has("salto") and Suoni.ultimi.has("forziere"),
			str(Suoni.ultimi.slice(-6)))
	Impostazioni.scrivi("acc/didascalie", true)
	Suoni.suona("crollo", g.global_position + Vector2(200, 0))
	await _fotogrammi(2)
	_verifica("accessibilità: didascalia con la direzione", _principale.hud.didascalie_visibili() > 0)
	Impostazioni.ripristina_scheda("accessibilita")
	Impostazioni.scrivi("audio/generale", 0.0)
	_verifica("audio: generale a zero = tutto muto", AudioServer.is_bus_mute(0))
	Impostazioni.ripristina_scheda("audio")
	_verifica("audio: modalità notte automatica solo sul telefono", Suoni.notte_attiva() == false)
	# Aggiornamento: confronto delle versioni e controllo dell'impronta del file scaricato.
	_verifica("aggiornamento: confronto delle versioni", Aggiornatore.confronta("0.1.17", "0.1.9") > 0
			and Aggiornatore.confronta("0.1.16", "0.1.16") == 0 and Aggiornatore.confronta("0.1.2", "0.1.10") < 0)
	var prova_apk := "user://prova_impronta.bin"
	var f := FileAccess.open(prova_apk, FileAccess.WRITE)
	f.store_string("NonNarrato")
	f.close()
	var giusta := FileAccess.get_sha256(prova_apk)
	_verifica("aggiornamento: impronta giusta accettata, sbagliata rifiutata", Aggiornatore.impronta_valida(prova_apk, giusta)
			and not Aggiornatore.impronta_valida(prova_apk, "0".repeat(64)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(prova_apk))
	_verifica("aggiornamento: senza plugin sul computer (Android lo ha)", Aggiornatore.plugin == null and Aggiornatore.testo_pulsante() != "")
	Impostazioni.ripristina()


func _prova_da_giocatore() -> void:
	# Le cose trovate guardando il gioco come un giocatore esigente (0.1.23).
	_principale.ricomincia_stanza()
	await _fotogrammi(30)
	var stanza: Stanza = _principale.stanza
	_verifica("da giocatore: il riquadro tecnico parte spento", Impostazioni.PREDEFINITE["gioco/debug"] == false)
	# Nessun nemico parte dentro un forziere.
	var dentro := []
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		var e := n as Nemico
		for f: Node in get_tree().get_nodes_in_group("forzieri"):
			var fz := f as Node2D
			if absf(fz.global_position.y - e.global_position.y) < 12.0 \
					and absf(fz.global_position.x - e.global_position.x) < e.mezza_larghezza() + Nemico.FORZIERE_MEZZO:
				dentro.append("%s@%s" % [e.tipo, str(e.global_position.round())])
	_verifica("da giocatore: nessun nemico parte dentro un forziere", dentro.is_empty(), str(dentro))
	# Un nemico fermo dentro un forziere se ne scosta da solo.
	var mago: Nemico = null
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		if (n as Nemico).tipo == "mago" and (n as Nemico).global_position.x < 1000:
			mago = n
	var forziere := stanza.meccanismi["forziere_cripta"] as Node2D
	_g().global_position = Vector2(2700, Stanza.PAVIMENTO)   # lontano: il mago resta fermo
	mago.global_position = forziere.global_position + Vector2(4, 0)
	mago.velocity = Vector2.ZERO
	await _fotogrammi(90)
	var distanza := absf(mago.global_position.x - forziere.global_position.x)
	_verifica("da giocatore: un nemico fermo esce dal forziere", distanza >= mago.mezza_larghezza() + Nemico.FORZIERE_MEZZO - 1.0,
			"%.1f px" % distanza)
	# Nessun nemico cammina sul posto contro un corpo (bug del 26/11/2026, dopo i corpi solidi della 0.1.22).
	await _prova_sul_posto(stanza)
	stanza = _principale.stanza   # la prova ricomincia la stanza
	# I messaggi stanno in alto e la frase del risveglio sopra il velo nero.
	var hud: Hud = _principale.hud
	var area: Vector2 = hud.get_viewport().get_visible_rect().size
	var msg := hud.get("_messaggio") as Label
	_verifica("da giocatore: i messaggi stanno in alto", msg.position.y < area.y * 0.2, "%.0f su %.0f" % [msg.position.y, area.y])
	var scritta := _principale.get("_scritta_velo") as Label
	_verifica("da giocatore: la frase del risveglio sta sopra il velo", scritta != null
			and (scritta.get_parent() as CanvasLayer).layer > hud.layer)
	# Interruttori del menu disegnati apposta (quelli di serie non si vedevano).
	var tema := (_principale.menu.get("_fondo") as Control).theme
	_verifica("da giocatore: interruttori del menu leggibili", tema.has_icon("checked", "CheckButton")
			and tema.has_icon("unchecked", "CheckButton") and tema.has_icon("checked", "CheckBox"))
	# La vendetta dice il nome di chi tornerà.
	var prima_memoria := Memoria.stato()
	var frase := ""
	for i in 40:
		var finto := Nemico.new()
		finto.tipo = "scheletro"
		frase = Memoria.nemico_sconfitto(finto, "spada")
		finto.free()
		if frase.begins_with("Qualcosa giura vendetta"):
			break
	_verifica("da giocatore: la vendetta dice il nome", frase.begins_with("Qualcosa giura vendetta. Tornerà come ")
			and frase.length() > 40, frase)
	Memoria.ripristina_stato(prima_memoria)
	# Sotto terra le sagome della stanza spariscono (cadevano in mezzo al sotterraneo).
	_g().global_position = Vector2(600, Stanza.PAVIMENTO_SOTTO - 2)
	_g().velocity = Vector2.ZERO
	await _fotogrammi(60)
	var sopra: Array = stanza.get("_sagome_sopra")
	var sotto: Array = stanza.get("_sagome_sotto")
	_verifica("da giocatore: sotto terra le sagome della stanza spariscono", stanza.sotto_terra
			and sopra.all(func(c: CanvasItem) -> bool: return not c.visible)
			and sotto.all(func(c: CanvasItem) -> bool: return c.visible))
	# Sott'acqua il personaggio si disegna sopra il velo dell'acqua.
	var vasca: Rect2 = Stanza.ACQUE[0]["rett"]
	_g().global_position = Vector2(vasca.get_center().x, vasca.end.y - 30.0)
	_g().velocity = Vector2.ZERO
	await _fotogrammi(4)
	_verifica("da giocatore: sott'acqua il personaggio si vede", _g().sott_acqua and _g().z_index == Giocatore.Z_SOTT_ACQUA,
			"sott'acqua %s, z %d" % [str(_g().sott_acqua), _g().z_index])
	_principale.ricomincia_stanza()
	await _fotogrammi(20)
	_verifica("da giocatore: fuori dall'acqua torna normale", _g().z_index == Giocatore.Z_NORMALE)


func _secondi_sul_posto(n: Nemico, fotogrammi: int) -> float:
	# Quanto tempo, al massimo di fila, il nemico ha l'animazione di camminata senza spostarsi.
	var di_fila := 0
	var massimo := 0
	var prima := n.global_position
	for i in fotogrammi:
		await _fotogrammi(1)
		if not is_instance_valid(n):
			break
		var cammina := n.sprite.animazione == "cammina" and absf(n.velocity.x) > 5.0
		if cammina and n.global_position.distance_to(prima) < 0.2:
			di_fila += 1
			massimo = maxi(massimo, di_fila)
		else:
			di_fila = 0
		prima = n.global_position
	return massimo / 60.0


func _prova_sul_posto(stanza: Stanza) -> void:
	var tutti: Array = get_tree().get_nodes_in_group("nemici")
	for n: Nemico in tutti:
		n.tregua(true)
	var g := _g()
	g.global_position = Vector2(700, Stanza.PAVIMENTO)
	g.velocity = Vector2.ZERO
	await _fotogrammi(10)
	# Saltatore attaccato a chi gioca con la tattica "zig": prima ci camminava contro all'infinito.
	var saltatore: Nemico = null
	var scheletri: Array = []
	for n: Nemico in tutti:
		if n.tipo == "saltatore" and saltatore == null:
			saltatore = n
		if n.tipo == "scheletro" and n.global_position.y < 500.0:
			scheletri.append(n)
	saltatore.tregua(false)
	saltatore.global_position = Vector2(724, Stanza.PAVIMENTO)
	saltatore.velocity = Vector2.ZERO
	saltatore.tattica = "zig"
	saltatore._t_tattica = 0.0
	var fermo_saltatore := await _secondi_sul_posto(saltatore, 180)
	_verifica("da giocatore: il saltatore vicino non cammina sul posto", fermo_saltatore < 0.5, "%.2f s" % fermo_saltatore)
	saltatore.tregua(true)
	saltatore.global_position = Vector2(2048, 312)
	# Due scheletri in fila: quello dietro non spinge sul posto quello davanti.
	if scheletri.size() >= 2:
		var davanti: Nemico = scheletri[0]
		var dietro: Nemico = scheletri[1]
		davanti.tregua(false)
		dietro.tregua(false)
		davanti.global_position = Vector2(740, Stanza.PAVIMENTO)
		davanti.set_physics_process(false)   # fermo, col suo corpo
		dietro.global_position = Vector2(800, Stanza.PAVIMENTO)
		dietro.dorme = false
		dietro.stato = Nemico.Stato.INSEGUE
		dietro.tattica = "finta"
		var fermo_dietro := await _secondi_sul_posto(dietro, 180)
		_verifica("da giocatore: un nemico dietro un compagno non cammina sul posto", fermo_dietro < 0.5,
				"%.2f s" % fermo_dietro)
		davanti.set_physics_process(true)
	_principale.ricomincia_stanza()
	await _fotogrammi(20)


func _prova_compenetrazioni() -> void:
	# Personaggio, nemici e barili non si attraversano; il rotolo sì; l'arma si disegna sopra al corpo.
	_principale.ricomincia_stanza()
	await _fotogrammi(30)
	var stanza: Stanza = _principale.stanza
	stanza.ondate_attive = false
	var scheletro: Nemico = null
	var altri: Array = []
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		var nemico := n as Nemico
		if nemico.tipo == "scheletro" and nemico.stato != Nemico.Stato.DORME and scheletro == null and nemico.global_position.y < 500:
			scheletro = nemico
		else:
			altri.append(nemico)
	for n: Nemico in altri:
		n.tregua(true)
	scheletro.global_position = Vector2(900, Stanza.PAVIMENTO)
	scheletro.set_physics_process(false)   # fermo, ma col suo corpo
	await _sposta(Vector2(880, Stanza.PAVIMENTO), 1)
	var g := _g()
	Input.action_press("destra")
	await _fotogrammi(40)
	Input.action_release("destra")
	var distanza := absf(scheletro.global_position.x - g.global_position.x)
	_verifica("compenetrazioni: il personaggio non entra nel nemico", distanza >= Giocatore.SPAZIO + scheletro.mezza_larghezza() - 1.5, "distanza %.1f" % distanza)
	await _scatta("contro_il_nemico")
	await _sposta(Vector2(scheletro.global_position.x - 40.0, Stanza.PAVIMENTO), 1)
	await _tocca("rotola")
	await _fotogrammi(40)
	_verifica("compenetrazioni: col rotolo gli si passa attraverso", _g().global_position.x > scheletro.global_position.x + 10.0,
			"%.0f contro %.0f" % [_g().global_position.x, scheletro.global_position.x])
	# Due nemici nello stesso punto si separano.
	var secondo := altri.filter(func(n: Nemico) -> bool: return n.tipo == "scheletro")[0] as Nemico
	secondo.tregua(false)
	secondo.stato = Nemico.Stato.FERMO
	secondo.set_physics_process(true)
	scheletro.set_physics_process(true)
	await _sposta(Vector2(1040, Stanza.PAVIMENTO), 1)   # dalla parte senza barili (inseguendo lo sfonderebbe)
	secondo.global_position = scheletro.global_position + Vector2(2, 0)
	await _fotogrammi(20)
	var fra_loro := absf(secondo.global_position.x - scheletro.global_position.x)
	_verifica("compenetrazioni: due nemici non stanno uno dentro l'altro", fra_loro >= scheletro.mezza_larghezza() * 2.0 - 2.0, "%.1f" % fra_loro)
	secondo.tregua(true)
	scheletro.set_physics_process(false)
	# Barile solido: non si attraversa; un nemico che ci finisce contro lo sfonda.
	# Il barile a terra più vicino a 812 ancora intero (inseguendo, uno scheletro può averlo già sfondato).
	var barile: Rompibile = null
	for b: Node in get_tree().get_nodes_in_group("rompibili"):
		var r := b as Rompibile
		if r.vita > 0 and absf(r.global_position.y - Stanza.PAVIMENTO) < 2.0 and r.global_position.x < 1200.0 \
				and (barile == null or absf(r.global_position.x - 812.0) < absf(barile.global_position.x - 812.0)):
			barile = r
	var bx := barile.global_position.x
	scheletro.set_physics_process(false)   # intanto lo scheletro non si muove (lo sfonderebbe lui)
	scheletro.global_position = Vector2(bx + 120.0, Stanza.PAVIMENTO)
	await _sposta(Vector2(bx - 30.0, Stanza.PAVIMENTO), 1)
	Input.action_press("destra")
	await _fotogrammi(40)
	Input.action_release("destra")
	_verifica("compenetrazioni: il barile non si attraversa", is_instance_valid(barile) and _g().global_position.x < barile.global_position.x - 12.0,
			"%.0f" % _g().global_position.x)
	await _sposta(Vector2(bx - 70.0, Stanza.PAVIMENTO), 1)
	scheletro.global_position = Vector2(bx + 30.0, Stanza.PAVIMENTO)
	scheletro.stato = Nemico.Stato.INSEGUE
	scheletro.set_physics_process(true)
	for i in 240:
		await _fotogrammi(1)
		if not is_instance_valid(barile) or barile.vita <= 0:
			break
	_verifica("compenetrazioni: il nemico sfonda il barile sulla sua strada", not is_instance_valid(barile) or barile.vita <= 0)
	# L'arma in mano si disegna sopra al corpo (anche nelle normali).
	var figura := _g().sprite as FiguraViva
	var pezzi: Dictionary = figura.get("_pezzi")
	var arma_ok := false
	for nome: String in pezzi:
		if figura.pezzo_sopra(nome):
			var coppia: Array = pezzi[nome]
			arma_ok = (coppia[0] as MeshInstance3D).material_override.render_priority == FiguraViva.PRIORITA_SOPRA \
					and (coppia[1] as MeshInstance3D).material_override.render_priority == FiguraViva.PRIORITA_SOPRA
			break
	_verifica("compenetrazioni: l'arma si disegna sopra a testa e busto", arma_ok and not figura.pezzo_sopra("Viandante__Rogue_Body"))
	_principale.ricomincia_stanza()
	await _fotogrammi(30)


func _prova_dispositivo() -> void:
	# Riconoscimento del dispositivo: livello consigliato, nome del processore, dati del plugin, energia.
	var d := Dispositivo
	_verifica("dispositivo: poca memoria = qualità bassa", d.consiglia_da({"ram_mb": 2048, "core": 8})[0] == "bassa"
			and d.consiglia_da({"poca_memoria": true, "ram_mb": 8000, "core": 8})[0] == "bassa")
	_verifica("dispositivo: grafica potente e memoria = alta", d.consiglia_da({"gpu": "Adreno (TM) 740", "ram_mb": 12000, "core": 8})[0] == "alta"
			and d.consiglia_da({"gpu": "Mali-G57", "ram_mb": 6000, "core": 8, "classe_prestazioni": 33})[0] == "alta")
	_verifica("dispositivo: fascia media = media", d.consiglia_da({"gpu": "Mali-G57", "ram_mb": 4000, "core": 8})[0] == "media")
	_verifica("dispositivo: nome commerciale del processore", d.nome_processore({"soc_modello": "SM8550", "soc_produttore": "QTI"}) == "Snapdragon 8 Gen 2 (SM8550)"
			and d.nome_processore({"soc_modello": "MT6985", "soc_produttore": "Mediatek"}) == "Mediatek MT6985",
			d.nome_processore({"soc_modello": "SM8550", "soc_produttore": "QTI"}))
	# Dati come li darebbe il plugin sulla Odin.
	var salvate: Dictionary = d.info.duplicate(true)
	var prima := [d.livello_consigliato, d.motivo_consiglio]
	d.call("_unisci_info", JSON.stringify({"produttore": "AYN", "modello": "Odin2 Portal", "android": "13", "sdk": 33,
			"soc_modello": "SM8550", "soc_produttore": "QTI", "core": 8, "ram_mb": 7680, "ram_libera_mb": 3100,
			"classe_prestazioni": 0, "spazio_libero_mb": 90000, "spazio_totale_mb": 120000, "giroscopio": true,
			"vibrazione": true, "vibrazione_dosabile": true, "frequenza_max_mhz": 3187}))
	_verifica("dispositivo: i dati del plugin riempiono memoria e processore", int(d.info["ram_mb"]) == 7680
			and String(d.info["processore"]).begins_with("Snapdragon 8 Gen 2") and d.info["modello"] == "Ayn Odin2 Portal"
			and d.info["versione_sistema"] == "Android 13", str(d.info))
	_principale.menu.call("_testi_informativi")
	var testo: String = _principale.menu.testo_info("dispositivo")
	_verifica("dispositivo: il menu dice cosa ha riconosciuto", testo.contains("Snapdragon 8 Gen 2") and testo.contains("7.5 GB")
			and testo.contains("3.19 GHz") and testo.contains("giroscopio"), testo)
	# Risparmio energetico: in automatico un livello in meno e 30 FPS; la modalità "prestazioni" vince.
	Impostazioni.scrivi("grafica/qualita", "auto")
	Impostazioni.scrivi("grafica/limite_fps", 0)
	d.livello_consigliato = "alta"
	d.aggiorna_energia(0, 1)
	d.applica()
	var normale := [d.livello, d.fps_obiettivo]
	d.aggiorna_energia(1, 1)
	var risparmio := [d.livello, d.fps_obiettivo]
	d.aggiorna_energia(1, 2)
	var prestazioni := [d.livello, d.fps_obiettivo]
	d.aggiorna_energia(0, 3)
	var batteria := [d.livello, d.fps_obiettivo]
	_verifica("dispositivo: risparmio energetico = un livello in meno e 30 FPS", normale == ["alta", 60] and risparmio == ["media", 30]
			and prestazioni == ["alta", 60] and batteria == ["media", 30], "%s %s %s %s" % [normale, risparmio, prestazioni, batteria])
	d.aggiorna_energia(-1, 0)
	d.info = salvate
	d.applica()
	d.livello_consigliato = prima[0]
	d.motivo_consiglio = prima[1]
	Impostazioni.ripristina()


func _prova_bottino() -> void:
	# Bottino secondo l'arma, pozioni che si sommano, forzieri a caso, mimic.
	var caso := RandomNumberGenerator.new()
	caso.seed = 99
	var deboli := 0
	for i in 200:
		deboli += Bottino.per_nemico("scheletro", 0, false, "magia", caso).size()
	_verifica("bottino: i nemici deboli non lasciano niente", deboli == 0 and not Bottino.forte("arciere", 1, false)
			and Bottino.forte("mago", 0, false) and Bottino.forte("scheletro", 2, false) and Bottino.forte("scheletro", 0, true))
	var conta := {}
	for arma: String in ["magia", "dardi", "frecce", "mischia"]:
		var c := {"mana": 0, "dardi": 0, "frecce": 0, "salute": 0, "stamina": 0, "velocita": 0}
		for i in 300:
			for v: Dictionary in Bottino.per_nemico("mago", 0, false, arma, caso):
				var chiave: String = v["tipo"] if v["cosa"] == "pozione" else v["cosa"]
				c[chiave] = int(c[chiave]) + 1
		conta[arma] = c
	_verifica("bottino: battuto con la magia lascia pozioni di mana", int(conta["magia"]["mana"]) > 180 and int(conta["magia"]["dardi"]) == 0,
			str(conta["magia"]))
	_verifica("bottino: con la balestra dardi, con l'arco frecce", int(conta["dardi"]["dardi"]) > 180 and int(conta["frecce"]["frecce"]) > 180
			and int(conta["dardi"]["frecce"]) == 0 and int(conta["frecce"]["mana"]) == 0, "%s %s" % [conta["dardi"], conta["frecce"]])
	_verifica("bottino: sempre possibili salute e stamina, più di rado velocità", int(conta["mischia"]["mana"]) == 0
			and int(conta["mischia"]["salute"]) > int(conta["mischia"]["velocita"]) and int(conta["mischia"]["stamina"]) > 30
			and int(conta["mischia"]["velocita"]) > 10, str(conta["mischia"]))
	var mimic_ok := true
	for i in 100:
		var l := Bottino.per_nemico("mimic", 0, false, "mischia", caso)
		if l.filter(func(v: Dictionary) -> bool: return v["cosa"] == "pozione" and v["taglia"] != "piccola").size() < 2:
			mimic_ok = false
	_verifica("bottino: il mimic lascia sempre almeno due pozioni medie o grandi", mimic_ok)
	var taglie := {"piccola": 0, "media": 0, "grande": 0}
	for i in 600:
		taglie[Bottino.taglia_a_caso(0, caso)] += 1
	_verifica("bottino: pozioni piccole, medie e grandi (le grandi rare)", int(taglie["piccola"]) > int(taglie["media"])
			and int(taglie["media"]) > int(taglie["grande"]) and int(taglie["grande"]) > 0, str(taglie))

	# Pozioni: effetto di qualche secondo che si somma.
	_principale.ricomincia_stanza()
	await _fotogrammi(30)
	var stanza: Stanza = _principale.stanza
	stanza.ondate_attive = false
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		(n as Nemico).tregua(true)
	await _sposta(Vector2(600, Stanza.PAVIMENTO), 1)
	var g := _g()
	g.bevi("velocita", "piccola")
	var prima: Dictionary = (g.effetti["velocita"] as Dictionary).duplicate()
	g.bevi("velocita", "media")
	var dopo: Dictionary = g.effetti["velocita"]
	_verifica("pozioni: due insieme si sommano (più forte e più lunga)", float(dopo["forza"]) == float(prima["forza"]) + 2.0
			and float(dopo["tempo"]) > float(prima["tempo"]) + 5.0 and is_equal_approx(g.moltiplicatore_velocita(), 1.3),
			"%s -> %s" % [str(prima), str(dopo)])
	Input.action_press("destra")
	await _fotogrammi(40)
	var corsa := g.velocity.x
	Input.action_release("destra")
	_verifica("pozioni: con la velocità si corre più forte", corsa > Giocatore.VELOCITA * 1.2, "%.0f" % corsa)
	_verifica("pozioni: in alto si vede l'effetto in corso", _principale.hud.pozioni_visibili() >= 1)
	g.vita = 3
	g.vita_cambiata.emit(g.vita, Giocatore.VITA_MASSIMA)
	g.bevi("salute", "media")
	g.stamina = 10.0
	g.bevi("stamina", "piccola")
	g.energia = 0.0
	g.bevi("mana", "piccola")
	await _fotogrammi(190)
	_verifica("pozioni: salute, stamina e mana tornano nel tempo", g.vita >= 5 and g.stamina > 60.0
			and g.energia > Giocatore.RICARICA_ENERGIA * 2.5 + 20.0, "vita %d stamina %.0f energia %.0f" % [g.vita, g.stamina, g.energia])
	await _fotogrammi(60 * 12)
	_verifica("pozioni: finito il tempo l'effetto sparisce", g.effetti.is_empty() and is_equal_approx(g.moltiplicatore_velocita(), 1.0),
			str(g.effetti))
	# Raccolta passandoci sopra (dopo il volo d'uscita).
	var r := Raccoglibile.new()
	r.cosa = "pozione"
	r.tipo_pozione = "stamina"
	r.taglia = "grande"
	r.lancio = Vector2(20, -160)
	r.position = g.position + Vector2(0, -20)
	stanza.add_child(r)
	await _fotogrammi(90)
	_verifica("pozioni: si raccolgono passandoci sopra", not is_instance_valid(r) and g.effetti.has("stamina")
			and float(g.effetti["stamina"]["forza"]) == 3.0, str(g.effetti))

	# Forziere a caso (non mimic): oggetti a caso, pozioni che saltano fuori e restano.
	var cripta := stanza.meccanismi["forziere_cripta"] as Forziere
	cripta.mimic = false
	cripta.interagisci(g)
	await _fotogrammi(110)
	var uscite := cripta.pozioni_uscite.filter(func(x: Node) -> bool: return is_instance_valid(x))
	_verifica("forzieri: oggetti a caso, almeno una pozione, niente storia", cripta.aperto and cripta.contenuto.has("pozioni")
			and not cripta.contenuto.has("frammento") and uscite.size() == (cripta.contenuto["pozioni"] as Array).size(), str(cripta.contenuto))
	_verifica("forzieri: le pozioni escono e cadono a terra, e restano", uscite.all(func(x: Raccoglibile) -> bool:
			return x.permanente and x.lancio == Vector2.ZERO), str(uscite.map(func(x: Raccoglibile) -> String: return "%s %s %s" % [x.global_position, x.lancio, x.permanente])))
	var diversi := {}
	for i in 30:
		diversi[JSON.stringify(Bottino.per_forziere(false, caso))] = true
	_verifica("forzieri: il contenuto cambia ogni volta", diversi.size() > 15, "%d diversi" % diversi.size())

	# Mimic: aperto si sveglia, morde, battuto lascia pozioni migliori; non diventa una nemesi.
	var galleria := stanza.meccanismi["forziere_galleria"] as Forziere
	galleria.mimic = true
	await _sposta(galleria.global_position + Vector2(-40, 0), 1)
	g = _g()
	galleria.interagisci(g)
	await _fotogrammi(40)
	var mimic: Nemico = null
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		if (n as Nemico).tipo == "mimic":
			mimic = n
	_verifica("mimic: il forziere si sveglia e diventa un nemico", mimic != null and not galleria.visible
			and galleria.contenuto.get("mimic", false) and not galleria.puo_interagire())
	await _scatta("mimic_sveglio")
	if mimic != null:
		await _fotogrammi(60)
		var vita := g.vita
		for i in 240:
			await _fotogrammi(1)
			if g.vita < vita:
				break
		_verifica("mimic: salta addosso e morde", g.vita < vita and Rapporto.contatore("balzi_saltatore") > 0, "vita %d -> %d" % [vita, g.vita])
		var nemesi_prima := Memoria.nemesi.size()
		Memoria.nemico_ha_ucciso(mimic)
		_verifica("mimic: non diventa una nemesi", Memoria.nemesi.size() == nemesi_prima)
		for i in 10:
			if mimic.stato == Nemico.Stato.MORTO:
				break
			mimic.subisci(3, mimic.global_position + Vector2(-20, 0), 50.0, "mischia", {"famiglia": "spada"})
			await _fotogrammi(10)
		var lasciate := mimic.bottino_lasciato.filter(func(v: Dictionary) -> bool: return v["cosa"] == "pozione" and v["taglia"] != "piccola")
		_verifica("mimic: battuto lascia pozioni migliori", mimic.stato == Nemico.Stato.MORTO and lasciate.size() >= 2,
				str(mimic.bottino_lasciato))
		await _fotogrammi(40)
		await _scatta("mimic_bottino")
	# Un nemico forte battuto con i dardi: quello che lascia esce davvero nella stanza.
	var mago: Nemico = null
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		if (n as Nemico).tipo == "mago" and (n as Nemico).stato != Nemico.Stato.MORTO:
			mago = n
	if mago != null:
		var prima_r := get_tree().get_nodes_in_group("raccoglibili").size()
		var seme := 1
		for prova_seme in range(1, 60):   # un seme con cui lascia qualcosa: la prova guarda che esca davvero
			var r_prova := RandomNumberGenerator.new()
			r_prova.seed = prova_seme
			if not Bottino.per_nemico("mago", int(mago.get("_forza")), false, "dardi", r_prova).is_empty():
				seme = prova_seme
				break
		(mago.get("_caso") as RandomNumberGenerator).seed = seme
		mago.stato = Nemico.Stato.FERMO
		mago.subisci(99, mago.global_position + Vector2(-30, 0), 50.0, "tiro", {"munizione": "dardi"})
		await _fotogrammi(80)
		var fuori := mago.bottino_lasciato.filter(func(v: Dictionary) -> bool: return v["cosa"] in ["pozione", "dardi", "frecce"]).size()
		_verifica("bottino: il nemico forte lascia gli oggetti nella stanza", not mago.bottino_lasciato.is_empty() and mago.bottino_lasciato.all(func(v: Dictionary) -> bool:
				return v["cosa"] != "pozione" or v["tipo"] != "mana")
				and get_tree().get_nodes_in_group("raccoglibili").size() >= prima_r + fuori, str(mago.bottino_lasciato))
	_principale.ricomincia_stanza()
	await _fotogrammi(30)


func _prova_sotterraneo() -> void:
	# Muro crepato, pozzo, arrampicata con la stamina, acqua con il respiro, assi di legno.
	_principale.ricomincia_stanza()
	await _fotogrammi(30)
	var stanza: Stanza = _principale.stanza
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		(n as Nemico).tregua(true)
	var g := _g()
	var muro := stanza.meccanismi["muro_ripiano"] as Struttura
	await _sposta(Vector2(216, Stanza.PAVIMENTO), -1)
	for i in 8:
		if not muro.integra:
			break
		await _tocca("attacca")
		await _fotogrammi(24)
	await _fotogrammi(4)
	_verifica("sotterraneo: il muro crepato si rompe a colpi", not muro.integra and stanza.condizione("rotto:muro_ripiano"))
	# Nella stanzetta e giù per il pozzo.
	Input.action_press("sinistra")
	for i in 240:
		await _fotogrammi(1)
		if _g().global_position.x < 124.0:
			Input.action_release("sinistra")   # sopra il buco si lascia: tenendo verso la parete ci si aggrapperebbe
		if _g().global_position.y > Stanza.SOTTO:
			break
	Input.action_release("sinistra")
	for i in 120:
		await _fotogrammi(1)
		if _g().is_on_floor() and _g().global_position.y > Stanza.SOTTO:
			break
	g = _g()
	_verifica("sotterraneo: giù per il pozzo fino in fondo", absf(g.global_position.y - Stanza.PAVIMENTO_SOTTO) < 3.0, str(g.global_position.round()))
	await _fotogrammi(20)
	_verifica("sotterraneo: la telecamera mostra il sotterraneo", stanza.sotto_terra and g.camera.limit_bottom == Stanza.FONDO_SOTTO)
	await _scatta("sotterraneo_fondo_pozzo")
	# Arrampicata sulla parete est del pozzo: salto verso la parete e si resta aggrappati.
	await _sposta(Vector2(134, Stanza.PAVIMENTO_SOTTO), 1)
	await _fotogrammi(20)
	Input.action_press("destra")
	Input.action_press("salta")   # salto pieno: la parete comincia sopra la testa
	for i in 40:
		await _fotogrammi(1)
		if _g().stato == Giocatore.Stato.ARRAMPICATA:
			break
	Input.action_release("salta")
	Input.action_release("destra")
	g = _g()
	_verifica("arrampicata: ci si aggrappa saltando verso la parete", g.stato == Giocatore.Stato.ARRAMPICATA, Giocatore.Stato.keys()[g.stato])
	_verifica("arrampicata: mani e piedi toccano la parete, non ci entrano", is_equal_approx(g.sprite.position.x, -Giocatore.SCOSTA_DAL_MURO),
			"%.1f" % g.sprite.position.x)
	var prima := g.stamina
	await _fotogrammi(60)
	var appeso := prima - g.stamina
	Input.action_press("su")
	await _fotogrammi(60)
	Input.action_release("su")
	var salito := prima - g.stamina - appeso
	_verifica("arrampicata: restare appesi stanca, salire stanca di più", appeso > 4.0 and salito > appeso * 1.5,
			"appeso %.1f salito %.1f" % [appeso, salito])
	await _scatta("arrampicata")
	g.stamina = 3.0
	await _fotogrammi(40)
	_verifica("arrampicata: senza stamina si cade", g.stato != Giocatore.Stato.ARRAMPICATA and g.get("_esausto"))
	for i in 200:
		await _fotogrammi(1)
		if _g().is_on_floor():
			break
	await _fotogrammi(90)
	_verifica("arrampicata: a terra la stamina torna", _g().stamina > 50.0 and not _g().get("_esausto"), "%.0f" % _g().stamina)
	# Acqua: dentro si nuota, sotto la superficie il respiro cala, a zero si perde vita.
	g = _g()
	g.global_position = Vector2(620, 1090)
	g.velocity = Vector2.ZERO
	await _fotogrammi(4)
	_verifica("acqua: dentro si nuota", g.stato == Giocatore.Stato.NUOTO and g.in_acqua)
	Input.action_press("giu")
	await _fotogrammi(60)
	Input.action_release("giu")
	_verifica("acqua: sott'acqua il respiro cala", g.sott_acqua and g.respiro < Giocatore.RESPIRO_MASSIMO - 5.0, "%.0f" % g.respiro)
	await _scatta("sott_acqua")
	var vita := g.vita
	g.respiro = 0.5
	Input.action_press("giu")
	await _fotogrammi(120)
	Input.action_release("giu")
	_verifica("acqua: senza respiro si perde vita", g.vita < vita, "vita %d -> %d" % [vita, g.vita])
	g.vita = Giocatore.VITA_MASSIMA
	g.vita_cambiata.emit(g.vita, Giocatore.VITA_MASSIMA)
	Impostazioni.scrivi("acc/respiro_infinito", true)
	g.respiro = 60.0
	Input.action_press("giu")
	await _fotogrammi(60)
	Input.action_release("giu")
	_verifica("accessibilità: respiro infinito", is_equal_approx(g.respiro, 60.0), "%.1f" % g.respiro)
	Impostazioni.scrivi("acc/respiro_infinito", false)
	for i in 300:
		await _fotogrammi(1)
		if not _g().sott_acqua:
			break
	await _fotogrammi(100)
	_verifica("acqua: a galla il respiro torna", not _g().sott_acqua and _g().respiro > 90.0, "%.0f" % _g().respiro)
	_verifica("hud: barre di stamina e respiro", _principale.hud.fiato_visibile() or _g().respiro >= Giocatore.RESPIRO_MASSIMO)
	# Tornati al pieno, le barre spariscono (prima la stamina restava appena sotto il pieno e la barra non spariva).
	for parte: float in [0.99, 0.997]:
		_g().stamina = Giocatore.STAMINA_MASSIMA * parte
		await _fotogrammi(2)
	_g().stamina = Giocatore.STAMINA_MASSIMA
	_g().respiro = Giocatore.RESPIRO_MASSIMO
	await _fotogrammi(3)
	_verifica("hud: al pieno le barre spariscono", not _principale.hud.fiato_visibile())
	# Assi di legno: si rompono e sotto c'è la fossa.
	g = _g()
	g.global_position = Vector2(316, Stanza.PAVIMENTO_SOTTO - 2)
	g.velocity = Vector2.ZERO
	await _fotogrammi(10)
	await _tieni("destra", 2)
	var assi := stanza.meccanismi["assi"] as Struttura
	for i in 6:
		if not assi.integra:
			break
		await _tocca("attacca")
		await _fotogrammi(24)
	_verifica("sotterraneo: le assi di legno si rompono", not assi.integra)
	Impostazioni.ripristina()
	_principale.ricomincia_stanza()
	await _fotogrammi(30)
