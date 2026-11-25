class_name Proiettile
extends Area2D
# Colpi che volano: la sfera di luce del mago, la freccia delle balestre nei muri.
# Si spengono contro i muri, feriscono chi gioca e si possono spezzare con un colpo di spada.

const COLORE := Color(0.42, 0.86, 1.0)

var tipo := "sfera"               # "sfera" o "freccia"
var velocita := Vector2.ZERO
var danno := 1
var autore: Node                  # chi l'ha lanciata: saprà se è andata a segno
var tattica := ""
var _vita := 3.5
var _spenta := false
var _colpito := false


func _ready() -> void:
	collision_layer = Effetti.S_BERSAGLI
	collision_mask = Effetti.S_MONDO | Effetti.S_BERSAGLIO_GIOCATORE
	set_meta("bersaglio", self)
	add_to_group("sfere")  # il bot le guarda arrivare
	z_index = 12
	if tipo == "freccia":
		_aspetto_freccia()
	else:
		_aspetto_sfera()
	body_entered.connect(func(_corpo: Node2D) -> void: _svanisci())
	area_entered.connect(_su_area)


func _aspetto_sfera() -> void:
	var cerchio := CircleShape2D.new()
	cerchio.radius = 4.0
	var forma := CollisionShape2D.new()
	forma.shape = cerchio
	add_child(forma)

	var alone := Polygon2D.new()
	alone.polygon = PackedVector2Array([Vector2(-4, 0), Vector2(0, -4), Vector2(4, 0), Vector2(0, 4)])
	alone.color = COLORE
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
	scia.color = COLORE
	scia.color_ramp = Effetti.sfumatura()
	scia.material = Effetti.materiale_luminoso()
	scia.light_mask = 0
	add_child(scia)

	if Dispositivo.livello != "bassa":
		add_child(Effetti.luce(COLORE, 62.0, 0.9, 20.0))


func _aspetto_freccia() -> void:
	_vita = 0.75   # una freccia di balestra arriva poco oltre la piastra, non attraversa tutta la galleria
	var rett := RectangleShape2D.new()
	rett.size = Vector2(16, 4)
	var forma := CollisionShape2D.new()
	forma.shape = rett
	add_child(forma)
	var s := SpriteAnimato.new()
	s.carica("freccia")
	s.light_mask = Effetti.L_DAVANTI
	s.set_process(false)
	s.flip_h = velocita.x > 0.0     # lo sprite guarda a sinistra
	add_child(s)


func _physics_process(delta: float) -> void:
	position += velocita * delta
	_vita -= delta
	if _vita <= 0.0:
		_svanisci()


func _su_area(area: Area2D) -> void:
	var chi: Variant = area.get_meta("bersaglio", null)
	if chi is Giocatore and (chi as Giocatore).subisci(danno, global_position, 150.0, autore):
		_colpito = true
		if tipo == "freccia":
			Rapporto.conta("trappole_subite")
			Rapporto.evento("trappola", {"cosa": "freccia", "x": roundi(global_position.x)})
		_svanisci()


func subisci(_danno: int, _da: Vector2, _spinta: float) -> bool:
	Rapporto.conta("frecce_spezzate" if tipo == "freccia" else "magie_spezzate")
	_svanisci()
	return true


func _svanisci() -> void:
	if _spenta:
		return
	_spenta = true
	if is_instance_valid(autore) and autore.has_method("esito_sfera"):
		autore.esito_sfera(tattica, _colpito)
	if tipo == "freccia":
		Effetti.scoppio(get_parent(), global_position, Color(0.6, 0.5, 0.4, 0.8), 6, 60.0, 0.3, 200.0, false)
	else:
		Effetti.scoppio(get_parent(), global_position, COLORE, 8, 70.0, 0.3, 0.0)
	queue_free()
