class_name EnigmaBracieri
extends Node2D
# Enigma: tre bracieri spenti e una tavoletta con tre segni colorati. Si accendono colpendoli;
# ognuno brucia di un colore. Accesi nell'ordine della tavoletta aprono il passaggio (bersaglio.apri());
# nell'ordine sbagliato si spengono tutti. L'ordine cambia a ogni sogno.

signal risolto

# Colori che la palette fissa del gioco sa mostrare bene.
const COLORI := [
	["azzurro", Color(0.42, 0.85, 0.95)],
	["viola", Color(0.66, 0.4, 0.85)],
	["rosso", Color(0.95, 0.3, 0.24)],
]

var posti: Array = []              # x dei tre bracieri (piedi alla quota del nodo)
var tavoletta := Vector2.ZERO      # dove sta la tavoletta (piedi)
var bersaglio: Node
var ordine: Array = []             # indici dei bracieri, nell'ordine giusto
var accesi: Array = []             # indici nell'ordine in cui sono stati accesi
var soluzione := false
var bracieri: Array = []

var _in_spegnimento := false


class Braciere extends Area2D:
	var indice := 0
	var colore := Color.WHITE
	var acceso := false
	var enigma: Node
	var _fuoco: CPUParticles2D
	var _luce: PointLight2D
	var _alone: Sprite2D
	var _sprite: SpriteAnimato

	func _ready() -> void:
		collision_layer = Effetti.S_BERSAGLI
		collision_mask = 0
		monitoring = false
		set_meta("bersaglio", self)
		set_meta("materiale", "metallo")
		var rett := RectangleShape2D.new()
		rett.size = Vector2(26, 40)
		var forma := CollisionShape2D.new()
		forma.shape = rett
		forma.position = Vector2(0, -20)
		add_child(forma)
		_sprite = SpriteAnimato.new()
		_sprite.carica("braciere")
		_sprite.light_mask = Effetti.L_DAVANTI
		_sprite.set_process(false)
		add_child(_sprite)
		Effetti.occlusore(self, Rect2(-6, -38, 12, 36), false)   # oggetti: niente ombra (strisce dalle torce)
		_fuoco = CPUParticles2D.new()
		_fuoco.position = Vector2(0, -40)
		_fuoco.amount = Effetti.quantita(36)
		_fuoco.lifetime = 0.6
		_fuoco.direction = Vector2.UP
		_fuoco.spread = 16.0
		_fuoco.initial_velocity_min = 20.0
		_fuoco.initial_velocity_max = 56.0
		_fuoco.gravity = Vector2(0, -40)
		_fuoco.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		_fuoco.emission_sphere_radius = 6.0
		_fuoco.scale_amount_min = 2.0
		_fuoco.scale_amount_max = 4.6
		var sfuma := Gradient.new()
		sfuma.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		sfuma.colors = PackedColorArray([Color(1, 1, 1, 1), colore, Color(colore.r * 0.4, colore.g * 0.4, colore.b * 0.4, 0.0)])
		_fuoco.color_ramp = sfuma
		_fuoco.material = Effetti.materiale_luminoso()
		_fuoco.light_mask = 0
		_fuoco.emitting = false
		add_child(_fuoco)
		_alone = Sprite2D.new()
		_alone.texture = Effetti.texture_luce()
		_alone.position = Vector2(0, -44)
		_alone.scale = Vector2.ONE * 0.38
		_alone.modulate = Color(colore.r, colore.g, colore.b, 0.6)
		_alone.material = Effetti.materiale_luminoso()
		_alone.light_mask = 0
		_alone.visible = false
		add_child(_alone)
		_luce = Effetti.luce(colore, 160.0, 2.2, 50.0)
		_luce.position = Vector2(0, -46)
		_luce.enabled = false
		add_child(Ombra.luce(_luce))
		Ombra.aggiungi(self, null, 26.0)

	func subisci(_danno: int, _da: Vector2, _spinta: float) -> bool:
		if acceso:
			return false
		return enigma.accendi(self)

	func accendi() -> void:
		acceso = true
		_fuoco.emitting = true
		_alone.visible = true
		_luce.enabled = Dispositivo.livello != "bassa"
		Effetti.scoppio(get_parent(), position + Vector2(0, -42), colore, 12, 70.0, 0.5, -60.0)
		Suoni.suona("bracere", position)

	func spegni() -> void:
		acceso = false
		_fuoco.emitting = false
		_alone.visible = false
		_luce.enabled = false
		Effetti.scoppio(get_parent(), position + Vector2(0, -42), Color(0.4, 0.4, 0.45, 0.7), 10, 40.0, 0.8, -40.0, false)


func _ready() -> void:
	# L'ordine giusto cambia da un sogno all'altro, ma è lo stesso per tutto il sogno.
	var caso := RandomNumberGenerator.new()
	caso.seed = 1103 + int(Memoria.sogni) * 31
	ordine = [0, 1, 2]
	for k in range(2, 0, -1):
		var j := caso.randi() % (k + 1)
		var tmp: int = ordine[k]
		ordine[k] = ordine[j]
		ordine[j] = tmp
	for i in posti.size():
		var b := Braciere.new()
		b.indice = i
		b.colore = COLORI[i][1]
		b.enigma = self
		b.position = Vector2(float(posti[i]), 0.0)
		add_child(b)
		bracieri.append(b)
	_crea_tavoletta()


func _crea_tavoletta() -> void:
	var s := SpriteAnimato.new()
	s.carica("tavoletta")
	s.light_mask = Effetti.L_SFONDO | Effetti.L_DAVANTI
	s.set_process(false)
	s.position = tavoletta
	s.z_index = -40
	add_child(s)
	# Tre fiammelle incise, nell'ordine giusto, da sinistra a destra.
	for i in 3:
		var c: Color = COLORI[ordine[i]][1]
		var segno := Polygon2D.new()
		segno.polygon = PackedVector2Array([Vector2(0, -6), Vector2(3, -1), Vector2(2, 3), Vector2(-2, 3), Vector2(-3, -1)])
		segno.color = c
		segno.material = Effetti.materiale_luminoso()
		segno.light_mask = 0
		segno.position = tavoletta + Vector2(-11.0 + 11.0 * i, -14.0)
		segno.z_index = -39
		add_child(segno)


func accendi(b: Braciere) -> bool:
	if _in_spegnimento or soluzione:
		return false
	b.accendi()
	accesi.append(b.indice)
	Rapporto.evento("braciere", {"colore": COLORI[b.indice][0], "accesi": accesi.size()})
	var i := accesi.size() - 1
	if accesi[i] != ordine[i]:
		_sbagliato()
	elif accesi.size() == ordine.size():
		_giusto()
	return true


func _sbagliato() -> void:
	_in_spegnimento = true
	Rapporto.conta("enigmi_sbagliati")
	await get_tree().create_timer(0.6, false).timeout
	if not is_instance_valid(self):
		return
	for b: Braciere in bracieri:
		if b.acceso:
			b.spegni()
	accesi.clear()
	get_tree().call_group("hud", "messaggio", "Le fiamme si spengono. Non era quest'ordine.", 2.5)
	_in_spegnimento = false


func _giusto() -> void:
	soluzione = true
	Rapporto.conta("enigmi_risolti")
	Rapporto.evento("enigma", {"nome": "bracieri"})
	get_tree().call_group("hud", "messaggio", "Qualcosa si muove nella pietra.", 2.5)
	if bersaglio != null:
		bersaglio.apri()
	risolto.emit()
