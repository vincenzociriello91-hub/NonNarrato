extends SceneTree
# Ogni arma (o aspetto) in mano al protagonista, in più animazioni, a doppia definizione: un foglio per voce.
# -- --cartella=DIR [--anim=a,b] [--ogni=2] [--voci=arma:spada_viandante;...|armi|armature]
func _initialize() -> void:
	_vai.call_deferred()

func _arg(nome: String, base: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nome):
			return a.trim_prefix("--%s=" % nome)
	return base

func _vai() -> void:
	await process_frame
	var dir := _arg("cartella", "/tmp")
	var eq := root.get_node("Equipaggiamento")
	var prima: Dictionary = eq.call("stato")
	var voci: Array = []
	var quali := _arg("voci", "armi")
	if quali == "armi":
		for posto in ["arma", "mano_sinistra"]:
			for id: String in eq.call("oggetti_del_posto", posto):
				voci.append({posto: id})
	elif quali == "armature":
		for posto in ["testa", "copricapo", "busto", "braccia", "gambe", "mantello"]:
			for id: String in eq.call("oggetti_del_posto", posto):
				voci.append({posto: id})
	else:
		for v in quali.split(";"):
			var d := {}
			for c in v.split(","):
				d[c.get_slice(":", 0)] = c.get_slice(":", 1)
			voci.append(d)
	var f: Sprite2D = (load("res://script/figura_viva.gd") as GDScript).new()
	f.set("densita_fissa", 2)
	f.call("carica", "protagonista")
	root.add_child(f)
	await process_frame
	var ogni := int(_arg("ogni", "2"))
	var anims := _arg("anim", "fermo,corsa,attacco1,attacco2,arrampica,nuota,issata,tiro_dardo").split(",")
	for v: Dictionary in voci:
		eq.call("ripristina")
		for posto: String in v:
			eq.call("indossa", posto, v[posto])
		await process_frame
		await process_frame
		var righe: Array = []
		for nome in anims:
			f.call("riproduci", nome, true)
			f.set("in_corso", false)
			var anim: Dictionary = f.get("_anim")
			var riga: Array = []
			var elenco: Array = anim["frame"]
			for k in range(0, elenco.size(), ogni):
				f.set("_ultimo", -1)
				f.call("_mostra", int(elenco[k]))
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				riga.append((f.call("anteprima") as Texture2D).get_image())
			righe.append(riga)
		var lato: int = (righe[0][0] as Image).get_width()
		var colonne := 0
		for r: Array in righe:
			colonne = maxi(colonne, r.size())
		var foglio := Image.create(colonne * lato, righe.size() * lato, false, Image.FORMAT_RGBA8)
		foglio.fill(Color(0.42, 0.45, 0.5))
		for y in righe.size():
			for x in (righe[y] as Array).size():
				var im: Image = righe[y][x]
				im.convert(Image.FORMAT_RGBA8)
				foglio.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x * lato, y * lato))
		var nome_f := "_".join(PackedStringArray(v.values()))
		foglio.save_png(dir.path_join(nome_f + ".png"))
		print("FOGLIO ", nome_f, " ", foglio.get_size())
	eq.call("ripristina_stato", prima)
	quit(0)
