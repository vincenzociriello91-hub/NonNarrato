extends SceneTree
# Strumento di lavoro: costruisce il "manichino" del protagonista (0.1.38: corpo Quaternius, proporzioni vere).
#
# - Scheletro e vestiti: Quaternius (Modular Character Outfits - Fantasy, Universal Base Characters), CC0,
#   tutti sullo stesso scheletro: busti, braccia, gambe, cappucci e capelli si scambiano.
# - Armi, scudi, elmi e cappelli: i pezzi rigidi KayKit di prima, attaccati alle ossa Quaternius
#   (stessa direzione nel mondo, rimpiccioliti: i KayKit hanno testa e armi grandi).
# - Mantelli: generati qui (stoffa e cuoio di ambientCG), legati a schiena, bacino e cosce.
# - Animazioni: quelle della Universal Animation Library di Quaternius (UAL.glb) e quelle KayKit di prima,
#   adattate allo scheletro nuovo (prefisso "KK_"), più le composte (arrampicata, appeso, issata).
#
# Uso: godot --headless --path . -s res://strumenti/crea_manichino.gd
# Scrive: res://modelli/manichino.scn (lo carica script/figura_viva.gd)

const USCITA := "res://modelli/manichino.scn"
const FIGURA := "res://arte/figure/protagonista.json"
const FOGLI := "res://strumenti/render_sprite.json"
const Q := "res://sorgenti3d/quaternius/"
const SCHELETRO_BASE := Q + "Male_Ranger.gltf"
const ANIMAZIONI_UAL := Q + "UAL.glb"
const ANIMAZIONI_KK := "res://sorgenti3d/personaggi/Rogue_Hooded.glb"
const PREFISSO_KK := "KK_"
const LATO_TEXTURE := 512

# Vestiti e corpo (pezzi morbidi, legati allo scheletro): file -> [prefisso, {nome della mesh: nome del pezzo}]
const VESTITI := {
	Q + "Male_Ranger.gltf": ["Viandante", {
		"Male_Ranger_Head_Hood": "Cappuccio", "Male_Ranger_Body": "Giubba", "Male_Ranger_Body_Belt_1": "Cinta",
		"Male_Ranger_Body_Belt_2": "Cinta2", "Male_Ranger_Arms": "Maniche", "Male_Ranger_Arms_Bracer": "Bracciale",
		"Male_Ranger_Legs": "Brache", "Male_Ranger_Feet_Boots": "Stivali", "Male_Ranger_Acc_Pauldron": "Spallaccio"}],
	Q + "Male_Peasant.gltf": ["Contadino", {
		"Male_Peasant_Body": "Veste", "Male_Peasant_Arms": "Maniche", "Male_Peasant_Legs": "Brache",
		"Male_Peasant_Feet": "Scarpe"}],
	Q + "Superhero_Male_FullBody.gltf": ["Corpo", {"SuperHero_Male": "Testa", "Eyes": "Occhi", "Eyebrows": "Sopracciglia"}],
	Q + "Hair_SimpleParted.gltf": ["Capelli", {"Hair_SimpleParted": "Corti"}],
	Q + "Hair_Buzzed.gltf": ["Capelli", {"Hair_Buzzed": "Rasati"}],
	Q + "Hair_Long.gltf": ["Capelli", {"Hair_Long": "Lunghi"}],
	Q + "Hair_Beard.gltf": ["Capelli", {"Hair_Beard": "Barba"}],
}
# Del corpo base si tiene solo la testa (testa e collo): il resto lo coprono i vestiti.
const SOLO_TESTA := ["Corpo__Testa"]
const OSSA_TESTA := ["neck_01", "Head"]
const CORPO_INTERO := "Intero"

# Pezzi rigidi KayKit (armi, scudi, elmi): file -> [prefisso, texture cupa]. Solo quelli attaccati a un osso.
const RIGIDI_KK := {
	"res://sorgenti3d/personaggi/Rogue_Hooded.glb": ["Viandante", "protagonista_texture"],
	"res://sorgenti3d/personaggi/Rogue.glb": ["Ladro", "rogue_cupo"],
	"res://sorgenti3d/personaggi/Knight.glb": ["Cavaliere", "knight_cupo"],
	"res://sorgenti3d/personaggi/Barbarian.glb": ["Barbaro", "barbarian_cupo"],
	"res://sorgenti3d/personaggi/Mage.glb": ["Mago", "mage_cupo"],
	"res://sorgenti3d/personaggi/Skeleton_Warrior.glb": ["Sepolto", "skeleton_cupo"],
	"res://sorgenti3d/personaggi/Skeleton_Rogue.glb": ["SepoltoLadro", "skeleton_cupo"],
	"res://sorgenti3d/personaggi/Skeleton_Mage.glb": ["SepoltoMago", "skeleton_cupo"],
}
# Armi singole (file gltf con un solo oggetto) da mettere nella mano destra.
const ARMI_SFUSE := {
	"res://sorgenti3d/oggetti/sword_1handed.gltf": ["Viandante", "Spada"],
	"res://sorgenti3d/oggetti/Skeleton_Blade.gltf": ["Sepolto", "Lama"],
	"res://sorgenti3d/oggetti/Skeleton_Axe.gltf": ["Sepolto", "Ascia"],
	"res://sorgenti3d/oggetti/Skeleton_Staff.gltf": ["Sepolto", "Bastone"],
}
# Osso KayKit -> [osso Quaternius, scala, punto d'attacco Quaternius nello spazio del modello a riposo]
# Il punto KayKit è l'origine del suo osso. Testa e armi KayKit sono grandi: si rimpiccioliscono.
const ATTACCHI := {
	"head": ["Head", 0.27, Vector3(0.0, 1.585, -0.01)],
	"handslot.r": ["hand_r", 0.6, Vector3(-0.765, 1.43, -0.06)],
	"handslot.l": ["hand_l", 0.6, Vector3(0.765, 1.43, -0.06)],
}

# Armi, scudi ed elmi CC0 nello stile nuovo (0.1.40, sorgenti3d/armi): prendono il posto dei pezzi KayKit con lo stesso
# nome (i salvataggi e i nemici restano validi). Il pezzo KayKit dice solo dove sta (impugnatura, centro, direzione).
# "arma": "punta" = asse del modello verso la punta ("+z", "-y"...), scritto guardando il modello disteso; la mano
#   stringe a "presa" (frazione dal manico); "lungo" = lunghezza vera in metri.
# "centro": scudi, libri, elmi: stesso centro e stessa grandezza del pezzo di prima ("grande" = quanto più grande),
#   "faccia" = scudi e libri (il lato più sottile guarda dove guardava quello di prima), "giro" in gradi attorno all'alto.
const ARMI_NUOVE := "res://sorgenti3d/armi/"
const SOSTITUZIONI := {
	"Viandante__Spada": ["spada", "arma", {"punta": "+z", "presa": 0.09, "lungo": 0.95}],
	"Cavaliere__1H_Sword": ["stocco", "arma", {"punta": "+y", "presa": 0.08, "lungo": 1.0}],
	"Cavaliere__1H_Sword_Offhand": ["spada_bronzo", "arma", {"punta": "+y", "presa": 0.09, "lungo": 0.9}],
	"Cavaliere__2H_Sword": ["spadone", "arma", {"punta": "+z", "presa": 0.1, "lungo": 1.35}],
	"Barbaro__1H_Axe": ["ascia", "arma", {"punta": "+z", "presa": 0.15, "lungo": 0.7}],
	"Barbaro__1H_Axe_Offhand": ["ascia_bronzo", "arma", {"punta": "+y", "presa": 0.15, "lungo": 0.65}],
	"Barbaro__2H_Axe": ["bipenne", "arma", {"punta": "+z", "presa": 0.12, "lungo": 1.2}],
	"Viandante__Knife": ["pugnale", "arma", {"punta": "+z", "presa": 0.15, "lungo": 0.4}],
	"Viandante__Knife_Offhand": ["pugnale", "arma", {"punta": "+z", "presa": 0.15, "lungo": 0.4}],
	"Ladro__Knife": ["pugnale", "arma", {"punta": "+z", "presa": 0.15, "lungo": 0.4}],
	"Ladro__Knife_Offhand": ["pugnale", "arma", {"punta": "+z", "presa": 0.15, "lungo": 0.4}],
	"Mago__2H_Staff": ["bastone", "arma", {"punta": "+z", "presa": 0.35, "lungo": 1.7}],
	"Mago__1H_Wand": ["bacchetta", "arma", {"punta": "+z", "presa": 0.2, "lungo": 0.4}],
	"Sepolto__Lama": ["spada_bronzo", "arma", {"punta": "+y", "presa": 0.09, "lungo": 0.9}],
	"Sepolto__Ascia": ["ascia_bronzo", "arma", {"punta": "+y", "presa": 0.15, "lungo": 0.75}],
	"Sepolto__Bastone": ["bastone_sepolti", "arma", {"punta": "+y", "presa": 0.35, "lungo": 1.6, "colore": "#a89c88"}],
	"Viandante__1H_Crossbow": ["balestra", "centro", {"faccia": true, "grande": 1.0}],
	"Ladro__1H_Crossbow": ["balestra", "centro", {"faccia": true, "grande": 1.0}],
	"Mago__Spellbook": ["grimorio", "centro", {"faccia": true, "grande": 0.9}],
	"Cavaliere__Round_Shield": ["scudo_tondo", "centro", {"faccia": true, "grande": 1.0, "colore": "#6c6a70"}],
	"Cavaliere__Badge_Shield": ["scudo_goccia", "centro", {"faccia": true, "grande": 1.15}],
	"Cavaliere__Rectangle_Shield": ["scudo_torre", "centro", {"faccia": true, "grande": 1.1}],
	"Cavaliere__Spike_Shield": ["scudo_chiodato", "centro", {"faccia": true, "grande": 1.0, "colore": "#5c5a62"}],
	"Barbaro__Barbarian_Round_Shield": ["scudo_legno", "centro", {"faccia": true, "grande": 1.0}],
	"Cavaliere__Knight_Helmet": ["elmo_chiuso", "centro", {"grande": 1.0}],
	"Barbaro__Barbarian_Hat": ["elmo_corna", "centro", {"grande": 1.0, "colore": {"metal": "#5e5a5c", "horn": "#b8a888"}}],
	"Mago__Mage_Hat": ["cappello_tesa", "centro", {"grande": 1.0, "colore": "#4a3c32"}],
	"Sepolto__Skeleton_Warrior_Helmet": ["elmo_tondo", "centro", {"grande": 1.0}],
	"SepoltoLadro__Skeleton_Rogue_Hood": ["maschera_teschio", "centro", {"grande": 0.8, "colore": "#c8c0b0"}],
	"SepoltoMago__Skeleton_Mage_Hat": ["cappello_punta", "centro", {"grande": 1.0, "colore": "#3c3048"}],
}

# Mantelli generati: nome -> [texture, lunghezza (0-1, 1 = fino ai polpacci), larghezza in basso]
const MANTELLI := {
	"Viandante": ["mantello_viandante", 0.82, 0.30],
	"Cavaliere": ["mantello_cavaliere", 1.0, 0.33],
	"Barbaro": ["mantello_barbaro", 0.55, 0.36],
	"Eremita": ["mantello_eremita", 0.95, 0.31],
	"Sepolti": ["mantello_sepolti", 0.9, 0.32],
}

# Ossa KayKit -> ossa Quaternius per adattare le animazioni KayKit (le ossa non elencate restano a riposo).
const MAPPA_KK := {
	"hips": "pelvis", "spine": "spine_01", "chest": "spine_03", "head": "Head",
	"upperarm.l": "upperarm_l", "lowerarm.l": "lowerarm_l", "hand.l": "hand_l",
	"upperarm.r": "upperarm_r", "lowerarm.r": "lowerarm_r", "hand.r": "hand_r",
	"upperleg.l": "thigh_l", "lowerleg.l": "calf_l", "foot.l": "foot_l", "toes.l": "ball_l",
	"upperleg.r": "thigh_r", "lowerleg.r": "calf_r", "foot.r": "foot_r", "toes.r": "ball_r",
}
# Le mani KayKit non hanno dita: nelle clip adattate le dita stringono come in questa clip UAL.
const DITA_DA := "Sword_Idle"
const FPS_ADATTAMENTO := 30.0

# Clip composte (sullo scheletro KayKit, poi adattate come le altre). Vedi 0.1.33 e 0.1.35 in CLAUDE.md.
const COMPOSTE := {
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
	var clip_usate := {}
	for a: Dictionary in figura.get("animazioni", []) + figura.get("prove", []):
		clip_usate[a["clip"]] = true
	for gruppo: Dictionary in (figura.get("mosse", {}) as Dictionary).values():
		for cambio: Dictionary in (gruppo.get("animazioni", {}) as Dictionary).values():
			if cambio.has("clip"):
				clip_usate[cambio["clip"]] = true
	# Anche le clip dei nemici fatti col manichino (voci con "scena" in render_sprite.json, 0.1.39).
	var fogli: Variant = JSON.parse_string(FileAccess.get_file_as_string(FOGLI))
	if typeof(fogli) == TYPE_DICTIONARY:
		for voce: Dictionary in fogli.get("voci", []):
			if voce.get("scena", "") == USCITA:
				for a: Dictionary in voce.get("animazioni", []):
					clip_usate[a["clip"]] = true

	var base := _carica(SCHELETRO_BASE)
	var scheletro_base: Skeleton3D = base.find_children("*", "Skeleton3D", true, false)[0]

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
		scheletro.set_bone_pose_position(i, scheletro_base.get_bone_rest(i).origin)
		scheletro.set_bone_pose_rotation(i, scheletro_base.get_bone_rest(i).basis.get_rotation_quaternion())
		scheletro.set_bone_pose_scale(i, scheletro_base.get_bone_rest(i).basis.get_scale())
	base.free()

	var parti: Array = []
	var cache_tex := {}
	# Vestiti, corpo e capelli.
	for percorso: String in VESTITI:
		var info: Array = VESTITI[percorso]
		var scena := _carica(percorso)
		for mi: MeshInstance3D in scena.find_children("*", "MeshInstance3D", true, false):
			var chiave := String(mi.name)
			if not (info[1] as Dictionary).has(chiave) and mi.mesh != null:
				chiave = String(mi.mesh.resource_name)
			if not (info[1] as Dictionary).has(chiave):
				continue
			var nome := "%s__%s" % [info[0], info[1][chiave]]
			var mesh := _ricolora(mi.mesh, cache_tex)
			if SOLO_TESTA.has(nome):
				# Il corpo intero serve ai nemici senza vestiti sopra (il ghoul, 0.1.39).
				var intero := MeshInstance3D.new()
				intero.name = nome.get_slice("__", 0) + "__" + CORPO_INTERO
				intero.mesh = mesh
				intero.skin = mi.skin
				intero.visible = false
				scheletro.add_child(intero)
				intero.skeleton = NodePath("..")
				parti.append(String(intero.name))
				mesh = _solo_ossa(mesh, mi.skin, scheletro, OSSA_TESTA)
			var copia := MeshInstance3D.new()
			copia.name = nome
			copia.mesh = mesh
			copia.skin = mi.skin
			copia.visible = false
			scheletro.add_child(copia)
			copia.skeleton = NodePath("..")
			parti.append(nome)
		scena.free()

	# Pezzi rigidi KayKit: stessa direzione nel mondo a riposo, rimpiccioliti attorno al punto d'attacco.
	var kk := _carica(ANIMAZIONI_KK)
	var sk_kk: Skeleton3D = kk.find_children("*", "Skeleton3D", true, false)[0]
	var attacchi := {}
	for percorso: String in RIGIDI_KK:
		var scena := _carica(percorso)
		var sk: Skeleton3D = scena.find_children("*", "Skeleton3D", true, false)[0]
		for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
			var genitore := mi.get_parent()
			if not genitore is BoneAttachment3D:
				continue
			var osso := (genitore as BoneAttachment3D).bone_name
			if not ATTACCHI.has(osso):
				continue
			var nome := "%s__%s" % [RIGIDI_KK[percorso][0], mi.name]
			var mondo_kk := sk.get_bone_global_rest(sk.find_bone(osso)) * mi.transform
			_attacca_rigido(scheletro, attacchi, nome, _ricolora(mi.mesh, cache_tex, _cupa(RIGIDI_KK[percorso][1], cache_tex)),
					osso, mondo_kk, sk_kk)
			parti.append(nome)
		scena.free()
	for percorso: String in ARMI_SFUSE:
		var info: Array = ARMI_SFUSE[percorso]
		var scena := _carica(percorso)
		var trovati := scena.find_children("*", "MeshInstance3D", true, false)
		if not trovati.is_empty():
			var mi := trovati[0] as MeshInstance3D
			var nome := "%s__%s" % [info[0], info[1]]
			var mondo_kk := sk_kk.get_bone_global_rest(sk_kk.find_bone("handslot.r")) * mi.transform
			_attacca_rigido(scheletro, attacchi, nome, _ricolora(mi.mesh, cache_tex), "handslot.r", mondo_kk, sk_kk)
			parti.append(nome)
		scena.free()

	# Armi, scudi ed elmi nuovi al posto dei KayKit (stesso nome, stesso posto).
	for nome: String in SOSTITUZIONI:
		var vecchio := scheletro.find_child(nome, true, false) as MeshInstance3D
		if vecchio == null:
			printerr("Pezzo da sostituire mancante: ", nome)
			continue
		var regola: Array = SOSTITUZIONI[nome]
		var nuovo := _unisci(_carica(ARMI_NUOVE + String(regola[0]) + ".glb"))
		vecchio.transform = _posa_sostituto(vecchio.transform, vecchio.mesh.get_aabb(), nuovo, String(regola[1]), regola[2])
		vecchio.mesh = _ricolora(nuovo, cache_tex)
		vecchio.set_meta("fonte", String(regola[0]))   # per la prova: pezzo rifatto nello stile nuovo
		if regola[1] == "arma":
			vecchio.set_meta("punta", asse_punta(String(regola[2]["punta"])))   # la prova controlla il verso in mano
		if regola[2].has("colore"):
			# Modelli senza texture: una texture piccola del colore scelto (la leggono figura_viva e render_sprite).
			# "colore" = un colore per tutto, oppure {nome del materiale: colore} (elmo con le corna: metallo e corno).
			var colori: Variant = regola[2]["colore"]
			for sup in vecchio.mesh.get_surface_count():
				var m := vecchio.mesh.surface_get_material(sup) as StandardMaterial3D
				if m == null or m.albedo_texture != null:
					continue
				var orig := nuovo.surface_get_material(sup) if sup < nuovo.get_surface_count() else null
				var nome_mat := String(orig.resource_name) if orig != null else ""   # _ricolora non tiene i nomi
				var c: String = String(colori) if colori is String else String(colori.get(nome_mat, ""))
				if c == "":
					printerr("Materiale senza colore: ", nome, " ", nome_mat)
					continue
				var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
				img.fill(Color(c))
				m.albedo_texture = ImageTexture.create_from_image(img)

	# Mantelli.
	for nome: String in MANTELLI:
		var m: Array = MANTELLI[nome]
		var mantello := _mantello(scheletro, String(m[0]), float(m[1]), float(m[2]))
		mantello.name = "Mantello__" + nome
		mantello.visible = false
		scheletro.add_child(mantello)
		mantello.skeleton = NodePath("..")
		parti.append(String(mantello.name))

	# Animazioni: UAL così come sono, KayKit adattate, composte adattate.
	var lettore := AnimationPlayer.new()
	lettore.name = "AnimationPlayer"
	radice.add_child(lettore)
	var libreria := AnimationLibrary.new()
	var ual := _carica(ANIMAZIONI_UAL)
	var lettore_ual: AnimationPlayer = ual.find_children("*", "AnimationPlayer", true, false)[0]
	var lettore_kk: AnimationPlayer = kk.find_children("*", "AnimationPlayer", true, false)[0]
	var dita := _pose_dita(lettore_ual.get_animation(DITA_DA))
	for clip: String in clip_usate:
		if clip.begins_with(PREFISSO_KK):
			var fonte := clip.trim_prefix(PREFISSO_KK)
			var a_kk: Animation = null
			if lettore_kk.has_animation(fonte):
				a_kk = lettore_kk.get_animation(fonte)
			elif COMPOSTE.has(fonte):
				var ricetta: Dictionary = COMPOSTE[fonte]
				a_kk = _componi_mirata(sk_kk, ricetta) if ricetta.get("mirata", false) else _componi(lettore_kk, sk_kk, ricetta)
			if a_kk != null:
				libreria.add_animation(clip, _adatta(a_kk, sk_kk, scheletro, dita))
		elif lettore_ual.has_animation(clip):
			libreria.add_animation(clip, _rinomina_tracce(lettore_ual.get_animation(clip)))
	lettore.add_animation_library("", libreria)
	ual.free()
	kk.free()

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


func _piccola(tex: Texture2D, cache: Dictionary) -> Texture2D:
	# Texture al massimo di LATO_TEXTURE pixel: a 96-192 pixel di figura non serve di più.
	if tex == null:
		return null
	if cache.has(tex):
		return cache[tex]
	var img := tex.get_image()
	if img == null:
		return tex
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	if maxi(img.get_width(), img.get_height()) > LATO_TEXTURE:
		img.resize(LATO_TEXTURE, LATO_TEXTURE, Image.INTERPOLATE_LANCZOS)
	var nuova := ImageTexture.create_from_image(img)
	cache[tex] = nuova
	return nuova


func _cupa(nome: String, cache: Dictionary) -> Texture2D:
	# Texture KayKit nella palette cupa (strumenti/genera_arte.py): armi ed elmi come prima.
	if not cache.has(nome):
		cache[nome] = ImageTexture.create_from_image(Image.load_from_file(
				ProjectSettings.globalize_path("res://sorgenti3d/oggetti/%s.png" % nome)))
	return cache[nome]


func _ricolora(mesh: Mesh, cache: Dictionary, tex: Texture2D = null) -> Mesh:
	# Stessa forma; per ogni superficie un materiale con colore, normali e occlusione (li legge figura_viva).
	var copia := mesh.duplicate() as Mesh
	for s in copia.get_surface_count():
		var mat := StandardMaterial3D.new()
		var originale := mesh.surface_get_material(s) as BaseMaterial3D
		if tex != null:
			mat.albedo_texture = tex
		if originale != null:
			if tex == null:
				mat.albedo_texture = _piccola(originale.albedo_texture, cache)
			mat.albedo_color = originale.albedo_color
			if originale.normal_enabled and originale.normal_texture != null:
				mat.normal_enabled = true
				mat.normal_texture = _piccola(originale.normal_texture, cache)
			if originale.ao_enabled and originale.ao_texture != null:
				mat.ao_enabled = true
				mat.ao_texture = _piccola(originale.ao_texture, cache)
			elif originale.roughness_texture != null and String(originale.roughness_texture.resource_name).contains("ORM"):
				# Quaternius mette l'occlusione nel rosso della texture ORM (il glTF la dà solo come rugosità).
				mat.ao_enabled = true
				mat.ao_texture = _piccola(originale.roughness_texture, cache)
			mat.transparency = originale.transparency
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		# Niente "unshaded": il materiale è solo un contenitore di texture (gli shader li mette figura_viva),
		# e con "unshaded" normali e occlusione non verrebbero salvati.
		copia.surface_set_material(s, mat)
	return copia


func _unisci(scena: Node3D) -> ArrayMesh:
	# Tutte le mesh di un file in una sola (scudi in più pezzi), con le loro trasformazioni.
	var unita := ArrayMesh.new()
	for mi: MeshInstance3D in scena.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != scena:
			if n is Node3D:
				t = (n as Node3D).transform * t
			n = n.get_parent()
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i in v.size():
				v[i] = t * v[i]
			arr[Mesh.ARRAY_VERTEX] = v
			if arr[Mesh.ARRAY_NORMAL] != null:
				var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				for i in nn.size():
					nn[i] = (t.basis * nn[i]).normalized()
				arr[Mesh.ARRAY_NORMAL] = nn
			if arr[Mesh.ARRAY_TANGENT] != null:
				var tg: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
				for i in range(0, tg.size(), 4):
					var d := (t.basis * Vector3(tg[i], tg[i + 1], tg[i + 2])).normalized()
					tg[i] = d.x
					tg[i + 1] = d.y
					tg[i + 2] = d.z
				arr[Mesh.ARRAY_TANGENT] = tg
			for k in [Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
				arr[k] = null
			unita.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			unita.surface_set_material(unita.get_surface_count() - 1, mi.get_active_material(s))
	scena.free()
	return unita


func _unita(i: int) -> Vector3:
	var v := Vector3.ZERO
	v[i] = 1.0
	return v


func _assi(aabb: AABB) -> Array:
	# Indici degli assi dal più lungo al più corto.
	var d := aabb.size
	var ordine := [0, 1, 2]
	ordine.sort_custom(func(a: int, b: int) -> bool: return d[a] > d[b])
	return ordine


const FETTE_ARMA := 12


static func profilo_arma(mesh: Mesh, asse: int) -> Array:
	# Larghezza massima (distanza dall'asse) in FETTE_ARMA fette lungo l'asse, dal lato negativo al positivo.
	var aabb := mesh.get_aabb()
	var lo: float = aabb.position[asse]
	var lungo: float = maxf(1e-6, aabb.size[asse])
	var c := aabb.get_center()
	var larg := []
	larg.resize(FETTE_ARMA)
	larg.fill(0.0)
	for s in mesh.get_surface_count():
		for p: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var k := clampi(int((p[asse] - lo) / lungo * FETTE_ARMA), 0, FETTE_ARMA - 1)
			var w := Vector2(p[(asse + 1) % 3] - c[(asse + 1) % 3], p[(asse + 2) % 3] - c[(asse + 2) % 3])
			larg[k] = maxf(larg[k], w.length())
	return larg


static func asse_punta(testo: String) -> Vector3:
	# "+z", "-x"...: dove sta la punta nello spazio del modello (deciso guardando il modello disteso, mai indovinato).
	var v := Vector3.ZERO
	v["xyz".find(testo[1])] = -1.0 if testo[0] == "-" else 1.0
	return v


func _posa_sostituto(vecchia: Transform3D, aabb_v: AABB, nuovo: Mesh, modo: String, opz: Dictionary) -> Transform3D:
	# Trasformazione (nello spazio dell'osso) del pezzo nuovo, ricavata da dove stava quello di prima.
	var aabb_n := nuovo.get_aabb()
	var av := _assi(aabb_v)
	var an := _assi(aabb_n)
	var asse_v := vecchia.basis * _unita(av[0])
	var largo_v := vecchia.basis * _unita(av[1])
	var sottile_v := vecchia.basis * _unita(av[2])
	var centro_v := vecchia * aabb_v.get_center()
	var u_n := _unita(an[0])
	var w_n := _unita(an[1])
	if modo == "arma":
		# Prima: la punta è l'estremo lontano dalla mano (l'origine dell'osso).
		var dir_v := asse_v.normalized()
		var a := centro_v - dir_v * asse_v.length() * aabb_v.size[av[0]] * 0.5
		var b := centro_v + dir_v * asse_v.length() * aabb_v.size[av[0]] * 0.5
		if a.length() > b.length():
			dir_v = -dir_v
		var presa_v := centro_v - dir_v * dir_v.dot(centro_v)   # il punto dell'asse più vicino alla mano
		# Fino alla 0.1.41 il verso si indovinava ("il lato più largo è la punta"): spade e bacchetta finivano al contrario.
		var punta_n := asse_punta(String(opz["punta"]))
		if absf(punta_n[an[0]]) < 0.5:
			printerr("Punta lungo un asse che non è il più lungo del modello: ", opz["punta"], " ", aabb_n)
		var lungo_n: float = aabb_n.size[an[0]]
		var manico_n := aabb_n.get_center() - punta_n * lungo_n * 0.5
		var presa_n := manico_n + punta_n * lungo_n * float(opz.get("presa", 0.1))
		var x := dir_v
		var y := (largo_v - x * x.dot(largo_v)).normalized()
		var base_v := Basis(x, y, x.cross(y))
		var yn := w_n
		var base_n := Basis(punta_n, yn, punta_n.cross(yn))
		var k: float = float(opz.get("lungo", lungo_n)) / lungo_n
		var r := base_v * base_n.inverse() * Basis.from_scale(Vector3.ONE * k)
		return Transform3D(r, presa_v - r * presa_n)
	# "centro": stessa posizione, stessa grandezza.
	var base := Basis.IDENTITY
	if opz.get("faccia", false):
		var f_n := _unita(an[2])
		var x := asse_v.normalized()
		var z := (sottile_v - x * x.dot(sottile_v)).normalized()
		base = Basis(x, z.cross(x), z) * Basis(u_n, f_n.cross(u_n), f_n).inverse()
	else:
		# Elmi, cappelli, balestra: l'alto del modello (+Y) resta l'alto del pezzo di prima, girato di "giro" gradi.
		var su := (vecchia.basis * Vector3.UP).normalized()
		var avanti := (vecchia.basis * Vector3.BACK).normalized()
		base = Basis(su.cross(avanti).normalized(), su, avanti.normalized()).orthonormalized()
		base = base * Basis(Vector3.UP, deg_to_rad(float(opz.get("giro", 0.0))))
	var k := (aabb_v.size * vecchia.basis.get_scale()).length() / maxf(0.0001, aabb_n.size.length()) * float(opz.get("grande", 1.0))
	var r2 := base * Basis.from_scale(Vector3.ONE * k)
	return Transform3D(r2, centro_v - r2 * aabb_n.get_center())


func _solo_ossa(mesh: Mesh, skin: Skin, scheletro: Skeleton3D, ossa: Array) -> Mesh:
	# Tiene solo i triangoli i cui vertici sono legati soprattutto a queste ossa (la testa del corpo base).
	var nuova := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var ossa_v: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var pesi_v: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var n_v: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		@warning_ignore("integer_division")
		var per_vertice := ossa_v.size() / maxi(1, n_v)
		var buoni := PackedByteArray()
		buoni.resize(n_v)
		for v in n_v:
			var somma := 0.0
			for k in per_vertice:
				var b := ossa_v[v * per_vertice + k]
				# I legami Quaternius sono per numero d'osso (stesso ordine in tutti i file), non per nome.
				var nome := ""
				if skin != null and b < skin.get_bind_count():
					nome = String(skin.get_bind_name(b))
					if nome == "":
						nome = scheletro.get_bone_name(skin.get_bind_bone(b))
				if ossa.has(nome):
					somma += pesi_v[v * per_vertice + k]
			buoni[v] = 1 if somma >= 0.5 else 0
		var indici: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var tenuti := PackedInt32Array()
		for t in range(0, indici.size(), 3):
			if buoni[indici[t]] == 1 and buoni[indici[t + 1]] == 1 and buoni[indici[t + 2]] == 1:
				tenuti.append_array([indici[t], indici[t + 1], indici[t + 2]])
		if tenuti.is_empty():
			continue
		arr[Mesh.ARRAY_INDEX] = tenuti
		nuova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		nuova.surface_set_material(nuova.get_surface_count() - 1, mesh.surface_get_material(s))
	return nuova


func _attacca_rigido(scheletro: Skeleton3D, attacchi: Dictionary, nome: String, mesh: Mesh, osso_kk: String,
		mondo_kk: Transform3D, sk_kk: Skeleton3D) -> void:
	var regola: Array = ATTACCHI[osso_kk]
	var osso_q: String = regola[0]
	var punto_kk := sk_kk.get_bone_global_rest(sk_kk.find_bone(osso_kk)).origin
	var punto_q: Vector3 = regola[2]
	var s: float = regola[1]
	var mondo_q := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), punto_q) * Transform3D(Basis.IDENTITY, -punto_kk) * mondo_kk
	if not attacchi.has(osso_q):
		var a := BoneAttachment3D.new()
		a.name = "attacco_" + osso_q
		a.bone_name = osso_q
		scheletro.add_child(a)
		attacchi[osso_q] = a
	var copia := MeshInstance3D.new()
	copia.name = nome
	copia.mesh = mesh
	copia.transform = scheletro.get_bone_global_rest(scheletro.find_bone(osso_q)).affine_inverse() * mondo_q
	copia.visible = false
	(attacchi[osso_q] as BoneAttachment3D).add_child(copia)


func _mantello(scheletro: Skeleton3D, texture: String, lunghezza: float, largo_giu: float) -> MeshInstance3D:
	# Telo che scende dalle spalle dietro la schiena: in alto segue il petto, in mezzo il bacino, in basso
	# le cosce (metà sinistra la coscia sinistra, metà destra la destra), così ondeggia con il passo.
	const COLONNE := 8
	const RIGHE := 12
	var alto := 1.47
	var basso := lerpf(1.0, 0.32, lunghezza)
	var vertici := PackedVector3Array()
	var normali := PackedVector3Array()
	var uv := PackedVector2Array()
	var ossa := PackedInt32Array()
	var pesi := PackedFloat32Array()
	var indici := PackedInt32Array()
	var nomi_ossa := ["spine_03", "pelvis", "thigh_l", "thigh_r"]
	for r in RIGHE + 1:
		var v := float(r) / RIGHE
		var y := lerpf(alto, basso, v)
		var mezzo := lerpf(0.17, largo_giu, pow(v, 0.8))
		var z := lerpf(-0.13, -0.23, v) - 0.03 * sin(v * PI)
		for c in COLONNE + 1:
			var u := float(c) / COLONNE
			var x := lerpf(mezzo, -mezzo, u)
			var curva := -0.05 * (1.0 - pow(2.0 * u - 1.0, 2.0))   # la schiena è tonda: il telo la avvolge
			vertici.append(Vector3(x, y, z + curva))
			normali.append(Vector3(0, 0, -1))
			uv.append(Vector2(u, v))
			# Pesi: petto in alto, bacino nel mezzo, cosce in basso.
			var w_petto := clampf(1.0 - v / 0.45, 0.0, 1.0)
			var w_gambe := clampf((v - 0.45) / 0.55, 0.0, 1.0) * 0.6
			var w_bacino := maxf(0.0, 1.0 - w_petto - w_gambe)
			var sinistra := clampf((x / maxf(mezzo, 0.01)) * 0.5 + 0.5, 0.0, 1.0)   # +X = sinistra
			ossa.append_array([0, 1, 2, 3])
			pesi.append_array([w_petto, w_bacino, w_gambe * sinistra, w_gambe * (1.0 - sinistra)])
	for r in RIGHE:
		for c in COLONNE:
			var a := r * (COLONNE + 1) + c
			indici.append_array([a, a + 1, a + COLONNE + 1, a + 1, a + COLONNE + 2, a + COLONNE + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vertici
	arr[Mesh.ARRAY_NORMAL] = normali
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_BONES] = ossa
	arr[Mesh.ARRAY_WEIGHTS] = pesi
	arr[Mesh.ARRAY_INDEX] = indici
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(
			ProjectSettings.globalize_path("res://sorgenti3d/ambientcg/%s.png" % texture)))
	mat.normal_enabled = true
	mat.normal_texture = ImageTexture.create_from_image(Image.load_from_file(
			ProjectSettings.globalize_path("res://sorgenti3d/ambientcg/mantello_normali.png")))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mesh.surface_set_material(0, mat)
	var skin := Skin.new()
	for n: String in nomi_ossa:
		skin.add_named_bind(n, scheletro.get_bone_global_rest(scheletro.find_bone(n)).affine_inverse())
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.skin = skin
	return mi


func _proprietario(nodo: Node, radice: Node) -> void:
	for figlio in nodo.get_children():
		figlio.owner = radice
		_proprietario(figlio, radice)


func _rinomina_tracce(a: Animation) -> Animation:
	# Le clip UAL guardano "Armature/Skeleton3D": nel manichino lo scheletro è "Rig/Skeleton3D".
	var copia := a.duplicate(true) as Animation
	for t in copia.get_track_count():
		var p := String(copia.track_get_path(t))
		copia.track_set_path(t, NodePath("Rig/Skeleton3D:" + p.get_slice(":", 1)))
	return copia


func _pose_dita(a: Animation) -> Dictionary:
	# Rotazioni delle dita al primo istante di una clip UAL (mano chiusa sull'impugnatura).
	var dita := {}
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var osso := String(a.track_get_path(t)).get_slice(":", 1)
		if osso.contains("index") or osso.contains("middle") or osso.contains("ring") or osso.contains("pinky") or osso.contains("thumb"):
			dita[osso] = a.rotation_track_interpolate(t, 0.0)
	return dita


func _locali(a: Animation, sk: Skeleton3D, prefisso: String, t: float) -> Array:
	# [rotazioni, posizioni] locali di ogni osso al tempo t (riposo dove la clip non ha tracce).
	var rot: Array = []
	var pos: Array = []
	for i in sk.get_bone_count():
		var riposo := sk.get_bone_rest(i)
		var q := riposo.basis.get_rotation_quaternion()
		var p := riposo.origin
		var percorso := NodePath(prefisso + sk.get_bone_name(i))
		var tr := a.find_track(percorso, Animation.TYPE_ROTATION_3D)
		if tr >= 0:
			q = a.rotation_track_interpolate(tr, t)
		var tp := a.find_track(percorso, Animation.TYPE_POSITION_3D)
		if tp >= 0:
			p = a.position_track_interpolate(tp, t)
		rot.append(q)
		pos.append(p)
	return [rot, pos]


static func _ordine(sk: Skeleton3D) -> Array:
	var ordine: Array = []
	var coda: Array = []
	for i in sk.get_bone_count():
		if sk.get_bone_parent(i) < 0:
			coda.append(i)
	while not coda.is_empty():
		var i: int = coda.pop_front()
		ordine.append(i)
		coda.append_array(sk.get_bone_children(i))
	return ordine


func _globali(sk: Skeleton3D, rot: Array, pos: Array, ordine: Array) -> Array:
	var g: Array = []
	g.resize(sk.get_bone_count())
	for i: int in ordine:
		var locale := Transform3D(Basis(rot[i] as Quaternion), pos[i] as Vector3)
		var padre := sk.get_bone_parent(i)
		g[i] = locale if padre < 0 else (g[padre] as Transform3D) * locale
	return g


func _adatta(a: Animation, sk_kk: Skeleton3D, sk_q: Skeleton3D, dita: Dictionary) -> Animation:
	# Adatta una clip KayKit allo scheletro Quaternius: ogni osso ruota nel mondo quanto il suo corrispondente
	# KayKit si è mosso dal riposo (i due scheletri sono entrambi a T, rivolti in avanti). Il bacino si sposta
	# quanto le anche KayKit, in proporzione alla lunghezza delle gambe.
	var fuori := Animation.new()
	fuori.length = a.length
	fuori.loop_mode = a.loop_mode
	var ordine_kk := _ordine(sk_kk)
	var ordine_q := _ordine(sk_q)
	var riposo_kk: Array = []
	for i in sk_kk.get_bone_count():
		riposo_kk.append(sk_kk.get_bone_global_rest(i))
	var riposo_q: Array = []
	for i in sk_q.get_bone_count():
		riposo_q.append(sk_q.get_bone_global_rest(i))
	var anche_kk := sk_kk.find_bone("hips")
	var bacino := sk_q.find_bone("pelvis")
	var rapporto := (riposo_q[bacino] as Transform3D).origin.y / (riposo_kk[anche_kk] as Transform3D).origin.y
	var corrisponde := {}   # indice Quaternius -> indice KayKit
	for nome_kk: String in MAPPA_KK:
		var i_kk := sk_kk.find_bone(nome_kk)
		var i_q := sk_q.find_bone(MAPPA_KK[nome_kk])
		if i_kk >= 0 and i_q >= 0:
			corrisponde[i_q] = i_kk
	var tracce := {}
	for i_q: int in corrisponde:
		var t := fuori.add_track(Animation.TYPE_ROTATION_3D)
		fuori.track_set_path(t, NodePath("Rig/Skeleton3D:" + sk_q.get_bone_name(i_q)))
		tracce[i_q] = t
	var traccia_bacino := fuori.add_track(Animation.TYPE_POSITION_3D)
	fuori.track_set_path(traccia_bacino, NodePath("Rig/Skeleton3D:pelvis"))
	for osso: String in dita:
		var t := fuori.add_track(Animation.TYPE_ROTATION_3D)
		fuori.track_set_path(t, NodePath("Rig/Skeleton3D:" + osso))
		fuori.rotation_track_insert_key(t, 0.0, dita[osso])
	var passi := maxi(1, ceili(a.length * FPS_ADATTAMENTO))
	for k in passi + 1:
		var tempo := minf(a.length, float(k) / FPS_ADATTAMENTO)
		var loc := _locali(a, sk_kk, "Rig/Skeleton3D:", tempo)
		var g_kk := _globali(sk_kk, loc[0], loc[1], ordine_kk)
		var rot_q: Array = []
		for i in sk_q.get_bone_count():
			rot_q.append(sk_q.get_bone_rest(i).basis.get_rotation_quaternion())
		var g_rot: Array = []
		g_rot.resize(sk_q.get_bone_count())
		for i: int in ordine_q:
			var padre := sk_q.get_bone_parent(i)
			var g_padre: Quaternion = Quaternion.IDENTITY if padre < 0 else g_rot[padre]
			if corrisponde.has(i):
				var j: int = corrisponde[i]
				var delta := (g_kk[j] as Transform3D).basis.get_rotation_quaternion() * (riposo_kk[j] as Transform3D).basis.get_rotation_quaternion().inverse()
				var voluta := delta * (riposo_q[i] as Transform3D).basis.get_rotation_quaternion()
				rot_q[i] = (g_padre.inverse() * voluta).normalized()
			g_rot[i] = g_padre * (rot_q[i] as Quaternion)
		for i_q: int in tracce:
			fuori.rotation_track_insert_key(tracce[i_q], tempo, rot_q[i_q])
		# Bacino: spostamento delle anche KayKit dal riposo. In alto e in basso in scala con le gambe (accucciarsi,
		# saltare); in avanti e di lato com'era: il corpo lo sposta il gioco, ingrandito scivolerebbe fuori posto.
		var d := (g_kk[anche_kk] as Transform3D).origin - (riposo_kk[anche_kk] as Transform3D).origin
		var spostamento := Vector3(d.x, d.y * rapporto, d.z)
		var mondo := (riposo_q[bacino] as Transform3D).origin + spostamento
		var padre_b := sk_q.get_bone_parent(bacino)
		var locale := mondo if padre_b < 0 else (riposo_q[padre_b] as Transform3D).affine_inverse() * mondo
		fuori.position_track_insert_key(traccia_bacino, tempo, locale)
	return fuori


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
