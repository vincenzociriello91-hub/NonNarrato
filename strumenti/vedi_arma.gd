extends SceneTree
# Armi di sorgenti3d/armi distese, asse lungo in orizzontale: per decidere "punta" in crea_manichino.gd (SOSTITUZIONI).
# -- --nomi=a,b --file=PATH. Ogni riga mostra a destra il lato positivo dell asse lungo del primo pezzo del modello
# (attenzione: crea_manichino unisce i pezzi, l asse lungo può cambiare: vale il messaggio "Punta lungo un asse...").
func _initialize() -> void:
	_vai.call_deferred()

func _arg(nome: String, base: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nome):
			return a.trim_prefix("--%s=" % nome)
	return base

func _vai() -> void:
	var CM: GDScript = load("res://strumenti/crea_manichino.gd")
	var nomi := _arg("nomi", "spada").split(",")
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 400 * nomi.size())
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.25 * nomi.size()
	cam.position = Vector3(0, 0, 5)
	vp.add_child(cam)
	var luce := DirectionalLight3D.new()
	luce.rotation_degrees = Vector3(-30, 20, 0)
	vp.add_child(luce)
	var amb := WorldEnvironment.new()
	amb.environment = Environment.new()
	amb.environment.ambient_light_color = Color.WHITE
	amb.environment.ambient_light_energy = 0.6
	amb.environment.background_mode = Environment.BG_COLOR
	amb.environment.background_color = Color(0.3, 0.32, 0.38)
	vp.add_child(amb)
	var i := 0
	for n in nomi:
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		doc.append_from_file(ProjectSettings.globalize_path("res://sorgenti3d/armi/%s.glb" % n), st)
		var sc: Node = doc.generate_scene(st)
		var mesh: Mesh = null
		for mi: MeshInstance3D in sc.find_children("*", "MeshInstance3D", true, false):
			mesh = mi.mesh
			break
		var aabb := mesh.get_aabb()
		var ax := 0
		for k in 3:
			if aabb.size[k] > aabb.size[ax]: ax = k
		var s := 1.0   # lato positivo dell asse a destra
		print(n, " asse lungo ", "xyz"[ax], " (a destra il +) profilo ", CM.profilo_arma(mesh, ax).map(func(w): return snappedf(w, 0.001)))
		var mi2 := MeshInstance3D.new()
		mi2.mesh = mesh
		var u := Vector3.ZERO; u[ax] = s
		var w := Vector3.ZERO; w[(ax + 1) % 3] = 1.0
		var b := Basis(u, w, u.cross(w))   # u -> X (destra)
		var k := 0.8 / aabb.size[ax]
		mi2.transform = Transform3D(b.inverse().scaled(Vector3.ONE * k), Vector3.ZERO)
		mi2.position = -(mi2.transform.basis * aabb.get_center()) + Vector3(0.0, ((nomi.size() - 1) * 0.5 - i) * 0.25, 0.0)
		vp.add_child(mi2)
		i += 1
	await process_frame
	await process_frame
	for _f in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(_arg("file", "/tmp/glb.png"))
	quit(0)
