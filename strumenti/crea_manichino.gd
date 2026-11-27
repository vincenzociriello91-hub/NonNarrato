extends SceneTree
# Strumento di lavoro: costruisce il "manichino" del protagonista.
# Tutti i personaggi KayKit hanno lo stesso scheletro, quindi teste, busti, braccia, gambe,
# mantelli, copricapi e armi si possono scambiare. Qui finiscono tutti su un solo scheletro,
# con le texture nella palette cupa e solo le animazioni che il gioco usa.
#
# Uso: godot --headless --path . -s res://strumenti/crea_manichino.gd
# Scrive: res://modelli/manichino.scn (lo carica script/figura_viva.gd)

const USCITA := "res://modelli/manichino.scn"
const FIGURA := "res://arte/figure/protagonista.json"
const SCHELETRO_BASE := "res://sorgenti3d/personaggi/Rogue_Hooded.glb"

# file sorgente -> (prefisso dei nomi, texture cupa)
const FONTI := {
	"res://sorgenti3d/personaggi/Rogue_Hooded.glb": ["Viandante", "protagonista_texture"],
	"res://sorgenti3d/personaggi/Rogue.glb": ["Ladro", "rogue_cupo"],
	"res://sorgenti3d/personaggi/Knight.glb": ["Cavaliere", "knight_cupo"],
	"res://sorgenti3d/personaggi/Barbarian.glb": ["Barbaro", "barbarian_cupo"],
	"res://sorgenti3d/personaggi/Mage.glb": ["Mago", "mage_cupo"],
	"res://sorgenti3d/personaggi/Skeleton_Warrior.glb": ["Sepolto", "skeleton_cupo"],
	"res://sorgenti3d/personaggi/Skeleton_Rogue.glb": ["SepoltoLadro", "skeleton_cupo"],
	"res://sorgenti3d/personaggi/Skeleton_Mage.glb": ["SepoltoMago", "skeleton_cupo"],
}
# Dai file degli scheletri prendo solo i pezzi rigidi (cappelli, cappucci, mantelli), non i corpi.
const SOLO_RIGIDI := ["Sepolto", "SepoltoLadro", "SepoltoMago"]
# Armi singole (file gltf con un solo oggetto) da mettere in mano destra; tengono la loro texture.
const ARMI_SFUSE := {
	"res://sorgenti3d/oggetti/sword_1handed.gltf": ["Viandante", "Spada", "handslot.r"],
	"res://sorgenti3d/oggetti/Skeleton_Blade.gltf": ["Sepolto", "Lama", "handslot.r"],
	"res://sorgenti3d/oggetti/Skeleton_Axe.gltf": ["Sepolto", "Ascia", "handslot.r"],
	"res://sorgenti3d/oggetti/Skeleton_Staff.gltf": ["Sepolto", "Bastone", "handslot.r"],
}


# Clip composte: per ogni chiave (tempo) e per ogni gruppo di ossa, la posa di una clip a un certo istante.
# Le misure delle mani e delle ginocchia (Cheer, Running_A) scelgono gli istanti: in Cheer a 0,62 s la mano
# sinistra è più in alto, a 1,04 s la destra; in Running_A a 0,3 s sale il ginocchio destro, a 0,7 il sinistro.
# Braccio alto e ginocchio opposto alzato insieme, come chi si arrampica. Il nuoto è l'arrampicata
# inclinata in avanti (vedi "inclina" in arte/figure/protagonista.json).
const COMPOSTE := {
	# Arrampicata (0.1.35, prima erano due pose prese da altre clip che si alternavano: "da burattino").
	# Pose costruite osso per osso ("mirata": ogni osso punta nella direzione data, nello spazio del modello:
	# +Y in alto, +Z avanti verso la parete, +X a sinistra). Un ciclo = due prese, a specchio.
	# Presa: una mano tesa in alto e il ginocchio opposto alto sulla parete; trazione: quella mano scende al
	# petto mentre il corpo sale (il gioco lo spinge in su proprio qui, Giocatore._arrampicata), l'altra mano
	# si stacca in basso e la gamba alta spinge fino a stendersi.
	"Arrampica": {"durata": 1.0, "mirata": true, "chiavi": [
		{"t": 0.0, "ossa": {
			"spine": [0, 1, 0.12], "chest": [0, 1, 0.1], "head": [0.05, 1, 0.0],
			"upperarm.l": [0.1, 0.92, 0.38], "lowerarm.l": [0.05, 0.95, 0.3],
			"upperarm.r": [-0.25, -0.2, 0.95], "lowerarm.r": [-0.05, 0.6, 0.8],
			"upperleg.r": [-0.05, -0.15, 1.0], "lowerleg.r": [0, -1, 0.15],
			"upperleg.l": [0.05, -1, 0.12], "lowerleg.l": [0, -1, 0.05]}},
		{"t": 0.25, "ossa": {
			"spine": [0, 1, 0.2], "chest": [0, 1, 0.18], "head": [0, 1, 0.05],
			"upperarm.l": [0.2, -0.1, 0.97], "lowerarm.l": [0, 0.6, 0.8],
			"upperarm.r": [-0.2, -0.8, 0.55], "lowerarm.r": [0, -0.2, 1.0],
			"upperleg.r": [-0.05, -0.85, 0.5], "lowerleg.r": [0, -1, 0.0],
			"upperleg.l": [0.05, -0.6, 0.8], "lowerleg.l": [0, -1, 0.1]}},
		{"t": 0.5, "specchio": 0.0},
		{"t": 0.75, "specchio": 0.25},
	]},
	"Appeso": {"durata": 1.0, "chiavi": [
		{"t": 0.0, "corpo": ["Jump_Idle", 0.0], "anche": ["Idle", 0.0], "braccio_l": ["Cheer", 0.83], "braccio_r": ["Cheer", 0.83],
			"gamba_l": ["Jump_Idle", 0.0], "gamba_r": ["Jump_Idle", 0.0]},
		{"t": 0.5, "corpo": ["Jump_Idle", 0.53], "anche": ["Idle", 0.0], "braccio_l": ["Cheer", 0.83], "braccio_r": ["Cheer", 0.83],
			"gamba_l": ["Jump_Idle", 0.53], "gamba_r": ["Jump_Idle", 0.53]},
	]},
	# Issata dal bordo alla Prince of Persia (0.1.33): appeso con le braccia tese, trazione con un ginocchio su,
	# busto sopra il bordo con le mani che spingono, in piedi. Il corpo lo sposta il gioco (Giocatore._scavalco).
	"Issata": {"durata": 1.0, "ciclo": false, "chiavi": [
		{"t": 0.0, "corpo": ["Jump_Idle", 0.0], "anche": ["Idle", 0.0], "braccio_l": ["Cheer", 0.83], "braccio_r": ["Cheer", 0.83],
			"gamba_l": ["Jump_Idle", 0.0], "gamba_r": ["Jump_Idle", 0.0]},
		{"t": 0.3, "corpo": ["PickUp", 0.25], "anche": ["Idle", 0.0], "braccio_l": ["Block", 0.46], "braccio_r": ["Block", 0.46],
			"gamba_l": ["Running_A", 0.3], "gamba_r": ["Jump_Idle", 0.53]},
		{"t": 0.62, "corpo": ["PickUp", 0.56], "anche": ["Idle", 0.0], "braccio_l": ["PickUp", 0.56], "braccio_r": ["PickUp", 0.56],
			"gamba_l": ["Lie_StandUp", 1.5], "gamba_r": ["Lie_StandUp", 1.5]},
		{"t": 1.0, "corpo": ["Idle", 0.0], "anche": ["Idle", 0.0], "braccio_l": ["Idle", 0.0], "braccio_r": ["Idle", 0.0],
			"gamba_l": ["Idle", 0.0], "gamba_r": ["Idle", 0.0]},
	]},
}
const GRUPPI_OSSA := {
	"anche": ["hips"],
	"corpo": ["spine", "chest", "head"],
	"braccio_l": ["upperarm.l", "lowerarm.l", "wrist.l", "hand.l"],
	"braccio_r": ["upperarm.r", "lowerarm.r", "wrist.r", "hand.r"],
	"gamba_l": ["upperleg.l", "lowerleg.l", "foot.l", "toes.l"],
	"gamba_r": ["upperleg.r", "lowerleg.r", "foot.r", "toes.r"],
}


func _initialize() -> void:
	_avvia.call_deferred()


func _avvia() -> void:
	await process_frame
	var figura: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIGURA))
	if typeof(figura) != TYPE_DICTIONARY:
		printerr("Manca ", FIGURA)
		quit(1)
		return
	# Le clip delle animazioni di gioco, dei gruppi di mosse e delle azioni di prova.
	var clip_usate := {}
	for a: Dictionary in figura.get("animazioni", []) + figura.get("prove", []):
		clip_usate[a["clip"]] = true
	for gruppo: Dictionary in (figura.get("mosse", {}) as Dictionary).values():
		for cambio: Dictionary in (gruppo.get("animazioni", {}) as Dictionary).values():
			if cambio.has("clip"):
				clip_usate[cambio["clip"]] = true

	var base := _carica(SCHELETRO_BASE)
	var scheletro_base: Skeleton3D = base.find_children("*", "Skeleton3D", true, false)[0]
	var lettore_base: AnimationPlayer = base.find_children("*", "AnimationPlayer", true, false)[0]

	var radice := Node3D.new()
	radice.name = "Manichino"
	var rig := Node3D.new()
	rig.name = "Rig"
	radice.add_child(rig)
	var scheletro := Skeleton3D.new()
	scheletro.name = "Skeleton3D"
	rig.add_child(scheletro)
	for i in scheletro_base.get_bone_count():
		scheletro.add_bone(scheletro_base.get_bone_name(i))
	for i in scheletro_base.get_bone_count():
		scheletro.set_bone_parent(i, scheletro_base.get_bone_parent(i))
		scheletro.set_bone_rest(i, scheletro_base.get_bone_rest(i))
		scheletro.set_bone_pose_position(i, scheletro_base.get_bone_pose_position(i))
		scheletro.set_bone_pose_rotation(i, scheletro_base.get_bone_pose_rotation(i))
		scheletro.set_bone_pose_scale(i, scheletro_base.get_bone_pose_scale(i))
	rig.transform = scheletro_base.get_parent().transform
	scheletro.transform = scheletro_base.transform

	var attacchi := {}
	var parti: Array = []
	var texture_cupe := {}

	for percorso: String in FONTI:
		var info: Array = FONTI[percorso]
		var prefisso: String = info[0]
		var tex := _texture(info[1], texture_cupe)
		var scena := _carica(percorso)
		var sk: Skeleton3D = scena.find_children("*", "Skeleton3D", true, false)[0]
		for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
			var genitore := mi.get_parent()
			var osso := ""
			if genitore is BoneAttachment3D:
				osso = (genitore as BoneAttachment3D).bone_name
			elif SOLO_RIGIDI.has(prefisso):
				continue  # corpo di scheletro: non serve
			var nome := "%s__%s" % [prefisso, mi.name]
			var copia := mi.duplicate() as MeshInstance3D
			copia.name = nome
			copia.mesh = _ricolora(mi.mesh, tex)
			copia.visible = false
			if osso == "":
				scheletro.add_child(copia)
				copia.skeleton = NodePath("..")
			else:
				copia.skin = null
				copia.skeleton = NodePath()
				_attacco(scheletro, osso, attacchi).add_child(copia)
			parti.append(nome)
		scena.free()

	for percorso: String in ARMI_SFUSE:
		var info: Array = ARMI_SFUSE[percorso]
		var scena := _carica(percorso)
		var trovati := scena.find_children("*", "MeshInstance3D", true, false)
		if not trovati.is_empty():
			var mi := trovati[0] as MeshInstance3D
			var copia := MeshInstance3D.new()
			copia.name = "%s__%s" % [info[0], info[1]]
			copia.mesh = _ricolora(mi.mesh, null)
			copia.transform = mi.transform
			copia.visible = false
			_attacco(scheletro, info[2], attacchi).add_child(copia)
			parti.append(String(copia.name))
		scena.free()

	# Solo le animazioni usate dal gioco, prese dal personaggio di base.
	var lettore := AnimationPlayer.new()
	lettore.name = "AnimationPlayer"
	radice.add_child(lettore)
	var libreria := AnimationLibrary.new()
	for nome in lettore_base.get_animation_list():
		if clip_usate.has(nome):
			libreria.add_animation(nome, lettore_base.get_animation(nome).duplicate(true))
	# Clip che i personaggi KayKit non hanno (arrampicata, appeso): composte da pose di altre clip.
	for nome: String in COMPOSTE:
		if clip_usate.has(nome):
			var ricetta: Dictionary = COMPOSTE[nome]
			libreria.add_animation(nome, _componi_mirata(scheletro_base, ricetta) if ricetta.get("mirata", false)
					else _componi(lettore_base, scheletro_base, ricetta))
	lettore.add_animation_library("", libreria)
	base.free()

	var mancanti: Array = []
	for clip: String in clip_usate:
		if not libreria.has_animation(clip):
			mancanti.append(clip)
	if not mancanti.is_empty():
		printerr("Animazioni mancanti: ", mancanti)

	_proprietario(radice, radice)
	var impacchettata := PackedScene.new()
	var esito := impacchettata.pack(radice)
	if esito != OK:
		printerr("Errore nel preparare la scena: ", esito)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://modelli"))
	esito = ResourceSaver.save(impacchettata, USCITA, ResourceSaver.FLAG_COMPRESS)
	print("MANICHINO: ", parti.size(), " pezzi, ", libreria.get_animation_list().size(), " animazioni, esito ", esito)
	parti.sort()
	print("PEZZI: ", ", ".join(parti))
	radice.free()
	quit(0 if esito == OK and mancanti.is_empty() else 1)


func _carica(percorso: String) -> Node3D:
	var doc := GLTFDocument.new()
	var stato := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(percorso), stato) != OK:
		printerr("Non riesco a caricare ", percorso)
		return Node3D.new()
	return doc.generate_scene(stato) as Node3D


func _texture(nome: String, cache: Dictionary) -> Texture2D:
	if not cache.has(nome):
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://sorgenti3d/oggetti/%s.png" % nome))
		cache[nome] = ImageTexture.create_from_image(img)
	return cache[nome]


func _ricolora(mesh: Mesh, tex: Texture2D) -> Mesh:
	# Stessa forma, materiale nuovo con la texture cupa: lo legge figura_viva per i suoi shader.
	var copia := mesh.duplicate() as Mesh
	for s in copia.get_surface_count():
		var mat := StandardMaterial3D.new()
		var originale := mesh.surface_get_material(s) as BaseMaterial3D
		mat.albedo_texture = tex if tex != null else (originale.albedo_texture if originale != null else null)
		if originale != null:
			mat.albedo_color = originale.albedo_color
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		copia.surface_set_material(s, mat)
	return copia


func _attacco(scheletro: Skeleton3D, osso: String, attacchi: Dictionary) -> BoneAttachment3D:
	if not attacchi.has(osso):
		var a := BoneAttachment3D.new()
		a.name = "attacco_" + osso.replace(".", "_")
		a.bone_name = osso
		scheletro.add_child(a)
		attacchi[osso] = a
	return attacchi[osso]


func _proprietario(nodo: Node, radice: Node) -> void:
	for figlio in nodo.get_children():
		figlio.owner = radice
		_proprietario(figlio, radice)


func _componi(lettore: AnimationPlayer, scheletro: Skeleton3D, ricetta: Dictionary) -> Animation:
	var anim := Animation.new()
	anim.length = float(ricetta["durata"])
	anim.loop_mode = Animation.LOOP_LINEAR if ricetta.get("ciclo", true) else Animation.LOOP_NONE
	for gruppo: String in GRUPPI_OSSA:
		for osso: String in GRUPPI_OSSA[gruppo]:
			var indice := scheletro.find_bone(osso)
			if indice < 0:
				continue
			var percorso := NodePath("Rig/Skeleton3D:" + osso)
			var traccia := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(traccia, percorso)
			var posizione := -1
			if osso == "hips":
				posizione = anim.add_track(Animation.TYPE_POSITION_3D)
				anim.track_set_path(posizione, percorso)
			for chiave: Dictionary in ricetta["chiavi"]:
				var fonte: Array = chiave[gruppo]
				var a := lettore.get_animation(String(fonte[0]))
				var q := scheletro.get_bone_rest(indice).basis.get_rotation_quaternion()
				var idx := a.find_track(percorso, Animation.TYPE_ROTATION_3D)
				if idx >= 0:
					q = a.rotation_track_interpolate(idx, float(fonte[1]))
				anim.rotation_track_insert_key(traccia, float(chiave["t"]), q)
				if posizione >= 0:
					var p := scheletro.get_bone_rest(indice).origin
					var idp := a.find_track(percorso, Animation.TYPE_POSITION_3D)
					if idp >= 0:
						p = a.position_track_interpolate(idp, float(fonte[1]))
					anim.position_track_insert_key(posizione, float(chiave["t"]), p)
	return anim


func _componi_mirata(scheletro: Skeleton3D, ricetta: Dictionary) -> Animation:
	# Come _componi, ma le pose sono direzioni delle ossa (vedi "Arrampica"). Le chiavi "specchio" rifanno
	# quella al tempo indicato con destra e sinistra scambiate.
	var chiavi: Array = ricetta["chiavi"]
	var per_tempo := {}
	for chiave: Dictionary in chiavi:
		if chiave.has("ossa"):
			per_tempo[float(chiave["t"])] = chiave["ossa"]
	var anim := Animation.new()
	anim.length = float(ricetta["durata"])
	anim.loop_mode = Animation.LOOP_LINEAR if ricetta.get("ciclo", true) else Animation.LOOP_NONE
	var tracce := {}
	for gruppo: String in GRUPPI_OSSA:
		for osso: String in GRUPPI_OSSA[gruppo]:
			if scheletro.find_bone(osso) < 0:
				continue
			var t := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(t, NodePath("Rig/Skeleton3D:" + osso))
			tracce[osso] = t
	var anche := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(anche, NodePath("Rig/Skeleton3D:hips"))
	for chiave: Dictionary in chiavi:
		var direzioni: Dictionary = chiave["ossa"] if chiave.has("ossa") else _specchia(per_tempo[float(chiave["specchio"])])
		var rotazioni := _mira(scheletro, direzioni)
		for osso: String in tracce:
			anim.rotation_track_insert_key(tracce[osso], float(chiave["t"]), rotazioni[osso])
		anim.position_track_insert_key(anche, float(chiave["t"]), scheletro.get_bone_rest(scheletro.find_bone("hips")).origin)
	return anim


static func _specchia(direzioni: Dictionary) -> Dictionary:
	var fuori := {}
	for osso: String in direzioni:
		var v: Array = direzioni[osso]
		var nome := osso
		if osso.ends_with(".l"):
			nome = osso.trim_suffix(".l") + ".r"
		elif osso.ends_with(".r"):
			nome = osso.trim_suffix(".r") + ".l"
		fuori[nome] = [-float(v[0]), v[1], v[2]]
	return fuori


func _mira(scheletro: Skeleton3D, direzioni: Dictionary) -> Dictionary:
	# Rotazione locale di ogni osso perché il suo asse +Y punti nella direzione voluta (il resto segue il
	# genitore come a riposo). Si parte dalle radici e si scende.
	var rotazioni := {}
	var da_fare: Array = []
	for i in scheletro.get_bone_count():
		if scheletro.get_bone_parent(i) < 0:
			da_fare.append([i, Transform3D.IDENTITY])
	while not da_fare.is_empty():
		var voce: Array = da_fare.pop_front()
		var i: int = voce[0]
		var genitore: Transform3D = voce[1]
		var g := genitore * scheletro.get_bone_rest(i)
		var nome := scheletro.get_bone_name(i)
		if direzioni.has(nome):
			var v: Array = direzioni[nome]
			var d := Vector3(float(v[0]), float(v[1]), float(v[2])).normalized()
			g.basis = Basis(Quaternion(g.basis.y.normalized(), d)) * g.basis
		rotazioni[nome] = (genitore.basis.inverse() * g.basis).get_rotation_quaternion()
		for figlio in scheletro.get_bone_children(i):
			da_fare.append([figlio, g])
	return rotazioni

