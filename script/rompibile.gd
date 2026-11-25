class_name Rompibile
extends Area2D
# Oggetto che si rompe a colpi di spada o da lontano (barili). Rompendosi va in pezzi veri,
# che cadono e rimbalzano, e solleva polvere; a volte lascia munizioni.

var foglio := "barile"
var vita := 1
var silenzioso := false   # per il preriscaldamento all'avvio: niente rapporto né vibrazione
var sprite: SpriteAnimato


func _ready() -> void:
	collision_layer = Effetti.S_BERSAGLI
	collision_mask = 0
	monitoring = false
	set_meta("bersaglio", self)
	z_index = 2

	sprite = SpriteAnimato.new()
	sprite.carica(foglio)
	sprite.light_mask = Effetti.L_DAVANTI
	sprite.set_process(false)
	add_child(sprite)

	var misura := Vector2(sprite.dimensione())
	var rett := RectangleShape2D.new()
	rett.size = Vector2(misura.x - 4.0, misura.y - 6.0)
	var forma := CollisionShape2D.new()
	forma.shape = rett
	forma.position = Vector2(0.0, -misura.y * 0.5)
	add_child(forma)
	Effetti.occlusore(self, Rect2(-misura.x * 0.5 + 3.0, -misura.y + 6.0, misura.x - 6.0, misura.y - 8.0))


func subisci(danno: int, da: Vector2, _spinta: float) -> bool:
	if vita <= 0:
		return false   # già in pezzi (si rompe al passo dopo)
	vita -= danno
	if vita > 0:
		Effetti.lampo(sprite)
		var tw := create_tween()
		tw.tween_property(sprite, "rotation", 0.12 * signf(global_position.x - da.x), 0.05)
		tw.tween_property(sprite, "rotation", 0.0, 0.12)
		return true
	set_deferred("monitorable", false)
	_rompi.call_deferred(da)   # i pezzi nascono fuori dal passo della fisica (un tiro lo rompe dentro)
	return true


func _rompi(da: Vector2) -> void:
	if not silenzioso:
		Rapporto.conta("oggetti_rotti")
		Rapporto.evento("rotto", {"cosa": foglio, "x": roundi(global_position.x)})
	var misura := Vector2(sprite.dimensione())
	var angolo := global_position - sprite.piedi()
	var lato := signf(global_position.x - da.x)
	if lato == 0.0:
		lato = 1.0
	var colonne := 2 if misura.x < 40.0 else 3
	var righe := 2
	var w := misura.x / colonne
	var h := misura.y / righe
	for r in righe:
		for c in colonne:
			var regione := Rect2(c * w, r * h, w, h)
			var pezzo := RigidBody2D.new()
			pezzo.collision_layer = 0
			pezzo.collision_mask = Effetti.S_MONDO | Effetti.S_PIATTAFORME
			pezzo.position = angolo + regione.get_center()
			pezzo.z_index = 6
			var figura := Sprite2D.new()
			figura.texture = sprite.texture
			figura.region_enabled = true
			figura.region_rect = regione
			figura.light_mask = Effetti.L_DAVANTI
			pezzo.add_child(figura)
			var cerchio := CircleShape2D.new()
			cerchio.radius = minf(w, h) * 0.35
			var forma := CollisionShape2D.new()
			forma.shape = cerchio
			pezzo.add_child(forma)
			pezzo.linear_velocity = Vector2(lato * randf_range(40.0, 130.0) + randf_range(-40.0, 40.0), randf_range(-190.0, -70.0))
			pezzo.angular_velocity = randf_range(-9.0, 9.0)
			get_parent().add_child(pezzo)
			var tw := pezzo.create_tween()
			# Nel preriscaldamento i pezzi spariscono finché lo schermo è ancora nero.
			tw.tween_interval(0.25 if silenzioso else 1.6)
			tw.tween_property(pezzo, "modulate:a", 0.0, 0.1 if silenzioso else 0.6)
			tw.tween_callback(pezzo.queue_free)
	Effetti.scoppio(get_parent(), global_position + Vector2(0.0, -misura.y * 0.5), Color(0.52, 0.43, 0.33, 0.8),
			14, 90.0, 0.5, 220.0, false)
	if not silenzioso:
		Controlli.vibra(0.5, 0.1)
		_lascia_munizioni()
	queue_free()


func _lascia_munizioni() -> void:
	# Un barile su tre lascia qualche dardo o qualche freccia.
	if randf() > 0.35:
		return
	var r := Raccoglibile.new()
	r.cosa = "dardi" if randf() < 0.55 else "frecce"
	r.quante = 3 if r.cosa == "dardi" else 2
	r.position = global_position
	get_parent().add_child.call_deferred(r)
