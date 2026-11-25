class_name Giocatore
extends CharacterBody2D
# Il Non Narrato: corre, salta, attacca (due colpi in fila), rotola e scatta in avanti o
# all'indietro, scavalca ostacoli bassi e si aggrappa ai bordi, afferra le casse per tirarle.
# I tempi sono nel codice e non dipendono dalle animazioni, così il comportamento
# è lo stesso su ogni dispositivo.

signal vita_cambiata(vita: int, massima: int)
signal morto

enum Stato { NORMALE, ATTACCO, ROTOLATA, SCHIVATA, COLPITO, MORTO, SCAVALCO, PRESA }

const VELOCITA := 150.0
const ACCELERAZIONE := 1500.0
const ATTRITO := 1900.0
const ACCELERAZIONE_ARIA := 1000.0
const SALTO := 390.0
const GRAVITA_SU := 1000.0
const GRAVITA_GIU := 1500.0
const CADUTA_MASSIMA := 540.0
const TAGLIO_SALTO := 0.45          # salto più basso se si lascia subito il tasto
const TEMPO_COYOTE := 0.10          # si può ancora saltare un attimo dopo il bordo
const TEMPO_MEMORIA := 0.12         # il salto premuto un attimo prima di toccare terra vale
const ROTOLATA_DURATA := 0.40
const ROTOLATA_VELOCITA := 250.0
const ROTOLATA_PAUSA := 0.25
const SCHIVATA_DURATA := 0.20
const SCHIVATA_VELOCITA := 290.0
const SCATTO_VELOCITA := 320.0
const SCHIVATA_PAUSA := 0.35
const ATTACCO_DURATA := 0.36
const ATTACCO_INIZIO := 0.10        # da qui il colpo fa male...
const ATTACCO_FINE := 0.24          # ...fino a qui
const VITA_MASSIMA := 5
const PROTEZIONE_DOPO_COLPO := 0.9
const SPINTA_CASSE := 70.0
const TEMPO_GIRO := 0.2             # direzione indietro + rotola/schiva entro questo tempo = mossa all'indietro
const SCAVALCO_DURATA := 0.32
const SCAVALCO_DA_TERRA := 40.0     # ostacoli fino a questa altezza si scavalcano da terra (su + direzione)
const APPIGLIO_IN_ARIA := 62.0      # in aria ci si aggrappa a bordi fino a questa altezza sopra i piedi
const PRESA_VELOCITA := 70.0
const PRESA_DISTANZA := 30.0        # centro cassa - centro giocatore per poterla afferrare

const ALTO := Vector2(14, 44)
const BASSO := Vector2(14, 20)

var stato := Stato.NORMALE
var verso := 1
var vita := VITA_MASSIMA

var sprite: SpriteAnimato
var camera: Camera2D

var _t_stato := 0.0
var _t_coyote := 0.0
var _t_memoria_salto := 0.0
var _t_pausa_rotolata := 0.0
var _t_pausa_schivata := 0.0
var _t_protetto := 0.0
var _t_attraversa := 0.0
var _t_atterra := 0.0
var _colpo_numero := 0
var _colpo_prenotato := false
var _gia_colpiti: Array = []
var _scatto_usato := false
var _schivata_in_aria := false
var _velocita_caduta := 0.0
var _scossa := 0.0
var _morte_segnalata := false
var _verso_prima := 1
var _t_girato := 0.0
var _dir_rotolata := 1
var _dir_schivata := 1
var _schivata_avanti := false
var _scavalco_da := Vector2.ZERO
var _scavalco_a := Vector2.ZERO
var _maschera := 0
var _cassa: RigidBody2D
var _scarto_cassa := 0.0
var _tirata_contata := false

var _forma: CollisionShape2D
var _rett: RectangleShape2D
var _colpo: Area2D
var _forma_colpo: CollisionShape2D
var _bersaglio: Area2D


func _ready() -> void:
	collision_layer = Effetti.S_GIOCATORE
	collision_mask = Effetti.S_MONDO | Effetti.S_PIATTAFORME | Effetti.S_OGGETTI
	floor_snap_length = 4.0
	z_index = 10

	_rett = RectangleShape2D.new()
	_forma = CollisionShape2D.new()
	_forma.shape = _rett
	add_child(_forma)
	_imposta_forma(ALTO)

	sprite = FiguraViva.new()  # aspetto dato dall'equipaggiamento, fotografato dal manichino 3D
	sprite.carica("protagonista")
	sprite.light_mask = Effetti.L_DAVANTI
	add_child(sprite)
	sprite.riproduci("fermo")

	# Zona colpita dalla spada.
	_colpo = Area2D.new()
	_colpo.collision_layer = Effetti.S_COLPI_GIOCATORE
	_colpo.collision_mask = Effetti.S_BERSAGLI
	_colpo.monitorable = false
	var rett_colpo := RectangleShape2D.new()
	rett_colpo.size = Vector2(40, 48)
	_forma_colpo = CollisionShape2D.new()
	_forma_colpo.shape = rett_colpo
	_forma_colpo.position = Vector2(24, -24)
	_colpo.add_child(_forma_colpo)
	add_child(_colpo)

	# Zona in cui il giocatore può essere colpito.
	_bersaglio = Area2D.new()
	_bersaglio.collision_layer = Effetti.S_BERSAGLIO_GIOCATORE
	_bersaglio.collision_mask = 0
	_bersaglio.monitoring = false
	_bersaglio.set_meta("bersaglio", self)
	var rett_bersaglio := RectangleShape2D.new()
	rett_bersaglio.size = Vector2(12, 38)
	var forma_bersaglio := CollisionShape2D.new()
	forma_bersaglio.shape = rett_bersaglio
	forma_bersaglio.position = Vector2(0, -21)
	_bersaglio.add_child(forma_bersaglio)
	add_child(_bersaglio)

	camera = Camera2D.new()
	camera.position = Vector2(0, -40)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)
	camera.make_current()

	# Un tenue alone freddo: il Non Narrato si vede sempre, anche nel buio.
	var aura := Effetti.luce(Color(0.6, 0.68, 1.0), 110.0, 1.0, 60.0)
	aura.position = Vector2(0, -26)
	add_child(aura)

	Effetti.occlusore(self, Rect2(-5, -40, 10, 38))


func limiti(riquadro: Rect2i) -> void:
	camera.limit_left = riquadro.position.x
	camera.limit_top = riquadro.position.y
	camera.limit_right = riquadro.end.x
	camera.limit_bottom = riquadro.end.y
	camera.reset_smoothing()


func _process(delta: float) -> void:
	if _scossa > 0.0:
		_scossa = maxf(0.0, _scossa - 30.0 * delta)
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _scossa
	else:
		camera.offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_scorri_tempi(delta)
	var a_terra := is_on_floor()
	if a_terra:
		_t_coyote = TEMPO_COYOTE
		_scatto_usato = false
	if Input.is_action_just_pressed("salta"):
		_t_memoria_salto = TEMPO_MEMORIA

	match stato:
		Stato.NORMALE:
			_normale(delta, a_terra)
		Stato.ATTACCO:
			_attacco(delta, a_terra)
		Stato.ROTOLATA:
			_rotolata(delta)
		Stato.SCHIVATA:
			_schivata(delta)
		Stato.COLPITO:
			_colpito(delta)
		Stato.MORTO:
			_da_morto(delta)
		Stato.SCAVALCO:
			_scavalco(delta)
		Stato.PRESA:
			_presa(delta)

	_velocita_caduta = velocity.y
	move_and_slide()
	_spingi_oggetti(delta)
	if is_on_floor() and not a_terra:
		_atterrato()
	_aggiorna_aspetto()


func _scorri_tempi(delta: float) -> void:
	_t_coyote = maxf(0.0, _t_coyote - delta)
	_t_memoria_salto = maxf(0.0, _t_memoria_salto - delta)
	_t_pausa_rotolata = maxf(0.0, _t_pausa_rotolata - delta)
	_t_pausa_schivata = maxf(0.0, _t_pausa_schivata - delta)
	_t_protetto = maxf(0.0, _t_protetto - delta)
	_t_atterra = maxf(0.0, _t_atterra - delta)
	_t_girato = maxf(0.0, _t_girato - delta)
	if _t_attraversa > 0.0:
		_t_attraversa -= delta
		if _t_attraversa <= 0.0:
			set_collision_mask_value(2, true)


# ------------------------------------------------------------------ stati

func _normale(delta: float, a_terra: bool) -> void:
	var direzione := Input.get_axis("sinistra", "destra")
	if absf(direzione) > 0.01:
		var nuovo := 1 if direzione > 0.0 else -1
		if nuovo != verso:
			_verso_prima = verso
			_t_girato = TEMPO_GIRO
			verso = nuovo
	_muovi(delta, a_terra, direzione)
	_gravita(delta)

	# Scavalcare: da terra con su + direzione contro un ostacolo basso; in aria ci si aggrappa da soli al bordo.
	if absf(direzione) > 0.01:
		var arrivo: Variant = null
		if a_terra and Input.is_action_pressed("su") and is_on_wall():
			arrivo = _appiglio(SCAVALCO_DA_TERRA, 6.0)
		elif not a_terra and velocity.y > -60.0:
			arrivo = _appiglio(APPIGLIO_IN_ARIA, 8.0)
		if arrivo != null:
			_inizia_scavalco(arrivo)
			return
	# Afferrare una cassa vicina: tenendo premuto si spinge o si tira.
	if a_terra and Input.is_action_pressed("afferra"):
		var cassa := vicino_cassa()
		if cassa != null:
			_inizia_presa(cassa)
			return

	if _t_memoria_salto > 0.0 and _t_coyote > 0.0:
		if a_terra and Input.is_action_pressed("giu") and _su_piattaforma():
			# Giù + salto: si scende attraverso la piattaforma.
			_t_attraversa = 0.25
			set_collision_mask_value(2, false)
			position.y += 2.0
		else:
			velocity.y = -SALTO
			Rapporto.conta("salti")
			_polvere(5)
		_t_memoria_salto = 0.0
		_t_coyote = 0.0
	if Input.is_action_just_released("salta") and velocity.y < 0.0:
		velocity.y *= TAGLIO_SALTO

	if Input.is_action_just_pressed("rotola") and a_terra and _t_pausa_rotolata <= 0.0:
		_inizia_rotolata(direzione)
	elif Input.is_action_just_pressed("schiva") and _t_pausa_schivata <= 0.0 and (a_terra or not _scatto_usato):
		_inizia_schivata(a_terra, direzione)
	elif Input.is_action_just_pressed("attacca"):
		_inizia_attacco(1, a_terra)


func _inizia_attacco(numero: int, a_terra: bool) -> void:
	stato = Stato.ATTACCO
	_t_stato = 0.0
	_colpo_numero = numero
	_colpo_prenotato = false
	_gia_colpiti.clear()
	_forma_colpo.position.x = 24.0 * verso
	sprite.riproduci("attacco%d" % numero, true)
	if a_terra:
		velocity.x = verso * 80.0
	Rapporto.conta("attacchi")


func _attacco(delta: float, a_terra: bool) -> void:
	var prima := _t_stato
	_t_stato += delta
	var direzione := Input.get_axis("sinistra", "destra")
	if a_terra:
		velocity.x = move_toward(velocity.x, 0.0, ATTRITO * 0.5 * delta)
	else:
		_muovi(delta, false, direzione)
	_gravita(delta)

	if prima < ATTACCO_INIZIO and _t_stato >= ATTACCO_INIZIO:
		_fendente()
	if _t_stato >= ATTACCO_INIZIO and _t_stato <= ATTACCO_FINE:
		_colpisci()
	if Input.is_action_just_pressed("attacca") and _t_stato >= 0.06:
		_colpo_prenotato = true

	if _t_stato > ATTACCO_FINE:
		if Input.is_action_just_pressed("rotola") and a_terra and _t_pausa_rotolata <= 0.0:
			_inizia_rotolata(direzione)
			return
		if Input.is_action_just_pressed("schiva") and _t_pausa_schivata <= 0.0 and (a_terra or not _scatto_usato):
			_inizia_schivata(a_terra, direzione)
			return
		if _colpo_prenotato and _colpo_numero == 1:
			if absf(direzione) > 0.01:
				verso = 1 if direzione > 0.0 else -1
			_inizia_attacco(2, a_terra)
			return
	if _t_stato >= ATTACCO_DURATA:
		stato = Stato.NORMALE


func _colpisci() -> void:
	for area in _colpo.get_overlapping_areas():
		var chi: Variant = area.get_meta("bersaglio", null)
		if chi == null or not is_instance_valid(chi) or _gia_colpiti.has(chi):
			continue
		_gia_colpiti.append(chi)
		if not chi.has_method("subisci"):
			continue
		var danno := 1 if _colpo_numero == 1 else 2
		if chi.subisci(danno, global_position, 150.0):
			var punto: Vector2 = (area as Area2D).global_position.lerp(global_position + Vector2(verso * 24.0, -24.0), 0.5)
			Effetti.scoppio(get_parent(), punto, Color(1.0, 0.9, 0.7), 8, 110.0, 0.22, 200.0)
			scuoti(2.5)
			Controlli.vibra(0.4, 0.08)
			Effetti.fermo_immagine(self, 0.05)


func _all_indietro(direzione: float) -> bool:
	# Direzione opposta allo sguardo (o appena girati): la mossa va all'indietro e lo sguardo resta.
	if absf(direzione) <= 0.01:
		return false
	var dir := 1 if direzione > 0.0 else -1
	if stato == Stato.NORMALE and _t_girato > 0.0 and dir != _verso_prima:
		verso = _verso_prima
		return true
	if dir != verso:
		if stato == Stato.NORMALE:
			verso = dir
			return false
		return true
	return false


func _inizia_rotolata(direzione: float) -> void:
	var indietro := _all_indietro(direzione)
	_dir_rotolata = -verso if indietro else verso
	stato = Stato.ROTOLATA
	_t_stato = 0.0
	_imposta_forma(BASSO)
	sprite.riproduci("rotolata_indietro" if indietro else "rotolata", true)
	Rapporto.conta("rotolate")
	if indietro:
		Rapporto.conta("rotolate_indietro")
	_polvere(6)


func _rotolata(delta: float) -> void:
	_t_stato += delta
	var k := clampf(_t_stato / ROTOLATA_DURATA, 0.0, 1.0)
	velocity.x = _dir_rotolata * lerpf(ROTOLATA_VELOCITA, 150.0, k)
	_gravita(delta)
	if is_on_wall():
		if _spazio_in_piedi():
			_fine_rotolata()
			return
		_dir_rotolata = -_dir_rotolata  # in un cunicolo non ci si può alzare: si torna indietro
		verso = -verso
	if _t_stato >= ROTOLATA_DURATA:
		if _spazio_in_piedi():
			_fine_rotolata()
		elif not sprite.in_corso:
			sprite.riproduci("rotolata", true)  # sotto un soffitto basso si continua a rotolare


func _fine_rotolata() -> void:
	_imposta_forma(ALTO)
	stato = Stato.NORMALE
	_t_pausa_rotolata = ROTOLATA_PAUSA


func _inizia_schivata(a_terra: bool, direzione: float = 0.0) -> void:
	# Senza direzione: a terra balzo all'indietro, in aria scatto in avanti.
	# Con la direzione dello sguardo: scatto in avanti; con quella opposta: scatto all'indietro.
	var indietro := _all_indietro(direzione)
	if absf(direzione) <= 0.01:
		_schivata_avanti = not a_terra
	else:
		_schivata_avanti = not indietro
	stato = Stato.SCHIVATA
	_t_stato = 0.0
	_schivata_in_aria = not a_terra
	_dir_schivata = verso if _schivata_avanti else -verso
	if _schivata_in_aria:
		_scatto_usato = true  # uno per salto
		velocity = Vector2(_dir_schivata * _velocita_schivata(), 0.0)
	else:
		velocity.x = _dir_schivata * _velocita_schivata()
		_polvere(4)
	sprite.riproduci("scatto" if _schivata_avanti else "schivata", true)
	Rapporto.conta("schivate")
	Rapporto.conta("scatti_avanti" if _schivata_avanti else "scatti_indietro")


func _velocita_schivata() -> float:
	return SCATTO_VELOCITA if _schivata_avanti else SCHIVATA_VELOCITA


func _schivata(delta: float) -> void:
	_t_stato += delta
	var k := clampf(_t_stato / SCHIVATA_DURATA, 0.0, 1.0)
	if _schivata_in_aria:
		velocity = Vector2(_dir_schivata * lerpf(_velocita_schivata(), 140.0, k), 0.0)
	else:
		velocity.x = _dir_schivata * lerpf(_velocita_schivata(), 60.0, k)
		_gravita(delta)
	if _t_stato >= SCHIVATA_DURATA:
		stato = Stato.NORMALE
		_t_pausa_schivata = SCHIVATA_PAUSA


func _inizia_scavalco(arrivo: Vector2) -> void:
	stato = Stato.SCAVALCO
	_t_stato = 0.0
	_scavalco_da = global_position
	_scavalco_a = arrivo
	velocity = Vector2.ZERO
	_maschera = collision_mask
	collision_mask = 0  # il percorso è già controllato: niente urti durante la salita
	sprite.riproduci("scavalco", true)
	Rapporto.conta("scavalchi")
	Controlli.vibra(0.15, 0.04)


func _scavalco(delta: float) -> void:
	# Prima su (con un filo di avanzamento), poi avanti fin sopra l'ostacolo.
	_t_stato += delta
	velocity = Vector2.ZERO
	var k := clampf(_t_stato / SCAVALCO_DURATA, 0.0, 1.0)
	var meta_x := lerpf(_scavalco_da.x, _scavalco_a.x, 0.2)
	if k < 0.6:
		var u := k / 0.6
		global_position = Vector2(lerpf(_scavalco_da.x, meta_x, u), lerpf(_scavalco_da.y, _scavalco_a.y - 3.0, 1.0 - (1.0 - u) * (1.0 - u)))
	else:
		var u := (k - 0.6) / 0.4
		global_position = Vector2(lerpf(meta_x, _scavalco_a.x, u), _scavalco_a.y - 3.0 * (1.0 - u))
	if k >= 1.0:
		global_position = _scavalco_a
		collision_mask = _maschera
		stato = Stato.NORMALE
		_polvere(3)


func vicino_cassa() -> RigidBody2D:
	# La cassa a portata di mano (a terra, accanto), oppure quella già afferrata.
	if stato == Stato.PRESA and is_instance_valid(_cassa):
		return _cassa
	if stato != Stato.NORMALE or not is_on_floor():
		return null
	var scelta: RigidBody2D = null
	var minima := PRESA_DISTANZA
	for c: RigidBody2D in get_tree().get_nodes_in_group("casse"):
		var dx := absf(c.global_position.x - global_position.x)
		if dx <= minima and absf(c.global_position.y - global_position.y) < 8.0:
			minima = dx
			scelta = c
	return scelta


func _inizia_presa(cassa: RigidBody2D) -> void:
	stato = Stato.PRESA
	_cassa = cassa
	verso = 1 if cassa.global_position.x > global_position.x else -1
	_scarto_cassa = cassa.global_position.x - global_position.x
	_tirata_contata = false
	velocity.x = 0.0
	add_collision_exception_with(cassa)  # finché la si tiene, la cassa segue senza urtare
	sprite.riproduci("presa", true)
	Rapporto.conta("prese")


func _presa(delta: float) -> void:
	if not Input.is_action_pressed("afferra") or not is_instance_valid(_cassa) or not is_on_floor() \
			or absf(_cassa.global_position.y - global_position.y) > 10.0:
		_lascia_cassa()
		return
	var direzione := Input.get_axis("sinistra", "destra")
	velocity.x = move_toward(velocity.x, direzione * PRESA_VELOCITA, ACCELERAZIONE * delta)
	_gravita(delta)
	# La cassa segue alla stessa distanza, sia spingendo sia tirando.
	var errore := (global_position.x + _scarto_cassa) - _cassa.global_position.x
	_cassa.sleeping = false
	_cassa.linear_velocity.x = velocity.x + errore * 20.0
	if absf(velocity.x) > 5.0 and signf(velocity.x) != float(verso) and not _tirata_contata:
		_tirata_contata = true
		Rapporto.conta("tirate")
	if Input.is_action_just_pressed("salta"):
		_lascia_cassa()


func _lascia_cassa() -> void:
	if is_instance_valid(_cassa):
		remove_collision_exception_with(_cassa)
		_cassa.linear_velocity.x = 0.0
	_cassa = null
	stato = Stato.NORMALE


func _colpito(delta: float) -> void:
	_t_stato += delta
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	_gravita(delta)
	if _t_stato >= 0.28:
		stato = Stato.NORMALE


func _da_morto(delta: float) -> void:
	_t_stato += delta
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	_gravita(delta)
	if _t_stato >= 1.4 and not _morte_segnalata:
		_morte_segnalata = true
		morto.emit()


# ------------------------------------------------------------------ danni

func intoccabile() -> bool:
	if stato == Stato.MORTO or _t_protetto > 0.0 or stato == Stato.SCHIVATA or stato == Stato.SCAVALCO:
		return true
	return stato == Stato.ROTOLATA and _t_stato > 0.03 and _t_stato < 0.33


func subisci(danno: int, da: Vector2, spinta: float) -> bool:
	if stato == Stato.MORTO:
		return false
	if intoccabile():
		if stato == Stato.ROTOLATA or stato == Stato.SCHIVATA:
			Rapporto.conta("colpi_evitati")
		return false
	vita = maxi(0, vita - danno)
	vita_cambiata.emit(vita, VITA_MASSIMA)
	Rapporto.conta("colpi_subiti")
	Rapporto.evento("colpito", {"vita": vita, "x": roundi(global_position.x), "y": roundi(global_position.y)})
	Controlli.vibra(0.8, 0.2)
	scuoti(5.0)
	Effetti.lampo(sprite)
	if vita <= 0:
		_muori()
		return true
	_t_protetto = PROTEZIONE_DOPO_COLPO
	if stato == Stato.PRESA:
		_lascia_cassa()
	if stato != Stato.ROTOLATA:
		var lato := signf(global_position.x - da.x)
		if lato == 0.0:
			lato = -verso
		stato = Stato.COLPITO
		_t_stato = 0.0
		velocity = Vector2(lato * spinta, -170.0)
		sprite.riproduci("colpito", true)
	return true


func _muori() -> void:
	if stato == Stato.PRESA:
		_lascia_cassa()
	if stato != Stato.ROTOLATA or _spazio_in_piedi():
		_imposta_forma(ALTO)  # sotto un soffitto basso si resta bassi anche da morti
	stato = Stato.MORTO
	_t_stato = 0.0
	_bersaglio.set_deferred("monitorable", false)
	sprite.riproduci("morte", true)
	Rapporto.conta("morti")
	Rapporto.evento("morte", {"x": roundi(global_position.x), "y": roundi(global_position.y)})
	Controlli.vibra(1.0, 0.4)


func scuoti(forza: float) -> void:
	if not Dispositivo.in_prova:
		_scossa = maxf(_scossa, forza)


# ------------------------------------------------------------------ movimento

func _muovi(delta: float, a_terra: bool, direzione: float) -> void:
	var accelerazione := ACCELERAZIONE_ARIA
	if a_terra:
		accelerazione = ACCELERAZIONE if absf(direzione) > 0.01 else ATTRITO
	velocity.x = move_toward(velocity.x, direzione * VELOCITA, accelerazione * delta)


func _gravita(delta: float) -> void:
	var g := GRAVITA_SU if velocity.y < 0.0 else GRAVITA_GIU
	velocity.y = minf(velocity.y + g * delta, CADUTA_MASSIMA)


func _imposta_forma(misura: Vector2) -> void:
	_rett.size = misura
	_forma.position = Vector2(0.0, -misura.y * 0.5)


func _spazio_in_piedi() -> bool:
	return _libero(global_position)


func _appiglio(sopra: float, sotto: float) -> Variant:
	# Cerca, subito davanti, una superficie fra "sopra" e "sotto" pixel più in alto dei piedi
	# con spazio per stare in piedi: restituisce dove arrivare, oppure null.
	var fx := global_position.x + verso * (ALTO.x * 0.5 + 5.0)
	var domanda := PhysicsRayQueryParameters2D.create(Vector2(fx, global_position.y - sopra),
			Vector2(fx, global_position.y - sotto), Effetti.S_MONDO | Effetti.S_PIATTAFORME | Effetti.S_OGGETTI, [get_rid()])
	var esito := get_world_2d().direct_space_state.intersect_ray(domanda)
	if esito.is_empty() or (esito["normal"] as Vector2).y > -0.7:
		return null
	var arrivo := Vector2(global_position.x + verso * (ALTO.x * 0.5 + 9.0), (esito["position"] as Vector2).y - 0.5)
	return arrivo if _libero(arrivo) else null


func _libero(piedi: Vector2) -> bool:
	var prova := RectangleShape2D.new()
	prova.size = Vector2(ALTO.x - 2.0, ALTO.y - 2.0)
	var domanda := PhysicsShapeQueryParameters2D.new()
	domanda.shape = prova
	domanda.transform = Transform2D(0.0, piedi + Vector2(0.0, -ALTO.y * 0.5 - 1.0))
	domanda.collision_mask = Effetti.S_MONDO | Effetti.S_OGGETTI
	domanda.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(domanda, 1).is_empty()


func _su_piattaforma() -> bool:
	for i in get_slide_collision_count():
		var corpo := get_slide_collision(i).get_collider() as CollisionObject2D
		if corpo != null and (corpo.collision_layer & Effetti.S_PIATTAFORME) != 0:
			return true
	return false


func _spingi_oggetti(delta: float) -> void:
	if stato != Stato.NORMALE and stato != Stato.ATTACCO:
		return
	for i in get_slide_collision_count():
		var urto := get_slide_collision(i)
		var corpo := urto.get_collider() as RigidBody2D
		if corpo != null and absf(urto.get_normal().x) > 0.8:
			var lato := -signf(urto.get_normal().x)
			corpo.sleeping = false
			corpo.linear_velocity.x = move_toward(corpo.linear_velocity.x, lato * SPINTA_CASSE, 900.0 * delta)


func _atterrato() -> void:
	if _velocita_caduta > 220.0:
		_t_atterra = 0.14
		_polvere(5)
		Controlli.vibra(0.2, 0.05)


# ------------------------------------------------------------------ aspetto

func _aggiorna_aspetto() -> void:
	sprite.flip_h = verso < 0
	var lampeggia := _t_protetto > 0.0 and stato != Stato.MORTO and int(_t_protetto * 14.0) % 2 == 0
	sprite.modulate.a = 0.35 if lampeggia else 1.0
	if stato == Stato.PRESA:
		if absf(velocity.x) < 5.0:
			sprite.riproduci("presa")
		else:
			sprite.riproduci("spinge" if signf(velocity.x) == float(verso) else "tira")
		return
	if stato != Stato.NORMALE:
		return
	if is_on_floor():
		if _t_atterra > 0.0:
			sprite.riproduci("atterra")
		elif absf(velocity.x) > 12.0:
			sprite.riproduci("corsa")
		else:
			sprite.riproduci("fermo")
	elif velocity.y < -40.0:
		sprite.riproduci("salto")
	else:
		sprite.riproduci("aria")


func _polvere(quanta: int) -> void:
	Effetti.scoppio(get_parent(), global_position + Vector2(0, -2), Color(0.55, 0.52, 0.5, 0.6), quanta, 38.0, 0.35, 40.0,
			false, 1.0, Vector2.UP, 80.0)


func _fendente() -> void:
	# Scia del colpo di spada: una mezzaluna chiara che svanisce subito.
	var punti := PackedVector2Array()
	var passi := 10
	var da := -1.25 if _colpo_numero == 1 else -0.9
	var a := 1.0 if _colpo_numero == 1 else 1.25
	for i in passi + 1:
		var angolo := lerpf(da, a, float(i) / passi)
		punti.append(Vector2(cos(angolo), sin(angolo)) * 30.0)
	for i in passi + 1:
		var angolo := lerpf(a, da, float(i) / passi)
		var raggio := 30.0 - 9.0 * sin(PI * float(i) / passi)
		punti.append(Vector2(cos(angolo), sin(angolo)) * raggio)
	var arco := Polygon2D.new()
	arco.polygon = punti
	arco.color = Color(0.8, 0.86, 1.0, 0.8)
	arco.material = Effetti.materiale_luminoso()
	arco.light_mask = 0
	arco.position = Vector2(verso * 8.0, -24.0)
	arco.scale.x = verso
	arco.z_index = 5
	add_child(arco)
	var tw := arco.create_tween()
	tw.tween_property(arco, "modulate:a", 0.0, 0.14)
	tw.tween_callback(arco.queue_free)
