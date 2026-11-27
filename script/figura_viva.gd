class_name FiguraViva
extends SpriteAnimato
# Il protagonista "fotografato" in tempo reale: stesso stile dei fogli di SpriteAnimato
# (colore + normali, contorno scuro, bordi netti), ma ogni fotogramma nasce dal manichino 3D
# con l'equipaggiamento di quel momento. Tempi e animazioni restano quelli di SpriteAnimato.
#
# Due SubViewport minuscoli condividono un solo mondo 3D: uno vede i pezzi col colore
# (strato 1), l'altro gli stessi pezzi con le normali (strato 2). Si ridisegnano solo
# quando cambia il fotogramma o l'aspetto.
#
# L'arma in mano (e quello che si tiene per un attimo: balestra, dardo) si disegna sempre sopra al corpo
# (niente prova di profondità): nelle animazioni dei modelli la lama passava dentro testa e busto.
# Sta nella mano rivolta verso chi guarda, quindi davanti è quasi sempre giusto.

const MANICHINO := "res://modelli/manichino.scn"
const STRATO_COLORE := 1
const STRATO_NORMALI := 2

const SHADER_COLORE := "
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 tinta : source_color = vec4(1.0);
uniform float saturazione = 1.0;
uniform float luminosita = 1.0;
uniform float forma = 0.4;
void fragment() {
	vec3 c = tinta.rgb * texture(tex, UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(g), c, saturazione) * luminosita;
	float l = clamp(dot(normalize(NORMAL), normalize(vec3(0.0, 0.8, 0.6))), 0.0, 1.0);
	ALBEDO = c * mix(1.0 - forma, 1.0, l);
}
"

const PRIORITA_SOPRA := 10         # i pezzi "sopra" si disegnano dopo il corpo, senza prova di profondità

const SHADER_NORMALI := "
shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	vec3 e = normalize(NORMAL) * 0.5 + 0.5;
	// Annulla la conversione lineare->sRGB che il motore applica in uscita.
	ALBEDO = mix(pow((e + 0.055) / 1.055, vec3(2.4)), e / 12.92, lessThan(e, vec3(0.04045)));
}
"

# Bordi netti e contorno di 1 pixel, come _rifinisci() di render_sprite.gd.
const SHADER_SPRITE := "
shader_type canvas_item;
%s
uniform vec4 contorno : source_color = vec4(0.051, 0.039, 0.071, 1.0);
varying vec4 tinta_nodo;
void vertex() {
	tinta_nodo = COLOR;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a >= 0.5) {
		COLOR = vec4(c.rgb, 1.0) * tinta_nodo;
	} else {
		vec2 p = TEXTURE_PIXEL_SIZE;
		float v = max(max(texture(TEXTURE, UV + vec2(p.x, 0.0)).a, texture(TEXTURE, UV - vec2(p.x, 0.0)).a),
				max(texture(TEXTURE, UV + vec2(0.0, p.y)).a, texture(TEXTURE, UV - vec2(0.0, p.y)).a));
		if (v < 0.5) {
			discard;
		}
		COLOR = contorno * tinta_nodo;
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	}
}
"

static var _shader_colore: Shader
static var _shader_normali: Shader
static var _mat_normali: ShaderMaterial
static var _shader_colore_sopra: Shader
static var _mat_normali_sopra: ShaderMaterial
static var _mat_sprite: ShaderMaterial
static var _mat_sprite_piatto: ShaderMaterial

var disegni := 0                 # quante foto ha scattato (per le prove e il rapporto)
var piega := 0.0:                # inclinazione in avanti (radianti) decisa dal gioco: slancio e frenata (0.1.33)
	set(v):
		var q := snappedf(v, deg_to_rad(1.0))   # un grado alla volta: si ridisegna solo quando cambia davvero
		if q != piega:
			piega = q
			if _ultimo >= 0:
				var i := _ultimo
				_ultimo = -1
				_mostra(i)
var _in_mano: Array = []         # pezzi tenuti in mano per un attimo (vedi mostra_in_mano)
var mosse := "una_mano"          # gruppo di mosse in uso (cambia le clip, non i tempi di gioco)
var usa_normali := true          # l'anteprima del menu non ne ha bisogno
var _figura := {}
var _scatti: Array = []
var _ultimo := -1
var _vp_colore: SubViewport
var _vp_normali: SubViewport
var _perno: Node3D
var _base: Node3D
var _manichino: Node3D
var _lettore: AnimationPlayer
var _sposta := Vector3.ZERO
var _pezzi := {}                 # nome -> [colore, normali]
var _colore_di := {}             # nome -> posto (per la tinta)
var _con_normali := true
var _lampo_fino := 0.0
var _insiemi := {}               # gruppo di mosse -> animazioni
var _proporzionato := false


func carica(nome: String) -> void:
	_prepara_shader()
	var dati: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://arte/figure/%s.json" % nome))
	if typeof(dati) != TYPE_DICTIONARY:
		push_error("Figura non valida: " + nome)
		return
	_figura = dati
	var cella := Vector2i(int(_figura["cella"][0]), int(_figura["cella"][1]))
	var ppu: float = _figura.get("px_per_unita", 24.0)
	var piedi_da_sotto: int = int(_figura.get("piedi_da_sotto", 20))
	var mondo := World3D.new()
	_vp_colore = _nuovo_viewport(cella, mondo, "Colore")
	_vp_normali = _nuovo_viewport(cella, mondo, "Normali")
	_camera(_vp_colore, cella, ppu, piedi_da_sotto, STRATO_COLORE)
	_camera(_vp_normali, cella, ppu, piedi_da_sotto, STRATO_NORMALI)

	# perno (capriole) -> base (rotazione, scala) -> manichino, come in render_sprite.gd
	_perno = Node3D.new()
	_base = Node3D.new()
	_vp_colore.add_child(_perno)
	_perno.add_child(_base)
	_manichino = (load(MANICHINO) as PackedScene).instantiate() as Node3D
	_base.add_child(_manichino)
	_base.rotation_degrees.y = _figura.get("rotazione_y", 90.0)
	var scala: Array = _figura.get("scala", [1.0, 1.0, 1.0])
	_base.scale = Vector3(scala[0], scala[1], scala[2])
	_lettore = _manichino.get_node("AnimationPlayer") as AnimationPlayer
	_lettore.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# Le ossa che un'animazione non muove tornano a riposo, invece di tenere la posa
	# dell'animazione precedente: ogni fotogramma è uguale a ogni giro.
	_lettore.deterministic = true
	_scatti = []
	_prepara_animazioni()
	@warning_ignore("integer_division")
	_dati = {"cella": [cella.x, cella.y], "piedi": [cella.x / 2, cella.y - piedi_da_sotto], "colonne": 1, "animazioni": _insiemi["una_mano"]}
	_cella = cella
	_colonne = 1
	_prepara_pezzi()

	var tex := CanvasTexture.new()
	tex.diffuse_texture = _vp_colore.get_texture()
	texture = tex
	centered = false
	region_enabled = false
	offset = -Vector2(float(_dati["piedi"][0]), float(_dati["piedi"][1]))
	material = _mat_sprite
	_applica_profilo()
	_applica_aspetto()
	if not Dispositivo.profilo_cambiato.is_connected(_applica_profilo):
		Dispositivo.profilo_cambiato.connect(_applica_profilo)
	if not Equipaggiamento.cambiato.is_connected(_applica_aspetto):
		Equipaggiamento.cambiato.connect(_applica_aspetto)
	if is_inside_tree():
		_avvia_in_albero()


func _notification(cosa: int) -> void:
	# Con Vulkan, una CanvasTexture che punta a un viewport già sparito fa liberare al motore
	# una risorsa non più valida ("Attempted to free invalid ID"). La sgancio finché i viewport ci sono.
	if cosa == NOTIFICATION_PREDELETE:
		var tex := texture as CanvasTexture
		if tex != null:
			tex.diffuse_texture = null
			tex.normal_texture = null
		texture = null


func lampo(durata: float) -> void:
	# Come Effetti.lampo per gli sprite normali: per un attimo a piena luce.
	material = _mat_sprite_piatto
	_lampo_fino = maxf(_lampo_fino, Time.get_ticks_msec() / 1000.0 + durata)
	await get_tree().create_timer(durata).timeout
	if is_instance_valid(self) and Time.get_ticks_msec() / 1000.0 >= _lampo_fino - 0.001:
		material = _mat_sprite


func riscalda() -> void:
	# Per un fotogramma mostra tutti i pezzi: il motore prepara subito i suoi shader.
	for nome: String in _pezzi:
		for mi: MeshInstance3D in _pezzi[nome]:
			mi.visible = true
	_ridisegna()
	# Due giri (non frame_post_draw: senza schermo, nelle prove, non arriverebbe mai).
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(self):
		_applica_aspetto()


func pezzi_visibili() -> Array:
	var elenco: Array = []
	for nome: String in _pezzi:
		if (_pezzi[nome][0] as MeshInstance3D).visible:
			elenco.append(nome)
	return elenco


func immagine() -> Image:
	return _vp_colore.get_texture().get_image()


func immagine_normali() -> Image:
	return _vp_normali.get_texture().get_image()


func _ready() -> void:
	if _manichino != null:
		_avvia_in_albero()


func _avvia_in_albero() -> void:
	# Va bene sia "carica poi aggiungi" sia "aggiungi poi carica".
	if not _proporzionato:
		_proporzionato = true
		_proporzioni()
	_ultimo = -1
	_mostra(int(_anim["frame"][fotogramma]) if not _anim.is_empty() else 0)


func _mostra(i: int) -> void:
	if _scatti.is_empty() or i == _ultimo or not is_inside_tree():
		return
	_ultimo = i
	var s: Dictionary = _scatti[clampi(i, 0, _scatti.size() - 1)]
	if s["clip"] != "" and _lettore.has_animation(s["clip"]):
		if _lettore.current_animation != s["clip"]:
			_lettore.play(s["clip"])
		_lettore.seek(s["t"], true)
	var centro: float = s.get("centro", 0.0)
	_perno.position = Vector3(0.0, centro - float(s["giu"]), 0.0)
	_base.position = Vector3(_sposta.x, _sposta.y - centro, _sposta.z)
	_perno.rotation = Vector3(0.0, 0.0, float(s["giro"]) - piega)
	_ridisegna()


func _ridisegna() -> void:
	# Una foto nel prossimo disegno dello schermo, anche a gioco in pausa (menu Aspetto).
	if _vp_colore == null:
		return
	_vp_colore.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _con_normali:
		_vp_normali.render_target_update_mode = SubViewport.UPDATE_ONCE
	disegni += 1


func anteprima() -> Texture2D:
	return _vp_colore.get_texture() if _vp_colore != null else null


static func materiale_anteprima() -> ShaderMaterial:
	_prepara_shader()
	return _mat_sprite_piatto


func _proporzioni() -> void:
	# Come render_sprite.gd: allunga o accorcia le ossa, poi rimette i piedi a terra.
	# Va fatto dentro l'albero, altrimenti lo scheletro non ricalcola le posizioni.
	var scheletro := _manichino.get_node("Rig/Skeleton3D") as Skeleton3D
	var prima := _altezza_piedi(scheletro)
	for o: Dictionary in _figura.get("ossa", []):
		var idx := scheletro.find_bone(o["osso"])
		if idx >= 0:
			var v: Array = o["scala"]
			scheletro.set_bone_pose_scale(idx, Vector3(v[0], v[1], v[2]))
	_sposta = Vector3(0.0, (prima - _altezza_piedi(scheletro)) * _base.scale.y, 0.0)
	_base.position = _sposta


func gruppi_di_mosse() -> Array:
	return _insiemi.keys()


func prove() -> Array:
	# Azioni da provare nel menu: [nome, etichetta]
	var elenco: Array = []
	for a: Dictionary in _figura.get("prove", []):
		elenco.append([a["nome"], a.get("etichetta", a["nome"])])
	return elenco


func imposta_mosse(id: String) -> void:
	if not _insiemi.has(id):
		id = "una_mano"
	if _insiemi.is_empty() or (id == mosse and _dati.get("animazioni") == _insiemi[id]):
		return
	mosse = id
	_dati["animazioni"] = _insiemi[id]
	if animazione != "" and (_insiemi[id] as Dictionary).has(animazione):
		# Stessa azione, clip del nuovo gruppo, senza ricominciarla.
		_anim = _insiemi[id][animazione]
		fotogramma = mini(fotogramma, (_anim["frame"] as Array).size() - 1)
		_mostra(int(_anim["frame"][fotogramma]))


func _prepara_animazioni() -> void:
	# Ogni gruppo di mosse cambia solo alcune clip: il resto (e il numero di fotogrammi
	# delle azioni di gioco, cioè la loro durata) viene dalle animazioni di base.
	var durate := {}
	for nome in _lettore.get_animation_list():
		durate[nome] = _lettore.get_animation(nome).length
	var fps: float = _figura.get("fps", 12.0)
	var specifiche := {}
	var base := {}
	for a: Dictionary in _figura.get("animazioni", []):
		specifiche[a["nome"]] = a
		base[a["nome"]] = _aggiungi_scatti(a, durate, fps)
	for a: Dictionary in _figura.get("prove", []):
		base[a["nome"]] = _aggiungi_scatti(a, durate, fps)
	_insiemi = {"una_mano": base}
	var gruppi: Dictionary = _figura.get("mosse", {})
	for id: String in gruppi:
		var anims := base.duplicate()
		var cambi: Dictionary = (gruppi[id] as Dictionary).get("animazioni", {})
		for nome: String in cambi:
			var spec: Dictionary = (specifiche.get(nome, {}) as Dictionary).duplicate()
			if (cambi[nome] as Dictionary).has("clip"):
				for k in ["da", "a", "tempo"]:
					spec.erase(k)  # un'altra clip non eredita la finestra di tempo della vecchia
			spec.merge(cambi[nome], true)
			anims[nome] = _aggiungi_scatti(spec, durate, fps)
		_insiemi[id] = anims


func _aggiungi_scatti(a: Dictionary, durate: Dictionary, fps: float) -> Dictionary:
	# Stessa scaletta di render_sprite.gd, ma invece di un foglio produce pose da applicare.
	var clip: String = a["clip"]
	var durata: float = durate.get(clip, 1.0)
	var da: float = a.get("da", 0.0)
	var fino: float = a.get("a", durata)
	var fps_a: float = a.get("fps", fps)
	var indici: Array = []
	var minimo: float = _figura.get("fps_minimo", 0.0)
	if a.get("capriola", false):
		var n: int = int(a.get("frame", 8))
		var k := SpriteAnimato.densita(n, fps_a, minimo)
		n *= k
		fps_a *= k
		for i in n:
			indici.append(_scatti.size())
			_scatti.append({
				"clip": clip, "t": a.get("tempo", 0.0),
				"giro": (1.0 if a.get("indietro", false) else -1.0) * TAU * float(i) / float(n),
				"centro": a.get("centro", 0.8), "giu": a.get("giu", 0.0),
			})
	else:
		var n: int = int(a.get("frame", maxi(1, roundi((fino - da) * fps_a))))
		var k := SpriteAnimato.densita(n, fps_a, minimo)
		n *= k
		fps_a *= k
		for i in n:
			indici.append(_scatti.size())
			var t := da + (fino - da) * float(i) / float(n)
			if not a.get("ciclo", false) and n > 1:
				t = da + (fino - da) * float(i) / float(n - 1)
			# "inclina": tutta la figura ruotata in avanti (gradi), per esempio orizzontale per nuotare.
			var inclina: float = a.get("inclina", 0.0)
			if inclina != 0.0:
				_scatti.append({"clip": clip, "t": t, "giro": -deg_to_rad(inclina), "centro": a.get("centro", 0.5), "giu": a.get("giu", 0.0)})
			else:
				_scatti.append({"clip": clip, "t": t, "giro": 0.0, "giu": 0.0})
	return {"fps": fps_a, "ciclo": a.get("ciclo", false), "frame": indici}


func _prepara_pezzi() -> void:
	for posto in Equipaggiamento.POSTI:
		for id in Equipaggiamento.oggetti_del_posto(posto):
			for p: String in Equipaggiamento.pezzi(id):
				_colore_di[p] = posto
	var forma: float = _figura.get("forma", 0.4)
	for m in _manichino.find_children("*__*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var originale := mi.mesh.surface_get_material(0) as BaseMaterial3D
		var sopra := pezzo_sopra(String(mi.name))
		var mat := ShaderMaterial.new()
		mat.shader = _shader_colore_sopra if sopra else _shader_colore
		if sopra:
			mat.render_priority = PRIORITA_SOPRA
		if originale != null and originale.albedo_texture != null:
			mat.set_shader_parameter("tex", originale.albedo_texture)
		mat.set_shader_parameter("forma", forma)
		mi.material_override = mat
		mi.layers = STRATO_COLORE
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var n := mi.duplicate() as MeshInstance3D
		n.name = String(mi.name) + "_n"
		n.material_override = _mat_normali_sopra if sopra else _mat_normali
		n.layers = STRATO_NORMALI
		mi.get_parent().add_child(n)
		if mi.skin != null:
			n.skeleton = mi.skeleton
		_pezzi[String(mi.name)] = [mi, n]


func pezzo_sopra(nome: String) -> bool:
	# L'arma della mano destra e gli oggetti tenuti in mano per un attimo (Giocatore.IN_MANO).
	if _colore_di.get(nome, "") == "arma":
		return true
	for elenco: Array in Giocatore.IN_MANO.values():
		if elenco.has(nome):
			return true
	return false


var armi_riposte := false        # arrampicandosi e nuotando le armi spariscono (riposte)


func riponi_armi(si: bool) -> void:
	if si == armi_riposte:
		return
	armi_riposte = si
	_applica_aspetto()


func mostra_in_mano(pezzi: Array) -> void:
	# Per un attimo in mano qualcosa che non fa parte dell'equipaggiamento (la balestra per le frecce,
	# un dardo da lanciare); l'arma di solito in mano sparisce. Lista vuota = di nuovo come prima.
	if pezzi == _in_mano:
		return
	_in_mano = pezzi.duplicate()
	_applica_aspetto()


func _applica_aspetto() -> void:
	if _pezzi.is_empty():
		return
	var accesi := {}
	for posto in Equipaggiamento.POSTI:
		if posto == "arma" and not _in_mano.is_empty():
			continue
		if armi_riposte and posto in ["arma", "mano_sinistra"]:
			continue
		for p: String in Equipaggiamento.pezzi(Equipaggiamento.indossati[posto]):
			accesi[p] = true
	for p: String in _in_mano:
		accesi[p] = true
	for nome: String in _pezzi:
		var visibile := accesi.has(nome)
		var coppia: Array = _pezzi[nome]
		(coppia[0] as MeshInstance3D).visible = visibile
		(coppia[1] as MeshInstance3D).visible = visibile
		if visibile:
			var posto: String = _colore_di.get(nome, "")
			var c: Array = Equipaggiamento.COLORI[Equipaggiamento.colori.get(posto, "naturale")]
			var mat := (coppia[0] as MeshInstance3D).material_override as ShaderMaterial
			mat.set_shader_parameter("tinta", c[1])
			mat.set_shader_parameter("saturazione", c[2])
			mat.set_shader_parameter("luminosita", c[3])
	imposta_mosse(Equipaggiamento.mosse_attive())
	_ridisegna()


func _applica_profilo() -> void:
	# Sui dispositivi più deboli niente foto delle normali: lo sprite usa una normale piatta.
	_con_normali = usa_normali and bool(Dispositivo.profilo.get("figura_normali", true))
	var tex := texture as CanvasTexture
	if tex != null:
		tex.normal_texture = _vp_normali.get_texture() if _con_normali else null
	_ridisegna()


func _nuovo_viewport(cella: Vector2i, mondo: World3D, nome: String) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = nome
	vp.size = cella
	vp.world_3d = mondo
	vp.transparent_bg = true
	vp.disable_3d = false
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	vp.positional_shadow_atlas_size = 0
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	return vp


func _camera(vp: SubViewport, cella: Vector2i, ppu: float, piedi_da_sotto: int, strato: int) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.1
	cam.far = 100.0
	cam.size = float(cella.y) / ppu
	cam.position = Vector3(0.0, (float(cella.y) * 0.5 - float(piedi_da_sotto)) / ppu, 20.0)
	cam.cull_mask = strato
	vp.add_child(cam)
	cam.current = true


func _altezza_piedi(sk: Skeleton3D) -> float:
	var idx := sk.find_bone("toes.l")
	return sk.get_bone_global_pose(idx).origin.y if idx >= 0 else 0.0


static func _prepara_shader() -> void:
	if _shader_colore != null:
		return
	_shader_colore = Shader.new()
	_shader_colore.code = SHADER_COLORE
	_shader_normali = Shader.new()
	_shader_normali.code = SHADER_NORMALI
	_mat_normali = ShaderMaterial.new()
	_mat_normali.shader = _shader_normali
	# Varianti "sopra" per l'arma: senza prova di profondità, facce dietro scartate (resta pulita).
	_shader_colore_sopra = Shader.new()
	_shader_colore_sopra.code = SHADER_COLORE.replace("render_mode unshaded, cull_disabled;", "render_mode unshaded, cull_back, depth_test_disabled;")
	var normali_sopra := Shader.new()
	normali_sopra.code = SHADER_NORMALI.replace("render_mode unshaded, cull_disabled;", "render_mode unshaded, cull_back, depth_test_disabled;")
	_mat_normali_sopra = ShaderMaterial.new()
	_mat_normali_sopra.shader = normali_sopra
	_mat_normali_sopra.render_priority = PRIORITA_SOPRA
	var s := Shader.new()
	s.code = SHADER_SPRITE % ""
	_mat_sprite = ShaderMaterial.new()
	_mat_sprite.shader = s
	var sp := Shader.new()
	sp.code = SHADER_SPRITE % "render_mode unshaded;"
	_mat_sprite_piatto = ShaderMaterial.new()
	_mat_sprite_piatto.shader = sp
	imposta_contorno()
	if not Impostazioni.cambiata.is_connected(_su_impostazione):
		Impostazioni.cambiata.connect(_su_impostazione)


static func _su_impostazione(chiave: String) -> void:
	if chiave == "acc/contorni":
		imposta_contorno()


static func imposta_contorno() -> void:
	# Accessibilità "contorni chiari": il contorno di 1 pixel del protagonista diventa chiaro.
	var colore := Color(0.98, 0.93, 0.72) if Impostazioni.leggi("acc/contorni") else Color(0.051, 0.039, 0.071)
	for m: ShaderMaterial in [_mat_sprite, _mat_sprite_piatto]:
		if m != null:
			m.set_shader_parameter("contorno", colore)
