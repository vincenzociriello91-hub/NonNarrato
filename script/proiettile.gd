class_name Proiettile
extends Area2D
# Colpi che volano. Dei nemici: la sfera di luce del mago, la freccia delle balestre e dell'arciere
# (feriscono chi gioca e si spezzano con un colpo di spada). Di chi gioca: magia, dardo e freccia
# (feriscono nemici, rompono barili, accendono bracieri, spengono i colpi nemici).
# Tutti si spengono contro i muri.

const COLORE := Color(0.42, 0.86, 1.0)
const COLORE_MAGIA := Color(0.74, 0.52, 1.0)
const AMICI := ["magia_eroe", "dardo", "freccia_eroe"]
# Frecce e dardi cadono un po' mentre volano (traiettoria a parabola) e puntano sempre dove vanno.
# Le sfere di magia volano dritte. Le balestre murate (senza autore) tirano dritto.
const GRAVITA_TIPO := {"freccia": 150.0, "dardo": 90.0, "freccia_eroe": 140.0}
const LUNGHI := ["freccia", "dardo", "freccia_eroe"]

var tipo := "sfera"               # "sfera", "freccia", oppure di chi gioca: "magia_eroe", "dardo", "freccia_eroe"
var velocita := Vector2.ZERO
var danno := 1
var autore: Node                  # chi l'ha lanciata: saprà se è andata a segno
var tattica := ""
var raggio_esplosione := 0.0      # magia caricata: esplode e colpisce tutti attorno
var perfora := 0                  # freccia a carica piena: quanti altri nemici può ancora attraversare
var gravita := -1.0               # -1 = quella del tipo (GRAVITA_TIPO); 0 = dritto
var _gia_colpiti: Array = []
var _vita := 3.5
var _spenta := false
var _colpito := false
var _materiale_colpito := ""	  # di cosa era fatto ciò che ha colpito: dà il tipo di schegge (vedi _svanisci)


static func gravita_di(tipo_colpo: String) -> float:
	return float(GRAVITA_TIPO.get(tipo_colpo, 0.0))


static func lancio(da: Vector2, a: Vector2, velocita_tiro: float, g: float) -> Vector2:
	# Velocità di partenza per arrivare in "a" cadendo con gravità g: un po' più in alto della linea dritta.
	var tempo := maxf(da.distance_to(a) / maxf(velocita_tiro, 1.0), 0.01)
	return (a - da) / tempo - Vector2(0.0, 0.5 * g * tempo)


func _ready() -> void:
	z_index = 12
	if gravita < 0.0:
		gravita = gravita_di(tipo) if (amico() or autore != null) else 0.0
	if amico():
		collision_layer = Effetti.S_COLPI_GIOCATORE
		collision_mask = Effetti.S_MONDO | Effetti.S_BERSAGLI
		add_to_group("tiri_eroe")  # i nemici che hanno imparato a schivarli li guardano arrivare
		match tipo:
			"magia_eroe":
				_vita = 1.6
				_aspetto_sfera(COLORE_MAGIA, 8.0 if raggio_esplosione > 0.0 else 5.0)
			"dardo":
				_vita = 0.9
				_aspetto_lungo("dardo", Vector2(12, 4))
			_:
				_vita = 1.4
				_aspetto_lungo("freccia", Vector2(16, 4))
	else:
		collision_layer = Effetti.S_BERSAGLI
		collision_mask = Effetti.S_MONDO | Effetti.S_BERSAGLIO_GIOCATORE
		set_meta("bersaglio", self)
		add_to_group("sfere")  # il bot le guarda arrivare
		if tipo == "freccia":
			_aspetto_freccia()
		else:
			_aspetto_sfera(COLORE, 4.0)
	body_entered.connect(func(corpo: Node2D) -> void:
		if amico() and corpo is Struttura:
			_colpisci_nemico(corpo)   # un muro crepato o un ripiano di legno: anche un tiro lo crepa
		elif _materiale_colpito == "":
			_materiale_colpito = "pietra"   # un muro: schegge di pietra
		_svanisci())
	area_entered.connect(_su_area)


func amico() -> bool:
	return AMICI.has(tipo)


func _aspetto_sfera(colore: Color, raggio: float) -> void:
	var cerchio := CircleShape2D.new()
	cerchio.radius = raggio
	var forma := CollisionShape2D.new()
	forma.shape = cerchio
	add_child(forma)

	var alone := Polygon2D.new()
	alone.polygon = PackedVector2Array([Vector2(-raggio, 0), Vector2(0, -raggio), Vector2(raggio, 0), Vector2(0, raggio)])
	alone.color = colore
	alone.material = Effetti.materiale_luminoso()
	alone.light_mask = 0
	add_child(alone)
	var cuore := Polygon2D.new()
	cuore.polygon = PackedVector2Array([Vector2(-2, 0), Vector2(0, -2), Vector2(2, 0), Vector2(0, 2)])
	cuore.color = Color(1, 1, 1)
	cuore.material = Effetti.materiale_luminoso()
	cuore.light_mask = 0
	add_child(cuore)

	var scia := CPUParticles2D.new()
	scia.amount = Effetti.quantita(10)
	scia.lifetime = 0.35
	scia.local_coords = false
	scia.spread = 180.0
	scia.initial_velocity_min = 2.0
	scia.initial_velocity_max = 10.0
	scia.gravity = Vector2.ZERO
	scia.color = colore
	scia.color_ramp = Effetti.sfumatura()
	scia.material = Effetti.materiale_luminoso()
	scia.light_mask = 0
	add_child(scia)

	if Dispositivo.livello != "bassa":
		add_child(Effetti.luce(colore, 62.0, 0.9, 20.0))


func _aspetto_freccia() -> void:
	# Una freccia di balestra murata arriva poco oltre la piastra; quella dell'arciere va più lontano.
	_vita = 1.6 if autore != null else 0.75
	var rett := RectangleShape2D.new()
	rett.size = Vector2(16, 4)
	var forma := CollisionShape2D.new()
	forma.shape = rett
	add_child(forma)
	var s := SpriteAnimato.new()
	s.carica("freccia")
	s.light_mask = Effetti.L_DAVANTI
	s.set_process(false)
	add_child(s)
	rotation = (-velocita).angle()   # lo sprite guarda a sinistra: punta dove vola (prima restava orizzontale)


func _aspetto_lungo(foglio: String, misura: Vector2) -> void:
	# Dardo o freccia di chi gioca: sprite che guarda a sinistra, girato verso dove vola.
	var rett := RectangleShape2D.new()
	rett.size = misura
	var forma := CollisionShape2D.new()
	forma.shape = rett
	add_child(forma)
	var s := SpriteAnimato.new()
	s.carica(foglio)
	s.light_mask = Effetti.L_DAVANTI
	s.set_process(false)
	add_child(s)
	rotation = (-velocita).angle()   # lo sprite punta a sinistra: lo giro nella direzione del volo


func _physics_process(delta: float) -> void:
	velocita.y += gravita * delta
	position += velocita * delta
	if LUNGHI.has(tipo) and velocita.length_squared() > 1.0:
		rotation = (-velocita).angle()
	_vita -= delta
	if _vita <= 0.0:
		_svanisci()


func _su_area(area: Area2D) -> void:
	var chi: Variant = area.get_meta("bersaglio", null)
	if amico():
		_colpisci_nemico(chi)
		return
	if chi is Giocatore and (chi as Giocatore).sta_parando(global_position):
		(chi as Giocatore).subisci(danno, global_position, 150.0, null)   # parato dallo scudo: si spegne qui
		_materiale_colpito = "metallo"
		_svanisci()
		return
	if chi is Giocatore and (chi as Giocatore).subisci(danno, global_position, 150.0, autore):
		_colpito = true
		_materiale_colpito = "carne"
		if tipo == "freccia" and autore == null:
			Rapporto.conta("trappole_subite")
			Rapporto.evento("trappola", {"cosa": "freccia", "x": roundi(global_position.x)})
		_svanisci()


func _colpisci_nemico(chi: Variant) -> void:
	# Tiro di chi gioca: nemici, barili, bracieri, colpi nemici (che si spengono insieme al tiro).
	if chi == null or not is_instance_valid(chi) or chi is Giocatore or (chi is Proiettile and (chi as Proiettile).amico()):
		return
	if not chi.has_method("subisci"):
		return
	if _gia_colpiti.has(chi):
		return
	_gia_colpiti.append(chi)
	var a_segno := false
	if chi is Nemico:
		a_segno = (chi as Nemico).subisci(danno, global_position - velocita.normalized() * 10.0, 110.0,
				"magia" if tipo == "magia_eroe" else "tiro",
				{"munizione": "magia" if tipo == "magia_eroe" else ("dardi" if tipo == "dardo" else "frecce")})
		if a_segno:
			Rapporto.conta("tiri_a_segno")
	else:
		a_segno = chi.subisci(danno, global_position, 110.0)
	if a_segno:
		_materiale_colpito = Effetti.materiale_di(chi)
	if a_segno and is_instance_valid(autore) and autore.has_method("scuoti"):
		autore.call("scuoti", 1.5)
	if chi is Nemico and perfora > 0:
		perfora -= 1   # trapassa e prosegue
		Rapporto.conta("nemici_trapassati")
		return
	_svanisci()


static func _esplodi(dove: Node, punto: Vector2, danno_esplosione: int, raggio: float, chi: Node, esclusi: Array) -> void:
	# Sfera caricata: colpisce tutti i nemici attorno. Statica e chiamata dopo: il proiettile è già sparito.
	if not is_instance_valid(dove):
		return
	var colpiti := 0
	for n: Node in dove.get_tree().get_nodes_in_group("nemici"):
		var nemico := n as Nemico
		if nemico == null or esclusi.has(nemico) or not nemico.bersagliabile():
			continue
		if nemico.centro().distance_to(punto) <= raggio:
			if nemico.subisci(danno_esplosione, punto, 160.0, "magia"):
				colpiti += 1
	Rapporto.conta("esplosioni")
	Suoni.suona("esplosione", punto)
	if colpiti > 1:
		Rapporto.conta("esplosioni_multiple")
	Effetti.scoppio(dove, punto, COLORE_MAGIA, 24, 160.0, 0.45, 0.0)
	if is_instance_valid(chi) and chi.has_method("scuoti"):
		chi.call("scuoti", 3.0)


func subisci(_danno: int, _da: Vector2, _spinta: float) -> bool:
	Rapporto.conta("frecce_spezzate" if tipo == "freccia" else "magie_spezzate")
	_svanisci()
	return true


func _svanisci() -> void:
	if _spenta:
		return
	_spenta = true
	if raggio_esplosione > 0.0:
		Proiettile._esplodi.call_deferred(get_parent(), global_position, danno, raggio_esplosione, autore, _gia_colpiti.duplicate())
	if is_instance_valid(autore) and autore.has_method("esito_sfera"):
		autore.esito_sfera(tattica, _colpito)
	if raggio_esplosione <= 0.0:
		Suoni.suona("impatto_tiro", global_position, -6.0, 0.8 if tipo in ["sfera", "magia_eroe"] else 1.2)
	match tipo:
		"freccia", "freccia_eroe", "dardo":
			if _materiale_colpito != "":
				# Schegge di ciò che ha colpito, nella direzione del volo (a metà forza: sono colpi piccoli).
				Effetti.impatto(get_parent(), global_position, _materiale_colpito, signf(velocita.x), 0.6)
			else:
				Effetti.scoppio(get_parent(), global_position, Color(0.6, 0.5, 0.4, 0.8), 6, 60.0, 0.3, 200.0, false)
		"magia_eroe":
			Effetti.scoppio(get_parent(), global_position, COLORE_MAGIA, 10, 80.0, 0.35, 0.0)
		_:
			Effetti.scoppio(get_parent(), global_position, COLORE, 8, 70.0, 0.3, 0.0)
	queue_free()
