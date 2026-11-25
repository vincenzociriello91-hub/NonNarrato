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


func _initialize() -> void:
	_avvia.call_deferred()


func _avvia() -> void:
	await process_frame
	var figura: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIGURA))
	if typeof(figura) != TYPE_DICTIONARY:
		printerr("Manca ", FIGURA)
		quit(1)
		return
	var clip_usate := {}
	for a: Dictionary in figura.get("animazioni", []):
		clip_usate[a["clip"]] = true

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
