class_name Ombra
extends Node2D
# Ombre corte e sfumate dei corpi (0.1.31): personaggio, nemici, casse, barili, forzieri, oggetti a terra.
#  - Macchia: alone morbido sul pavimento sotto i piedi; si stringe e sbiadisce quando il corpo si alza.
#  - Sagome: la figura stessa, schiacciata e sfocata, stesa sul pavimento dalla parte opposta alle luci
#    più vicine (torce, candele, bracieri); più si è vicini alla fiamma, più è scura.
# Prendono il posto delle ombre "vere" delle torce sui corpi, che erano coni neri lunghi fino al soffitto.
# Quante sagome: Dispositivo.profilo["ombre_corpi"] (0 = solo la macchia).

const Z := -7                     # sopra lastre (-8, -9) e fondamenta (-10), sotto forzieri (-1) e corpi
const GRUPPO_LUCI := "luci_ombra"  # luci fisse che fanno ombra ai corpi (le aggiunge chi le crea)
const PORTATA := 96.0             # oltre questa altezza da terra niente ombra
const ALFA_MACCHIA := 0.7
const ALFA_SAGOMA := 0.8
const SAGOME_MASSIME := 2
const OGNI_FERMO := 0.25          # corpi fermi (forzieri, barili): la terra si cerca 4 volte al secondo

const SHADER := "
shader_type canvas_item;
render_mode unshaded;
uniform float densita = 1.0;   // pixel del foglio per pixel di gioco (doppia definizione: 2)
varying float alto;
varying float alfa;
void vertex() {
	alto = -VERTEX.y / densita;   // pixel di gioco sopra i piedi dello sprite (lo sprite ha i piedi in 0)
	alfa = COLOR.a;     // in fragment() COLOR contiene già la texture
}
void fragment() {
	// Sagoma sfocata: la figura è schiacciata in altezza, quindi si sfuma più in verticale.
	vec2 p = TEXTURE_PIXEL_SIZE * densita;   // sfocatura uguale in pixel di gioco
	float a = texture(TEXTURE, UV).a * 0.28;
	a += (texture(TEXTURE, UV + vec2(p.x * 1.5, 0.0)).a + texture(TEXTURE, UV - vec2(p.x * 1.5, 0.0)).a) * 0.13;
	a += (texture(TEXTURE, UV + vec2(0.0, p.y * 3.0)).a + texture(TEXTURE, UV - vec2(0.0, p.y * 3.0)).a) * 0.13;
	a += (texture(TEXTURE, UV + vec2(p.x * 1.5, p.y * 3.0)).a + texture(TEXTURE, UV - vec2(p.x * 1.5, p.y * 3.0)).a) * 0.05;
	a += (texture(TEXTURE, UV + vec2(p.x * 1.5, -p.y * 3.0)).a + texture(TEXTURE, UV - vec2(p.x * 1.5, -p.y * 3.0)).a) * 0.05;
	float punta = 1.0 - smoothstep(4.0, 60.0, alto);   // più chiara verso la testa (la punta dell'ombra)
	COLOR = vec4(0.0, 0.0, 0.0, a * punta * alfa);
}
"

static var _materiali := {}       # densità -> materiale
static var _texture_macchia: GradientTexture2D
static var _luci: Array = []
static var _fotogramma_luci := -1

var sorgente: Sprite2D            # sprite del corpo (null = solo la macchia: pipistrelli, oggetti piccoli)
var larghezza := 20.0             # larghezza della macchia
var distanza_terra := INF         # dai piedi al pavimento sotto (INF = niente sotto, entro PORTATA)
var sagome_visibili := 0          # per le prove e il rapporto
var _corpo: Node2D
var _macchia: Sprite2D
var _sagome: Array[Sprite2D] = []
var _raggio := PhysicsRayQueryParameters2D.new()
var _t_terra := 0.0


static func aggiungi(corpo: Node2D, sprite: Sprite2D, largo: float) -> Ombra:
	var o := Ombra.new()
	o.sorgente = sprite
	o.larghezza = largo
	corpo.add_child(o)
	return o


static func luce(l: PointLight2D) -> PointLight2D:
	# Chi crea una luce fissa (torcia, candela, braciere) la segna qui: farà ombra ai corpi vicini.
	l.add_to_group(GRUPPO_LUCI)
	return l


static func materiale(densita: int = 1) -> ShaderMaterial:
	if not _materiali.has(densita):
		var s: Shader = (_materiali.values()[0] as ShaderMaterial).shader if not _materiali.is_empty() else Shader.new()
		if s.code == "":
			s.code = SHADER
		var m := ShaderMaterial.new()
		m.shader = s
		m.set_shader_parameter("densita", float(densita))
		_materiali[densita] = m
	return _materiali[densita]


static func texture_macchia() -> GradientTexture2D:
	if _texture_macchia == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0)])
		_texture_macchia = GradientTexture2D.new()
		_texture_macchia.gradient = g
		_texture_macchia.width = 32
		_texture_macchia.height = 32
		_texture_macchia.fill = GradientTexture2D.FILL_RADIAL
		_texture_macchia.fill_from = Vector2(0.5, 0.5)
		_texture_macchia.fill_to = Vector2(1.0, 0.5)
	return _texture_macchia


static func luci_attive(albero: SceneTree) -> Array:
	# Una sola ricerca per fotogramma, per tutti i corpi: solo le luci accese (la stanza spegne quelle lontane).
	var f := Engine.get_process_frames()
	if f != _fotogramma_luci:
		_fotogramma_luci = f
		_luci.clear()
		for n: Node in albero.get_nodes_in_group(GRUPPO_LUCI):
			var l := n as PointLight2D
			if l.enabled and l.is_visible_in_tree():
				_luci.append(l)
	return _luci


static func inclinazione(dx: float, alto: float) -> float:
	# Quanto la sagoma stesa si piega di lato: dalla parte opposta alla luce, di più se la luce è bassa e lontana.
	return clampf(dx / maxf(alto, 24.0), -1.2, 1.2) * 0.42


func _ready() -> void:
	_corpo = get_parent() as Node2D
	z_as_relative = false
	z_index = Z
	_macchia = Sprite2D.new()
	_macchia.texture = texture_macchia()
	_macchia.light_mask = 0
	add_child(_macchia)
	_raggio.collision_mask = Effetti.S_MONDO | Effetti.S_PIATTAFORME
	if _corpo is CollisionObject2D:
		_raggio.exclude = [(_corpo as CollisionObject2D).get_rid()]
	_t_terra = randf() * OGNI_FERMO   # i corpi fermi non cercano la terra tutti nello stesso fotogramma
	_cerca_terra()


func _physics_process(delta: float) -> void:
	var cb := _corpo as CharacterBody2D
	if cb != null and cb.is_on_floor():
		distanza_terra = 0.0
		return
	var fermo := cb == null and not (_corpo is RigidBody2D and not (_corpo as RigidBody2D).sleeping) \
			and not (_corpo is Raccoglibile)
	if fermo:
		_t_terra -= delta
		if _t_terra > 0.0:
			return
		_t_terra = OGNI_FERMO
	_cerca_terra()


func _cerca_terra() -> void:
	if not is_inside_tree():
		return
	var da := _corpo.global_position + Vector2(0.0, -3.0)
	_raggio.from = da
	_raggio.to = da + Vector2(0.0, PORTATA + 3.0)
	var colpo := _corpo.get_world_2d().direct_space_state.intersect_ray(_raggio)
	distanza_terra = (colpo["position"] as Vector2).y - _corpo.global_position.y if not colpo.is_empty() else INF


func _process(_delta: float) -> void:
	var vicino := 1.0 - clampf(distanza_terra / PORTATA, 0.0, 1.0)
	var alfa := vicino
	if sorgente != null:
		alfa *= sorgente.modulate.a * sorgente.self_modulate.a * (1.0 if sorgente.is_visible_in_tree() else 0.0)
	alfa *= _corpo.modulate.a
	if alfa <= 0.01:
		visible = false
		sagome_visibili = 0
		return
	visible = true
	var piede_x := sorgente.position.x if sorgente != null else 0.0
	position = Vector2(piede_x, maxf(distanza_terra, 0.0))
	# Macchia: più piccola e chiara quando il corpo è in alto.
	var w := larghezza * (0.55 + 0.45 * vicino)
	_macchia.scale = Vector2(w, w * 0.34) / 32.0
	_macchia.modulate = Color(1, 1, 1, ALFA_MACCHIA * alfa)
	_aggiorna_sagome(alfa)


func _aggiorna_sagome(alfa: float) -> void:
	var quante := 0
	if sorgente != null and sorgente.texture != null:
		quante = clampi(int(Dispositivo.profilo.get("ombre_corpi", 1)), 0, SAGOME_MASSIME)
	var scelte: Array = []   # [forza, luce]
	if quante > 0:
		var terra := global_position
		for l: PointLight2D in luci_attive(get_tree()):
			if _corpo.is_ancestor_of(l):
				continue   # il braciere non fa ombra a sé stesso
			var raggio := l.texture_scale * 64.0
			var d := (terra + Vector2(0.0, -20.0)).distance_to(l.global_position)
			if d >= raggio or l.global_position.y > terra.y - 8.0:
				continue   # lontana, o all'altezza del pavimento
			scelte.append([pow(1.0 - d / raggio, 0.8), l])
		scelte.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	sagome_visibili = mini(quante, scelte.size())
	while _sagome.size() < sagome_visibili:
		var s := Sprite2D.new()
		s.light_mask = 0
		add_child(s)
		_sagome.append(s)
	for i in _sagome.size():
		var s := _sagome[i]
		s.visible = i < sagome_visibili
		if not s.visible:
			continue
		var l: PointLight2D = scelte[i][1]
		var dx := global_position.x - l.global_position.x
		var alto := global_position.y - l.global_position.y
		var k := inclinazione(dx, alto)
		var lungo := 0.24 + 0.12 * absf(k) / 0.5   # più lunga quando la luce è di lato
		var mat := materiale(int(sorgente.get("densita_px")) if sorgente is SpriteAnimato else 1)
		if s.material != mat:
			s.material = mat
		s.texture = sorgente.texture
		s.region_enabled = sorgente.region_enabled
		s.region_rect = sorgente.region_rect
		s.centered = sorgente.centered
		s.offset = sorgente.offset
		s.flip_h = sorgente.flip_h
		# Stesa sul pavimento: in giù (verso chi guarda) e piegata di lato, lontano dalla fiamma.
		var sc := sorgente.scale
		s.transform = Transform2D(Vector2(sc.x, 0.0), Vector2(-k * sc.y, -lungo * sc.y), Vector2.ZERO)
		s.modulate = Color(1, 1, 1, ALFA_SAGOMA * float(scelte[i][0]) * alfa)
