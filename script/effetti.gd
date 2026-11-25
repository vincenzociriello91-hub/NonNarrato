class_name Effetti
extends RefCounted
# Piccoli aiuti per luci, scintille e polvere, usati da giocatore, nemici, oggetti e stanza.

# Strati della fisica (gli stessi nomi di project.godot).
const S_MONDO := 1
const S_PIATTAFORME := 2
const S_GIOCATORE := 4
const S_NEMICI := 8
const S_OGGETTI := 16
const S_COLPI_GIOCATORE := 32
const S_COLPI_NEMICI := 64
const S_BERSAGLI := 128
const S_BERSAGLIO_GIOCATORE := 256

# Maschere delle luci: il muro di fondo riceve le ombre, ciò che sta davanti no.
const L_SFONDO := 1
const L_DAVANTI := 2

static var _luce: GradientTexture2D
static var _luminoso: CanvasItemMaterial
static var _piatto: CanvasItemMaterial
static var _sfuma: Gradient


static func texture_luce() -> Texture2D:
	# Alone rotondo che sfuma: è la forma di ogni luce del gioco.
	if _luce == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1), Color(0.55, 0.55, 0.55), Color(0.16, 0.16, 0.16), Color(0, 0, 0)])
		_luce = GradientTexture2D.new()
		_luce.gradient = g
		_luce.width = 128
		_luce.height = 128
		_luce.fill = GradientTexture2D.FILL_RADIAL
		_luce.fill_from = Vector2(0.5, 0.5)
		_luce.fill_to = Vector2(1.0, 0.5)
	return _luce


static func materiale_luminoso() -> CanvasItemMaterial:
	# Per ciò che brilla al buio (fiamme, scintille, magie): non risente dell'oscurità.
	if _luminoso == null:
		_luminoso = CanvasItemMaterial.new()
		_luminoso.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_luminoso.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _luminoso


static func materiale_piatto() -> CanvasItemMaterial:
	if _piatto == null:
		_piatto = CanvasItemMaterial.new()
		_piatto.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _piatto


static func sfumatura() -> Gradient:
	if _sfuma == null:
		_sfuma = Gradient.new()
		_sfuma.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
		_sfuma.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	return _sfuma


static func quantita(base: int) -> int:
	var fattore: float = Dispositivo.profilo.get("particelle", 1.0)
	return maxi(1, roundi(base * fattore))


static func scoppio(genitore: Node, dove: Vector2, colore: Color, quanti: int, velocita: float,
		durata: float = 0.4, gravita: float = 300.0, luminoso: bool = true, grandezza: float = 1.0,
		direzione: Vector2 = Vector2.UP, apertura: float = 180.0) -> CPUParticles2D:
	# Getto di particelle che si spegne da solo (scintille, schegge, polvere).
	var p := CPUParticles2D.new()
	p.position = dove
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = quantita(quanti)
	p.lifetime = durata
	p.direction = direzione
	p.spread = apertura
	p.initial_velocity_min = velocita * 0.35
	p.initial_velocity_max = velocita
	p.gravity = Vector2(0.0, gravita)
	p.scale_amount_min = grandezza
	p.scale_amount_max = grandezza * 2.0
	p.color = colore
	p.color_ramp = sfumatura()
	p.material = materiale_luminoso() if luminoso else materiale_piatto()
	p.light_mask = 0
	p.z_index = 20
	genitore.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


static func fermo_immagine(nodo: Node, durata: float) -> void:
	# Un istante di "fermo" quando un colpo va a segno: dà peso all'impatto.
	if Dispositivo.in_prova or Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	await nodo.get_tree().create_timer(durata, true, false, true).timeout
	Engine.time_scale = 1.0


static func occlusore(genitore: Node, rett: Rect2) -> LightOccluder2D:
	# Sagoma che proietta ombra sul muro di fondo.
	var forma := OccluderPolygon2D.new()
	forma.polygon = PackedVector2Array([
		rett.position, Vector2(rett.end.x, rett.position.y), rett.end, Vector2(rett.position.x, rett.end.y),
	])
	var o := LightOccluder2D.new()
	o.occluder = forma
	o.occluder_light_mask = L_SFONDO
	genitore.add_child(o)
	return o


static func lampo(sprite: CanvasItem, durata: float = 0.08) -> void:
	# Lo sprite appare per un attimo a piena luce: segnala il colpo ricevuto.
	if sprite.has_method("lampo"):
		sprite.call("lampo", durata)  # la figura viva ha il suo materiale e lo rimette da sola
		return
	sprite.material = materiale_piatto()
	await sprite.get_tree().create_timer(durata).timeout
	if is_instance_valid(sprite):
		sprite.material = null


static func luce(colore: Color, raggio: float, energia: float, altezza: float = 40.0) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = texture_luce()
	l.texture_scale = raggio / 64.0
	l.color = colore
	l.energy = energia
	l.height = altezza
	l.range_item_cull_mask = 3
	return l
