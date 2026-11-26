class_name Raccoglibile
extends Area2D
# Da raccogliere passandoci sopra: un fascio di dardi, una faretra di frecce o una pozione (piccola,
# media o grande: salute, stamina, mana, velocità). Le lasciano i barili rotti, i nemici forti e i
# forzieri (vedi Bottino); dopo un po' svaniscono, tranne quelle uscite da un forziere.

const DURATA := 14.0
const DURATA_POZIONE := 22.0
const ATTESA := 0.35               # appena lanciata non si raccoglie: si vede volare fuori
const GRAVITA := 640.0

var cosa := "dardi"                # "dardi", "frecce" o "pozione"
var quante := 3
var tipo_pozione := ""             # solo per le pozioni
var taglia := ""
var lancio := Vector2.ZERO         # velocità con cui salta fuori (poi cade fino a terra)

var _t := 0.0
var _t_attesa := 0.0
var _sprite: SpriteAnimato
var _preso := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = Effetti.S_GIOCATORE
	monitorable = false
	var rett := RectangleShape2D.new()
	rett.size = Vector2(18, 18)
	var forma := CollisionShape2D.new()
	forma.shape = rett
	forma.position = Vector2(0, -9)
	add_child(forma)
	_sprite = SpriteAnimato.new()
	var colore_luce := Color(1.0, 0.82, 0.5)
	if cosa == "pozione":
		_sprite.carica("pozione_" + tipo_pozione)
		_sprite.riproduci(taglia if taglia != "" else "piccola")
		colore_luce = Bottino.COLORI_POZIONE.get(tipo_pozione, colore_luce)
	else:
		_sprite.carica("munizioni_" + cosa)
	_sprite.light_mask = Effetti.L_DAVANTI
	_sprite.set_process(false)
	add_child(_sprite)
	if Dispositivo.profilo.get("luci_doppie", true):
		var bagliore := Effetti.luce(colore_luce, 34.0, 0.8, 14.0)   # si nota anche al buio
		bagliore.position = Vector2(0, -10)
		add_child(bagliore)
	z_index = 3
	if lancio != Vector2.ZERO:
		_t_attesa = ATTESA
	body_entered.connect(_su_corpo)
	add_to_group("raccoglibili")


var permanente := false           # quelli messi nella stanza (per esempio sul ripiano di legno) non spariscono


func _physics_process(delta: float) -> void:
	# Saltata fuori da un nemico o da un forziere: vola e cade finché non tocca terra (o una piattaforma).
	if lancio == Vector2.ZERO:
		return
	lancio.y = minf(lancio.y + GRAVITA * delta, 420.0)
	var arrivo := global_position + lancio * delta
	var q := PhysicsRayQueryParameters2D.create(global_position, arrivo, Effetti.S_MONDO | (Effetti.S_PIATTAFORME if lancio.y > 0.0 else 0))
	var colpo := get_world_2d().direct_space_state.intersect_ray(q)
	if colpo.is_empty():
		global_position = arrivo
		return
	var normale: Vector2 = colpo["normal"]
	if normale.y < -0.5:
		global_position = colpo["position"]
		lancio = Vector2.ZERO
		if cosa == "pozione":
			Suoni.suona("pozione_cade", global_position, -8.0)
	else:
		lancio.x = -lancio.x * 0.3   # contro un muro: rimbalza appena
		if normale.y > 0.5:
			lancio.y = 0.0


func _process(delta: float) -> void:
	if _t_attesa > 0.0:
		_t_attesa -= delta
		if _t_attesa <= 0.0:
			for corpo: Node2D in get_overlapping_bodies():
				_su_corpo(corpo)
	if permanente:
		_t = fmod(_t + delta, 2.0 * PI)
		_sprite.position.y = -2.0 - absf(sin(_t * 3.0)) * 3.0
		return
	_t += delta
	_sprite.position.y = -2.0 - absf(sin(_t * 3.0)) * 3.0   # saltella per farsi notare
	var durata := DURATA_POZIONE if cosa == "pozione" else DURATA
	if _t > durata - 2.0:
		_sprite.visible = int(_t * 8.0) % 2 == 0
	if _t > durata:
		queue_free()


func _su_corpo(corpo: Node2D) -> void:
	if not corpo is Giocatore or _t_attesa > 0.0 or _preso:
		return
	if cosa == "pozione":
		_preso = true
		(corpo as Giocatore).bevi(tipo_pozione, taglia)
		Effetti.scoppio(get_parent(), global_position + Vector2(0, -8), Bottino.COLORI_POZIONE.get(tipo_pozione, Color.WHITE),
				10, 60.0, 0.45, -50.0)
		queue_free()
		return
	var prese := (corpo as Giocatore).raccogli(cosa, quante)
	if prese <= 0:
		return   # già piene: restano lì
	Rapporto.conta("munizioni_raccolte", prese)
	Effetti.scoppio(get_parent(), global_position + Vector2(0, -8), Color(0.95, 0.85, 0.6), 8, 50.0, 0.4, -40.0)
	queue_free()
