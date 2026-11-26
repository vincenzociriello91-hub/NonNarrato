class_name Struttura
extends StaticBody2D
# Una parte della stanza che si può rompere a colpi (spada, tiri): un muro crepato che nasconde
# una stanza segreta, assi di legno sopra un sottopassaggio, un ripiano di legno.
# Si vede che è fragile (crepe o assi), a ogni colpo si crepa di più; rotta, sparisce e scopre
# quello che nascondeva ("veli": nodi che svaniscono). Si ricostruisce solo con una stanza nuova.

signal rotta

const COLORE_LEGNO := Color(0.42, 0.29, 0.19)
const COLORE_LEGNO_SCURO := Color(0.24, 0.16, 0.11)

var nome := ""
var tipo := "muro"                 # "muro" (pietra) o "legno"
var misura := Vector2(12, 70)      # rettangolo, con l'angolo in alto a sinistra in "position"
var vita := 3
var veli: Array[CanvasItem] = []   # cosa sparisce quando si rompe (il buio davanti alla stanza segreta)
var integra := true

var _vita_iniziale := 3
var _disegno: Node2D
var _crepe: Line2D
var _bersaglio: Area2D
var _occlusore: LightOccluder2D
var _forma: CollisionShape2D


func _ready() -> void:
	collision_layer = Effetti.S_MONDO
	collision_mask = 0
	_vita_iniziale = vita
	var r := RectangleShape2D.new()
	r.size = misura
	_forma = CollisionShape2D.new()
	_forma.shape = r
	_forma.position = misura * 0.5
	add_child(_forma)
	_disegno = Node2D.new()
	add_child(_disegno)
	if tipo == "legno":
		_disegna_legno()
	else:
		_disegna_muro()
	_crepe = Line2D.new()
	_crepe.width = 1.0
	_crepe.default_color = Color(0.05, 0.04, 0.06) if tipo == "muro" else COLORE_LEGNO_SCURO
	_crepe.light_mask = Effetti.L_DAVANTI
	_crepe.z_index = 1
	_disegno.add_child(_crepe)
	_aggiorna_crepe()
	# I colpi la trovano come i barili: un'area "bersaglio".
	_bersaglio = Area2D.new()
	_bersaglio.collision_layer = Effetti.S_BERSAGLI
	_bersaglio.collision_mask = 0
	_bersaglio.monitoring = false
	_bersaglio.set_meta("bersaglio", self)
	var rb := RectangleShape2D.new()
	rb.size = misura + Vector2(6, 6)
	var fb := CollisionShape2D.new()
	fb.shape = rb
	fb.position = misura * 0.5
	_bersaglio.add_child(fb)
	add_child(_bersaglio)
	if tipo == "muro":
		_occlusore = Effetti.occlusore(self, Rect2(Vector2.ZERO, misura), false)   # niente ombra: strisce dalle torce
	add_to_group("strutture")


func _disegna_muro() -> void:
	# Pietra come le fondamenta, un po' più chiara, con un bordo che la stacca dal resto.
	var voce := SpriteAnimato.foglio("fondamenta")
	var s := Sprite2D.new()
	s.texture = voce["texture"]
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(Vector2(7, 3), misura)
	s.light_mask = Effetti.L_DAVANTI
	s.modulate = Color(1.08, 1.04, 1.0)
	_disegno.add_child(s)
	var bordo := Line2D.new()
	bordo.width = 1.0
	bordo.default_color = Color(0.12, 0.1, 0.14)
	bordo.points = PackedVector2Array([Vector2.ZERO, Vector2(0, misura.y), misura, Vector2(misura.x, 0), Vector2.ZERO])
	bordo.light_mask = Effetti.L_DAVANTI
	_disegno.add_child(bordo)


func _disegna_legno() -> void:
	# Assi in fila, con le fessure scure: si capisce subito che sono di legno.
	var orizzontali := misura.x >= misura.y
	var assi := maxi(1, int((misura.x if orizzontali else misura.y) / 16.0))
	for i in assi:
		var p := Polygon2D.new()
		var r := Rect2()
		if orizzontali:
			var w := misura.x / assi
			r = Rect2(i * w, 0, w - 1.0, misura.y)
		else:
			var h := misura.y / assi
			r = Rect2(0, i * h, misura.x, h - 1.0)
		p.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		p.color = COLORE_LEGNO.lerp(COLORE_LEGNO_SCURO, 0.15 * (i % 3))
		p.light_mask = Effetti.L_DAVANTI
		_disegno.add_child(p)
	var chiodi := Line2D.new()
	chiodi.width = 1.0
	chiodi.default_color = COLORE_LEGNO_SCURO
	chiodi.points = PackedVector2Array([Vector2(0, 1), Vector2(misura.x, 1)])
	chiodi.light_mask = Effetti.L_DAVANTI
	_disegno.add_child(chiodi)


func _aggiorna_crepe() -> void:
	# Più colpi ha preso, più crepe si vedono (sempre le stesse: seme dal nome).
	var caso := RandomNumberGenerator.new()
	caso.seed = hash(nome)
	var punti := PackedVector2Array()
	var rami := 2 + (_vita_iniziale - vita) * 2
	for i in rami:
		var da := Vector2(caso.randf_range(0.2, 0.8) * misura.x, caso.randf_range(0.1, 0.9) * misura.y)
		var a := da + Vector2(caso.randf_range(-0.5, 0.5) * misura.x, caso.randf_range(-0.3, 0.3) * misura.y)
		punti.append(da)
		punti.append(a.clamp(Vector2.ZERO, misura))
	_crepe.points = punti


func subisci(danno: int, da: Vector2, _spinta: float) -> bool:
	if not integra:
		return false
	vita -= maxi(1, danno)
	var lato := signf(global_position.x + misura.x * 0.5 - da.x)
	Effetti.scoppio(get_parent(), centro(), Color(0.5, 0.46, 0.44, 0.8) if tipo == "muro" else COLORE_LEGNO,
			6, 60.0, 0.35, 200.0, false, 1.0, Vector2(lato, -0.5).normalized(), 70.0)
	if vita <= 0:
		_rompi.call_deferred()
	else:
		Suoni.suona("crepa", centro())
		_aggiorna_crepe()
		Rapporto.conta("colpi_su_strutture")
	return true


func _rompi() -> void:
	if not integra:
		return
	integra = false
	_forma.set_deferred("disabled", true)
	_bersaglio.set_deferred("monitorable", false)
	if _occlusore != null:
		_occlusore.queue_free()
	Effetti.scoppio(get_parent(), centro(), Color(0.5, 0.46, 0.44, 0.9) if tipo == "muro" else COLORE_LEGNO, 22, 120.0, 0.7, 400.0, false, 1.4)
	Suoni.suona("muro_rotto" if tipo == "muro" else "legno_rotto", centro())
	Controlli.vibra(0.4, 0.12)
	var tw := create_tween()
	tw.tween_property(_disegno, "modulate:a", 0.0, 0.25)
	for velo in veli:
		if is_instance_valid(velo):
			var t2 := velo.create_tween()
			t2.tween_property(velo, "modulate:a", 0.0, 0.6)
			t2.tween_callback(velo.hide)
	Rapporto.conta("strutture_rotte")
	Rapporto.evento("struttura_rotta", {"nome": nome, "tipo": tipo})
	rotta.emit()


func centro() -> Vector2:
	return global_position + misura * 0.5
