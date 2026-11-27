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

static var _contorni := {}
static var _muro: ShaderMaterial
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


static func velocita_base() -> float:
	# Velocità del gioco scelta in Accessibilità (1 = normale). Nelle prove resta sempre 1.
	if Dispositivo.in_prova or Dispositivo.bot_attivo:
		return 1.0
	return clampf(Impostazioni.leggi("acc/velocita"), 0.5, 1.0)


static func applica_velocita() -> void:
	Engine.time_scale = velocita_base()


static func fermo_immagine(nodo: Node, durata: float) -> void:
	# Un istante di "fermo" quando un colpo va a segno: dà peso all'impatto (spento con "meno lampi").
	var base := velocita_base()
	if Dispositivo.in_prova or Engine.time_scale < base or Impostazioni.leggi("acc/meno_lampi"):
		return
	Engine.time_scale = 0.05
	await nodo.get_tree().create_timer(durata, true, false, true).timeout
	Engine.time_scale = velocita_base()


static func occlusore(genitore: Node, rett: Rect2, fa_ombra: bool = true) -> LightOccluder2D:
	# Sagoma che proietta ombra sul muro di fondo. fa_ombra = false: il nodo c'è ma non fa ombra
	# (personaggi e nemici: le loro ombre erano lunghe strisce che partivano dalle torce).
	var forma := OccluderPolygon2D.new()
	forma.polygon = PackedVector2Array([
		rett.position, Vector2(rett.end.x, rett.position.y), rett.end, Vector2(rett.position.x, rett.end.y),
	])
	var o := LightOccluder2D.new()
	o.occluder = forma
	o.occluder_light_mask = L_SFONDO if fa_ombra else 0
	o.sdf_collision = fa_ombra   # solo muri e pilastri fanno ombra sul muro di fondo (vedi materiale_muro)
	genitore.add_child(o)
	return o


static func materiale_muro() -> ShaderMaterial:
	# Muro di fondo con ombre corte e sfumate (0.1.32). Le ombre del motore arrivavano fino al bordo
	# della luce: coni neri dalla torcia al soffitto (spente nella 0.1.28). Qui la luce cerca l'ostacolo
	# verso la fiamma nel campo di distanze degli occlusori (SDF): l'ombra c'è solo vicino a muri e
	# pilastri e sparisce entro "lunghezza" pixel, con il bordo che si sfuma allontanandosi.
	if _muro == null:
		var s := Shader.new()
		s.code = """
shader_type canvas_item;
uniform float lunghezza = 56.0;   // 0 = niente ombre
uniform float morbidezza = 4.0;   // più basso = bordo più sfumato
uniform float forza = 0.85;
uniform int passi = 10;
void light() {
	float cNdotL = max(0.0, dot(NORMAL, LIGHT_DIRECTION));
	vec4 luce = vec4(LIGHT_COLOR.rgb * COLOR.rgb * LIGHT_ENERGY * cNdotL, LIGHT_COLOR.a);   // la luce di serie
	if (lunghezza > 0.0 && !LIGHT_IS_DIRECTIONAL) {
		vec2 uv_px = SCREEN_UV / FRAGCOORD.xy;
		vec2 p = screen_uv_to_sdf(SCREEN_UV);
		vec2 v = screen_uv_to_sdf(LIGHT_POSITION.xy * uv_px) - p;
		float d = length(v);
		vec2 dir = v / max(d, 0.001);
		float fine = min(d - 4.0, lunghezza);
		float ombra = 0.0;
		float t = 1.0;
		for (int i = 0; i < passi; i++) {
			if (t >= fine) {
				break;
			}
			float h = texture_sdf(p + dir * t);
			float vicino = 1.0 - smoothstep(lunghezza * 0.35, lunghezza, t);   // piena vicino all'ostacolo, poi svanisce
			ombra = max(ombra, (1.0 - clamp(morbidezza * h / t, 0.0, 1.0)) * vicino);
			if (h < 0.5) {
				break;
			}
			t += max(h, 2.0);
		}
		luce.rgb *= 1.0 - ombra * forza;
	}
	LIGHT = luce;
}
"""
		_muro = ShaderMaterial.new()
		_muro.shader = s
	return _muro


static func applica_ombre_muri(profilo: Dictionary) -> void:
	# Dal profilo: accese o no, sfumatura (ombre morbide) e passi della ricerca (dettaglio delle ombre).
	var m := materiale_muro()
	m.set_shader_parameter("lunghezza", 56.0 if int(profilo.get("luci_con_ombra", 0)) > 0 else 0.0)
	m.set_shader_parameter("morbidezza", 3.0 if profilo.get("ombre_morbide", false) else 6.0)
	m.set_shader_parameter("passi", {512: 6, 1024: 10, 2048: 14}.get(int(profilo.get("atlante_ombre", 1024)), 10))


static func numero_danno(genitore: Node, dove: Vector2, danno: int) -> void:
	# Numero del danno che sale e sparisce (impostazione "numeri dei danni", spenta di base).
	if not Impostazioni.leggi("gioco/numeri_danno") or genitore == null:
		return
	var e := Label.new()
	e.text = str(danno)
	e.add_theme_font_size_override("font_size", 10)
	e.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	e.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.06))
	e.add_theme_constant_override("outline_size", 3)
	e.position = dove + Vector2(randf_range(-6.0, 2.0), 0.0)
	e.z_index = 40
	e.material = materiale_piatto()
	genitore.add_child(e)
	var tw := e.create_tween()
	tw.set_parallel(true)
	tw.tween_property(e, "position:y", e.position.y - 16.0, 0.7)
	tw.tween_property(e, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.chain().tween_callback(e.queue_free)


static func materiale_contorno(colore: Color, spessore: int = 1) -> ShaderMaterial:
	# Accessibilità "contorni chiari": linea di 1 pixel di gioco del colore scelto attorno allo sprite
	# ("spessore" pixel del foglio: 2 nella doppia definizione).
	var chiave := "%s/%d" % [colore.to_html(), spessore]
	if not _contorni.has(chiave):
		var s := Shader.new()
		s.code = """
shader_type canvas_item;
uniform vec4 contorno : source_color;
uniform float spessore = 1.0;
varying vec4 tinta;
void vertex() {
	tinta = COLOR;   // in fragment() COLOR contiene già la texture: la tinta del nodo si prende qui
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.5) {
		vec2 p = TEXTURE_PIXEL_SIZE;
		float v = 0.0;
		for (float k = 1.0; k <= spessore; k += 1.0) {
			v = max(v, max(max(texture(TEXTURE, UV + vec2(p.x * k, 0.0)).a, texture(TEXTURE, UV - vec2(p.x * k, 0.0)).a),
					max(texture(TEXTURE, UV + vec2(0.0, p.y * k)).a, texture(TEXTURE, UV - vec2(0.0, p.y * k)).a)));
		}
		if (v < 0.5) {
			discard;
		}
		COLOR = vec4(contorno.rgb, contorno.a * tinta.a);
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	} else {
		COLOR = c * tinta;
	}
}
"""
		var m := ShaderMaterial.new()
		m.shader = s
		m.set_shader_parameter("contorno", colore)
		m.set_shader_parameter("spessore", float(spessore))
		_contorni[chiave] = m
	return _contorni[chiave]


static func lampo(sprite: CanvasItem, durata: float = 0.08) -> void:
	# Lo sprite appare per un attimo a piena luce: segnala il colpo ricevuto (più breve con "meno lampi").
	if Impostazioni.leggi("acc/meno_lampi"):
		durata *= 0.4
	if sprite.has_method("lampo"):
		sprite.call("lampo", durata)  # la figura viva ha il suo materiale e lo rimette da sola
		return
	var prima := sprite.material if sprite.material != materiale_piatto() else sprite.get_meta("materiale_prima", null) as Material
	sprite.set_meta("materiale_prima", prima)
	sprite.material = materiale_piatto()
	await sprite.get_tree().create_timer(durata).timeout
	if is_instance_valid(sprite):
		sprite.material = sprite.get_meta("materiale_prima", null) as Material


static func luce(colore: Color, raggio: float, energia: float, altezza: float = 40.0) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = texture_luce()
	l.texture_scale = raggio / 64.0
	l.color = colore
	l.energy = energia
	l.height = altezza
	l.range_item_cull_mask = 3
	return l
