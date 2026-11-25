extends SceneTree
# Strumento di lavoro: trasforma modelli 3D (GLB) in fogli di sprite in pixel art
# con la relativa mappa delle normali (il "metodo Dead Cells").
#
# Uso (serve uno schermo, anche virtuale):
#   godot --path . -s res://strumenti/render_sprite.gd -- strumenti/render_sprite.json [nome ...]
# Senza nomi rifà tutte le voci; con uno o più nomi rifà solo quelle.
#
# Per ogni voce scrive in arte/sprite: <nome>.png (colore), <nome>_n.png (normali)
# e <nome>.json (celle e animazioni), che il gioco legge con SpriteAnimato.

const SHADER_COLORE := "
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D tex : source_color, filter_nearest;
uniform float usa_tex = 1.0;
uniform vec4 tinta : source_color = vec4(1.0);
uniform float saturazione = 1.0;
uniform float luminosita = 1.0;
uniform float forma = 0.4;
void fragment() {
	vec3 c = tinta.rgb;
	if (usa_tex > 0.5) {
		c *= texture(tex, UV).rgb;
	}
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(g), c, saturazione) * luminosita;
	float l = clamp(dot(normalize(NORMAL), normalize(vec3(0.0, 0.8, 0.6))), 0.0, 1.0);
	ALBEDO = c * mix(1.0 - forma, 1.0, l);
}
"

const SHADER_NORMALI := "
shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	vec3 e = normalize(NORMAL) * 0.5 + 0.5;
	// Annulla la conversione lineare->sRGB che il motore applica in uscita.
	ALBEDO = mix(pow((e + 0.055) / 1.055, vec3(2.4)), e / 12.92, lessThan(e, vec3(0.04045)));
}
"

const CONTORNO := Color8(13, 10, 18)
const COLONNE_MAX := 12

var _vp: SubViewport
var _camera: Camera3D
var _shader_colore: Shader
var _shader_normali: Shader


func _initialize() -> void:
	_avvia.call_deferred()


func _avvia() -> void:
	await process_frame
	var argomenti := OS.get_cmdline_user_args()
	if argomenti.is_empty():
		printerr("Manca il file di configurazione")
		quit(1)
		return
	var testo := FileAccess.get_file_as_string(argomenti[0])
	var config: Variant = JSON.parse_string(testo)
	if typeof(config) != TYPE_DICTIONARY:
		printerr("Configurazione non valida: ", argomenti[0])
		quit(1)
		return
	var solo: Array = argomenti.slice(1)
	_shader_colore = Shader.new()
	_shader_colore.code = SHADER_COLORE
	_shader_normali = Shader.new()
	_shader_normali.code = SHADER_NORMALI

	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.1
	_camera.far = 100.0
	_vp.add_child(_camera)

	var uscita: String = config.get("uscita", "res://arte/sprite")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(uscita))
	var errori := 0
	for voce: Dictionary in config.get("voci", []):
		if not solo.is_empty() and not solo.has(voce["nome"]):
			continue
		if not await _render_voce(voce, uscita):
			errori += 1
	print("RENDER FINE, errori: ", errori)
	quit(1 if errori > 0 else 0)


func _render_voce(voce: Dictionary, uscita: String) -> bool:
	var nome: String = voce["nome"]
	var cella := Vector2i(int(voce["cella"][0]), int(voce["cella"][1]))
	var ppu: float = voce.get("px_per_unita", 20.0)
	var piedi_da_sotto: int = int(voce.get("piedi_da_sotto", 8))
	var fps: float = voce.get("fps", 12.0)

	# Un modello GLB, oppure un oggetto composto da forme semplici ("pezzi"), oppure entrambi.
	var modello: Node3D = null
	if voce.has("glb"):
		modello = _carica(voce["glb"])
		if modello == null:
			printerr("Non riesco a caricare ", voce["glb"])
			return false
	else:
		modello = Node3D.new()
	if not _componi(modello, voce.get("pezzi", [])):
		return false

	# perno (capriole) -> base (rotazione, scala) -> modello
	var perno := Node3D.new()
	var base := Node3D.new()
	_vp.add_child(perno)
	perno.add_child(base)
	base.add_child(modello)
	base.rotation_degrees.y = voce.get("rotazione_y", 90.0)
	base.rotation_degrees.x = voce.get("rotazione_x", 0.0)
	var scala: Array = voce.get("scala", [1.0, 1.0, 1.0])
	base.scale = Vector3(scala[0], scala[1], scala[2])
	var sposta: Array = voce.get("sposta", [0.0, 0.0, 0.0])
	base.position = Vector3(sposta[0], sposta[1], sposta[2])

	for n: String in voce.get("nascondi", []):
		for trovato in modello.find_children(n, "Node3D", true, false):
			(trovato as Node3D).visible = false
	for percorso: String in voce.get("animazioni_da", []):
		_aggiungi_animazioni(modello, percorso)
	for a: Dictionary in voce.get("attacca", []):
		_attacca(modello, a)
	# Proporzioni: dopo aver allungato o accorciato le ossa rimetto i piedi a terra.
	var prima := _altezza_piedi(modello)
	for o: Dictionary in voce.get("ossa", []):
		_scala_osso(modello, o)
	var alza := (prima - _altezza_piedi(modello)) * base.scale.y
	sposta = [sposta[0], sposta[1] + alza, sposta[2]]
	base.position = Vector3(sposta[0], sposta[1], sposta[2])

	_vp.size = cella
	_camera.size = float(cella.y) / ppu
	_camera.position = Vector3(0.0, (float(cella.y) * 0.5 - float(piedi_da_sotto)) / ppu, 20.0)
	_camera.rotation = Vector3.ZERO

	var lettore: AnimationPlayer = null
	var lettori := modello.find_children("*", "AnimationPlayer", true, false)
	if not lettori.is_empty():
		lettore = lettori[0]
		# Ossa non mosse dall'animazione a riposo, non nella posa della precedente.
		lettore.deterministic = true

	# Elenco dei fotogrammi da scattare.
	var scatti: Array = []
	var animazioni := {}
	var lista: Array = voce.get("animazioni", [])
	var pose: Array = voce.get("pose", [])
	if not pose.is_empty():
		# Oggetti senza scheletro: ogni fotogramma sposta o ruota dei nodi (coperchio, leva, punte).
		for p: Dictionary in pose:
			var n: int = int(p.get("frame", 1))
			var indici: Array = []
			for i in n:
				indici.append(scatti.size())
				var k := 0.0 if n <= 1 else float(i) / float(n - 1)
				if p.get("ciclo", false) and n > 1:
					k = float(i) / float(n)
				scatti.append({"clip": "", "t": 0.0, "giro": 0.0, "giu": 0.0, "nodi": p.get("nodi", []), "k": k})
			animazioni[p["nome"]] = {"fps": p.get("fps", fps), "ciclo": p.get("ciclo", false), "frame": indici}
	elif lista.is_empty() or lettore == null:
		scatti.append({"clip": "", "t": 0.0, "giro": 0.0, "giu": 0.0})
		animazioni["base"] = {"fps": 1.0, "ciclo": false, "frame": [0]}
	else:
		for a: Dictionary in lista:
			var clip: String = a["clip"]
			if not lettore.has_animation(clip):
				printerr(nome, ": animazione mancante ", clip)
				return false
			var durata := lettore.get_animation(clip).length
			var da: float = a.get("da", 0.0)
			var fino: float = a.get("a", durata)
			var fps_a: float = a.get("fps", fps)
			var indici: Array = []
			if a.get("capriola", false):
				var n: int = int(a.get("frame", 8))
				for i in n:
					indici.append(scatti.size())
					scatti.append({
						"clip": clip, "t": a.get("tempo", 0.0),
						"giro": -TAU * float(i) / float(n),
						"centro": a.get("centro", 0.8), "giu": a.get("giu", 0.0),
					})
			else:
				var n: int = int(a.get("frame", maxi(1, roundi((fino - da) * fps_a))))
				for i in n:
					indici.append(scatti.size())
					var t := da + (fino - da) * float(i) / float(n)
					if not a.get("ciclo", false) and n > 1:
						t = da + (fino - da) * float(i) / float(n - 1)
					scatti.append({"clip": clip, "t": t, "giro": 0.0, "giu": 0.0})
			animazioni[a["nome"]] = {"fps": fps_a, "ciclo": a.get("ciclo", false), "frame": indici}

	var colonne := mini(COLONNE_MAX, scatti.size())
	var righe := ceili(float(scatti.size()) / float(colonne))
	var foglio_c := Image.create(colonne * cella.x, righe * cella.y, false, Image.FORMAT_RGBA8)
	var foglio_n := Image.create(colonne * cella.x, righe * cella.y, false, Image.FORMAT_RGBA8)

	for passata in 2:
		_materiali(modello, voce, passata == 1)
		for i in scatti.size():
			var s: Dictionary = scatti[i]
			if lettore != null and s["clip"] != "":
				lettore.play(s["clip"])
				lettore.seek(s["t"], true)
				lettore.pause()
			if s.has("nodi"):
				_metti_in_posa(modello, s["nodi"], s["k"])
			var centro: float = s.get("centro", 0.0)
			perno.position = Vector3(0.0, centro - float(s["giu"]), 0.0)
			base.position = Vector3(sposta[0], sposta[1] - centro, sposta[2])
			perno.rotation = Vector3(0.0, 0.0, s["giro"])
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var img := _vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			var dove := Vector2i((i % colonne) * cella.x, (i / colonne) * cella.y)
			if passata == 0:
				foglio_c.blit_rect(img, Rect2i(Vector2i.ZERO, cella), dove)
			else:
				foglio_n.blit_rect(img, Rect2i(Vector2i.ZERO, cella), dove)

	_rifinisci(foglio_c, foglio_n, cella, voce.get("contorno", true))

	var piedi := Vector2i(cella.x / 2, cella.y - piedi_da_sotto)
	if voce.get("ritaglia", false) and scatti.size() == 1:
		# Oggetti fermi: tengo solo il rettangolo disegnato.
		var usato := foglio_c.get_used_rect()
		if usato.size.x > 0 and usato.size.y > 0:
			foglio_c = foglio_c.get_region(usato)
			foglio_n = foglio_n.get_region(usato)
			piedi -= usato.position
			cella = usato.size
	elif voce.get("ritaglia", false):
		# Più fotogrammi: tengo in ogni cella lo stesso rettangolo, quello che li contiene tutti.
		var unione := Rect2i()
		for i in scatti.size():
			var dove := Vector2i((i % colonne) * cella.x, (i / colonne) * cella.y)
			var usato := foglio_c.get_region(Rect2i(dove, cella)).get_used_rect()
			if usato.size.x > 0 and usato.size.y > 0:
				unione = usato if unione.size == Vector2i.ZERO else unione.merge(usato)
		if unione.size.x > 0 and unione.size.y > 0:
			var nuovo_c := Image.create(colonne * unione.size.x, righe * unione.size.y, false, Image.FORMAT_RGBA8)
			var nuovo_n := Image.create(colonne * unione.size.x, righe * unione.size.y, false, Image.FORMAT_RGBA8)
			for i in scatti.size():
				var da := Vector2i((i % colonne) * cella.x, (i / colonne) * cella.y) + unione.position
				var a := Vector2i((i % colonne) * unione.size.x, (i / colonne) * unione.size.y)
				nuovo_c.blit_rect(foglio_c, Rect2i(da, unione.size), a)
				nuovo_n.blit_rect(foglio_n, Rect2i(da, unione.size), a)
			foglio_c = nuovo_c
			foglio_n = nuovo_n
			piedi -= unione.position
			cella = unione.size

	var percorso := uscita.path_join(nome)
	foglio_c.save_png(ProjectSettings.globalize_path(percorso + ".png"))
	foglio_n.save_png(ProjectSettings.globalize_path(percorso + "_n.png"))
	var dati := {
		"cella": [cella.x, cella.y],
		"piedi": [piedi.x, piedi.y],
		"colonne": colonne,
		"animazioni": animazioni,
	}
	var f := FileAccess.open(percorso + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(dati, "\t"))
	f.close()
	print(nome, ": ", scatti.size(), " fotogrammi, foglio ", foglio_c.get_width(), "x", foglio_c.get_height())
	perno.queue_free()
	await process_frame
	return true


func _componi(modello: Node3D, pezzi: Array) -> bool:
	# Forme semplici (scatola, cilindro, cono, sfera, anello) con un colore: per meccanismi e trappole
	# che non esistono nei pacchetti di modelli. "genitore" permette di muovere più pezzi insieme.
	for p: Dictionary in pezzi:
		var nodo: Node3D
		var forma: String = p.get("forma", "vuoto")
		var m: Array = p.get("misura", [1.0, 1.0, 1.0])
		var mesh: PrimitiveMesh = null
		match forma:
			"box":
				var b := BoxMesh.new()
				b.size = Vector3(m[0], m[1], m[2])
				mesh = b
			"cilindro", "cono":
				var c := CylinderMesh.new()
				c.top_radius = 0.0 if forma == "cono" else float(m[0])
				c.bottom_radius = float(m[1]) if m.size() > 2 else float(m[0])
				c.height = float(m[m.size() - 1])
				c.radial_segments = int(p.get("lati", 12))
				c.rings = 1
				mesh = c
			"sfera":
				var s := SphereMesh.new()
				s.radius = float(m[0])
				s.height = float(m[1]) if m.size() > 1 else float(m[0]) * 2.0
				s.radial_segments = 12
				s.rings = 6
				mesh = s
			"anello":
				var t := TorusMesh.new()
				t.inner_radius = float(m[0])
				t.outer_radius = float(m[1])
				t.rings = 12
				t.ring_segments = 6
				mesh = t
			"vuoto":
				pass
			_:
				printerr("Forma sconosciuta: ", forma)
				return false
		if mesh != null:
			var materiale := StandardMaterial3D.new()
			materiale.albedo_color = Color(String(p.get("colore", "#808080")))
			mesh.material = materiale
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			nodo = mi
		else:
			nodo = Node3D.new()
		nodo.name = p.get("nome", forma)
		var pos: Array = p.get("pos", [0.0, 0.0, 0.0])
		var rot: Array = p.get("rot", [0.0, 0.0, 0.0])
		nodo.position = Vector3(pos[0], pos[1], pos[2])
		nodo.rotation_degrees = Vector3(rot[0], rot[1], rot[2])
		var genitore: Node = modello
		if p.has("genitore"):
			genitore = modello.find_child(p["genitore"], true, false)
			if genitore == null:
				printerr("Genitore non trovato: ", p["genitore"])
				return false
		genitore.add_child(nodo)
	return true


func _metti_in_posa(modello: Node3D, nodi: Array, k: float) -> void:
	# Ogni voce: {"nodo", "da": {"pos", "rot", "scala"}, "a": {...}}; k va da 0 (da) a 1 (a).
	for v: Dictionary in nodi:
		var nodo := modello.find_child(v["nodo"], true, false) as Node3D
		if nodo == null:
			printerr("Nodo da mettere in posa non trovato: ", v["nodo"])
			continue
		if not nodo.has_meta("riposo"):
			nodo.set_meta("riposo", nodo.transform)
		var riposo: Transform3D = nodo.get_meta("riposo")
		var da: Dictionary = v.get("da", {})
		var a: Dictionary = v.get("a", da)
		nodo.transform = riposo
		if da.has("pos") or a.has("pos"):
			var p0: Array = da.get("pos", [0.0, 0.0, 0.0])
			var p1: Array = a.get("pos", p0)
			nodo.position = riposo.origin + Vector3(p0[0], p0[1], p0[2]).lerp(Vector3(p1[0], p1[1], p1[2]), k)
		if da.has("rot") or a.has("rot"):
			var r0: Array = da.get("rot", [0.0, 0.0, 0.0])
			var r1: Array = a.get("rot", r0)
			var r := Vector3(r0[0], r0[1], r0[2]).lerp(Vector3(r1[0], r1[1], r1[2]), k)
			nodo.basis = riposo.basis * Basis.from_euler(r * PI / 180.0)
		if da.has("scala") or a.has("scala"):
			var s0: Array = da.get("scala", [1.0, 1.0, 1.0])
			var s1: Array = a.get("scala", s0)
			nodo.scale = nodo.scale * Vector3(s0[0], s0[1], s0[2]).lerp(Vector3(s1[0], s1[1], s1[2]), k)


func _carica(percorso: String) -> Node3D:
	var doc := GLTFDocument.new()
	var stato := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(percorso), stato) != OK:
		return null
	return doc.generate_scene(stato) as Node3D


func _aggiungi_animazioni(modello: Node3D, percorso: String) -> void:
	# Prende le animazioni da un altro file con lo stesso scheletro (per esempio Mesh2Motion)
	# e le aggiunge al modello. I nomi delle ossa devono coincidere.
	var sorgente := _carica(percorso)
	if sorgente == null:
		printerr("Non riesco a caricare ", percorso)
		return
	var da_lettori := sorgente.find_children("*", "AnimationPlayer", true, false)
	if da_lettori.is_empty():
		sorgente.free()
		return
	var da := da_lettori[0] as AnimationPlayer
	var lettore: AnimationPlayer
	var esistenti := modello.find_children("*", "AnimationPlayer", true, false)
	if esistenti.is_empty():
		lettore = AnimationPlayer.new()
		lettore.name = "AnimationPlayer"
		modello.add_child(lettore)
	else:
		lettore = esistenti[0]
	if not lettore.has_animation_library(""):
		lettore.add_animation_library("", AnimationLibrary.new())
	var libreria := lettore.get_animation_library("")
	for nome in da.get_animation_list():
		if not libreria.has_animation(nome):
			libreria.add_animation(nome, da.get_animation(nome).duplicate(true))
	sorgente.free()


func _attacca(modello: Node3D, a: Dictionary) -> void:
	var scheletri := modello.find_children("*", "Skeleton3D", true, false)
	if scheletri.is_empty():
		return
	var oggetto := _carica(a["gltf"])
	if oggetto == null:
		printerr("Non riesco a caricare ", a["gltf"])
		return
	if a.has("nodo"):
		# Solo un pezzo del file (per esempio il cappuccio o il mantello di un altro personaggio).
		var trovati := oggetto.find_children(a["nodo"], "MeshInstance3D", true, false)
		if trovati.is_empty():
			printerr("Pezzo non trovato: ", a["nodo"], " in ", a["gltf"])
			oggetto.free()
			return
		var pezzo := (trovati[0] as MeshInstance3D).duplicate() as MeshInstance3D
		pezzo.skeleton = NodePath()
		pezzo.skin = null
		pezzo.transform = Transform3D.IDENTITY
		oggetto.free()
		oggetto = Node3D.new()
		oggetto.add_child(pezzo)
	var attacco := BoneAttachment3D.new()
	(scheletri[0] as Skeleton3D).add_child(attacco)
	attacco.bone_name = a["osso"]
	attacco.set_meta("attaccato", true)
	attacco.add_child(oggetto)
	var r: Array = a.get("rotazione", [0.0, 0.0, 0.0])
	oggetto.rotation_degrees = Vector3(r[0], r[1], r[2])
	var p: Array = a.get("posizione", [0.0, 0.0, 0.0])
	oggetto.position = Vector3(p[0], p[1], p[2])
	var sc: float = a.get("scala", 1.0)
	oggetto.scale = Vector3.ONE * sc


func _scala_osso(modello: Node3D, o: Dictionary) -> void:
	# Cambia le proporzioni (per esempio testa più piccola) senza toccare le animazioni:
	# le animazioni di questi modelli non hanno tracce di scala.
	for s in modello.find_children("*", "Skeleton3D", true, false):
		var sk := s as Skeleton3D
		var idx := sk.find_bone(o["osso"])
		if idx >= 0:
			var v: Array = o["scala"]
			sk.set_bone_pose_scale(idx, Vector3(v[0], v[1], v[2]))


func _altezza_piedi(modello: Node3D) -> float:
	for s in modello.find_children("*", "Skeleton3D", true, false):
		var sk := s as Skeleton3D
		var idx := sk.find_bone("toes.l")
		if idx >= 0:
			return sk.get_bone_global_pose(idx).origin.y
	return 0.0


func _materiali(modello: Node3D, voce: Dictionary, normali: bool) -> void:
	var regole: Array = voce.get("colori", [])
	var texture_nuova: Texture2D = null
	if voce.has("texture"):
		var img := Image.load_from_file(ProjectSettings.globalize_path(voce["texture"]))
		if img != null:
			texture_nuova = ImageTexture.create_from_image(img)
	for m in modello.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var attaccato := false
		var su: Node = mi
		while su != null and su != modello:
			if su.has_meta("attaccato"):
				attaccato = true
			su = su.get_parent()
		for s in mi.mesh.get_surface_count():
			var mat := ShaderMaterial.new()
			if normali:
				mat.shader = _shader_normali
			else:
				mat.shader = _shader_colore
				var originale := mi.mesh.surface_get_material(s) as BaseMaterial3D
				if originale != null and originale.albedo_texture != null:
					var tex: Texture2D = originale.albedo_texture
					if texture_nuova != null and not attaccato:
						tex = texture_nuova
					mat.set_shader_parameter("tex", tex)
					mat.set_shader_parameter("usa_tex", 1.0)
				else:
					mat.set_shader_parameter("usa_tex", 0.0)
					if originale != null:
						mat.set_shader_parameter("tinta", originale.albedo_color)
				mat.set_shader_parameter("forma", voce.get("forma", 0.4))
				for r: Dictionary in regole:
					if String(mi.name).matchn(r.get("mesh", "*")):
						if r.has("tinta"):
							mat.set_shader_parameter("tinta", Color(String(r["tinta"])))
						if r.has("saturazione"):
							mat.set_shader_parameter("saturazione", r["saturazione"])
						if r.has("luminosita"):
							mat.set_shader_parameter("luminosita", r["luminosita"])
						if r.get("senza_tex", false):
							mat.set_shader_parameter("usa_tex", 0.0)
			mi.set_surface_override_material(s, mat)


func _rifinisci(colore: Image, normali: Image, cella: Vector2i, contorno: bool) -> void:
	# Bordi netti (niente pixel semitrasparenti) e contorno scuro di 1 pixel.
	var w := colore.get_width()
	var h := colore.get_height()
	var pieno := PackedByteArray()
	pieno.resize(w * h)
	for y in h:
		for x in w:
			var c := colore.get_pixel(x, y)
			if c.a >= 0.5:
				pieno[y * w + x] = 1
				c.a = 1.0
				colore.set_pixel(x, y, c)
				var n := normali.get_pixel(x, y)
				n.a = 1.0
				normali.set_pixel(x, y, n)
			else:
				colore.set_pixel(x, y, Color(0, 0, 0, 0))
				normali.set_pixel(x, y, Color(0.5, 0.5, 1.0, 0.0))
	if not contorno:
		return
	var piatto := Color(0.5, 0.5, 1.0, 1.0)
	for y in h:
		for x in w:
			if pieno[y * w + x] == 1:
				continue
			# Il contorno non esce dalla propria cella.
			var cx := x % cella.x
			var cy := y % cella.y
			var vicino := false
			if cx > 0 and pieno[y * w + x - 1] == 1:
				vicino = true
			elif cx < cella.x - 1 and pieno[y * w + x + 1] == 1:
				vicino = true
			elif cy > 0 and pieno[(y - 1) * w + x] == 1:
				vicino = true
			elif cy < cella.y - 1 and pieno[(y + 1) * w + x] == 1:
				vicino = true
			if vicino:
				colore.set_pixel(x, y, CONTORNO)
				normali.set_pixel(x, y, piatto)
