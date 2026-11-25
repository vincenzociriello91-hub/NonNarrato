extends SceneTree
# Strumento di lavoro: elenca nodi, animazioni e ingombro di un modello GLB.
# Uso: godot --headless --path . -s res://strumenti/ispeziona_glb.gd -- <file.glb> [altro.glb ...]

func _initialize() -> void:
	_avvia.call_deferred()


func _avvia() -> void:
	await process_frame
	for percorso in OS.get_cmdline_user_args():
		_ispeziona(percorso)
	quit()


func _ispeziona(percorso: String) -> void:
	print("=== ", percorso)
	var doc := GLTFDocument.new()
	var stato := GLTFState.new()
	var err := doc.append_from_file(percorso, stato)
	if err != OK:
		print("ERRORE apertura: ", err)
		return
	var scena := doc.generate_scene(stato)
	if scena == null:
		print("ERRORE scena nulla")
		return
	root.add_child(scena)
	_stampa_albero(scena, 0)
	var aabb := _aabb_totale(scena)
	print("AABB: ", aabb.position, " dimensione ", aabb.size)
	for ap in scena.find_children("*", "AnimationPlayer", true, false):
		var nomi: Array = []
		for n in (ap as AnimationPlayer).get_animation_list():
			var a := (ap as AnimationPlayer).get_animation(n)
			nomi.append("%s(%.2fs)" % [n, a.length])
		print("ANIMAZIONI (", nomi.size(), "): ", ", ".join(nomi))
	scena.queue_free()


func _stampa_albero(n: Node, livello: int) -> void:
	if livello > 4:
		return
	var extra := ""
	if n is MeshInstance3D:
		extra = " [mesh]"
	elif n is Skeleton3D:
		var sk := n as Skeleton3D
		var nomi_ossa: Array = []
		for i in sk.get_bone_count():
			nomi_ossa.append(sk.get_bone_name(i))
		extra = " [ossa: %s]" % ", ".join(nomi_ossa)
	elif n is BoneAttachment3D:
		extra = " [attacco: %s]" % (n as BoneAttachment3D).bone_name
	print("  ".repeat(livello), n.name, " (", n.get_class(), ")", extra)
	for c in n.get_children():
		_stampa_albero(c, livello + 1)


func _aabb_totale(n: Node) -> AABB:
	var totale := AABB()
	var primo := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var a: AABB = mi.global_transform * mi.get_aabb()
		if primo:
			totale = a
			primo = false
		else:
			totale = totale.merge(a)
	return totale
