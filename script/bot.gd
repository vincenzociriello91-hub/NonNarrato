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
const AZIONI: Array[String] = ["sinistra", "destra", "su", "giu", "salta", "attacca", "rotola", "schiva", "afferra", "tira", "cambia_arma"]
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
var _arrampicate := 0              # pareti salite (sotterraneo)
var _riposi_mensola := 0           # soste sulle mensole per riprendere fiato
var _respiro_minimo := 100.0       # il respiro più basso durante le nuotate
var _foto_acqua := false
var _in_combattimento := false
var _difese := {}                # schivata -> [prove, riuscite]
var _passaggi := {}              # modo di muoversi -> volte
var _morti_impreviste := 0
var _memoria_bot := {}
var _attese_trappole := 0        # quante volte ha aspettato il momento giusto davanti a una trappola
var _difese_in_cammino := 0      # frecce e sfere schivate mentre camminava
var _tesori_bot := {}
var _piastre_saltate := 0
var _alle_spalle := 0            # volte che è passato alle spalle del bestione
var _usa_tiri := true            # spento quando una fase vuole provare il corpo a corpo
var _stanza_segnalata: Node = null
var _fase_interrotta := false
var _pericolo_da_chi: Nemico = null
var _esito_ondate := {}
var _ondate_permesse := false
var seme := 0                    # 0 = a caso (sul telefono ogni partita è diversa); la prova sul computer ne fissa uno
var _in_partita := false         # nella partita libera i controlli delle vecchie fasi diventano risultati, non errori
var _esiti_partita := {}
var _umore := {}                 # carattere di questa partita: coraggio, prudenza, curiosità, avidità
var _diario: Array = []          # gli obiettivi scelti, in ordine (finisce nel rapporto)
var _obiettivi := {}             # nome -> [scelto, riuscito]: il bot ricorda cosa gli riesce
var _visitate := {}
var _armi_provate := {}
var _pericolosi := {}            # tipo di nemico -> quante volte l'ha ucciso: ne terrà conto
var _stallo_massimo := 0.0
var _obiettivi_storici := {}
var _partita_finale := {}
var _t_fermo := 0.0
var _fermate: Array = []
var _ultimo_posto := Vector2.ZERO
var _obiettivo_ora := ""
var _esito_armi := {}            # tipo di nemico -> famiglia d'arma -> [combattimenti, vinti]
var _ignorati := {}              # nemici che non si riesce a raggiungere: lasciati stare per un po'

const DURATA_PARTITA := 420.0    # secondi di gioco della partita libera
const ESPERIENZA_CERVELLO := "user://bot_cervello.cfg"
var _armatura_provata := false   # il primo colpo di spada sul bestione si prova da davanti (come farebbe una persona)
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
	_caso.seed = seme if seme != 0 else int(Time.get_unix_time_from_system() * 1000.0) % 2147483647
	_nav = Navigatore.new(Stanza.superfici(), Stanza.passaggi_speciali())
	_nav.condizione = func(nome: String) -> bool: return _principale.stanza.condizione(nome)
	var f := FileAccess.open(SEGNO, FileAccess.WRITE)
	if f != null:
		f.store_string(var_to_str(_stato_utente))
		f.close()
	Dispositivo.bot_attivo = true
	Effetti.applica_velocita()
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
	if _in_partita:
		# Nella partita libera il bot sceglie da sé: quello che riesce o no è un risultato da raccontare.
		_esiti_partita[nome] = riuscita
		if Dispositivo.in_prova:
			print("PROVA partita: %s %s %s" % ["riuscito" if riuscita else "non riuscito", nome, dettaglio])
		return
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
		if g.stato == Giocatore.Stato.MORTO or g.in_acqua or g.aggrappato():
			return   # in acqua o su una parete non si aspetta il pavimento: ci pensa _vai_a
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
		if g.in_acqua:
			await _esci_dall_acqua(dove)
			continue
		if g.aggrappato():
			# Ancora su una parete (salita non finita): ci si lascia andare e si riparte da terra.
			await _tieni("sinistra" if g.verso > 0 else "destra", 12)
			await _atterra()
			continue
		var minaccia := _minaccia() if _combatte_minacce else null
		if minaccia != null:
			await _combatti_contro(minaccia)
			continue
		var da := _nav.superficie_di(g.global_position)
		var a := _nav.superficie_per(dove)
		if a == "":
			return false
		if da == "" and _su_mensola():
			# Su una mensola a metà parete (sosta finita male, o caduti sopra): giù attraverso.
			Input.action_press("giu")
			await _tocca("salta")
			await _fotogrammi(12)
			Input.action_release("giu")
			await _atterra()
			continue
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
		"arrampica":
			if not await _arrampica(arco):
				_rilascia_tutto()
				return false
		"nuota":
			if not await _nuota(arco):
				_rilascia_tutto()
				return false
	_rilascia_tutto()
	await _atterra(120)
	return _nav.superficie_di(_g().global_position) == arco["a"]


# ------------------------------------------------------------------ pareti e acqua (0.1.18)

func _arrampica(arco: Dictionary) -> bool:
	# Salto pieno verso la parete (comincia sopra la testa), poi su. Se la stamina non basta fino in
	# cima ci si posa su una mensola (ci si scende sopra) e si riprende fiato prima di continuare.
	var v: int = arco["verso"]
	var dir := "destra" if v > 0 else "sinistra"
	for prova in 3:
		await _atterra(60)
		Input.action_press(dir)
		Input.action_press("salta")
		for i in 50:
			await _fotogrammi(1)
			if _g().aggrappato():
				break
		Input.action_release("salta")
		Input.action_release(dir)
		if _g().aggrappato():
			break
		await _atterra(60)
		await _cammina_verso(_nav.stacco(arco), 3.0, 120)
	if not _g().aggrappato():
		return false
	_arrampicate += 1
	if Dispositivo.in_prova:
		print("PROVA arrampicata: presa a %s, stamina %.0f" % [str(_g().global_position.round()), _g().stamina])
	var stanza: Stanza = _principale.stanza
	var mensola: Variant = null
	var scendo := false   # deciso di posarsi sulla mensola: giù finché non ci si è sopra
	for i in 1800:
		var g := _g()
		if g.stato == Giocatore.Stato.MORTO:
			break
		if g.stato == Giocatore.Stato.SCAVALCO:
			Input.action_release("su")
			await _fotogrammi(1)
			continue
		if g.aggrappato():
			if scendo and g.global_position.y > (mensola as Rect2).position.y + 12.0:
				scendo = false   # mancata (non doveva succedere): si riprende a salire
				mensola = null
			if mensola == null:
				mensola = _mensola_per_riposare(g, stanza)
				if mensola != null and Dispositivo.in_prova:
					print("PROVA arrampicata: sosta sulla mensola a y %.0f (piedi %.0f, stamina %.0f)" % [(mensola as Rect2).position.y,
							g.global_position.y, g.stamina])
			if mensola != null and (scendo or g.global_position.y < (mensola as Rect2).position.y - 3.0):
				# Coi piedi sopra la mensola: giù, ci si posa e la parete si lascia da sola.
				scendo = true
				Input.action_release("su")
				Input.action_press("giu")
			else:
				Input.action_release("giu")
				Input.action_press("su")
			await _fotogrammi(1)
			continue
		Input.action_release("su")
		Input.action_release("giu")
		if g.is_on_floor() and mensola != null and absf(g.global_position.y - (mensola as Rect2).position.y) < 3.0:
			# Sulla mensola: si riprende fiato, poi su per riaggrapparsi.
			_riposi_mensola += 1
			for j in 400:
				await _fotogrammi(1)
				if _g().stamina >= Giocatore.STAMINA_MASSIMA - 2.0:
					break
			mensola = null
			scendo = false
			await _tieni("su", 8)
			continue
		if g.is_on_floor():
			break   # arrivati in cima (oppure caduti: lo dice la superficie)
		await _fotogrammi(1)
	_rilascia_tutto()
	if Dispositivo.in_prova:
		print("PROVA arrampicata: fine a %s, stamina %.0f, %s" % [str(_g().global_position.round()), _g().stamina,
				Giocatore.Stato.keys()[_g().stato]])
	return _g().stato != Giocatore.Stato.MORTO


func _su_mensola() -> bool:
	var g := _g()
	if not g.is_on_floor():
		return false
	for m: Rect2 in Stanza.MENSOLE:
		if absf(g.global_position.y - m.position.y) < 3.0 and g.global_position.x > m.position.x - 7.0 and g.global_position.x < m.end.x + 7.0:
			return true
	return false


func _mensola_per_riposare(g: Giocatore, stanza: Stanza) -> Variant:
	# Serve una sosta? Si confronta la stamina che resta con quella per arrivare in cima; se non basta,
	# la mensola più alta sulla stessa parete che si raggiunge con la stamina di adesso.
	var zona: Dictionary = stanza.zona_scalabile(g.global_position + Vector2(0.0, -Giocatore.ALTO.y * 0.5))
	if zona.is_empty():
		return null
	var per_px := Giocatore.STAMINA_SCALA / Giocatore.ARRAMPICATA_VELOCITA
	var cima := (zona["rett"] as Rect2).position.y + Giocatore.ALTO.y * 0.5   # i piedi in cima alla parete
	if (g.global_position.y - cima) * per_px + 10.0 < g.stamina:
		return null
	var scelta: Variant = null
	for m: Rect2 in Stanza.MENSOLE:
		if g.global_position.x < m.position.x - 2.0 or g.global_position.x > m.end.x + 2.0:
			continue
		var salita := g.global_position.y - (m.position.y - 3.0)
		if salita > 0.0 and salita * per_px + 6.0 < g.stamina and (scelta == null or m.position.y < (scelta as Rect2).position.y):
			scelta = m
	return scelta


func _nuota(arco: Dictionary) -> bool:
	# Dalla riva in acqua; prima dell'arco giù finché i piedi stanno sotto la quota di "immersione",
	# sotto l'arco avanti, poi a galla e fuori con un salto verso la riva (il bordo si afferra da solo).
	var v: int = arco["verso"]
	var dir := "destra" if v > 0 else "sinistra"
	var meta := float(arco["meta"])
	var imm: Array = arco.get("immersione", [])
	var vasca := _vasca_vicina(Vector2(meta, Stanza.PAVIMENTO_SOTTO))
	var riva := vasca.end.x if v > 0 else vasca.position.x
	var entrato := _g().in_acqua
	var uscito := false
	for i in 1500:
		var g := _g()
		if g.stato == Giocatore.Stato.MORTO:
			break
		if not g.in_acqua:
			if entrato and (g.is_on_floor() or g.stato == Giocatore.Stato.SCAVALCO):
				uscito = true
				break
			Input.action_press(dir)
			await _fotogrammi(1)
			continue
		entrato = true
		_respiro_minimo = minf(_respiro_minimo, g.respiro)
		var x := g.global_position.x
		var piedi := g.global_position.y
		var alla_riva := (riva - x) * v   # > 0 finché non si tocca la riva
		var sotto_arco := false
		var all_arco := INF
		if imm.size() == 3:
			all_arco = (float(imm[0] if v > 0 else imm[1]) - x) * v        # < 0: già sotto l'arco
			var passato := (x - float(imm[1] if v > 0 else imm[0])) * v    # > 0: arco superato
			sotto_arco = all_arco < 70.0 and passato < 0.0
		if sotto_arco:
			if piedi < float(imm[2]) + 6.0:
				Input.action_press("giu")
			else:
				Input.action_release("giu")
			# Sotto l'arco si entra solo abbastanza in basso, altrimenti si sbatte contro la roccia.
			if all_arco < 24.0 and all_arco > -4.0 and piedi < float(imm[2]) - 4.0:
				Input.action_release(dir)
			else:
				Input.action_press(dir)
			if fase_nome == "sotterraneo" and not _foto_acqua and all_arco < -40.0 and g.sott_acqua:
				_foto_acqua = true
				await _scatta("bot_sott_acqua")
		else:
			Input.action_release("giu")
			if alla_riva > 10.0:
				Input.action_press(dir)
			elif not g.sott_acqua:
				# A galla accanto alla riva: salto verso il bordo.
				Input.action_press(dir)
				Input.action_press("salta")
				await _fotogrammi(16)
				Input.action_release("salta")
				continue
			else:
				Input.action_release(dir)
		await _fotogrammi(1)
	_rilascia_tutto()
	if uscito:
		await _atterra(60)
		await _cammina_verso(meta, 6.0, 200)
	return uscito


func _vasca_vicina(dove: Vector2) -> Rect2:
	var migliore := Rect2()
	var distanza := INF
	for a: Dictionary in Stanza.ACQUE:
		var r: Rect2 = a["rett"]
		var d := dove.distance_to(Vector2(clampf(dove.x, r.position.x, r.end.x), clampf(dove.y, r.position.y, r.end.y)))
		if d < distanza:
			distanza = d
			migliore = r
	return migliore


func _esci_dall_acqua(dove: Vector2) -> void:
	# Caduti (o rimasti) in acqua: si esce dalla riva dalla parte della meta, passando sotto l'arco se serve.
	var g := _g()
	for a: Dictionary in Stanza.ACQUE:
		var r: Rect2 = a["rett"]
		if r.grow(10.0).has_point(g.global_position):
			var v := 1 if dove.x > r.get_center().x else -1
			var riva := r.end.x if v > 0 else r.position.x
			await _nuota({"verso": v, "meta": riva + v * 16.0, "immersione": a.get("immersione", [])})
			return
	await _fotogrammi(10)


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
	if not is_instance_valid(nodo):
		return false
	var lato := -14.0 if _g().global_position.x < nodo.global_position.x else 14.0
	await _vai_a(nodo.global_position + Vector2(lato, 0.0), 5.0)
	if not is_instance_valid(nodo):
		return false   # morto per strada: la stanza è ricominciata
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
	return _nemici_vivi().filter(func(n: Nemico) -> bool: return n.global_position.x < Stanza.CRIPTA and not n.has_meta("sotterraneo"))


func _minaccia() -> Nemico:
	# Un nemico sveglio e vicino: alla stessa quota, oppure un pipistrello che vola qui attorno.
	var g := _g()
	for n: Nemico in _nemici_vivi():
		if n.stato in [Nemico.Stato.DORME, Nemico.Stato.RISVEGLIO] or _ignorato(n):
			continue
		var d := n.global_position - g.global_position
		if n.tipo == "pipistrello":
			if d.length() < 150.0 and _visibile(n):
				return n
		elif absf(d.x) < 110.0 and absf(d.y) < (60.0 if n.tipo in Nemico.SALTANO else 40.0) and _visibile(n):
			return n   # dietro un muro non è una minaccia
	return null


func _ignorato(n: Nemico) -> bool:
	return int(_ignorati.get(n.get_instance_id(), 0)) > Engine.get_physics_frames()


func _visibile(n: Nemico) -> bool:
	# Niente muri fra noi e lui.
	var g := _g()
	var raggio := PhysicsRayQueryParameters2D.create(g.global_position + Vector2(0, -22), n.centro(), Effetti.S_MONDO)
	return g.get_world_2d().direct_space_state.intersect_ray(raggio).is_empty()


func _pericolo(n: Nemico) -> String:
	# Il pericolo può arrivare anche da chi non si sta guardando (chi ti gira alle spalle).
	var mio := _pericolo_da(n)
	if mio != "":
		return mio
	for altro: Nemico in _nemici_vivi():
		if altro == n or altro.global_position.distance_to(_g().global_position) > 110.0:
			continue
		var suo := _pericolo_da(altro)
		if suo in ["colpo", "carica", "picchiata", "balzo"]:
			_pericolo_da_chi = altro
			return suo
	return ""


func _pericolo_da(n: Nemico) -> String:
	_pericolo_da_chi = n
	var g := _g()
	var d := n.global_position - g.global_position
	var t := float(n.get("_t_stato"))
	var tempi := n.tempi_attacco()
	var portata := 92.0 if n.tipo == "bestione" else 72.0
	if n.stato == Nemico.Stato.ATTACCO and not n.get("_in_balzo") and t < float(tempi[1]) - 0.06 \
			and absf(d.x) < portata and absf(d.y) < 40.0:
		return "colpo"
	if n.tipo in Nemico.SALTANO and n.stato == Nemico.Stato.ATTACCO and n.get("_in_balzo") and t < 0.5 and d.length() < 90.0:
		return "balzo"
	if n.tipo == "bestione" and n.get("_carica") and absf(d.x) < 110.0 and absf(d.y) < 40.0:
		return "carica"
	if n.tipo == "pipistrello" and n.get("_fase_volo") == "scende" and d.length() < 80.0:
		return "picchiata"
	# Si reagisce quando sta per arrivare (un rotolo protegge solo per un attimo).
	if _sfera_in_arrivo() != null:
		return "sfera"
	return ""


func _scegli_arma(n: Nemico) -> String:
	# La magia passa la corazza del bestione; per il resto prima le frecce (fanno più male), poi i dardi.
	var g := _g()
	if not _usa_tiri:
		return ""
	var ordine: Array = ["magia", "frecce", "dardi"] if n.tipo == "bestione" else ["frecce", "dardi", "magia"]
	for a: String in ordine:
		if g.puo_tirare(a):
			return a
	return ""


func _a_tiro(n: Nemico) -> int:
	# Da qui lo si prende? 0 = no, 1 = tiro dritto, 2 = tiro con su. Stessa geometria dell'aiuto alla
	# mira del giocatore (cono attorno alla direzione del tiro, portata, niente muri in mezzo).
	var g := _g()
	if not is_instance_valid(n) or not n.bersagliabile():
		return 0
	var v := 1 if n.global_position.x > g.global_position.x else -1
	var da := g.global_position + Vector2(v * 14.0, -22.0)
	var d := n.centro() - da
	if d.length() > Giocatore.MIRA_PORTATA - 10.0:
		return 0
	var raggio := PhysicsRayQueryParameters2D.create(da, n.centro(), Effetti.S_MONDO)
	if not g.get_world_2d().direct_space_state.intersect_ray(raggio).is_empty():
		return 0
	if absf(Vector2(v, 0.0).angle_to(d)) < Giocatore.MIRA_CONO - 0.05:
		return 1
	if absf(Vector2(v, -0.85).normalized().angle_to(d)) < Giocatore.MIRA_CONO - 0.05:
		return 2
	return 0


func _tira_contro(n: Nemico, arma: String) -> bool:
	# Sceglie l'arma (tasto "cambia_arma"), si gira verso il bersaglio e tira; con su se è in alto.
	var g := _g()
	if arma == "" or not g.puo_tirare(arma):
		return false
	for i in 3:
		if g.arma_distanza == arma:
			break
		await _tocca("cambia_arma")
	if g.arma_distanza != arma:
		return false
	_rilascia_tutto()
	if not is_instance_valid(n):
		return false
	await _guarda(1 if n.global_position.x > g.global_position.x else -1)
	var modo := _a_tiro(n)
	if modo == 0:
		return false
	if modo == 2:
		Input.action_press("su")
	# Ogni arma col suo attacco: l'arco sempre caricato (se c'è tempo), la magia caricata contro il
	# bestione o un gruppo, i dardi a raffica contro chi è piccolo e veloce.
	var vicini := _nemici_vivi().filter(func(m: Nemico) -> bool: return m.global_position.distance_to(n.global_position) < 50.0).size()
	var lontano := n.global_position.distance_to(g.global_position) > 110.0
	match arma:
		"frecce":
			if lontano:
				await _tieni_tiro(true, 60)
			else:
				await _tocca("tira")
		"magia":
			if g.energia >= g.costo_magia(true) and (n.tipo == "bestione" or vicini >= 2) and lontano:
				await _tieni_tiro(true, 50)
			else:
				await _tocca("tira")
		"dardi":
			if n.tipo in ["pipistrello", "saltatore", "mimic"]:
				await _tieni_tiro(false, 26)
			else:
				await _tocca("tira")
	if modo == 2:
		Input.action_release("su")
	if arma == "dardi" or g.stato == Giocatore.Stato.TIRO:
		await _fotogrammi(int(float(Giocatore.ARMI_DISTANZA[arma]["durata"]) * 60.0) + 2)
	return true


func _scegli_difesa(pericolo: String) -> String:
	# Come i nemici: prova le schivate, ricorda quali funzionano e usa più spesso quelle.
	# Contro sfere e frecce si salta, si colpisce o si rotola verso il colpo (rotolando via, arriva a fine rotolo).
	var opzioni: Array = ["salto", "colpisci", "rotolo_avanti"]
	if pericolo == "colpo":
		opzioni = ["scatto_indietro", "rotolo_indietro", "rotolo_avanti"]
	elif pericolo == "picchiata":
		opzioni = ["colpisci", "rotolo_avanti", "scatto_indietro"]   # il pipistrello muore con un colpo
	elif pericolo == "balzo":
		opzioni = ["rotolo_avanti", "salto", "rotolo_indietro"]   # un balzo arriva lontano: arretrando ti raggiunge
	elif pericolo == "carica":
		opzioni = ["rotolo_avanti", "salto"]   # una carica non si scansa arretrando: la si passa
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
		var origine := ""
		if n is Proiettile:
			var autore: Variant = (n as Proiettile).autore
			origine = " (%s di %s)" % [(n as Proiettile).tipo, (autore as Nemico).tipo if autore is Nemico and is_instance_valid(autore) else "trappola"]
		elif n is Nemico:
			origine = " (%s)" % (n as Nemico).tipo
		print("PROVA difesa: %s contro %s%s a %.0f px, stato %s, a terra %s" % [mossa, pericolo, origine,
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
	var t_tiro := 0
	var nascosto := 0
	# Contro lo stallo: se per otto secondi non cambia niente (nessuno si muove, nessuno si ferisce), si lascia.
	var inizio_ms := Engine.get_physics_frames()
	var istantanea := ""
	var ultimo_progresso := Engine.get_physics_frames()
	var bloccato := 0
	var vita_nemico := n.vita
	var vita_mia := _g().vita
	for i in massimo:
		if is_instance_valid(n) and (n.vita < vita_nemico or _g().vita < vita_mia):
			vita_nemico = n.vita
			vita_mia = _g().vita
			ultimo_progresso = Engine.get_physics_frames()
		elif Engine.get_physics_frames() - ultimo_progresso > 60 * 15:
			# Quindici secondi senza ferire né essere feriti: irraggiungibile, per ora lo si lascia stare.
			if is_instance_valid(n):
				_ignorati[n.get_instance_id()] = Engine.get_physics_frames() + 60 * 25
			Rapporto.conta("bot_rinunce")
			break
		if Engine.get_physics_frames() - inizio_ms >= 480:
			inizio_ms = Engine.get_physics_frames()
			var ora := "%s %d %d %s" % [str((_g().global_position / 8.0).round()), _g().vita,
					n.vita if is_instance_valid(n) else -1, str((n.global_position / 8.0).round()) if is_instance_valid(n) else ""]
			if ora == istantanea:
				Rapporto.conta("stalli_bot")
				if Dispositivo.in_prova:
					print("PROVA stallo contro %s" % (n.tipo if is_instance_valid(n) else "?"))
				break
			istantanea = ora
		if not is_instance_valid(n) or n.stato == Nemico.Stato.MORTO:
			break
		var g := _g()
		if g.stato == Giocatore.Stato.MORTO:
			break
		var d := n.global_position - g.global_position
		t_tiro -= 1
		if n.tipo == "pipistrello":
			# Chi vola dietro un muro non si insegue: si lascia perdere dopo un po'.
			nascosto = 0 if _visibile(n) else nascosto + 1
			if nascosto > 90:
				break
			if await _contro_pipistrello(n, t_tiro <= 0):
				t_tiro = 36
			continue
		if absf(d.y) > 40.0 and not (n.tipo in Nemico.SALTANO and absf(d.y) < 70.0):
			# È su un'altra quota (per esempio il mago sulla piattaforma): se è a tiro gli si tira,
			# altrimenti ci si arriva.
			_rilascia_tutto()
			var arma := _scegli_arma(n)
			if arma != "" and t_tiro <= 0 and n.stato != Nemico.Stato.DORME and _a_tiro(n) != 0:
				await _tira_contro(n, arma)
				t_tiro = 30
				continue
			if not gia_in_combattimento:
				var lato := -28.0 if d.x > 0.0 else 28.0
				var raggiunto := await _vai_a(n.global_position + Vector2(lato, 0.0), 24.0)
				if not raggiunto:
					await _fotogrammi(10)
				continue
			break   # combattimento dentro un altro: chi è su un'altra quota lo cercherà quello di fuori
		# Stessa quota ma superfici diverse (per esempio un muro in mezzo): ci si arriva col navigatore.
		if absf(d.x) > 60.0 and _pericolo(n) == "":
			var mia := _nav.superficie_di(g.global_position)
			var sua := _nav.superficie_di(n.global_position)
			if mia != "" and sua != "" and mia != sua:
				_rilascia_tutto()
				if gia_in_combattimento:
					break
				var lato := -28.0 if d.x > 0.0 else 28.0
				if not await _vai_a(n.global_position + Vector2(lato, 0.0), 24.0):
					await _fotogrammi(10)
				continue
		var pericolo := _pericolo(n)
		if pericolo != "":
			await _difenditi(_pericolo_da_chi if is_instance_valid(_pericolo_da_chi) else n, pericolo)
			continue
		var v := 1 if d.x > 0.0 else -1
		var avanti := "destra" if v > 0 else "sinistra"
		Input.action_release("sinistra" if v > 0 else "destra")
		# Legge il nemico: mentre carica un colpo non gli si va addosso; dopo il colpo è scoperto.
		var tempi := n.tempi_attacco()
		var carica := n.stato == Nemico.Stato.ATTACCO and (float(n.get("_t_stato")) < float(tempi[2]) or n.colpi_in_arrivo() > 0)
		var scoperto := (n.stato == Nemico.Stato.ATTACCO and float(n.get("_t_stato")) >= float(tempi[2]) and n.colpi_in_arrivo() == 0) \
				or n.stato == Nemico.Stato.COLPITO
		# Prudenza: con poca vita non si resta addosso a chi non è scoperto; da lontano si tira.
		if g.vita <= 2 and not scoperto and n.tipo in Nemico.CORPO_A_CORPO:
			if absf(d.x) > 90.0 and t_tiro <= 0 and _scegli_arma(n) != "" and _a_tiro(n) != 0:
				await _tira_contro(n, _scegli_arma(n))
				t_tiro = 30
				continue
			if absf(d.x) < 90.0:
				Input.action_release(avanti)
				Input.action_press("sinistra" if v > 0 else "destra")
				await _fotogrammi(8)
				Input.action_release("sinistra" if v > 0 else "destra")
				continue
		if n.sta_parando() and absf(d.x) < 70.0:
			# Para: non si colpisce lo scudo, si aspetta (o si gira attorno).
			Input.action_release(avanti)
			await _fotogrammi(4)
			continue
		# Il bestione para da davanti: magia da lontano, oppure gli si rotola alle spalle.
		# La prima volta si prova comunque un colpo di spada da davanti, per vedere che para.
		if n.tipo == "bestione" and not _armatura_provata and absf(d.x) < 80.0 and not n.esposto() \
				and n.stato != Nemico.Stato.ATTACCO:
			_armatura_provata = true
			for k in 30:   # un passo avanti, finché è a portata di spada (se attacca, si lascia stare)
				if not is_instance_valid(n) or n.stato == Nemico.Stato.ATTACCO \
						or absf(n.global_position.x - _g().global_position.x) < 36.0:
					break
				Input.action_press(avanti)
				await _fotogrammi(1)
			Input.action_release(avanti)
			if is_instance_valid(n) and n.stato != Nemico.Stato.ATTACCO:
				await _guarda(v)
				await _tocca("attacca")
				await _fotogrammi(16)
			else:
				_armatura_provata = false   # ci si riprova alla prossima occasione
			continue
		if n.tipo == "bestione" and not n.esposto() and signf(-d.x) == float(n.verso) and not carica:
			if t_tiro <= 0 and g.puo_tirare("magia") and absf(d.x) > 50.0:
				await _tira_contro(n, "magia")
				t_tiro = 40
				continue
			if absf(d.x) < 60.0:
				await _premi_insieme(avanti, "rotola")   # gli si passa attraverso
				Input.action_release(avanti)
				for k in 40:
					if _g().stato != Giocatore.Stato.ROTOLATA:
						break
					await _fotogrammi(1)
				if is_instance_valid(n) and signf(n.global_position.x - _g().global_position.x) == float(-v) \
						and n.verso == v:
					_alle_spalle += 1   # è passato dietro e il bestione guarda ancora dall'altra parte
					await _guarda(-v)
					await _tocca("attacca")
					await _fotogrammi(8)
					await _tocca("attacca")
					await _fotogrammi(10)
				continue
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
			# Spinge ma non avanza (qualcosa in mezzo): un salto; se non basta, da lontano; se no, si lascia stare.
			bloccato = bloccato + 1 if absf(_g().velocity.x) < 15.0 else 0
			if bloccato == 45:
				Input.action_press("salta")
				await _fotogrammi(14)
				Input.action_release("salta")
			elif bloccato >= 120:
				_rilascia_tutto()
				var arma := _scegli_arma(n)
				if arma != "" and _a_tiro(n) != 0:
					await _tira_contro(n, arma)
					bloccato = 46
				else:
					_ignorati[n.get_instance_id()] = Engine.get_physics_frames() + 60 * 20
					Rapporto.conta("bot_rinunce")
					break
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


func _contro_pipistrello(n: Nemico, puo_tirare: bool) -> bool:
	# Chi vola: si schiva la picchiata (o lo si colpisce mentre scende), quando è basso e vicino lo si
	# colpisce con la spada, altrimenti gli si tira (anche in alto, con su). Vero se ha tirato.
	var g := _g()
	if n.stato == Nemico.Stato.DORME and _a_tiro(n) == 0:
		# Appeso e addormentato: ci si va sotto (si sveglia) o finché non è a tiro.
		var posto := _sotto_o_sopra(n)
		if posto != Vector2.INF:
			var arrivato := await _vai_a(posto, 12.0)
			if Dispositivo.in_prova and not arrivato:
				print("PROVA pipistrello appeso: non arriva a %s da %s" % [str(posto), str(_g().global_position.round())])
		await _fotogrammi(10)
		return false
	var pericolo := _pericolo(n)
	if pericolo != "":
		await _difenditi(n, pericolo)
		return false
	var d := n.centro() - (g.global_position + Vector2(0, -22))
	var v := 1 if d.x > 0.0 else -1
	if absf(d.x) < 42.0 and absf(d.y) < 34.0:
		_rilascia_tutto()
		await _guarda(v)
		await _tocca("attacca")
		await _fotogrammi(8)
		return false
	if absf(d.x) < 56.0 and d.y < -30.0 and d.y > -100.0 and g.is_on_floor():
		# Poco sopra la testa: si salta e lo si colpisce in aria.
		_rilascia_tutto()
		await _guarda(v)
		Input.action_press("salta")
		await _fotogrammi(9)
		await _tocca("attacca")
		Input.action_release("salta")
		await _fotogrammi(16)
		return false
	var arma := _scegli_arma(n)
	if puo_tirare and arma != "" and _a_tiro(n) != 0:
		return await _tira_contro(n, arma)
	# Troppo sopra la testa per prenderlo: ci si allontana un po'; altrimenti si aspetta che scenda.
	_rilascia_tutto()
	if arma != "" and d.y < -20.0 and absf(Vector2(v, 0.0).angle_to(d)) > 1.2:
		Input.action_press("destra" if v < 0 else "sinistra")
	await _fotogrammi(4)
	_rilascia_tutto()
	return false


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
	if _in_partita:
		return   # gli obiettivi della partita libera restano tutti nella fase "partita"
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
	# Le ondate restano ferme finché il bot prova enigmi e meccanismi; le affronta nella sua fase.
	if in_corso and is_instance_valid(_principale.stanza) and _principale.stanza.ondate_attive != _ondate_permesse:
		_principale.stanza.ondate_attive = _ondate_permesse
	if _in_partita and is_instance_valid(_principale.stanza):
		var qui := _g().global_position
		if Engine.get_process_frames() % 10 == 0:
			var sotto := _nav.superficie_di(qui)
			if sotto != "" and _g().is_on_floor():
				_visitate[sotto] = true   # ogni zona dove passa, non solo dove decide
		if qui.distance_to(_ultimo_posto) > 16.0 or _obiettivo_ora == "aspetta" or get_tree().paused:
			_ultimo_posto = qui
			_t_fermo = 0.0
		else:
			_t_fermo += delta
			_stallo_massimo = maxf(_stallo_massimo, _t_fermo)
			if int(_t_fermo * 60.0) == 20 * 60:
				# Fermo da 20 secondi: lo si annota (dove, mentre faceva cosa) per capire e correggere.
				_fermate.append({"obiettivo": _obiettivo_ora, "x": roundi(qui.x), "y": roundi(qui.y)})
				if Dispositivo.in_prova:
					print("PROVA fermo da 20 s: %s a %s, %s" % [_obiettivo_ora, str(qui.round()), Giocatore.Stato.keys()[_g().stato]])
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

	# Prima le prove tecniche, a nemici fermi (tregua): comandi, menu, armi, qualità. Poi la partita libera,
	# in una stanza nuova, dove il bot decide da solo cosa fare. Alla fine le prestazioni.
	_tregua(true)
	var tecniche: Array[Callable] = [_movimento, _oggetti, _tasti_a_schermo, _qualita, _menu_e_aspetto, _mosse_in_partita,
			_ambiente, _sotterraneo, _bottino, _armi_da_mischia, _armi_a_distanza]
	for fase: Callable in tecniche:
		if solo_fasi.is_empty() or solo_fasi.has(fase.get_method().trim_prefix("_")):
			await fase.call()
	_tregua(false)
	if solo_fasi.is_empty() or solo_fasi.has("partita"):
		await _partita()
	if solo_fasi.is_empty() or solo_fasi.has("prestazioni"):
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
	var arma_prima := _g().arma_distanza
	var tasto_arma: Vector2 = _principale.hud.centro_tasto("cambia_arma")
	_tocco_schermo(1, tasto_arma, true)
	await _fotogrammi(3)
	_tocco_schermo(1, tasto_arma, false)
	await _fotogrammi(3)
	var tiri := Rapporto.contatore("tiri")
	var tasto_tiro: Vector2 = _principale.hud.centro_tasto("tira")
	_tocco_schermo(1, tasto_tiro, true)
	await _fotogrammi(3)
	_tocco_schermo(1, tasto_tiro, false)
	await _fotogrammi(40)
	_verifica("i tasti Arma e Tira a schermo cambiano arma e tirano", _g().arma_distanza != arma_prima
			and Rapporto.contatore("tiri") == tiri + 1, "%s -> %s, tiri %d" % [arma_prima, _g().arma_distanza, Rapporto.contatore("tiri") - tiri])
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
	menu.mostra_scheda("aspetto")   # come chi gioca: tasto "Aspetto e mosse"
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
		if azione in ["colpo_rotante", "saluto", "attacco1", "arrampica", "appeso", "nuota", "galleggia"]:
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
	await _menu_impostazioni(menu)
	_principale._alterna_pausa()
	await _fotogrammi(5)
	_verifica("ripresa dal menu", not _principale.menu.aperto and not get_tree().paused)


func _menu_impostazioni(menu: Menu) -> void:
	# Le cinque schede delle impostazioni, usate come le userebbe chi gioca (linguette, voci, cursori).
	_nuova_fase("menu_impostazioni")
	var minimi := {"gioco": 14, "schermo": 12, "grafica": 14, "audio": 10, "accessibilita": 10}
	for coppia: Array in Menu.SCHEDE:
		var nome: String = coppia[0]
		(menu.get("_linguette")[nome] as Button).pressed.emit()
		await _fotogrammi_in_pausa(2)
		_verifica("menu: scheda %s aperta dalla linguetta" % nome, menu.pagina_visibile(nome) and menu.scheda == nome)
		_verifica("menu: scheda %s con i suoi controlli" % nome, menu.controlli_scheda(nome) >= int(minimi[nome]), str(menu.controlli_scheda(nome)))
		await _scatta("menu_" + nome)
	var vista: TextureRect = _principale.get("_vista")
	var mondo: SubViewport = _principale.mondo
	# Schermo: le grandezze del mondo vengono dal dispositivo; "Sempre 360 righe" cambia la tela.
	menu.mostra_scheda("schermo")
	_verifica("schermo: grandezze proposte dal dispositivo", menu.opzioni_di("schermo/scala").size() >= 2, str(menu.opzioni_di("schermo/scala")))
	_verifica("schermo: limiti FPS proposti", menu.opzioni_di("grafica/limite_fps").size() >= 3, str(menu.opzioni_di("grafica/limite_fps")))
	_verifica("schermo: descrizione dello schermo", menu.testo_info("schermo").contains("Mondo di gioco"), menu.testo_info("schermo"))
	_verifica("gioco: descrizione del dispositivo", menu.testo_info("dispositivo").contains("Processore"), menu.testo_info("dispositivo"))
	if Dispositivo.plugin != null:
		# Sul telefono il plugin deve aver letto memoria, processore e stato dell'energia.
		_verifica("dispositivo: il plugin legge memoria, processore ed energia", int(Dispositivo.info.get("ram_mb", -1)) > 0
				and String(Dispositivo.info.get("processore", "")) != "" and Dispositivo.risparmio_energetico >= 0,
				"%s, %s MB, risparmio %d" % [Dispositivo.info.get("processore", ""), Dispositivo.info.get("ram_mb", -1), Dispositivo.risparmio_energetico])
	menu.scegli("schermo/adatta", "riempi")
	await _fotogrammi_in_pausa(2)
	var tela: Vector2i = mondo.size_2d_override if mondo.size_2d_override != Vector2i.ZERO else mondo.size
	var finestra := get_window().size
	_verifica("schermo: sempre 360 righe", absi(tela.y - Dispositivo.ALTEZZA_BASE) <= 1 or finestra.y < 300, str(tela))
	menu.scegli("schermo/adatta", "intera")
	menu.scegli("schermo/luminosita", 1.3)
	await _fotogrammi_in_pausa(2)
	_verifica("schermo: luminosità sull'immagine", vista.material != null)
	menu.scegli("schermo/luminosita", 1.0)
	# Grafica: risoluzione interna al 50% con SGSR, livello, dettaglio a mano, ripristino.
	menu.mostra_scheda("grafica")
	await _fotogrammi_in_pausa(1)
	var prima: Vector2i = mondo.size
	menu.scegli("grafica/risoluzione", 0.5)
	menu.scegli("grafica/filtro", "sgsr")
	await _fotogrammi_in_pausa(3)
	_verifica("grafica: risoluzione interna al 50%", mondo.size.y <= prima.y / 2 + 1 and mondo.size_2d_override == prima,
			"%s -> %s (%s)" % [prima, mondo.size, mondo.size_2d_override])
	var filtro_vista: int = int((vista.material as ShaderMaterial).get_shader_parameter("filtro")) if vista.material != null else -1
	_verifica("grafica: filtro SGSR sull'immagine", filtro_vista == 2, str(filtro_vista))
	await _scatta("grafica_sgsr_50")
	menu.scegli("grafica/qualita", "bassa")
	await _fotogrammi_in_pausa(2)
	_verifica("grafica: livello basso dal menu", Dispositivo.livello == "bassa" and not bool(Dispositivo.profilo.get("nebbia")))
	menu.scegli("grafica/nebbia", 1)
	await _fotogrammi_in_pausa(2)
	_verifica("grafica: il dettaglio scelto a mano vince sul livello", bool(Dispositivo.profilo.get("nebbia")) and Impostazioni.personalizzata())
	Impostazioni.ripristina_scheda("grafica")
	await _fotogrammi_in_pausa(2)
	_verifica("grafica: ripristino dei valori consigliati", mondo.size == prima and vista.material == null and not Impostazioni.personalizzata())
	Impostazioni.scrivi("grafica/qualita", "alta")   # come all'inizio del bot (misure confrontabili)
	# Audio: volumi sui canali, mono, ripristino.
	menu.mostra_scheda("audio")
	var musica := AudioServer.get_bus_index(&"Musica")
	var master := AudioServer.get_bus_index(&"Master")
	menu.scegli("audio/musica", 0.0)
	menu.scegli("audio/mono", true)
	await _fotogrammi_in_pausa(1)
	_verifica("audio: musica a zero = canale muto", AudioServer.is_bus_mute(musica))
	_verifica("audio: mono acceso", AudioServer.is_bus_effect_enabled(master, 2))
	_verifica("audio: dice dove esce il suono", menu.testo_info("audio").contains("Il suono esce da"), menu.testo_info("audio"))
	Impostazioni.ripristina_scheda("audio")
	await _fotogrammi_in_pausa(1)
	_verifica("audio: ripristino", not AudioServer.is_bus_mute(musica) and not AudioServer.is_bus_effect_enabled(master, 2))
	# Accessibilità: didascalie dei suoni e correzione dei colori.
	menu.mostra_scheda("accessibilita")
	menu.scegli("acc/didascalie", true)
	Suoni.suona("ondata")
	await _fotogrammi_in_pausa(2)
	_verifica("accessibilità: didascalia del suono", _principale.hud.didascalie_visibili() > 0)
	menu.scegli("acc/daltonismo", "deuteranopia")
	menu.scegli("acc/contorni", true)
	await _fotogrammi_in_pausa(2)
	var dalto: int = int((vista.material as ShaderMaterial).get_shader_parameter("daltonismo")) if vista.material != null else -1
	_verifica("accessibilità: correzione per il daltonismo", dalto == 2, str(dalto))
	await _scatta("accessibilita_colori")
	Impostazioni.ripristina_scheda("accessibilita")
	await _fotogrammi_in_pausa(1)
	_verifica("accessibilità: ripristino", vista.material == null and not Impostazioni.leggi("acc/contorni"))
	# Con un controller RB passa alla scheda dopo.
	menu.mostra_scheda("gioco")
	var tasto := InputEventAction.new()
	tasto.action = &"tira"
	tasto.pressed = true
	Input.parse_input_event(tasto)
	await _fotogrammi_in_pausa(2)
	var lascia := InputEventAction.new()
	lascia.action = &"tira"
	lascia.pressed = false
	Input.parse_input_event(lascia)
	await _fotogrammi_in_pausa(1)
	_verifica("menu: RB passa alla scheda dopo", menu.scheda == "schermo", menu.scheda)
	_verifica("aggiornamenti: pulsante nel menu", (menu.get("_aggiorna") as Button).text != "")


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


# ------------------------------------------------------------------ sotterraneo (0.1.18)

func _sotterraneo() -> void:
	# Il sotterraneo come lo scoprirebbe chi gioca: muro crepato, stanzetta, pozzo, assi e fossa, cunicolo
	# col forziere, ripiano coi dardi, la vasca sotto l'arco (respiro), la risalita con una sosta sulla
	# mensola (stamina) fino all'alcova, giù dalla botola, di nuovo a nuoto, oltre la fossa e su per il pozzo.
	_nuova_fase("sotterraneo")
	_principale.ricomincia_stanza()
	await _fotogrammi(30)
	_tregua(true)
	var stanza_fase: Node = _principale.stanza
	var stanza: Stanza = _principale.stanza
	var muro := _m("muro_ripiano") as Struttura
	var rotto := await _rompi_struttura(muro)
	if _interrotta(stanza_fase):
		return
	_verifica("sotterraneo: il muro crepato si rompe a colpi", rotto and not muro.integra)
	await _vai_a(Vector2(168, Stanza.PAVIMENTO), 6.0)
	if _interrotta(stanza_fase):
		return
	_verifica("sotterraneo: dietro il muro c'è la stanza segreta", _nav.superficie_di(_g().global_position) == "stanza_segreta",
			str(_g().global_position.round()))
	await _scatta("stanza_segreta")
	await _vai_a(Vector2(220, Stanza.PAVIMENTO_SOTTO), 8.0)
	if _interrotta(stanza_fase):
		return
	_verifica("sotterraneo: giù per il pozzo", _nav.superficie_di(_g().global_position) == "camera_ovest" and stanza.sotto_terra,
			str(_g().global_position.round()))
	# Assi di legno: rotte scoprono la fossa; dalla fossa si rotola nel cunicolo fino allo stanzino.
	var assi := _m("assi") as Struttura
	rotto = await _rompi_struttura(assi)
	if _interrotta(stanza_fase):
		return
	_verifica("sotterraneo: le assi si rompono e scoprono la fossa", rotto and not assi.integra)
	var forziere := _m("forziere_sotto") as Forziere
	var rotoli := int(_passaggi.get("rotola", 0))
	var a_portata := await _usa(forziere)
	if _interrotta(stanza_fase):
		return
	_verifica("sotterraneo: dalla fossa si rotola nel cunicolo fino allo stanzino", int(_passaggi.get("rotola", 0)) > rotoli
			and _nav.superficie_di(_g().global_position) == "stanzino", str(_g().global_position.round()))
	_verifica("sotterraneo: il forziere dello stanzino si apre", a_portata and forziere.aperto, str(forziere.contenuto))
	await _scatta("stanzino")
	# Ripiano di legno coi dardi: un tiro verso l'alto lo rompe e i dardi cadono.
	var ripiano := _m("ripiano_legno") as Struttura
	rotto = await _rompi_struttura(ripiano, "dardi")   # coi dardi: dopo c'è posto per quelli che cadono
	if _interrotta(stanza_fase):
		return
	_verifica("sotterraneo: un tiro verso l'alto rompe il ripiano di legno", rotto and not ripiano.integra)
	await _fotogrammi(30)
	var dardi: int = _g().munizioni["dardi"]
	await _cammina_verso(492.0, 4.0, 120)
	await _fotogrammi(20)
	_verifica("sotterraneo: i dardi del ripiano cadono e si raccolgono", int(_g().munizioni["dardi"]) > dardi,
			"dardi %d -> %d" % [dardi, _g().munizioni["dardi"]])
	# La vasca: sotto l'arco si passa solo sott'acqua, col respiro che cala.
	_respiro_minimo = Giocatore.RESPIRO_MASSIMO
	var vita := _g().vita
	var nuotate := int(_passaggi.get("nuota", 0))
	await _vai_a(Vector2(1150, Stanza.PAVIMENTO_SOTTO), 8.0)
	if _interrotta(stanza_fase):
		return
	_verifica("sotterraneo: a nuoto sotto l'arco fino alla camera est", int(_passaggi.get("nuota", 0)) > nuotate
			and _nav.superficie_di(_g().global_position) == "camera_est", str(_g().global_position.round()))
	_verifica("sotterraneo: sott'acqua il respiro cala, ma basta", _respiro_minimo < Giocatore.RESPIRO_MASSIMO - 10.0
			and _g().vita >= vita, "respiro minimo %.0f, vita %d -> %d" % [_respiro_minimo, vita, _g().vita])
	# Su per il pilastro fino all'alcova: la stamina non basta tutta d'un fiato, si sosta sulla mensola.
	var riposi := _riposi_mensola
	var prese_perse := Rapporto.contatore("prese_perse")
	await _vai_a(Vector2(1262, Stanza.PAVIMENTO), 6.0)
	if _interrotta(stanza_fase):
		return
	_verifica("sotterraneo: si risale il pilastro fino all'alcova", _nav.superficie_di(_g().global_position) == "alcova"
			and not stanza.sotto_terra, str(_g().global_position.round()))
	_verifica("sotterraneo: a metà salita si riprende fiato sulla mensola", _riposi_mensola > riposi
			and Rapporto.contatore("prese_perse") == prese_perse,
			"soste %d, prese perse %d" % [_riposi_mensola - riposi, Rapporto.contatore("prese_perse") - prese_perse])
	await _scatta("alcova_dal_sotterraneo")
	# Giù dalla botola, di nuovo a nuoto, oltre la fossa con un salto e su per il pozzo.
	await _vai_a(Vector2(1180, Stanza.PAVIMENTO_SOTTO), 8.0)
	if _interrotta(stanza_fase):
		return
	_verifica("sotterraneo: dalla botola dell'alcova si torna giù", _nav.superficie_di(_g().global_position) == "camera_est",
			str(_g().global_position.round()))
	await _vai_a(Vector2(470, Stanza.PAVIMENTO_SOTTO), 8.0)
	if _interrotta(stanza_fase):
		return
	var salti := int(_passaggi.get("salto", 0))
	await _vai_a(Vector2(200, Stanza.PAVIMENTO_SOTTO), 8.0)
	if _interrotta(stanza_fase):
		return
	_verifica("sotterraneo: di nuovo a nuoto e oltre la fossa con un salto", _nav.superficie_di(_g().global_position) == "camera_ovest"
			and int(_passaggi.get("salto", 0)) > salti, "%s, passaggi %s" % [str(_g().global_position.round()), str(_passaggi)])
	riposi = _riposi_mensola
	await _vai_a(Vector2(168, Stanza.PAVIMENTO), 6.0)
	if _interrotta(stanza_fase):
		return
	_verifica("sotterraneo: su per il pozzo fino alla stanza segreta", _nav.superficie_di(_g().global_position) == "stanza_segreta"
			and _riposi_mensola > riposi, "%s, soste %d" % [str(_g().global_position.round()), _riposi_mensola - riposi])
	await _vai_a(Vector2(400, Stanza.PAVIMENTO), 8.0)
	_verifica("sotterraneo: la telecamera torna in superficie", not stanza.sotto_terra
			and _nav.superficie_di(_g().global_position) == "pavimento", str(_g().global_position.round()))
	_principale.ricomincia_stanza()
	await _fotogrammi(30)
	_tregua(true)


func _rompi_struttura(s: Struttura, arma_tiro: String = "magia") -> bool:
	# Un muro crepato o delle assi: accanto, a colpi. Un ripiano in alto: sotto, con un tiro verso l'alto.
	if not is_instance_valid(s) or not s.integra:
		return false
	var c := s.centro()
	var lato := 1.0 if _g().global_position.x > c.x else -1.0
	var in_alto := false
	var posto := Vector2(c.x + lato * (s.misura.x * 0.5 + 16.0), s.global_position.y + s.misura.y)   # muro: accanto, a terra
	if s.misura.x > s.misura.y:
		posto = Vector2(c.x + lato * (s.misura.x * 0.5 + 14.0), s.global_position.y)   # assi: di fianco, alla stessa quota
		var sotto := _nav.superficie_per(posto)
		if sotto == "" or absf(float(_nav.superfici[sotto]["y"]) - posto.y) > 6.0:
			in_alto = true
			sotto = _nav.superficie_per(Vector2(c.x - 22.0, s.global_position.y + 12.0))
			if sotto == "":
				return false
			posto = Vector2(c.x - 22.0, float(_nav.superfici[sotto]["y"]))
	await _vai_a(posto, 4.0)
	if not is_instance_valid(s):
		return false
	if in_alto:
		await _scegli_arma_col_tasto(arma_tiro)
	else:
		await _guarda(1 if c.x > _g().global_position.x else -1)
	for i in 8:
		if not s.integra or _g().stato == Giocatore.Stato.MORTO:
			break
		if in_alto:
			Input.action_press("su")
			await _tocca("tira")
			await _fotogrammi(30)
			Input.action_release("su")
			await _fotogrammi(10)
		else:
			await _tocca("attacca")
			await _fotogrammi(24)
	await _fotogrammi(6)
	if is_instance_valid(s) and not s.integra:
		Rapporto.conta("bot_strutture_rotte")
	return is_instance_valid(s) and not s.integra


# ------------------------------------------------------------------ bottino (0.1.19)

func _bottino() -> void:
	# Forzieri con oggetti a caso, pozioni che saltano fuori e si raccolgono, un mimic da battere che
	# lascia pozioni migliori. Il bottino dei nemici forti secondo l'arma lo prova test/prova.gd (a caso).
	_nuova_fase("bottino")
	_principale.ricomincia_stanza()
	await _fotogrammi(30)
	_tregua(true)
	var stanza_fase: Node = _principale.stanza
	var cripta := _m("forziere_cripta") as Forziere
	var galleria := _m("forziere_galleria") as Forziere
	cripta.mimic = false   # prova a colpo sicuro: uno vero e uno che morde
	galleria.mimic = true
	var bevute := Rapporto.contatore("pozioni_bevute")
	var a_portata := await _usa(cripta)
	if _interrotta(stanza_fase):
		return
	await _fotogrammi(40)
	var pozioni: Array = cripta.contenuto.get("pozioni", [])
	_verifica("bottino: il forziere a caso si apre e dà oggetti a caso", a_portata and cripta.aperto and not pozioni.is_empty()
			and not cripta.contenuto.has("frammento"), str(cripta.contenuto))
	await _scatta("forziere_pozioni")
	await _raccogli_vicini(cripta.global_position, 160.0)
	if _interrotta(stanza_fase):
		return
	_verifica("bottino: le pozioni saltate fuori si raccolgono", Rapporto.contatore("pozioni_bevute") >= bevute + pozioni.size(),
			"bevute %d su %d" % [Rapporto.contatore("pozioni_bevute") - bevute, pozioni.size()])
	_verifica("bottino: in alto si vedono le pozioni in corso", _principale.hud.pozioni_visibili() > 0 or _g().effetti.is_empty() == false,
			str(_g().effetti))
	# Il mimic: aperto, si sveglia e morde.
	var svegliati := Rapporto.contatore("mimic_svegliati")
	await _usa(galleria)
	if _interrotta(stanza_fase):
		return
	await _fotogrammi(50)
	var mimic: Nemico = null
	for n: Nemico in _nemici_vivi("mimic"):
		mimic = n
	_verifica("bottino: un forziere era un mimic e si sveglia", mimic != null and Rapporto.contatore("mimic_svegliati") == svegliati + 1
			and not galleria.visible)
	await _scatta("mimic")
	if mimic == null:
		return
	await _affronta(mimic)
	for i in 6:
		if not is_instance_valid(mimic) or mimic.stato == Nemico.Stato.MORTO or _g().stato == Giocatore.Stato.MORTO:
			break
		await _affronta(mimic)
	if _interrotta(stanza_fase):
		return
	var battuto := is_instance_valid(mimic) and mimic.stato == Nemico.Stato.MORTO
	var lasciato: Array = mimic.bottino_lasciato if is_instance_valid(mimic) else []
	var migliori := lasciato.filter(func(v: Dictionary) -> bool: return v["cosa"] == "pozione" and v["taglia"] in ["media", "grande"])
	_verifica("bottino: il mimic si batte", battuto, "vita %d" % (mimic.vita if is_instance_valid(mimic) else -1))
	_verifica("bottino: il mimic lascia pozioni migliori", migliori.size() >= 2, str(lasciato))
	bevute = Rapporto.contatore("pozioni_bevute")
	var punto := mimic.global_position if is_instance_valid(mimic) else _g().global_position
	await _fotogrammi(30)
	await _raccogli_vicini(punto, 200.0)
	if _interrotta(stanza_fase):
		return
	_verifica("bottino: le pozioni del mimic si raccolgono", Rapporto.contatore("pozioni_bevute") >= bevute + migliori.size(),
			"bevute %d" % (Rapporto.contatore("pozioni_bevute") - bevute))
	await _scatta("pozioni_in_corso")
	_principale.ricomincia_stanza()
	await _fotogrammi(30)
	_tregua(true)


func _raccogli_vicini(punto: Vector2, raggio: float) -> void:
	# Passa sopra a pozioni e munizioni attorno a un punto, dalla più vicina.
	for giro in 8:
		await _fotogrammi(10)   # quelle appena uscite devono prima atterrare
		var vicini := get_tree().get_nodes_in_group("raccoglibili").filter(func(r: Node) -> bool:
			return is_instance_valid(r) and (r as Node2D).global_position.distance_to(punto) < raggio \
					and (r as Raccoglibile).lancio == Vector2.ZERO)
		if vicini.is_empty():
			return
		vicini.sort_custom(func(a: Node, b: Node) -> bool:
			return (a as Node2D).global_position.distance_to(_g().global_position) < (b as Node2D).global_position.distance_to(_g().global_position))
		var r := vicini[0] as Raccoglibile
		if r.cosa != "pozione" and int(_g().munizioni.get(r.cosa, 0)) >= int(Giocatore.MUNIZIONI_MASSIME.get(r.cosa, 99)):
			return   # munizioni già piene: restano lì
		await _vai_a(r.global_position, 3.0)


# ------------------------------------------------------------------ armi a distanza e nemici nuovi

func _scegli_arma_col_tasto(arma: String) -> bool:
	for i in Giocatore.ORDINE_ARMI.size():
		if _g().arma_distanza == arma:
			return true
		await _tocca("cambia_arma")
		await _fotogrammi(3)
	return _g().arma_distanza == arma


func _ultimo_tiro(tipo: String) -> Proiettile:
	for t: Node in get_tree().get_nodes_in_group("tiri_eroe"):
		if (t as Proiettile).tipo == tipo:
			return t as Proiettile
	return null


func _armi_da_mischia() -> void:
	# Ogni arma da mischia ha la sua combinazione: il bot le prova tutte (numero di colpi, danno dell'ultimo),
	# poi la seconda arma (un colpo in più) e lo scudo (Schiva da fermo = parata). Alla fine torna alla spada.
	_nuova_fase("armi_da_mischia")
	await _vai_a(Vector2(560, Stanza.PAVIMENTO), 8.0)
	var prove := {"spada_viandante": "mano_vuota", "ascia": "mano_vuota", "pugnale": "mano_vuota", "spadone": "mano_vuota",
			"bipenne": "mano_vuota", "bastone": "mano_vuota", "bacchetta": "mano_vuota", "mani_nude": "mano_vuota",
			"lama_sepolti": "seconda_spada"}
	var esiti := {}
	var giuste := 0
	for arma: String in prove:
		Equipaggiamento.indossa("arma", arma)
		Equipaggiamento.indossa("mano_sinistra", prove[arma])
		await _fotogrammi(8)
		await _guarda(1 if _g().global_position.x < 700.0 else -1)
		var attesi: Array = Armi.colpi(Armi.famiglia(arma), prove[arma])
		var inizio := Rapporto.contatore("attacchi")
		var danno_ultimo := -1
		var fotogrammi := 0
		await _tocca("attacca")
		while Rapporto.contatore("attacchi") - inizio < attesi.size() and fotogrammi < 300:
			await _fotogrammi(3)
			await _tocca("attacca")
			fotogrammi += 6
		for i in 90:
			if _g().stato != Giocatore.Stato.ATTACCO:
				break
			if not _g().colpo_attuale().is_empty():
				danno_ultimo = int(_g().colpo_attuale()["d"])
			await _fotogrammi(1)
		var fatti := Rapporto.contatore("attacchi") - inizio
		esiti[arma] = "%d/%d colpi, ultimo %d" % [fatti, attesi.size(), danno_ultimo]
		if fatti == attesi.size() and danno_ultimo == int((attesi[-1] as Dictionary)["d"]):
			giuste += 1
		await _fotogrammi(10)
	_verifica("ogni arma da mischia ha la sua combinazione", giuste == prove.size(), str(esiti))
	# Scudo: Schiva da fermo alza lo scudo.
	Equipaggiamento.indossa("arma", "spada_viandante")
	Equipaggiamento.indossa("mano_sinistra", "scudo_tondo")
	await _fotogrammi(20)
	_rilascia_tutto()
	await _tocca("schiva")
	await _fotogrammi(2)
	var parata := _g().stato == Giocatore.Stato.PARATA
	await _scatta("parata")
	await _fotogrammi(40)
	_verifica("con lo scudo Schiva da fermo para", parata, Giocatore.Stato.keys()[_g().stato])
	Equipaggiamento.indossa("mano_sinistra", "mano_vuota")
	await _fotogrammi(10)


func _tieni_tiro(fino_alla_carica: bool, massimo: int = 90) -> void:
	# Tiene premuto Tira: fino a carica piena (arco, magia) o per un po' (raffica), poi lascia.
	Input.action_press("tira")
	await _fotogrammi(3)
	for i in massimo:
		if fino_alla_carica and _g().carica_tiro() >= 1.0:
			break
		if _g().stato != Giocatore.Stato.TIRO:
			break
		await _fotogrammi(1)
	Input.action_release("tira")
	await _fotogrammi(int(float(Giocatore.ARMI_DISTANZA[_g().arma_distanza]["durata"]) * 60.0) + 4)


func _armi_a_distanza() -> void:
	# Magia, dardi e frecce: il tasto Arma le scorre e l'indicatore segue; ogni tiro consuma energia
	# o munizioni; una freccia rompe un barile da lontano; con su si tira in alto; l'energia torna da sola;
	# finite le frecce il tiro va a vuoto (le ridà il forziere dell'alcova, poi).
	_nuova_fase("armi_a_distanza")
	await _vai_a(Vector2(600, Stanza.PAVIMENTO), 8.0)
	var hud: Node = _principale.hud
	var viste := {}
	for i in Giocatore.ORDINE_ARMI.size():
		var nome: String = Giocatore.ARMI_DISTANZA[_g().arma_distanza]["nome"]
		if String(hud.testo_armi()).contains("[" + nome):
			viste[_g().arma_distanza] = true
		await _tocca("cambia_arma")
		await _fotogrammi(4)
	_verifica("il tasto Arma scorre le tre armi e l'indicatore mostra quella scelta", viste.size() == Giocatore.ORDINE_ARMI.size(),
			"%s — %s" % [str(viste.keys()), hud.testo_armi()])

	# Una freccia rompe un barile da lontano.
	var barile: Rompibile = null
	for b: Node in get_tree().get_nodes_in_group("rompibili"):
		var r := b as Rompibile
		if is_instance_valid(r) and _nav.superficie_di(r.global_position) == "pavimento" \
				and (barile == null or r.global_position.x > barile.global_position.x):
			barile = r
	var dal_ripiano := false
	if barile == null:
		# Rotti tutti quelli a terra: ci sono quelli sul ripiano, si tira dal suo bordo.
		for b: Node in get_tree().get_nodes_in_group("rompibili"):
			if is_instance_valid(b) and _nav.superficie_di((b as Node2D).global_position) == "ripiano":
				barile = b as Rompibile
				dal_ripiano = true
	if barile == null:
		_verifica("c'è un barile per provare i tiri", false)
	else:
		if dal_ripiano:
			await _vai_a(Vector2(196.0, 392.0), 4.0)
		else:
			await _vai_a(Vector2(barile.global_position.x + 84.0, Stanza.PAVIMENTO), 4.0)
		await _scegli_arma_col_tasto("frecce")
		await _guarda(-1)
		var rotti := Rapporto.contatore("oggetti_rotti")
		var frecce: int = _g().munizioni["frecce"]
		var cariche := Rapporto.contatore("tiri_carichi")
		var pronta := _g().puo_tirare("frecce")
		await _tieni_tiro(true)   # l'arco si carica tenendo premuto
		await _fotogrammi(4)
		await _scatta("tiro_freccia")
		await _fotogrammi(30)
		_verifica("una freccia caricata rompe un barile da lontano", pronta and Rapporto.contatore("oggetti_rotti") > rotti
				and int(_g().munizioni["frecce"]) == frecce - 1 and Rapporto.contatore("tiri_carichi") == cariche + 1,
				"frecce %d -> %d, rotti %d, cariche %d" % [frecce, _g().munizioni["frecce"], Rapporto.contatore("oggetti_rotti") - rotti,
				Rapporto.contatore("tiri_carichi") - cariche])

	# Dardi: veloci, uno alla volta; con su si tira in alto.
	await _scegli_arma_col_tasto("dardi")
	var dardi: int = _g().munizioni["dardi"]
	Input.action_press("su")
	await _tocca("tira")
	await _fotogrammi(9)
	Input.action_release("su")
	var dardo := _ultimo_tiro("dardo")
	var in_alto := dardo != null and dardo.velocita.y < -100.0
	await _fotogrammi(20)
	_verifica("con su il dardo parte verso l'alto", in_alto and int(_g().munizioni["dardi"]) == dardi - 1,
			"dardi %d -> %d, velocità %s" % [dardi, _g().munizioni["dardi"], "nessun dardo" if dardo == null else str(dardo.velocita.round())])
	# Tenendo premuto parte una raffica.
	dardi = _g().munizioni["dardi"]
	var in_raffica := Rapporto.contatore("dardi_in_raffica")
	Input.action_press("tira")
	await _fotogrammi(46)
	Input.action_release("tira")
	await _fotogrammi(24)
	_verifica("tenendo premuto i dardi partono a raffica", Rapporto.contatore("dardi_in_raffica") >= in_raffica + 2
			and int(_g().munizioni["dardi"]) <= dardi - 3, "dardi %d -> %d" % [dardi, _g().munizioni["dardi"]])

	# Magia: consuma energia, che torna da sola.
	await _scegli_arma_col_tasto("magia")
	for i in 400:
		if _g().energia >= Giocatore.ENERGIA_MASSIMA:
			break
		await _fotogrammi(1)
	var energia := _g().energia
	await _guarda(1)
	await _tocca("tira")
	await _fotogrammi(16)
	var sfera_partita := _ultimo_tiro("magia_eroe") != null
	await _scatta("tiro_magia")
	var dopo := _g().energia
	await _fotogrammi(150)
	_verifica("la magia consuma energia, che poi torna", sfera_partita and dopo < energia - _g().costo_magia() + 8.0
			and _g().energia > dopo + 20.0, "energia %.0f -> %.0f -> %.0f" % [energia, dopo, _g().energia])
	# Caricata, la sfera è più grande ed esplode.
	for i in 400:
		if _g().energia >= _g().costo_magia(true) + 4.0:
			break
		await _fotogrammi(1)
	energia = _g().energia
	var esplosioni := Rapporto.contatore("esplosioni")
	await _tieni_tiro(true)
	dopo = _g().energia
	for i in 140:
		if Rapporto.contatore("esplosioni") > esplosioni:
			break
		await _fotogrammi(1)
	_verifica("la magia caricata costa di più ed esplode", dopo < energia - _g().costo_magia(true) + 8.0
			and Rapporto.contatore("esplosioni") > esplosioni, "energia %.0f -> %.0f" % [energia, dopo])

	# Finite le frecce, il tiro va a vuoto e l'indicatore lo segnala.
	await _scegli_arma_col_tasto("frecce")
	for i in 12:
		if not _g().puo_tirare("frecce"):
			break
		await _tocca("tira")
		await _fotogrammi(int(Giocatore.ARMI_DISTANZA["frecce"]["durata"] * 60.0) + 4)
	var a_vuoto := Rapporto.contatore("tiri_a_vuoto")
	var tiri := Rapporto.contatore("tiri")
	await _tocca("tira")
	await _fotogrammi(20)
	_verifica("senza frecce il tiro va a vuoto", int(_g().munizioni["frecce"]) == 0 and Rapporto.contatore("tiri_a_vuoto") == a_vuoto + 1
			and Rapporto.contatore("tiri") == tiri and _g().stato != Giocatore.Stato.TIRO and String(hud.testo_armi()).contains("Frecce 0"),
			"%s — a vuoto %d, tiri %d, stato %s" % [hud.testo_armi(), Rapporto.contatore("tiri_a_vuoto") - a_vuoto,
			Rapporto.contatore("tiri") - tiri, Giocatore.Stato.keys()[_g().stato]])
	await _scegli_arma_col_tasto("dardi")


func _sotto_o_sopra(n: Nemico) -> Vector2:
	# Dove mettersi per svegliare un pipistrello appeso: la superficie più vicina sotto di lui (appeso,
	# da sopra lo copre il soffitto a cui è attaccato); se non c'è, la più vicina in verticale.
	var migliore := Vector2.INF
	var sotto := _nav.superfici.values().any(func(sup: Dictionary) -> bool:
		return float(sup["y"]) > n.global_position.y and absf(clampf(n.global_position.x, float(sup["x0"]), float(sup["x1"])) - n.global_position.x) < 60.0 \
				and not sup.get("isolata", false) and not sup.has("condizione"))
	for sup: Dictionary in _nav.superfici.values():
		if sup.get("isolata", false) or sup.has("condizione"):
			continue
		if sotto and float(sup["y"]) <= n.global_position.y:
			continue
		var x := clampf(n.global_position.x, float(sup["x0"]) + 10.0, float(sup["x1"]) - 10.0)
		if absf(x - n.global_position.x) > 60.0:
			continue
		var p := Vector2(x, float(sup["y"]))
		if absf(p.y - n.global_position.y) < absf(migliore.y - n.global_position.y):
			migliore = p
	return migliore


func _affronta(n: Nemico) -> void:
	# Un pipistrello appeso si va a svegliare (andandogli vicino); poi si combatte.
	if n.tipo == "pipistrello" and n.stato == Nemico.Stato.DORME:
		var posto := _sotto_o_sopra(n)
		if posto != Vector2.INF:
			await _vai_a(posto, 10.0)
			await _veglia(30)
	if is_instance_valid(n) and n.stato != Nemico.Stato.MORTO:
		await _combatti_contro(n, 2400)


# ------------------------------------------------------------------ cervello: la partita libera
# Come il bot di Minecraft: osserva (vita, nemici, forzieri, enigmi, zone da vedere), decide l'obiettivo
# che conviene di più adesso (con un carattere diverso a ogni partita e quello che ha imparato),
# agisce, verifica com'è andata e lo ricorda. Nessun copione: ogni partita va in un altro modo.

func _tregua(si: bool) -> void:
	# Durante le prove tecniche i nemici restano fermi e non si possono colpire.
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		(n as Nemico).tregua(si)


func _partita() -> void:
	_nuova_fase("partita")
	_principale.ricomincia_stanza()
	await _fotogrammi(40)
	Equipaggiamento.indossa("arma", "spada_viandante")
	Equipaggiamento.indossa("mano_sinistra", "mano_vuota")
	_ondate_permesse = true
	_in_partita = true
	_carica_cervello()
	_umore = {"coraggio": _caso.randf_range(0.7, 1.3), "prudenza": _caso.randf_range(0.7, 1.3),
			"curiosita": _caso.randf_range(0.7, 1.3), "avidita": _caso.randf_range(0.7, 1.3)}
	Rapporto.evento("bot_carattere", _umore)
	var uccisi_prima := Rapporto.contatore("nemici_uccisi")
	var morti_prima := Rapporto.contatore("morti")
	var ondate_prima := Rapporto.contatore("ondate")
	var inizio := Engine.get_physics_frames()
	var ultimi: Array = []
	while Engine.get_physics_frames() - inizio < int(DURATA_PARTITA * 60.0) and not _fermato:
		if _g().stato == Giocatore.Stato.MORTO or _principale._in_transizione:
			# Chi l'ha ucciso? La prossima volta ci starà più attento (e ci ripenserà prima di affrontarlo).
			var eventi: Array = Rapporto.get("_eventi")
			for i in range(eventi.size() - 1, -1, -1):
				if (eventi[i] as Dictionary).get("tipo", "") == "morte":
					var chi := String((eventi[i] as Dictionary).get("da", "")).get_slice(" ", 0)
					if chi != "" and chi != "trappola":
						_pericolosi[chi] = int(_pericolosi.get(chi, 0)) + 1
					break
			await _rinasci()
			continue
		_visitate[_nav.superficie_di(_g().global_position)] = true
		var scelta := _decidi(ultimi)
		_obiettivo_ora = scelta["nome"]
		_diario.append("%.0fs %s" % [(Engine.get_physics_frames() - inizio) / 60.0, scelta["nome"]])
		if Dispositivo.in_prova:
			print("PROVA cervello: %s (%.0f) vita %d" % [scelta["nome"], float(scelta["punti"]), _g().vita])
		var vita_prima := _g().vita
		var riuscito: bool = await _agisci(scelta)
		var c: Array = _obiettivi.get(scelta["nome"], [0, 0])
		_obiettivi[scelta["nome"]] = [int(c[0]) + 1, int(c[1]) + (1 if riuscito else 0)]
		ultimi.append([scelta["nome"], riuscito])
		if ultimi.size() > 4:
			ultimi.pop_front()
		if _g().vita < vita_prima - 2:
			Rapporto.conta("bot_ferite_gravi")
	_in_partita = false
	_obiettivo_ora = ""
	_salva_cervello()
	await _scatta("partita")
	# I controlli della partita: decide da solo, combatte, esplora, non resta bloccato. Il resto (forzieri,
	# enigmi, ondate) dipende da come va: lo racconta il rapporto.
	var diversi := _obiettivi.keys().size()
	var da_vedere := _nav.superfici.keys().filter(func(id: String) -> bool:
		return not _nav.superfici[id].get("fragile", false) and not _nav.superfici[id].has("condizione"))
	var viste := da_vedere.filter(func(id: String) -> bool: return _visitate.has(id)).size()
	_verifica("partita: sceglie da solo obiettivi diversi", diversi >= 5, str(_obiettivi))
	_verifica("partita: combatte e vince", Rapporto.contatore("nemici_uccisi") - uccisi_prima >= 4,
			"uccisi %d, morti %d" % [Rapporto.contatore("nemici_uccisi") - uccisi_prima, Rapporto.contatore("morti") - morti_prima])
	_verifica("partita: esplora la stanza", viste * 2 >= da_vedere.size(), "%d su %d" % [viste, da_vedere.size()])
	_verifica("partita: non resta mai bloccato", _stallo_massimo < 90.0, "fermo al massimo %.0f s" % _stallo_massimo)
	_verifica("partita: impara quale arma usare contro chi", not _esito_armi.is_empty(), str(_esito_armi))
	_partita_finale = {
		"carattere": _umore, "obiettivi": _obiettivi, "diario": _diario.slice(-60), "esiti": _esiti_partita,
		"zone_viste": "%d su %d" % [viste, da_vedere.size()], "uccisi": Rapporto.contatore("nemici_uccisi") - uccisi_prima,
		"morti": Rapporto.contatore("morti") - morti_prima, "ondate": Rapporto.contatore("ondate") - ondate_prima,
		"sogno_completato": _principale.stanza.sogno_completato, "armi_provate": _armi_provate.keys(),
		"esito_armi": _esito_armi, "pericolosi": _pericolosi, "fermo_massimo_s": snappedf(_stallo_massimo, 0.1),
		"fermate_lunghe": _fermate,
	}
	if Dispositivo.in_prova:
		print("PROVA partita libera: %s" % JSON.stringify(_partita_finale))


func _decidi(ultimi: Array) -> Dictionary:
	# Osserva e dà un punteggio a ogni obiettivo possibile; vince il più conveniente.
	var g := _g()
	var candidati: Array = []
	var minaccia := _minaccia()
	var vita := g.vita
	var poca_vita := vita <= 3
	var munizioni_basse := int(g.munizioni["dardi"]) + int(g.munizioni["frecce"]) < 5
	if minaccia != null:
		var paura := 1.0 + 0.3 * float(_pericolosi.get(minaccia.tipo, 0))
		if poca_vita:
			candidati.append({"nome": "ritirata", "punti": 130.0 * _umore["prudenza"] * paura, "nemico": minaccia})
		candidati.append({"nome": "combatti", "punti": 100.0 * _umore["coraggio"] / (paura if poca_vita else 1.0),
				"nemico": minaccia})
	# Forzieri ed enigmi (ogni obiettivo sa da sé come arrivarci e cosa fare).
	var stanza: Stanza = _principale.stanza
	var mecc := stanza.meccanismi
	var cura: float = 95.0 * float(_umore["prudenza"]) if vita <= 4 else 0.0
	if not (mecc["forziere_alcova"] as Forziere).aperto or not (mecc["leva_alcova"] as Leva).accesa:
		candidati.append({"nome": "alcova", "punti": 45.0 * _umore["curiosita"] + cura})
	if not (mecc["forziere_torre"] as Forziere).aperto:
		candidati.append({"nome": "torre", "punti": 42.0 * _umore["avidita"] + cura * 0.8})
	if not (mecc["forziere_tesoro"] as Forziere).aperto:
		candidati.append({"nome": "cassa", "punti": 40.0 * _umore["curiosita"] + (cura * 0.5 if (mecc["piastra_tesoro"] as Piastra).da_cassa else 0.0)})
	if not (mecc["forziere_oro"] as Forziere).aperto:
		candidati.append({"nome": "bracieri", "punti": 40.0 * _umore["avidita"]})
	var vivi := _nemici_vivi().filter(func(n: Nemico) -> bool: return not _ignorato(n) and _conosciuto(n))
	if not vivi.is_empty():
		var bonus_ondate := 25.0 if vivi.size() <= 3 and not stanza.sogno_completato else 0.0
		candidati.append({"nome": "caccia", "punti": 38.0 * _umore["coraggio"] + bonus_ondate - (25.0 if poca_vita else 0.0),
				"nemico": vivi[0]})
	elif not stanza.sogno_completato and stanza.nemici_vivi() == 0:
		candidati.append({"nome": "aspetta", "punti": 22.0})   # la prossima ondata (quelli del sotterraneo non contano)
	var da_vedere := _nav.superfici.keys().filter(func(id: String) -> bool:
		return not _visitate.has(id) and not _nav.superfici[id].get("fragile", false) and not _nav.superfici[id].has("condizione"))
	if not da_vedere.is_empty():
		candidati.append({"nome": "esplora", "punti": 32.0 * _umore["curiosita"]})
	var pacchi := get_tree().get_nodes_in_group("raccoglibili").filter(func(r: Node) -> bool:
		return (r as Node2D).global_position.distance_to(g.global_position) < 400.0)
	if not pacchi.is_empty():
		var pozione := pacchi.any(func(r: Node) -> bool: return (r as Raccoglibile).cosa == "pozione")
		candidati.append({"nome": "raccogli", "punti": 60.0 if munizioni_basse else (40.0 + cura * 0.3 if pozione else 26.0),
				"dove": (pacchi[0] as Node2D).global_position})
	# Forzieri senza storia ancora chiusi (qualcuno può essere un mimic).
	for f: Node in get_tree().get_nodes_in_group("forzieri"):
		var forziere := f as Forziere
		if forziere.casuale and not forziere.aperto and forziere.visible:
			candidati.append({"nome": "forziere", "punti": 36.0 * _umore["avidita"] + cura * 0.5, "forziere": forziere})
			break
	if munizioni_basse:
		var barili := get_tree().get_nodes_in_group("rompibili").filter(func(b: Node) -> bool:
			return is_instance_valid(b) and (b as Node2D).global_position.distance_to(g.global_position) < 300.0)
		if not barili.is_empty():
			candidati.append({"nome": "rompi", "punti": 30.0, "barile": barili[0]})
	# Un muro crepato o delle assi qui vicino: la curiosità di vedere cosa nascondono.
	for st: Node in get_tree().get_nodes_in_group("strutture"):
		if (st as Struttura).integra and (st as Struttura).centro().distance_to(g.global_position) < 240.0:
			candidati.append({"nome": "rompi", "punti": 28.0 * _umore["curiosita"], "struttura": st})
			break
	if minaccia == null and _armi_provate.size() < Armi.FAMIGLIE.size():
		candidati.append({"nome": "prova_arma", "punti": 34.0 - 2.5 * _armi_provate.size()})
	# Quello che ha imparato, un po' di caso, e niente ostinazione su ciò che è appena fallito.
	var migliore: Dictionary = {"nome": "aspetta", "punti": 0.0}
	for c: Dictionary in candidati:
		var vecchia: Array = _obiettivi_storici.get(c["nome"], [0, 0])
		var nuova: Array = _obiettivi.get(c["nome"], [0, 0])
		var riuscita := (1.0 + float(vecchia[1]) + float(nuova[1])) / (2.0 + float(vecchia[0]) + float(nuova[0]))
		var punti := float(c["punti"]) * (0.6 + 0.8 * riuscita) * _caso.randf_range(0.8, 1.2)
		var falliti_di_fila := 0
		for u: Array in ultimi:
			if u[0] == c["nome"] and not u[1]:
				falliti_di_fila += 1
		if falliti_di_fila >= 2:
			punti *= 0.3
		c["punti"] = punti
		if punti > float(migliore["punti"]):
			migliore = c
	return migliore


func _agisci(scelta: Dictionary) -> bool:
	var stanza_prima: Node = _principale.stanza
	var mecc: Dictionary = (stanza_prima as Stanza).meccanismi
	match String(scelta["nome"]):
		"combatti", "caccia":
			var n: Nemico = scelta["nemico"]
			if not is_instance_valid(n):
				return false
			await _arma_adatta(n)
			var famiglia := _g().famiglia_arma()
			var morti := Rapporto.contatore("morti")
			await _affronta(n)
			var vinto := not is_instance_valid(n) or n.stato == Nemico.Stato.MORTO
			_ricorda_arma(n.tipo if is_instance_valid(n) else String(scelta.get("tipo", "?")), famiglia, vinto)
			return vinto and Rapporto.contatore("morti") == morti
		"ritirata":
			return await _ritirata(scelta["nemico"])
		"alcova":
			await _galleria()
			return _principale.stanza == stanza_prima and (mecc["forziere_alcova"] as Forziere).aperto
		"torre":
			await _torre()
			return _principale.stanza == stanza_prima and (mecc["forziere_torre"] as Forziere).aperto
		"cassa":
			await _enigma_cassa()
			return _principale.stanza == stanza_prima and (mecc["forziere_tesoro"] as Forziere).aperto
		"bracieri":
			await _enigma_bracieri()
			return _principale.stanza == stanza_prima and (mecc["forziere_oro"] as Forziere).aperto
		"esplora":
			var qui := _g().global_position
			var da_vedere := _nav.superfici.keys().filter(func(id: String) -> bool:
				return not _visitate.has(id) and not _nav.superfici[id].get("fragile", false) and not _nav.superfici[id].has("condizione"))
			da_vedere.sort_custom(func(a: String, b: String) -> bool:
				return _distanza_superficie(a, qui) < _distanza_superficie(b, qui))
			# Non sempre la più vicina: un po' di curiosità per quelle lontane.
			var id: String = da_vedere[mini(da_vedere.size() - 1, _caso.randi() % 2)]
			await _vai_a(_meta_sicura(_nav.superfici[id]), 12.0)
			var arrivato := _nav.superficie_di(_g().global_position) == id
			if arrivato or not _raggiungibile(id):
				_visitate[id] = true   # vista, oppure ora non ci si arriva (grata chiusa)
			return arrivato
		"raccogli":
			return await _vai_a(scelta["dove"], 8.0)
		"forziere":
			var forziere: Forziere = scelta["forziere"]
			if not is_instance_valid(forziere):
				return false
			await _usa(forziere)
			if is_instance_valid(forziere) and forziere.mimic and forziere.aperto:
				_esiti_partita["un forziere era un mimic"] = true
			return is_instance_valid(forziere) and forziere.aperto
		"rompi":
			if scelta.has("struttura"):
				return await _rompi_struttura(scelta["struttura"])
			var barile: Node2D = scelta["barile"]
			if not is_instance_valid(barile):
				return false
			await _vai_a(barile.global_position + Vector2(-20.0 * signf(barile.global_position.x - _g().global_position.x), 0.0), 6.0)
			if not is_instance_valid(barile):
				return true
			await _guarda(1 if barile.global_position.x > _g().global_position.x else -1)
			await _tocca("attacca")
			await _fotogrammi(20)
			return not is_instance_valid(barile)
		"prova_arma":
			var da_provare := Armi.FAMIGLIA_DI.keys().filter(func(a: String) -> bool:
				return not _armi_provate.has(Armi.famiglia(a)))
			if da_provare.is_empty():
				return false
			var arma: String = da_provare[_caso.randi() % da_provare.size()]
			Equipaggiamento.indossa("arma", arma)
			_armi_provate[Armi.famiglia(arma)] = true
			await _fotogrammi(10)
			return true
		_:
			await _veglia(60)
			return true
	return false


func _conosciuto(n: Nemico) -> bool:
	# Chi dorme nel sotterraneo non si sa che c'è finché non ci si scende (o non si sveglia da sé).
	if not n.has_meta("sotterraneo"):
		return true
	return (_principale.stanza as Stanza).sotto_terra or n.stato not in [Nemico.Stato.DORME, Nemico.Stato.RISVEGLIO]


func _raggiungibile(id: String) -> bool:
	var da := _nav.superficie_di(_g().global_position)
	return da != "" and (da == id or not _nav.percorso(da, id).is_empty())


func _ritirata(n: Nemico) -> bool:
	# Poca vita: ci si allontana da chi minaccia (tirandogli contro, se si può) e si prende fiato.
	var vita := _g().vita
	for passo in 3:
		if not is_instance_valid(n) or n.stato == Nemico.Stato.MORTO:
			break
		var via := -1 if n.global_position.x > _g().global_position.x else 1
		var arma := _scegli_arma(n)
		if arma != "" and _a_tiro(n) != 0 and absf(n.global_position.x - _g().global_position.x) > 90.0:
			await _tira_contro(n, arma)
			continue
		await _cammina_verso(clampf(_g().global_position.x + via * 140.0, 60.0, Stanza.LARGHEZZA - 60.0), 10.0, 70)
	return _g().vita >= vita


func _arma_adatta(n: Nemico) -> void:
	# Sceglie l'arma (come farebbe una persona dal menu): quella che contro questo nemico ha vinto di più;
	# contro chi para (bestione, scheletro) all'inizio prova un'arma che rompe le parate.
	var conti: Dictionary = _esito_armi.get(n.tipo, {})
	var migliore := ""
	var punti := -1.0
	for famiglia: String in conti:
		var c: Array = conti[famiglia]
		var p := (1.0 + float(c[1])) / (2.0 + float(c[0]))
		if p > punti:
			punti = p
			migliore = famiglia
	if (migliore == "" or _caso.randf() < 0.2) and n.tipo in ["bestione", "scheletro"]:
		migliore = ["ascia", "spadone", "bipenne"][_caso.randi() % 3]
	if migliore == "" or migliore == _g().famiglia_arma():
		return
	for arma: String in Armi.FAMIGLIA_DI:
		if Armi.famiglia(arma) == migliore:
			Equipaggiamento.indossa("arma", arma)
			_armi_provate[migliore] = true
			await _fotogrammi(6)
			return


func _ricorda_arma(tipo: String, famiglia: String, vinto: bool) -> void:
	if not _esito_armi.has(tipo):
		_esito_armi[tipo] = {}
	var c: Array = (_esito_armi[tipo] as Dictionary).get(famiglia, [0, 0])
	_esito_armi[tipo][famiglia] = [int(c[0]) + 1, int(c[1]) + (1 if vinto else 0)]


func _carica_cervello() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ESPERIENZA_CERVELLO) == OK:
		_esito_armi = cfg.get_value("cervello", "armi", {})
		_obiettivi_storici = cfg.get_value("cervello", "obiettivi", {})
		_pericolosi = cfg.get_value("cervello", "pericolosi", {})
	# Si ricorda il passato (quanto gli riesce ogni obiettivo), ma ogni partita conta i suoi da capo.
	_obiettivi = {}


func _salva_cervello() -> void:
	var cfg := ConfigFile.new()
	var tutti := _obiettivi_storici.duplicate(true)
	for nome: String in _obiettivi:
		var a: Array = tutti.get(nome, [0, 0])
		var b: Array = _obiettivi[nome]
		tutti[nome] = [int(a[0]) + int(b[0]), int(a[1]) + int(b[1])]
	cfg.set_value("cervello", "armi", _esito_armi)
	cfg.set_value("cervello", "obiettivi", tutti)
	cfg.set_value("cervello", "pericolosi", _pericolosi)
	cfg.save(ESPERIENZA_CERVELLO)


# ------------------------------------------------------------------ galleria

func _interrotta(stanza_fase: Variant) -> bool:
	# Morto davvero a metà fase: la stanza è ricominciata e i meccanismi di prima non ci sono più.
	# La fase si ferma (senza toccare oggetti spariti) e _esegui la rifà.
	if is_instance_valid(stanza_fase) and _principale.stanza == stanza_fase:
		return false
	if not _fase_interrotta and Dispositivo.in_prova:
		print("PROVA fase interrotta: %s (morto davvero)" % fase_nome)
	_fase_interrotta = true
	return true


func _m(nome: String) -> Node:
	return _principale.stanza.meccanismi[nome]


func _galleria() -> void:
	# Dalla terrazza si scende nella galleria; la leva apre la grata dell'alcova (scorciatoia);
	# il forziere dell'alcova si apre.
	_nuova_fase("galleria")
	var stanza_fase: Node = _principale.stanza
	await _vai_a(Vector2(1440, Stanza.PAVIMENTO), 10.0)
	if _interrotta(stanza_fase):
		return
	_verifica("dalla terrazza si scende nella galleria", _nav.superficie_di(_g().global_position) == "galleria",
			"%s" % str(_g().global_position))
	await _scatta("galleria")
	if _interrotta(stanza_fase):
		return
	var leva := _m("leva_alcova") as Leva
	var grata := _m("porta_alcova") as Porta
	await _vai_a(leva.global_position + Vector2(14.0, 0.0), 5.0)
	if _interrotta(stanza_fase):
		return
	await _guarda(-1)
	if _interrotta(stanza_fase):
		return
	await _fotogrammi(3)
	if _interrotta(stanza_fase):
		return
	var etichetta := _g().cosa_vicina()
	await _tocca("afferra")
	if _interrotta(stanza_fase):
		return
	await _fotogrammi(70)
	if _interrotta(stanza_fase):
		return
	_verifica("accanto alla leva il tasto dice «Leva»", etichetta == "Leva", etichetta)
	_verifica("la leva apre la grata dell'alcova", leva.accesa and grata.del_tutto_aperta())
	await _scatta("leva")
	if _interrotta(stanza_fase):
		return
	var passati := int(_passaggi.get("passa", 0))
	var forziere := _m("forziere_alcova") as Forziere
	var vita_prima := _g().vita
	var a_portata := await _usa(forziere)
	if _interrotta(stanza_fase):
		return
	await _fotogrammi(30)
	if _interrotta(stanza_fase):
		return
	_verifica("dalla grata aperta si entra nell'alcova", int(_passaggi.get("passa", 0)) > passati
			and _nav.superficie_di(_g().global_position) == "alcova", str(_passaggi))
	_verifica("il forziere si apre col tasto, accanto", a_portata and forziere.aperto, str(forziere.contenuto))
	_verifica("dentro c'è un frammento della storia", forziere.contenuto.has("frammento") and Equipaggiamento.frammenti.size() >= 1)
	_verifica("il forziere ridà le frecce finite", forziere.contenuto.has("frecce") and int(_g().munizioni["frecce"]) > 0,
			str(forziere.contenuto))
	_verifica("il forziere cura chi è ferito", vita_prima >= Giocatore.VITA_MASSIMA or _g().vita > vita_prima,
			"vita %d -> %d" % [vita_prima, _g().vita])
	await _scatta("forziere")
	if _interrotta(stanza_fase):
		return
	await _vai_a(Vector2(1500, Stanza.PAVIMENTO), 8.0)
	if _interrotta(stanza_fase):
		return


func _torre() -> void:
	# Ci si aggrappa allo zoccolo; le lastre fragili portano alla torre ovest (forziere) e crollano;
	# il montacarichi porta al salone.
	_nuova_fase("torre")
	var stanza_fase: Node = _principale.stanza
	await _vai_a(Vector2(2165, 384), 8.0)
	if _interrotta(stanza_fase):
		return
	_verifica("si aggrappa allo zoccolo della torre", _nav.superficie_di(_g().global_position) == "zoccolo",
			str(_g().global_position))
	var crolli := Rapporto.contatore("piattaforme_crollate")
	var forziere := _m("forziere_torre") as Forziere
	await _usa(forziere)
	if _interrotta(stanza_fase):
		return
	await _scatta("torre_ovest")
	if _interrotta(stanza_fase):
		return
	_verifica("sale per le lastre fragili fino alla torre ovest", _nav.superficie_di(_g().global_position) == "torre_ovest",
			str(_g().global_position))
	if Rapporto.contatore("piattaforme_crollate") == crolli and _nav.superficie_di(_g().global_position) == "torre_ovest":
		# Ci è arrivato con un salto lungo aggrappandosi al bordo, senza le lastre: ci si scende sopra apposta.
		await _vai_a(Vector2(2049, 184), 8.0)
		if _interrotta(stanza_fase):
			return
		await _fotogrammi(90)
		if _interrotta(stanza_fase):
			return
	_verifica("le lastre fragili crollano dopo che ci si è saliti", Rapporto.contatore("piattaforme_crollate") > crolli,
			str(_passaggi))
	_verifica("il forziere della torre si apre", forziere.aperto)
	await _fotogrammi(260)
	if _interrotta(stanza_fase):
		return
	var tutte := true
	for f: Node in get_tree().get_nodes_in_group("fragili"):
		tutte = tutte and (f as PiattaformaFragile).presente
	_verifica("le lastre crollate tornano al loro posto", tutte)
	var montacarichi := int(_passaggi.get("ascensore", 0))
	await _vai_a(Vector2(2420, 120), 10.0)
	if _interrotta(stanza_fase):
		return
	_verifica("arriva al salone (col montacarichi o per un'altra strada)", _nav.superficie_di(_g().global_position) == "salone",
			"%s, montacarichi %s, passaggi %s" % [str(_g().global_position), int(_passaggi.get("ascensore", 0)) > montacarichi, str(_passaggi)])
	await _scatta("salone")
	if _interrotta(stanza_fase):
		return


func _enigma_cassa() -> void:
	# La cassa sulla balconata va spinta giù, poi sulla piastra: la grata del tesoro resta alzata.
	_nuova_fase("enigma_cassa")
	var stanza_fase: Node = _principale.stanza
	var cassa := _m("cassa_enigma") as RigidBody2D
	var piastra := _m("piastra_tesoro") as Piastra
	var grata := _m("porta_tesoro") as Porta
	# Prima si sistema chi c'è nella sala.
	for giro in 8:
		var nella_sala := _nemici_vivi().filter(func(n: Nemico) -> bool:
			return n.global_position.x > 2208.0 and n.global_position.y > 300.0 and not _ignorato(n))
		if nella_sala.is_empty():
			break
		await _combatti_contro(nella_sala[0], 1800)
		if _interrotta(stanza_fase):
			return
		if _g().stato == Giocatore.Stato.MORTO:
			await _rinasci()
			if _interrotta(stanza_fase):
				return
	# Sulla balconata, si scavalca la cassa per mettersi dalla parte giusta e la si spinge giù.
	await _vai_a(Vector2(2510.0, 352.0), 6.0)
	if _interrotta(stanza_fase):
		return
	Input.action_press("destra")
	Input.action_press("su")
	for i in 240:
		await _fotogrammi(1)
		if _interrotta(stanza_fase):
			return
		var g := _g()
		if g.global_position.x > 2626.0 or (g.is_on_floor() and g.global_position.x > cassa.global_position.x + 26.0
				and absf(g.global_position.y - 352.0) < 3.0):
			break
	_rilascia_tutto()
	await _fotogrammi(10)
	if _interrotta(stanza_fase):
		return
	await _guarda(-1)
	if _interrotta(stanza_fase):
		return
	Input.action_press("sinistra")
	var x_balconata := cassa.global_position.x
	var liberata := false
	for i in 420:
		await _fotogrammi(1)
		if _interrotta(stanza_fase):
			return
		if cassa.global_position.y > 420.0 or _g().global_position.x < 2484.0:
			break
		if i % 60 == 59:
			if absf(cassa.global_position.x - x_balconata) < 2.0 and not liberata:
				# La cassa non va: qualcuno dall'altra parte la blocca (un nemico la trattiene). Prima lui.
				liberata = true
				for n: Nemico in _nemici_vivi():
					if n.global_position.distance_to(cassa.global_position) < 140.0:
						_rilascia_tutto()
						await _combatti_contro(n, 900)
						break
				if _interrotta(stanza_fase):
					return
				await _cammina_verso(cassa.global_position.x + 26.0, 3.0, 200, false)
				await _guarda(-1)
				Input.action_press("sinistra")
			x_balconata = cassa.global_position.x
	_rilascia_tutto()
	await _fotogrammi(60)
	if _interrotta(stanza_fase):
		return
	_verifica("spinge la cassa giù dalla balconata", cassa.global_position.y > 470.0, "%s, nemici vicini %s" % [
			str(cassa.global_position), str(_nemici_vivi().filter(func(n: Nemico) -> bool: return n.global_position.x > 2208.0)
			.map(func(n: Nemico) -> String: return "%s %s %s" % [n.tipo, str(n.global_position.round()), Nemico.Stato.keys()[n.stato]]))])
	await _scatta("cassa_giu")
	if _interrotta(stanza_fase):
		return
	# Si scende dall'altra parte e la si spinge sulla piastra, senza scavalcarla.
	if _nav.superficie_di(_g().global_position) == "balconata":
		Input.action_press("destra")
		for i in 120:
			await _fotogrammi(1)
			if _interrotta(stanza_fase):
				return
			if not _g().is_on_floor():
				break
		_rilascia_tutto()
		await _atterra()
		if _interrotta(stanza_fase):
			return
	for tentativo in 4:
		if piastra.da_cassa:
			break
		var lato := 1.0 if cassa.global_position.x > piastra.global_position.x else -1.0
		if lato > 0.0 and cassa.global_position.x > 2630.0 or tentativo >= 2:
			# Incastrata contro la grata (non c'è posto per spingerla): la si afferra e la si tira.
			var dalla := -lato
			await _cammina_verso(cassa.global_position.x + 26.0 * dalla, 3.0, 600, false)
			if _interrotta(stanza_fase):
				return
			await _guarda(int(lato))
			Input.action_press("afferra")
			await _fotogrammi(4)
			Input.action_press("sinistra" if lato > 0.0 else "destra")
			for i in 300:
				await _fotogrammi(1)
				if _interrotta(stanza_fase):
					return
				if piastra.da_cassa or _g().stato != Giocatore.Stato.PRESA:
					break
			_rilascia_tutto()
			Rapporto.conta("bot_cassa_tirata")
			await _fotogrammi(30)
			continue
		await _cammina_verso(cassa.global_position.x + 26.0 * lato, 3.0, 600, false)
		if _interrotta(stanza_fase):
			return
		await _guarda(-int(lato))
		if _interrotta(stanza_fase):
			return
		Input.action_press("sinistra" if lato > 0.0 else "destra")
		var x_cassa := cassa.global_position.x
		for i in 360:
			await _fotogrammi(1)
			if _interrotta(stanza_fase):
				return
			if piastra.da_cassa or _g().stato != Giocatore.Stato.NORMALE:
				break
			if i % 60 == 59:
				if absf(cassa.global_position.x - x_cassa) < 3.0:
					break   # la cassa non si muove (incastrata o non la si sta spingendo): si riprova da capo
				x_cassa = cassa.global_position.x
		_rilascia_tutto()
		await _fotogrammi(30)
		if _interrotta(stanza_fase):
			return
	await _fotogrammi(60)
	if _interrotta(stanza_fase):
		return
	_verifica("la cassa sulla piastra tiene alzata la grata", piastra.da_cassa and grata.del_tutto_aperta(),
			"cassa %s, piastra %s" % [str(cassa.global_position), str(piastra.giu)])
	await _scatta("cassa_piastra")
	if _interrotta(stanza_fase):
		return
	var forziere := _m("forziere_tesoro") as Forziere
	await _usa(forziere)
	if _interrotta(stanza_fase):
		return
	_verifica("oltre la grata si apre il forziere del tesoro", forziere.aperto and _nav.superficie_di(_g().global_position) == "tesoro")


func _accendi_braciere(b: Node2D) -> void:
	var stanza_fase: Node = _principale.stanza
	# Ci si mette accanto e lo si colpisce; se qualcosa va storto (un nemico, un colpo a vuoto) si riprova.
	var enigma := b.get_parent() as EnigmaBracieri
	for tentativo in 3:
		var accesi := enigma.accesi.size()
		var sbagli := Rapporto.contatore("enigmi_sbagliati")
		var lato := -20.0 if _g().global_position.x < b.global_position.x else 20.0
		await _vai_a(b.global_position + Vector2(lato, 0.0), 5.0)
		if _interrotta(stanza_fase):
			return
		await _guarda(1 if b.global_position.x > _g().global_position.x else -1)
		if _interrotta(stanza_fase):
			return
		await _tocca("attacca")
		if _interrotta(stanza_fase):
			return
		await _fotogrammi(24)
		if _interrotta(stanza_fase):
			return
		if enigma.accesi.size() != accesi or Rapporto.contatore("enigmi_sbagliati") != sbagli or enigma.soluzione:
			return


func _enigma_bracieri() -> void:
	# Bracieri da accendere nell'ordine della tavoletta: prima apposta in un ordine sbagliato,
	# poi in quello giusto. Si alza il gradino verso la nicchia e il forziere d'oro dà un colore nuovo.
	_nuova_fase("enigma_bracieri")
	var stanza_fase: Node = _principale.stanza
	var enigma := _m("bracieri") as EnigmaBracieri
	var gradino := _m("gradino") as Porta
	await _vai_a(Vector2(2440, 120), 10.0)
	if _interrotta(stanza_fase):
		return
	for giro in 6:
		var nel_salone := _nemici_vivi().filter(func(n: Nemico) -> bool:
			return n.global_position.y < 200.0 and n.global_position.x > 2340.0 and not _ignorato(n))
		if nel_salone.is_empty():
			break
		await _combatti_contro(nel_salone[0], 1800)
		if _interrotta(stanza_fase):
			return
	# Combattendo se ne può accendere qualcuno per caso: l'errore voluto tiene conto di quelli già accesi.
	var sbagli := Rapporto.contatore("enigmi_sbagliati")
	var sbagliato := -1
	if not enigma.soluzione and not _in_partita:
		var atteso: int = enigma.ordine[enigma.accesi.size()]
		for i in enigma.bracieri.size():
			if i != atteso and not enigma.accesi.has(i):
				sbagliato = i
	if sbagliato >= 0:
		await _accendi_braciere(enigma.bracieri[sbagliato])
		if _interrotta(stanza_fase):
			return
		await _fotogrammi(70)
		if _interrotta(stanza_fase):
			return
		var spenti := enigma.bracieri.all(func(b: Node) -> bool: return not b.get("acceso"))
		_verifica("ordine sbagliato: i bracieri si spengono", spenti and Rapporto.contatore("enigmi_sbagliati") > sbagli)
	for i: int in enigma.ordine:
		if not enigma.accesi.has(i):
			await _accendi_braciere(enigma.bracieri[i])
			if _interrotta(stanza_fase):
				return
	await _scatta("bracieri")
	if _interrotta(stanza_fase):
		return
	await _fotogrammi(120)
	if _interrotta(stanza_fase):
		return
	_verifica("nell'ordine della tavoletta si alza il gradino segreto", enigma.soluzione and gradino.del_tutto_aperta(),
			"accesi %s, ordine %s" % [str(enigma.accesi), str(enigma.ordine)])
	var forziere := _m("forziere_oro") as Forziere
	var colori := Equipaggiamento.trovati.size()
	await _usa(forziere)
	if _interrotta(stanza_fase):
		return
	await _scatta("nicchia")
	if _interrotta(stanza_fase):
		return
	_verifica("dal gradino si sale alla nicchia segreta", _nav.superficie_di(_g().global_position) == "nicchia",
			str(_g().global_position))
	var colore: String = forziere.contenuto.get("colore", "")
	_verifica("il forziere d'oro dà un colore nuovo", forziere.aperto and colore != "" and Equipaggiamento.trovati.size() == colori + 1,
			str(forziere.contenuto))
	_verifica("il colore trovato si può indossare", Equipaggiamento.disponibile(colore))
	if colore != "":
		Equipaggiamento.colora("mantello", colore)
		await _fotogrammi(3)
		if _interrotta(stanza_fase):
			return
		_verifica("il mantello prende il colore trovato", Equipaggiamento.colori["mantello"] == colore)
		await _scatta("colore_nuovo")
		if _interrotta(stanza_fase):
			return
		Equipaggiamento.ripristina()


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
	_ondate_permesse = true
	if is_instance_valid(_principale.stanza):
		_principale.stanza.ondate_attive = true
	_memoria_bot = Memoria.descrizione()
	_tesori_bot = {"colori": Equipaggiamento.trovati.duplicate(), "frammenti": Equipaggiamento.frammenti.size()}
	if get_tree().paused and _principale.menu.aperto:
		_principale.menu.chiudi()
	# Impostazioni e aspetto tornano come li aveva chi gioca.
	if not _stato_utente.is_empty():
		_rimetti(_stato_utente)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SEGNO))
	Dispositivo.bot_attivo = false
	Effetti.applica_velocita()
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
		"morti_vere": Rapporto.contatore("morti"),
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
		"partita_libera": _partita_finale,
		"armi_e_nemici_nuovi": {
			"tiri": Rapporto.contatore("tiri"),
			"tiri_a_segno": Rapporto.contatore("tiri_a_segno"),
			"tiri_a_vuoto": Rapporto.contatore("tiri_a_vuoto"),
			"tiri_per_arma": {"magia": Rapporto.contatore("tiri_magia"), "dardi": Rapporto.contatore("tiri_dardi"),
					"frecce": Rapporto.contatore("tiri_frecce")},
			"munizioni_raccolte": Rapporto.contatore("munizioni_raccolte"),
			"alle_spalle_del_bestione": _alle_spalle,
			"parate_bestione": Rapporto.contatore("parate_bestione"),
			"cariche_bestione": Rapporto.contatore("cariche_bestione"),
			"picchiate_pipistrello": Rapporto.contatore("picchiate_pipistrello"),
			"balzi_saltatore": Rapporto.contatore("balzi_saltatore"),
			"dardi_nemici": Rapporto.contatore("dardi_nemici"),
			"tiri_schivati_dai_nemici": Rapporto.contatore("tiri_schivati_dai_nemici"),
			"ondate": _esito_ondate,
			"parate_nemici": Rapporto.contatore("parate_nemici"),
			"combo_nemici": Rapporto.contatore("combo_nemici"),
			"accerchiamenti": Rapporto.contatore("accerchiamenti"),
			"richiami": Rapporto.contatore("richiami"),
			"letture_arma": Rapporto.contatore("letture_arma"),
			"guardie_rotte": Rapporto.contatore("guardie_rotte"),
			"tiri_carichi": Rapporto.contatore("tiri_carichi"),
			"esplosioni": Rapporto.contatore("esplosioni"),
			"veterani": Memoria.descrizione()["veterani"],
			"uccisi": {"arciere": Rapporto.contatore("uccisi_arciere"), "pipistrello": Rapporto.contatore("uccisi_pipistrello"),
					"saltatore": Rapporto.contatore("uccisi_saltatore"), "bestione": Rapporto.contatore("uccisi_bestione")},
		},
	}
