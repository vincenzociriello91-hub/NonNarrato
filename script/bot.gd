class_name Bot
extends Node
# Il bot di prova: gioca da solo la stanza come farebbe chi gioca (corsa, salti, colpi, cassa,
# barili, nemici, cunicolo, piattaforme, schivate, tasti a schermo, menu, poi la galleria con leve,
# trappole, montacarichi, lastre che crollano, enigmi e forzieri), prova ogni gruppo di mosse,
# ogni azione del menu, molti aspetti e le tre qualità, e misura la fluidità di ogni fase.
# Alla fine rimette impostazioni e aspetto di chi gioca e salva il rapporto (che finisce in
# Download/NonNarrato_report e da lì su Drive). Sul telefono poi chiude il gioco.
# Lo usa anche la prova automatica sul computer (test/prova.gd).

signal finito(falliti: int)
signal _mai                                 # non arriva mai: tiene ferma la sequenza dopo uno stop

const SEGNO := "user://bot_in_corso.txt"   # stato di chi gioca, se il gioco si chiude a metà
const AZIONI: Array[String] = ["sinistra", "destra", "su", "giu", "salta", "attacca", "rotola", "schiva", "afferra"]
const LENTO_MS := 33.4                      # sotto i 30 FPS
const MOLTO_LENTO_MS := 50.0                # sotto i 20 FPS

var chiudi_alla_fine := true     # sul telefono: chiude il gioco dopo aver salvato il rapporto
var scritta := true              # la scritta "Bot in azione" in alto
var cartella_foto := ""          # solo nelle prove sul computer
var solo_fasi: Array = []        # solo nelle prove sul computer: fa soltanto queste fasi (per correggere più in fretta)
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
var _nav: Navigatore
var _caso := RandomNumberGenerator.new()
var _combatte_minacce := true    # per strada affronta i nemici svegli vicini
var _in_combattimento := false
var _difese := {}                # schivata -> [prove, riuscite]
var _passaggi := {}              # modo di muoversi -> volte
var _morti_impreviste := 0
var _memoria_bot := {}
var _attese_trappole := 0        # quante volte ha aspettato il momento giusto davanti a una trappola
var _difese_in_cammino := 0      # frecce e sfere schivate mentre camminava
var _tesori_bot := {}
var _piastre_saltate := 0
var _trappole_forzate := {}      # trappola -> fino a quando non la si aspetta più (ms)


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
	if stato.has("memoria"):
		Memoria.ripristina_stato(stato["memoria"])  # le nemesi del bot non restano a chi gioca


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_principale = get_parent()


func avvia() -> void:
	if in_corso:
		return
	in_corso = true
	_inizio_ms = Time.get_ticks_msec()
	_stato_utente = {"impostazioni": Impostazioni.tutte(), "aspetto": Equipaggiamento.stato(), "memoria": Memoria.stato()}
	_caso.seed = 4242
	_nav = Navigatore.new(Stanza.superfici(), Stanza.passaggi_speciali())
	_nav.condizione = func(nome: String) -> bool: return _principale.stanza.condizione(nome)
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
	# Solo i tasti davvero premuti: lasciare e ripremere un tasto nello stesso istante vale come
	# un tocco rapidissimo (per esempio un salto cortissimo).
	for azione in AZIONI:
		if Input.is_action_pressed(azione):
			Input.action_release(azione)


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


# ------------------------------------------------------------------ muoversi come chi gioca
# Niente teletrasporti: il bot si sposta solo premendo i comandi. Il Navigatore sceglie il percorso
# (camminare, saltare, aggrapparsi, scendere, attraversare, rotolare); una cassa sulla strada si
# scavalca; un nemico sveglio vicino si affronta prima di proseguire.

func _guarda(v: int) -> void:
	if _g().verso != v:
		await _tieni("destra" if v > 0 else "sinistra", 2)


func _atterra(massimo: int = 150) -> void:
	for i in massimo:
		var g := _g()
		if g.stato == Giocatore.Stato.MORTO:
			return
		if g.is_on_floor() and g.stato in [Giocatore.Stato.NORMALE, Giocatore.Stato.ATTACCO]:
			return
		await _fotogrammi(1)


func _rinasci() -> void:
	# Morto per strada: si aspetta il nuovo sogno e si riparte.
	_rilascia_tutto()
	_morti_impreviste += 1
	var sogno: int = _principale.sogno
	for i in 600:
		if _principale.sogno > sogno and not _principale._in_transizione:
			break
		await _fotogrammi(1)
	await _fotogrammi(20)


func _cassa_davanti(v: int) -> bool:
	var g := _g()
	for c: RigidBody2D in get_tree().get_nodes_in_group("casse"):
		var dx := c.global_position.x - g.global_position.x
		if signf(dx) == float(v) and absf(dx) < 28.0 and absf(c.global_position.y - g.global_position.y) < 8.0:
			return true
	return false


func _cassa_sotto() -> RigidBody2D:
	var g := _g()
	for c: RigidBody2D in get_tree().get_nodes_in_group("casse"):
		if absf(c.global_position.x - g.global_position.x) < 26.0 and absf(c.global_position.y - 32.0 - g.global_position.y) < 6.0:
			return c
	return null


func _cammina_verso(x: float, tolleranza: float = 6.0, massimo: int = 600, scavalca: bool = true) -> bool:
	var fermo := 0
	var ultimo := _g().global_position.x
	for i in massimo:
		var g := _g()
		if g.stato == Giocatore.Stato.MORTO:
			break
		var dx := x - g.global_position.x
		if absf(dx) <= tolleranza + 4.0:
			_rilascia_tutto()
			await _veglia(6)
			return absf(x - _g().global_position.x) <= tolleranza + 8.0
		var v := 1 if dx > 0.0 else -1
		Input.action_release("sinistra" if v > 0 else "destra")
		Input.action_press("destra" if v > 0 else "sinistra")
		# Una cassa sulla strada: su + direzione per scavalcarla.
		if scavalca and g.is_on_floor() and _cassa_davanti(v):
			Input.action_press("su")
		else:
			Input.action_release("su")
		if i % 10 == 0 and _combatte_minacce and _minaccia() != null:
			_rilascia_tutto()
			return false
		# Una freccia o una sfera in arrivo: prima ci si difende.
		var colpo := _sfera_in_arrivo()
		if colpo != null:
			_difese_in_cammino += 1
			await _difenditi(colpo, "sfera")
			continue
		# Una trappola sulla strada: ci si ferma prima e si passa al momento giusto.
		if g.is_on_floor() and await _aspetta_trappola(v, x):
			continue
		# Una piastra che fa scattare una trappola: la si salta (a meno che non sia proprio la meta).
		if g.is_on_floor() and g.stato == Giocatore.Stato.NORMALE and _piastra_davanti(v, x):
			_piastre_saltate += 1
			Input.action_press("salta")
			await _fotogrammi(14)
			Input.action_release("salta")
			continue
		await _fotogrammi(1)
		if absf(_g().global_position.x - ultimo) < 0.5:
			fermo += 1
		else:
			fermo = 0
		ultimo = _g().global_position.x
		if fermo > 40:
			await _tocca("salta")  # bloccato: prova a saltare
			fermo = 0
	_rilascia_tutto()
	return false


func _vai_a(dove: Vector2, tolleranza: float = 8.0) -> bool:
	for tentativo in 12:
		await _atterra()
		var g := _g()
		if g.stato == Giocatore.Stato.MORTO:
			await _rinasci()
			continue
		var minaccia := _minaccia() if _combatte_minacce else null
		if minaccia != null:
			await _combatti_contro(minaccia)
			continue
		var da := _nav.superficie_di(g.global_position)
		var a := _nav.superficie_per(dove)
		if a == "":
			return false
		if da == "":
			# Su una cassa: se la meta è più in alto e vicina, si salta da lì; altrimenti si scende.
			var sup: Dictionary = _nav.superfici[a]
			if float(sup["y"]) < g.global_position.y - 4.0 and dove.x > float(sup["x0"]) - 40.0 and dove.x < float(sup["x1"]) + 40.0:
				var v := 1 if dove.x > g.global_position.x else -1
				Input.action_press("salta")
				for i in 70:
					await _fotogrammi(1)
					if _g().velocity.y > -80.0 and not _g().is_on_floor():
						Input.action_press("destra" if v > 0 else "sinistra")
					if i > 6 and _g().is_on_floor():
						break
				_rilascia_tutto()
				await _atterra()
			else:
				# Si scende dalla cassa dalla parte della meta, oltre il bordo, senza riscavalcarla.
				var sotto := _cassa_sotto()
				var x_giu := dove.x
				if sotto != null:
					x_giu = sotto.global_position.x + (30.0 if dove.x >= sotto.global_position.x else -30.0)
				await _cammina_verso(x_giu, 4.0, 90, false)
			continue
		if da == a:
			if await _cammina_verso(dove.x, tolleranza) and _nav.superficie_di(_g().global_position) == a:
				return true
			continue
		var cammino := _nav.percorso(da, a)
		if cammino.is_empty():
			return false
		var arco: Dictionary = cammino[0]
		var riuscito := await _esegui_arco(arco)
		_nav.esito(arco, riuscito)
		if Dispositivo.in_prova:
			print("PROVA passaggio: %s>%s %s %s -> %s" % [arco["da"], arco["a"], arco["tipo"], "ok" if riuscito else "NO",
					str(_g().global_position.round())])
		_passaggi[arco["tipo"]] = int(_passaggi.get(arco["tipo"], 0)) + 1
	return false


func _esegui_arco(arco: Dictionary) -> bool:
	if not await _cammina_verso(_nav.stacco(arco), 4.0, 500):
		return false
	var v: int = arco["verso"]
	var dir := "destra" if v > 0 else "sinistra"
	var b: Dictionary = _nav.superfici[arco["a"]]
	match arco["tipo"]:
		"salto":
			await _guarda(v)
			Input.action_press("salta")
			for i in 80:
				await _fotogrammi(1)
				var g := _g()
				if i == 3:
					Input.action_press(dir)
				# Sopra la meta smette di spingere, per non superarla.
				if g.global_position.x > float(b["x0"]) + 14.0 and g.global_position.x < float(b["x1"]) - 14.0 \
						and g.global_position.y < float(b["y"]) - 2.0:
					Input.action_release(dir)
				if i > 6 and g.is_on_floor() and g.stato == Giocatore.Stato.NORMALE:
					break
		"salto_su":
			var presa := float(arco["altezza"]) > Navigatore.SALTO_PIENO
			Input.action_press("salta")
			for i in 90:
				await _fotogrammi(1)
				var g := _g()
				# Troppo alto per un salto normale: vicino al punto più alto ci si aggrappa al bordo.
				if presa and g.velocity.y > -80.0 and not g.is_on_floor():
					Input.action_press(dir)
				if i > 6 and g.is_on_floor() and g.stato == Giocatore.Stato.NORMALE:
					break
		"attraversa":
			Input.action_press("giu")
			await _tocca("salta")
			await _fotogrammi(10)
			Input.action_release("giu")
		"caduta":
			Input.action_press(dir)
			for i in 60:
				await _fotogrammi(1)
				if not _g().is_on_floor():
					break
			await _fotogrammi(6)
		"rotola":
			await _guarda(v)
			await _tocca("rotola")
			for i in 150:
				await _fotogrammi(1)
				if _g().stato == Giocatore.Stato.NORMALE and _g().is_on_floor():
					break
		"passa":
			# Una grata aperta: si cammina oltre.
			await _cammina_verso(float(arco["meta"]), 6.0, 300)
		"ascensore":
			if not await _prendi_montacarichi(arco):
				_rilascia_tutto()
				return false
	_rilascia_tutto()
	await _atterra(120)
	return _nav.superficie_di(_g().global_position) == arco["a"]


# ------------------------------------------------------------------ combattere come chi gioca

func _prendi_montacarichi(arco: Dictionary) -> bool:
	# Si aspetta il piano alla propria quota, ci si sale, si aspetta la sosta dall'altra parte e si scende.
	var m := _principale.stanza.meccanismi["montacarichi"] as PiattaformaMobile
	var sale := int(arco["verso"]) > 0
	var lato := float(arco["stacco"]) + (-48.0 if sale else 48.0)   # si aspetta di fianco, non sotto
	await _cammina_verso(lato, 6.0, 300)
	for i in 900:
		if not is_instance_valid(m) or _g().stato == Giocatore.Stato.MORTO:
			return false
		if _combatte_minacce and _minaccia() != null:
			return false   # prima si affronta chi arriva, poi si riprova
		if (m.fermo_in_basso(0.9) if sale else m.fermo_in_alto()):
			break
		await _veglia(1)
	await _cammina_verso(float(arco["stacco"]), 5.0, 120)
	for i in 900:
		await _veglia(1)
		if not is_instance_valid(m) or _g().stato == Giocatore.Stato.MORTO:
			return false
		if (m.fermo_in_alto() if sale else m.fermo_in_basso()) and _g().is_on_floor():
			break
	await _cammina_verso(float(arco["meta"]), 8.0, 200)
	return true


func _aspetta_trappola(v: int, meta_x: float) -> bool:
	# Se poco più avanti c'è una trappola che colpirebbe chi passa adesso, ci si ferma e si aspetta
	# il momento giusto (la trappola simula il passaggio). Dopo 8 secondi si passa comunque.
	# Vero se ha aspettato.
	var g := _g()
	var px := g.global_position.x
	for t: Node in get_tree().get_nodes_in_group("trappole"):
		var z: Rect2 = t.call("zona")
		if absf(g.global_position.y - z.end.y) > 8.0 or _trappole_forzate.get(t.get_instance_id(), 0) > Time.get_ticks_msec():
			continue
		var vicino := z.position.x - 8.0 if v > 0 else z.end.x + 8.0
		var distanza := (vicino - px) * v
		if distanza < 0.0 or distanza > 34.0 or (meta_x - vicino) * v <= 0.0:
			continue
		if t.call("attraversabile", px, v, Giocatore.VELOCITA * 0.92, 0.1):
			if Dispositivo.in_prova:
				print("PROVA trappola: passa %s da %.0f verso %d" % [t.name, px, v])
			return false
		_rilascia_tutto()
		_attese_trappole += 1
		for i in 480:
			await _fotogrammi(1)
			if _combatte_minacce and _minaccia() != null:
				return true
			if t.call("attraversabile", _g().global_position.x, v, Giocatore.VELOCITA * 0.92, 0.1):
				return true
		_trappole_forzate[t.get_instance_id()] = Time.get_ticks_msec() + 3000   # non si apre mai: si passa comunque
		return true
	return false


func _piastra_davanti(v: int, meta_x: float) -> bool:
	var px := _g().global_position.x
	for n: Node in get_tree().get_nodes_in_group("piastre"):
		var p := n as Piastra
		if p.modo != "scatto" or absf(p.global_position.y - _g().global_position.y) > 6.0:
			continue
		var vicino := p.global_position.x - 17.0 * v
		var lontano := p.global_position.x + 17.0 * v
		var distanza := (vicino - px) * v
		if distanza > 8.0 and distanza < 30.0 and (meta_x - lontano) * v > 10.0:
			return true
	return false


func _sfera_in_arrivo() -> Node2D:
	# Una sfera o una freccia che sta per arrivare addosso (conta anche come ci si sta muovendo).
	var g := _g()
	for s: Node in get_tree().get_nodes_in_group("sfere"):
		var sfera := s as Proiettile
		var ds := sfera.global_position - (g.global_position + Vector2(0, -22))
		var relativa := sfera.velocita - g.velocity
		var avvicina := -ds.dot(relativa) / maxf(1.0, ds.length())
		if avvicina > 20.0 and ds.length() / avvicina < 0.3 and absf(ds.y) < 60.0:
			return sfera
	return null


func _veglia(n: int) -> void:
	# Aspetta n fotogrammi, difendendosi da quello che arriva.
	for i in n:
		var colpo := _sfera_in_arrivo()
		if colpo != null:
			await _difenditi(colpo, "sfera")
		else:
			await _fotogrammi(1)


func _usa(nodo: Node2D) -> bool:
	# Va accanto a una leva o a un forziere e preme "afferra". Vero se era a portata.
	var lato := -14.0 if _g().global_position.x < nodo.global_position.x else 14.0
	await _vai_a(nodo.global_position + Vector2(lato, 0.0), 5.0)
	await _guarda(1 if nodo.global_position.x > _g().global_position.x else -1)
	await _fotogrammi(4)
	var a_portata := _g().interagibile_vicino() == nodo
	await _tocca("afferra")
	await _fotogrammi(30)
	return a_portata


func _nemici_vivi(tipo: String = "") -> Array:
	var elenco: Array = []
	for n: Nemico in get_tree().get_nodes_in_group("nemici"):
		if n.stato != Nemico.Stato.MORTO and (tipo == "" or n.tipo == tipo):
			elenco.append(n)
	var g := _g()
	elenco.sort_custom(func(a: Nemico, b: Nemico) -> bool:
		return a.global_position.distance_to(g.global_position) < b.global_position.distance_to(g.global_position))
	return elenco


func _nemici_cripta() -> Array:
	return _nemici_vivi().filter(func(n: Nemico) -> bool: return n.global_position.x < Stanza.CRIPTA)


func _minaccia() -> Nemico:
	# Un nemico sveglio, vicino e alla stessa quota.
	var g := _g()
	for n: Nemico in _nemici_vivi():
		if n.stato in [Nemico.Stato.DORME, Nemico.Stato.RISVEGLIO]:
			continue
		var d := n.global_position - g.global_position
		if absf(d.x) < 110.0 and absf(d.y) < 40.0:
			return n
	return null


func _pericolo(n: Nemico) -> String:
	var g := _g()
	var d := n.global_position - g.global_position
	if n.stato == Nemico.Stato.ATTACCO and float(n.get("_t_stato")) < Nemico.ATTACCO_INIZIO - 0.06 \
			and absf(d.x) < 72.0 and absf(d.y) < 40.0:
		return "colpo"
	# Si reagisce quando sta per arrivare (un rotolo protegge solo per un attimo).
	if _sfera_in_arrivo() != null:
		return "sfera"
	return ""


func _scegli_difesa(pericolo: String) -> String:
	# Come i nemici: prova le schivate, ricorda quali funzionano e usa più spesso quelle.
	# Contro sfere e frecce si salta, si colpisce o si rotola verso il colpo (rotolando via, arriva a fine rotolo).
	var opzioni: Array = ["scatto_indietro", "rotolo_indietro", "rotolo_avanti"] if pericolo == "colpo" \
			else ["salto", "colpisci", "rotolo_avanti"]
	if _caso.randf() < 0.25:
		return opzioni[_caso.randi() % opzioni.size()]
	var migliore: String = opzioni[0]
	var punti := -1.0
	for o: String in opzioni:
		var c: Array = _difese.get(o, [0, 0])
		var p := (1.0 + float(c[1])) / (2.0 + float(c[0]))
		if p > punti:
			punti = p
			migliore = o
	return migliore


func _difenditi(n: Node2D, pericolo: String) -> void:
	var g := _g()
	var v := 1 if n.global_position.x > g.global_position.x else -1
	var avanti := "destra" if v > 0 else "sinistra"
	var indietro := "sinistra" if v > 0 else "destra"
	var mossa := _scegli_difesa(pericolo)
	var vita_prima := g.vita
	if Dispositivo.in_prova:
		print("PROVA difesa: %s contro %s a %.0f px, stato %s, a terra %s" % [mossa, pericolo,
				n.global_position.distance_to(g.global_position + Vector2(0, -22)), Giocatore.Stato.keys()[g.stato], g.is_on_floor()])
	_rilascia_tutto()
	if g.verso != v and mossa in ["scatto_indietro", "rotolo_indietro"]:
		await _guarda(v)
	match mossa:
		"scatto_indietro":
			await _premi_insieme(indietro, "schiva")
		"rotolo_indietro":
			await _premi_insieme(indietro, "rotola")
		"rotolo_avanti":
			await _premi_insieme(avanti, "rotola")  # gli si passa attraverso, alle spalle
		"salto":
			await _tieni("salta", 14)
		"colpisci":
			await _guarda(v)
			await _tocca("attacca")
	_rilascia_tutto()
	await _fotogrammi(30)
	var riuscita := _g().vita >= vita_prima
	var c: Array = _difese.get(mossa, [0, 0])
	_difese[mossa] = [int(c[0]) + 1, int(c[1]) + (1 if riuscita else 0)]


func _combatti_contro(n: Nemico, massimo: int = 1200) -> void:
	var gia_in_combattimento := _in_combattimento
	_in_combattimento = true
	for i in massimo:
		if not is_instance_valid(n) or n.stato == Nemico.Stato.MORTO:
			break
		var g := _g()
		if g.stato == Giocatore.Stato.MORTO:
			break
		var d := n.global_position - g.global_position
		if absf(d.y) > 40.0:
			# È su un'altra quota (per esempio il mago sulla piattaforma): ci si arriva.
			_rilascia_tutto()
			if not gia_in_combattimento:
				var lato := -28.0 if d.x > 0.0 else 28.0
				var raggiunto := await _vai_a(n.global_position + Vector2(lato, 0.0), 24.0)
				if not raggiunto:
					await _fotogrammi(10)
			else:
				await _fotogrammi(10)
			continue
		var pericolo := _pericolo(n)
		if pericolo != "":
			await _difenditi(n, pericolo)
			continue
		var v := 1 if d.x > 0.0 else -1
		var avanti := "destra" if v > 0 else "sinistra"
		Input.action_release("sinistra" if v > 0 else "destra")
		# Legge il nemico: mentre carica un colpo non gli si va addosso; dopo il colpo è scoperto.
		var carica := n.stato == Nemico.Stato.ATTACCO and float(n.get("_t_stato")) < Nemico.ATTACCO_FINE
		var scoperto := n.stato == Nemico.Stato.ATTACCO and float(n.get("_t_stato")) >= Nemico.ATTACCO_FINE
		if carica and absf(d.x) < 90.0:
			Input.action_release(avanti)
			await _fotogrammi(1)
		elif absf(d.x) > 95.0 and _caso.randf() < 0.04:
			await _premi_insieme(avanti, "schiva")  # scatto in avanti per accorciare
			Input.action_release(avanti)
		elif absf(d.x) > 30.0:
			Input.action_press(avanti)
			if g.is_on_floor() and _cassa_davanti(v):
				Input.action_press("su")   # anche in combattimento le casse si scavalcano, non si spingono
			else:
				Input.action_release("su")
			await _fotogrammi(1)
		else:
			Input.action_release(avanti)
			Input.action_release("su")
			await _guarda(v)
			await _tocca("attacca")
			await _fotogrammi(6)
			if _pericolo(n) == "" and (scoperto or _caso.randf() < 0.6):
				await _tocca("attacca")   # secondo colpo solo se non arriva niente
				await _fotogrammi(12)
			else:
				await _fotogrammi(4)
	_rilascia_tutto()
	_in_combattimento = gia_in_combattimento
	await _fotogrammi(10)


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
	if Dispositivo.in_prova and in_corso and Engine.get_process_frames() % 600 == 0 and _principale.stanza != null:
		var g := _g()
		print("PROVA traccia: %s %s %s" % [fase_nome, str(g.global_position.round()), Giocatore.Stato.keys()[g.stato]])
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
	Equipaggiamento.azzera_tesori()   # senza tesori i forzieri danno sempre qualcosa (alla fine tornano quelli di chi gioca)
	Memoria.ripristina_stato({})   # il bot parte da un sogno senza ricordi: risultati confrontabili
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

	var tutte: Array[Callable] = [_movimento, _oggetti, _scheletro, _morte, _nemesi, _percorso, _qualita, _tasti_a_schermo,
			_menu_e_aspetto, _mosse_in_partita, _ambiente, _galleria, _trappole, _torre, _enigma_cassa, _enigma_bracieri,
			_gioco_libero, _prestazioni]
	for fase: Callable in tutte:
		if solo_fasi.is_empty() or solo_fasi.has(fase.get_method().trim_prefix("_")):
			await fase.call()
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
	var cassa := _cassa_vicina(350.0)
	await _vai_a(Vector2(cassa.position.x - 28.0, Stanza.PAVIMENTO), 4.0)
	await _guarda(1)
	var cassa_x := cassa.position.x
	await _tieni("destra", 70)
	await _scatta("cassa")
	await _fotogrammi(20)
	_verifica("cassa spinta", cassa.position.x > cassa_x + 12.0, "%.0f -> %.0f" % [cassa_x, cassa.position.x])

	# I barili stanno oltre la cassa: si scavalca la cassa e li si colpisce.
	var rotti := Rapporto.contatore("oggetti_rotti")
	var scavalchi := Rapporto.contatore("scavalchi")
	await _vai_a(Vector2(486, Stanza.PAVIMENTO), 6.0)
	await _guarda(-1)
	await _tocca("attacca")
	await _fotogrammi(14)
	await _scatta("barile")
	await _fotogrammi(30)
	_verifica("barile rotto", Rapporto.contatore("oggetti_rotti") > rotti, "rotti %d" % Rapporto.contatore("oggetti_rotti"))
	_verifica("per passare la cassa la scavalca", Rapporto.contatore("scavalchi") > scavalchi,
			"scavalchi %d" % (Rapporto.contatore("scavalchi") - scavalchi))


func _scheletro() -> void:
	_nuova_fase("scheletro")
	# Avvicinandosi, lo scheletro addormentato si sveglia: poi si combatte schivando i suoi colpi.
	_combatte_minacce = false
	await _vai_a(Vector2(556, Stanza.PAVIMENTO), 6.0)
	_combatte_minacce = true
	await _fotogrammi(30)
	var sveglio := false
	for n: Nemico in _nemici_vivi("scheletro"):
		if n.global_position.x < 800.0 and n.stato != Nemico.Stato.DORME:
			sveglio = true
	_verifica("lo scheletro si risveglia", sveglio)
	await _scatta("risveglio")
	var uccisi := Rapporto.contatore("nemici_uccisi")
	for n: Nemico in _nemici_vivi("scheletro"):
		if n.global_position.x < 800.0:
			await _scatta("scheletro")
			await _combatti_contro(n, 2400)
			break
	_verifica("scheletro sconfitto", Rapporto.contatore("nemici_uccisi") > uccisi,
			"uccisi %d, vita %d" % [Rapporto.contatore("nemici_uccisi"), _g().vita])
	_verifica("i nemici scelgono e ricordano le tattiche", not Memoria.tattiche.is_empty(), str(Memoria.tattiche))
	await _scatta("dopo_scheletro")


func _morte() -> void:
	# Contro il secondo scheletro il bot si distrae (non si difende): cade, e il sogno lo ricorda.
	_nuova_fase("morte")
	var sogno: int = _principale.sogno
	var killer: Nemico = null
	for n: Nemico in _nemici_vivi("scheletro"):
		if n.global_position.x < Stanza.CRIPTA:
			killer = n
	if killer == null:
		_verifica("c'è un nemico per la prova della morte", false)
		return
	_combatte_minacce = false
	await _vai_a(killer.global_position + Vector2(-30.0, 0.0), 12.0)
	for i in 1800:
		if _g().stato == Giocatore.Stato.MORTO or not is_instance_valid(killer):
			break
		var dx := killer.global_position.x - _g().global_position.x
		if absf(dx) > 34.0:
			Input.action_press("destra" if dx > 0.0 else "sinistra")
		else:
			_rilascia_tutto()
		await _fotogrammi(1)
	_rilascia_tutto()
	await _scatta("morte")
	for i in 600:
		if _principale.sogno > sogno and not _principale._in_transizione:
			break
		await _fotogrammi(1)
	await _fotogrammi(20)
	_combatte_minacce = true
	var g := _g()
	_verifica("dopo la morte si rinasce in un nuovo sogno", _principale.sogno == sogno + 1 and g.vita == Giocatore.VITA_MASSIMA
			and g.stato == Giocatore.Stato.NORMALE, "sogno %d, vita %d" % [_principale.sogno, g.vita])
	var nemesi: Array = Memoria.nemesi_per("scheletro")
	_verifica("chi ti uccide diventa una nemesi", not nemesi.is_empty() and int(nemesi[0]["vittorie"]) >= 1,
			str(Memoria.descrizione()["nemesi"]))
	await _scatta("nuovo_sogno")


func _nemesi() -> void:
	# Nuovo sogno: la nemesi è tornata, più forte. Il bot ripulisce la stanza combattendo davvero.
	_nuova_fase("nemesi")
	var nemesi_viva: Nemico = null
	for n: Nemico in _nemici_vivi():
		if not n.nemesi.is_empty():
			nemesi_viva = n
	_verifica("la nemesi torna nel sogno, più forte", nemesi_viva != null and nemesi_viva.potere >= 1
			and nemesi_viva.vita > int(Nemico.TIPI["scheletro"]["vita"]),
			"" if nemesi_viva == null else "%s, vita %d" % [Memoria.nome_completo(nemesi_viva.nemesi), nemesi_viva.vita])
	var uccisi := Rapporto.contatore("nemici_uccisi")
	var magie := Rapporto.contatore("magie_lanciate")
	for giro in 8:
		var vivi := _nemici_cripta()
		if vivi.is_empty():
			break
		# Prima chi è sulla stessa quota, poi il mago sulla sua piattaforma.
		var bersaglio: Nemico = vivi[0]
		for n: Nemico in vivi:
			if absf(n.global_position.y - _g().global_position.y) < 40.0:
				bersaglio = n
				break
		await _combatti_contro(bersaglio, 2400)
		if _g().stato == Giocatore.Stato.MORTO:
			await _rinasci()
	var presentata: bool = Rapporto.get("_eventi").any(func(e: Dictionary) -> bool: return e.get("tipo", "") == "nemesi_incontro")
	_verifica("la nemesi si presenta con la sua frase", presentata)
	_verifica("il mago lancia", Rapporto.contatore("magie_lanciate") > magie)
	_verifica("cripta ripulita combattendo", _nemici_cripta().is_empty(),
			"uccisi %d, rimasti %d" % [Rapporto.contatore("nemici_uccisi") - uccisi, _nemici_cripta().size()])
	_verifica("la nemesi ricorda com'è finita", Memoria.nemesi.is_empty() or Memoria.nemesi.any(
			func(r: Dictionary) -> bool: return int(r["sconfitte"]) >= 1 or int(r["vittorie"]) >= 2),
			str(Memoria.descrizione()["nemesi"]))
	await _scatta("stanza_ripulita")


func _percorso() -> void:
	_nuova_fase("cunicolo")
	await _vai_a(Vector2(1070, Stanza.PAVIMENTO), 6.0)
	await _tieni("destra", 30)
	_verifica("in piedi nel cunicolo non si passa", _g().position.x < 1104.0, "x %.0f" % _g().position.x)
	var rotolate := int(_passaggi.get("rotola", 0))
	await _vai_a(Vector2(1250, Stanza.PAVIMENTO), 10.0)
	await _scatta("alcova")
	var g := _g()
	_verifica("rotolata attraverso il cunicolo", g.position.x > 1200.0 and g.stato == Giocatore.Stato.NORMALE
			and int(_passaggi.get("rotola", 0)) > rotolate, "x %.0f stato %s" % [g.position.x, Giocatore.Stato.keys()[g.stato]])
	await _vai_a(Vector2(1000, Stanza.PAVIMENTO), 10.0)
	_verifica("ritorno dal cunicolo", _g().position.x < 1104.0, "x %.0f" % _g().position.x)

	_nuova_fase("piattaforme")
	# Sale per piattaforme e bordi fino alla terrazza e alla piattaforma più alta, poi scende.
	await _vai_a(Vector2(1180, 384), 10.0)
	_verifica("sale sulla terrazza", _nav.superficie_di(_g().global_position) == "terrazza", "y %.0f" % _g().position.y)
	await _vai_a(Vector2(676, 290), 12.0)
	_verifica("sale fino alla piattaforma più alta", _nav.superficie_di(_g().global_position) == "p2", "y %.0f" % _g().position.y)
	await _scatta("piattaforma")
	await _vai_a(Vector2(348, 412), 8.0)
	g = _g()
	_verifica("in piedi sulla piattaforma", g.is_on_floor() and absf(g.position.y - 412.0) < 2.0, "y %.0f" % g.position.y)
	await _vai_a(Vector2(348, Stanza.PAVIMENTO), 10.0)
	_verifica("discesa dalla piattaforma", _g().position.y > 430.0 and int(_passaggi.get("attraversa", 0)) > 0,
			"y %.0f" % _g().position.y)
	await _vai_a(Vector2(120, 392), 10.0)
	_verifica("si aggrappa e sale sul ripiano alto", _nav.superficie_di(_g().global_position) == "ripiano", "y %.0f" % _g().position.y)

	_nuova_fase("schivate")
	await _vai_a(Vector2(900, Stanza.PAVIMENTO), 8.0)
	await _guarda(1)
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
	await _vai_a(Vector2(560, Stanza.PAVIMENTO), 8.0)
	await _guarda(-1)
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
		await _vai_a(Vector2(560, Stanza.PAVIMENTO), 8.0)
		await _guarda(1)
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


func _premi_insieme(direzione: String, azione: String) -> void:
	# Direzione e tasto nello stesso istante (come "indietro + rotola").
	Input.action_press(direzione)
	Input.action_press(azione)
	await _fotogrammi(2)
	Input.action_release(azione)
	await _fotogrammi(1)


func _cassa_vicina(x: float) -> RigidBody2D:
	var scelta: RigidBody2D = null
	for c: RigidBody2D in get_tree().get_nodes_in_group("casse"):
		if scelta == null or absf(c.position.x - x) < absf(scelta.position.x - x):
			scelta = c
	return scelta


func _ambiente() -> void:
	# Mosse per muoversi nell'ambiente: rotoli e scatti avanti/indietro, scavalcare, aggrapparsi, tirare.
	_nuova_fase("ambiente")
	await _vai_a(Vector2(600, Stanza.PAVIMENTO), 6.0)
	await _guarda(1)
	await _fotogrammi(10)
	var x0 := _g().position.x
	var indietro := Rapporto.contatore("rotolate_indietro")
	await _premi_insieme("sinistra", "rotola")
	Input.action_release("sinistra")
	await _fotogrammi(10)
	await _scatta("rotolo_indietro")
	await _fotogrammi(30)
	_verifica("rotolo all'indietro: si arretra guardando avanti", _g().position.x < x0 - 30.0 and _g().verso == 1
			and Rapporto.contatore("rotolate_indietro") == indietro + 1, "%.0f -> %.0f verso %d" % [x0, _g().position.x, _g().verso])
	x0 = _g().position.x
	await _tocca("rotola")
	await _fotogrammi(40)
	_verifica("rotolo in avanti", _g().position.x > x0 + 30.0 and _g().verso == 1, "%.0f -> %.0f" % [x0, _g().position.x])

	x0 = _g().position.x
	var avanti := Rapporto.contatore("scatti_avanti")
	await _premi_insieme("destra", "schiva")
	Input.action_release("destra")
	await _fotogrammi(45)
	_verifica("scatto in avanti a terra", _g().position.x > x0 + 20.0 and Rapporto.contatore("scatti_avanti") == avanti + 1,
			"%.0f -> %.0f" % [x0, _g().position.x])
	x0 = _g().position.x
	var dietro := Rapporto.contatore("scatti_indietro")
	await _premi_insieme("sinistra", "schiva")
	Input.action_release("sinistra")
	await _fotogrammi(45)
	_verifica("scatto all'indietro con la direzione", _g().position.x < x0 - 15.0 and _g().verso == 1
			and Rapporto.contatore("scatti_indietro") == dietro + 1, "%.0f -> %.0f verso %d" % [x0, _g().position.x, _g().verso])
	Input.action_press("salta")
	await _fotogrammi(14)
	x0 = _g().position.x
	await _premi_insieme("sinistra", "schiva")
	Input.action_release("sinistra")
	await _fotogrammi(10)
	Input.action_release("salta")
	_verifica("scatto all'indietro in aria", _g().position.x < x0 - 20.0 and _g().verso == 1, "%.0f -> %.0f" % [x0, _g().position.x])
	await _fotogrammi(40)

	# Tirare (e spingere) una cassa tenendola afferrata.
	var cassa := _cassa_vicina(770.0)
	await _vai_a(Vector2(cassa.position.x - 25.0, Stanza.PAVIMENTO), 3.0)
	await _guarda(1)
	await _fotogrammi(10)
	var tasto_ok := true
	if Controlli.touch:
		tasto_ok = _principale.hud.tasto_visibile("afferra")
	var cx := cassa.position.x
	var tirate := Rapporto.contatore("tirate")
	Input.action_press("afferra")
	await _fotogrammi(4)
	var presa := _g().stato == Giocatore.Stato.PRESA
	await _tieni("sinistra", 45)
	await _scatta("tirare")
	_verifica("tirare una cassa", presa and cassa.position.x < cx - 20.0 and Rapporto.contatore("tirate") == tirate + 1 and _g().verso == 1,
			"presa %s, cassa %.0f -> %.0f" % [presa, cx, cassa.position.x])
	cx = cassa.position.x
	await _tieni("destra", 30)
	_verifica("spingere una cassa afferrata", cassa.position.x > cx + 12.0, "%.0f -> %.0f" % [cx, cassa.position.x])
	Input.action_release("afferra")
	await _fotogrammi(5)
	_verifica("lasciando il tasto si molla la cassa", _g().stato == Giocatore.Stato.NORMALE and tasto_ok)

	# Scavalcare la cassa da terra (su + direzione) e aggrapparsi al ripiano alto saltando.
	await _vai_a(Vector2(cassa.position.x - 30.0, Stanza.PAVIMENTO), 3.0)
	await _guarda(1)
	await _fotogrammi(5)
	var scavalchi := Rapporto.contatore("scavalchi")
	Input.action_press("su")
	await _tieni("destra", 30)
	Input.action_release("su")
	await _fotogrammi(10)
	await _scatta("scavalco")
	var g := _g()
	_verifica("scavalcare un ostacolo basso", Rapporto.contatore("scavalchi") == scavalchi + 1 and g.is_on_floor()
			and absf(g.position.y - (cassa.position.y - 32.0)) < 3.0, "y %.0f, cassa %.0f" % [g.position.y, cassa.position.y])
	await _vai_a(Vector2(222, Stanza.PAVIMENTO), 4.0)
	await _guarda(-1)
	await _fotogrammi(5)
	Input.action_press("sinistra")
	Input.action_press("salta")
	await _fotogrammi(50)
	Input.action_release("salta")
	Input.action_release("sinistra")
	await _fotogrammi(10)
	g = _g()
	_verifica("aggrapparsi a un bordo e salire", Rapporto.contatore("scavalchi") >= scavalchi + 2 and g.is_on_floor()
			and absf(g.position.y - 392.0) < 3.0, "y %.0f" % g.position.y)
	await _vai_a(Vector2(600, Stanza.PAVIMENTO), 10.0)


# ------------------------------------------------------------------ galleria

func _m(nome: String) -> Node:
	return _principale.stanza.meccanismi[nome]


func _galleria() -> void:
	# Dalla terrazza si scende nella galleria; la leva apre la grata dell'alcova (scorciatoia);
	# il forziere dell'alcova si apre.
	_nuova_fase("galleria")
	await _vai_a(Vector2(1440, Stanza.PAVIMENTO), 10.0)
	_verifica("dalla terrazza si scende nella galleria", _nav.superficie_di(_g().global_position) == "galleria",
			"%s" % str(_g().global_position))
	await _scatta("galleria")
	var leva := _m("leva_alcova") as Leva
	var grata := _m("porta_alcova") as Porta
	await _vai_a(leva.global_position + Vector2(14.0, 0.0), 5.0)
	await _guarda(-1)
	await _fotogrammi(3)
	var etichetta := _g().cosa_vicina()
	await _tocca("afferra")
	await _fotogrammi(70)
	_verifica("accanto alla leva il tasto dice «Leva»", etichetta == "Leva", etichetta)
	_verifica("la leva apre la grata dell'alcova", leva.accesa and grata.del_tutto_aperta())
	await _scatta("leva")
	var passati := int(_passaggi.get("passa", 0))
	var forziere := _m("forziere_alcova") as Forziere
	var vita_prima := _g().vita
	var a_portata := await _usa(forziere)
	await _fotogrammi(30)
	_verifica("dalla grata aperta si entra nell'alcova", int(_passaggi.get("passa", 0)) > passati
			and _nav.superficie_di(_g().global_position) == "alcova", str(_passaggi))
	_verifica("il forziere si apre col tasto, accanto", a_portata and forziere.aperto, str(forziere.contenuto))
	_verifica("dentro c'è un frammento della storia", forziere.contenuto.has("frammento") and Equipaggiamento.frammenti.size() >= 1)
	_verifica("il forziere cura chi è ferito", vita_prima >= Giocatore.VITA_MASSIMA or _g().vita > vita_prima,
			"vita %d -> %d" % [vita_prima, _g().vita])
	await _scatta("forziere")
	await _vai_a(Vector2(1500, Stanza.PAVIMENTO), 8.0)


func _trappole() -> void:
	# Spuntoni a tempo e sega a pendolo: si passa al momento giusto. Poi la piastra della balestra.
	_nuova_fase("trappole")
	await _vai_a(Vector2(1530, Stanza.PAVIMENTO), 8.0)
	await _veglia(10)
	var vita := _g().vita
	var subite := Rapporto.contatore("trappole_subite")
	var attese := _attese_trappole
	await _vai_a(Vector2(1900, Stanza.PAVIMENTO), 8.0)
	_verifica("passa spuntoni e sega aspettando il momento giusto", _g().global_position.x > 1880.0 and _attese_trappole > attese
			and Rapporto.contatore("trappole_subite") == subite, "vita %d -> %d, attese %d, ferite %d" % [
				vita, _g().vita, _attese_trappole - attese, Rapporto.contatore("trappole_subite") - subite])
	await _scatta("trappole")

	# La piastra davanti alla torre fa scattare la balestra nel muro: la freccia si schiva.
	var scoccate := Rapporto.contatore("frecce_scoccate")
	vita = _g().vita
	var piastra := _m("piastra_freccia") as Piastra
	await _cammina_verso(piastra.global_position.x, 4.0, 200)
	await _veglia(70)
	_verifica("la piastra fa scattare la balestra", Rapporto.contatore("frecce_scoccate") > scoccate)
	_verifica("la freccia si schiva", _g().vita >= vita, "vita %d -> %d, difese %s" % [vita, _g().vita, str(_difese)])

	# Le trappole fanno male davvero: il bot resta apposta sugli spuntoni.
	var punte := _m("spuntoni") as Spuntoni
	await _vai_a(Vector2(1700, Stanza.PAVIMENTO), 6.0)
	for i in 300:
		if punte.sicura_per(0.6):
			break
		await _fotogrammi(1)
	vita = _g().vita
	subite = Rapporto.contatore("trappole_subite")
	Input.action_press("sinistra")
	for i in 30:
		await _fotogrammi(1)
		if _g().global_position.x <= punte.global_position.x:
			break
	_rilascia_tutto()
	for i in 240:
		if _g().vita < vita:
			break
		await _fotogrammi(1)
	_verifica("gli spuntoni feriscono chi ci resta sopra", _g().vita < vita and Rapporto.contatore("trappole_subite") > subite,
			"vita %d -> %d" % [vita, _g().vita])
	await _fotogrammi(20)
	await _vai_a(Vector2(1700, Stanza.PAVIMENTO), 6.0)


func _torre() -> void:
	# Ci si aggrappa allo zoccolo; le lastre fragili portano alla torre ovest (forziere) e crollano;
	# il montacarichi porta al salone.
	_nuova_fase("torre")
	await _vai_a(Vector2(2165, 384), 8.0)
	_verifica("si aggrappa allo zoccolo della torre", _nav.superficie_di(_g().global_position) == "zoccolo",
			str(_g().global_position))
	var crolli := Rapporto.contatore("piattaforme_crollate")
	var forziere := _m("forziere_torre") as Forziere
	await _usa(forziere)
	await _scatta("torre_ovest")
	_verifica("sale per le lastre fragili fino alla torre ovest", _nav.superficie_di(_g().global_position) == "torre_ovest",
			str(_g().global_position))
	_verifica("le lastre fragili crollano dopo che ci si è saliti", Rapporto.contatore("piattaforme_crollate") > crolli)
	_verifica("il forziere della torre si apre", forziere.aperto)
	await _fotogrammi(260)
	var tutte := true
	for f: Node in get_tree().get_nodes_in_group("fragili"):
		tutte = tutte and (f as PiattaformaFragile).presente
	_verifica("le lastre crollate tornano al loro posto", tutte)
	var montacarichi := int(_passaggi.get("ascensore", 0))
	await _vai_a(Vector2(2420, 120), 10.0)
	_verifica("prende il montacarichi fino al salone", _nav.superficie_di(_g().global_position) == "salone"
			and int(_passaggi.get("ascensore", 0)) > montacarichi, "%s %s" % [str(_g().global_position), str(_passaggi)])
	await _scatta("salone")


func _enigma_cassa() -> void:
	# La cassa sulla balconata va spinta giù, poi sulla piastra: la grata del tesoro resta alzata.
	_nuova_fase("enigma_cassa")
	var cassa := _m("cassa_enigma") as RigidBody2D
	var piastra := _m("piastra_tesoro") as Piastra
	var grata := _m("porta_tesoro") as Porta
	# Prima si sistema chi c'è nella sala.
	for n: Nemico in _nemici_vivi():
		if n.global_position.x > 2208.0 and n.global_position.y > 300.0:
			await _combatti_contro(n, 1800)
	# Sulla balconata, si scavalca la cassa per mettersi dalla parte giusta e la si spinge giù.
	await _vai_a(Vector2(2510.0, 352.0), 6.0)
	Input.action_press("destra")
	Input.action_press("su")
	for i in 240:
		await _fotogrammi(1)
		var g := _g()
		if g.global_position.x > 2626.0 or (g.is_on_floor() and g.global_position.x > cassa.global_position.x + 26.0
				and absf(g.global_position.y - 352.0) < 3.0):
			break
	_rilascia_tutto()
	await _fotogrammi(10)
	await _guarda(-1)
	Input.action_press("sinistra")
	for i in 300:
		await _fotogrammi(1)
		if cassa.global_position.y > 420.0 or _g().global_position.x < 2490.0:
			break
	_rilascia_tutto()
	await _fotogrammi(60)
	_verifica("spinge la cassa giù dalla balconata", cassa.global_position.y > 470.0, str(cassa.global_position))
	await _scatta("cassa_giu")
	# Si scende dall'altra parte e la si spinge sulla piastra, senza scavalcarla.
	if _nav.superficie_di(_g().global_position) == "balconata":
		Input.action_press("destra")
		for i in 120:
			await _fotogrammi(1)
			if not _g().is_on_floor():
				break
		_rilascia_tutto()
		await _atterra()
	for tentativo in 4:
		if piastra.da_cassa:
			break
		var lato := 1.0 if cassa.global_position.x > piastra.global_position.x else -1.0
		await _cammina_verso(cassa.global_position.x + 26.0 * lato, 3.0, 600, false)
		await _guarda(-int(lato))
		Input.action_press("sinistra" if lato > 0.0 else "destra")
		for i in 360:
			await _fotogrammi(1)
			if piastra.da_cassa or _g().stato != Giocatore.Stato.NORMALE:
				break
		_rilascia_tutto()
		await _fotogrammi(30)
	await _fotogrammi(60)
	_verifica("la cassa sulla piastra tiene alzata la grata", piastra.da_cassa and grata.del_tutto_aperta(),
			"cassa %s, piastra %s" % [str(cassa.global_position), str(piastra.giu)])
	await _scatta("cassa_piastra")
	var forziere := _m("forziere_tesoro") as Forziere
	await _usa(forziere)
	_verifica("oltre la grata si apre il forziere del tesoro", forziere.aperto and _nav.superficie_di(_g().global_position) == "tesoro")


func _accendi_braciere(b: Node2D) -> void:
	# Ci si mette accanto e lo si colpisce; se qualcosa va storto (un nemico, un colpo a vuoto) si riprova.
	var enigma := b.get_parent() as EnigmaBracieri
	for tentativo in 3:
		var accesi := enigma.accesi.size()
		var sbagli := Rapporto.contatore("enigmi_sbagliati")
		var lato := -20.0 if _g().global_position.x < b.global_position.x else 20.0
		await _vai_a(b.global_position + Vector2(lato, 0.0), 5.0)
		await _guarda(1 if b.global_position.x > _g().global_position.x else -1)
		await _tocca("attacca")
		await _fotogrammi(24)
		if enigma.accesi.size() != accesi or Rapporto.contatore("enigmi_sbagliati") != sbagli or enigma.soluzione:
			return


func _enigma_bracieri() -> void:
	# Bracieri da accendere nell'ordine della tavoletta: prima apposta in un ordine sbagliato,
	# poi in quello giusto. Si alza il gradino verso la nicchia e il forziere d'oro dà un colore nuovo.
	_nuova_fase("enigma_bracieri")
	var enigma := _m("bracieri") as EnigmaBracieri
	var gradino := _m("gradino") as Porta
	await _vai_a(Vector2(2440, 120), 10.0)
	for n: Nemico in _nemici_vivi():
		if n.global_position.y < 200.0 and n.global_position.x > 2340.0:
			await _combatti_contro(n, 1800)
	# Combattendo se ne può accendere qualcuno per caso: l'errore voluto tiene conto di quelli già accesi.
	var sbagli := Rapporto.contatore("enigmi_sbagliati")
	var sbagliato := -1
	if not enigma.soluzione:
		var atteso: int = enigma.ordine[enigma.accesi.size()]
		for i in enigma.bracieri.size():
			if i != atteso and not enigma.accesi.has(i):
				sbagliato = i
	if sbagliato >= 0:
		await _accendi_braciere(enigma.bracieri[sbagliato])
		await _fotogrammi(70)
		var spenti := enigma.bracieri.all(func(b: Node) -> bool: return not b.get("acceso"))
		_verifica("ordine sbagliato: i bracieri si spengono", spenti and Rapporto.contatore("enigmi_sbagliati") > sbagli)
	for i: int in enigma.ordine:
		if not enigma.accesi.has(i):
			await _accendi_braciere(enigma.bracieri[i])
	await _scatta("bracieri")
	await _fotogrammi(120)
	_verifica("nell'ordine della tavoletta si alza il gradino segreto", enigma.soluzione and gradino.del_tutto_aperta(),
			"accesi %s, ordine %s" % [str(enigma.accesi), str(enigma.ordine)])
	var forziere := _m("forziere_oro") as Forziere
	var colori := Equipaggiamento.trovati.size()
	await _usa(forziere)
	await _scatta("nicchia")
	_verifica("dal gradino si sale alla nicchia segreta", _nav.superficie_di(_g().global_position) == "nicchia",
			str(_g().global_position))
	var colore: String = forziere.contenuto.get("colore", "")
	_verifica("il forziere d'oro dà un colore nuovo", forziere.aperto and colore != "" and Equipaggiamento.trovati.size() == colori + 1,
			str(forziere.contenuto))
	_verifica("il colore trovato si può indossare", Equipaggiamento.disponibile(colore))
	if colore != "":
		Equipaggiamento.colora("mantello", colore)
		await _fotogrammi(3)
		_verifica("il mantello prende il colore trovato", Equipaggiamento.colori["mantello"] == colore)
		await _scatta("colore_nuovo")
		Equipaggiamento.ripristina()


func _gioco_libero() -> void:
	# Gioca da solo, con una logica: va nella zona più vicina dove non è ancora stato (per strada usa
	# tutte le mosse che servono, aspetta le trappole, prende il montacarichi), rompe i barili che trova,
	# affronta chi incontra, e ogni tanto cambia aspetto. Le lastre fragili e il gradino segreto non contano.
	_nuova_fase("gioco_libero")
	var visitate := {}
	var fuori := 0
	var da_visitare: Array = []
	for id: String in _nav.superfici:
		var sup: Dictionary = _nav.superfici[id]
		if not sup.get("fragile", false) and not sup.has("condizione"):
			da_visitare.append(id)
	var rng_aspetto := RandomNumberGenerator.new()
	rng_aspetto.seed = 11
	var passo := 0
	var inizio := Time.get_ticks_msec()
	while not da_visitare.is_empty() and Time.get_ticks_msec() - inizio < 240000:
		# La più vicina fra quelle ancora da vedere.
		var qui := _g().global_position
		da_visitare.sort_custom(func(a: String, b: String) -> bool:
			return _distanza_superficie(a, qui) < _distanza_superficie(b, qui))
		var id: String = da_visitare.pop_front()
		var sup: Dictionary = _nav.superfici[id]
		var meta := _meta_sicura(sup)
		await _vai_a(meta, 12.0)
		if _nav.superficie_di(_g().global_position) == id:
			visitate[id] = true
		for b: Node in get_tree().get_nodes_in_group("rompibili"):
			if not is_instance_valid(b):
				continue
			var barile := b as Node2D
			if is_instance_valid(barile) and absf(barile.global_position.y - _g().global_position.y) < 10.0 \
					and absf(barile.global_position.x - _g().global_position.x) < 90.0:
				await _vai_a(barile.global_position + Vector2(-20.0 * signf(barile.global_position.x - _g().global_position.x), 0.0), 6.0)
				await _guarda(1 if barile.global_position.x > _g().global_position.x else -1)
				await _tocca("attacca")
				await _fotogrammi(16)
		passo += 1
		if passo % 3 == 2:
			Equipaggiamento.casuale(rng_aspetto)
		var p := _g().global_position
		if not (is_finite(p.x) and is_finite(p.y)) or p.x < 40.0 or p.x > Stanza.LARGHEZZA - 40.0 or p.y > Stanza.PAVIMENTO + 2.0:
			fuori += 1
	Equipaggiamento.ripristina()
	await _scatta("fine")
	_verifica("gioco libero: raggiunge da solo tutte le zone", da_visitare.is_empty() and visitate.size() >= passo - 1,
			"%d su %d: %s" % [visitate.size(), passo, ", ".join(visitate.keys())])
	_verifica("gioco libero: il giocatore resta nella stanza", fuori == 0, "fuori %d" % fuori)
	_verifica("per muoversi usa salti, prese, discese, rotoli, grate e montacarichi", _passaggi.size() >= 6
			and Rapporto.contatore("scavalchi") > 0, str(_passaggi))


func _distanza_superficie(id: String, da: Vector2) -> float:
	var s: Dictionary = _nav.superfici[id]
	var x := clampf(da.x, float(s["x0"]), float(s["x1"]))
	return da.distance_to(Vector2(x, float(s["y"])))


func _meta_sicura(sup: Dictionary) -> Vector2:
	# Un punto a caso sulla superficie, ma non dentro una trappola.
	for prova in 8:
		var meta := Vector2(lerpf(float(sup["x0"]) + 14.0, float(sup["x1"]) - 14.0, _caso.randf()), float(sup["y"]))
		var libera := true
		for t: Node in get_tree().get_nodes_in_group("trappole"):
			var z: Rect2 = t.call("zona")
			if meta.x > z.position.x - 16.0 and meta.x < z.end.x + 16.0 and absf(meta.y - z.end.y) < 8.0:
				libera = false
		if libera:
			return meta
	return Vector2((float(sup["x0"]) + float(sup["x1"])) * 0.5, float(sup["y"]))


func _prestazioni() -> void:
	# La stessa corsa con colpi per ogni qualità: dice quanto regge il telefono.
	for q in ["bassa", "media", "alta"]:
		Impostazioni.scrivi("grafica/qualita", q)
		await _vai_a(Vector2(560, Stanza.PAVIMENTO), 10.0)
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
	await _prova_limite_utente()
	Impostazioni.scrivi("grafica/qualita", "auto")
	await _fotogrammi(10)


func _prova_limite_utente() -> void:
	# Se chi gioca ha scelto più di 60 FPS, il bot gioca anche con quel limite e controlla che li raggiunga.
	var limite := int((_stato_utente.get("impostazioni", {}) as Dictionary).get("grafica/limite_fps", 0))
	if limite <= 60:
		return
	Impostazioni.scrivi("grafica/limite_fps", limite)
	await get_tree().create_timer(3.5).timeout   # la richiesta della frequenza allo schermo dura 2,5 s
	_nuova_fase("prestazioni_%dfps" % limite)
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
	var t: float = _fase["tempo"]
	var fps := float(_fase["fotogrammi"]) / t if t > 0.0 else 0.0
	_chiudi_fase()
	var hz := float(Dispositivo.info.get("hz", 60.0))
	# Sul computer di prova il limite non si applica: il controllo vale solo sul telefono.
	if Dispositivo.letture_android and hz > 61.0:
		_verifica("con limite %d il gioco supera i 60 FPS" % limite, fps > 66.0,
				"%.1f FPS, schermo %.0f Hz" % [fps, hz])
	Impostazioni.scrivi("grafica/limite_fps", 0)


# ------------------------------------------------------------------ fine

func _concludi(motivo: String) -> void:
	_rilascia_tutto()
	_memoria_bot = Memoria.descrizione()
	_tesori_bot = {"colori": Equipaggiamento.trovati.duplicate(), "frammenti": Equipaggiamento.frammenti.size()}
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
		"muoversi": _passaggi,
		"difese": _difese,
		"esperienza": _nav.riassunto() if _nav != null else {},
		"morti_impreviste": _morti_impreviste,
		"memoria_nemici": _memoria_bot,
		"galleria": {
			"attese_davanti_alle_trappole": _attese_trappole,
			"colpi_schivati_camminando": _difese_in_cammino,
			"piastre_saltate": _piastre_saltate,
			"forzieri_aperti": Rapporto.contatore("forzieri_aperti"),
			"enigmi_risolti": Rapporto.contatore("enigmi_risolti"),
			"enigmi_sbagliati": Rapporto.contatore("enigmi_sbagliati"),
			"trappole_subite": Rapporto.contatore("trappole_subite"),
			"lastre_crollate": Rapporto.contatore("piattaforme_crollate"),
			"tesori": _tesori_bot,
		},
	}
