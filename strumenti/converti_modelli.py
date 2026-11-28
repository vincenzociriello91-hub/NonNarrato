# Strumento di lavoro (Blender 4.2, fuori dal gioco): porta nel repository i modelli CC0 scaricati, in .glb
# con le texture dentro e ridotte a LATO pixel. Uso:
#   blender -b -P strumenti/converti_modelli.py -- elenco.json cartella_uscita
# elenco.json = {"nome": {"file": "...glb/gltf/obj/fbx/dae/blend", "oggetto": "nome facoltativo", "texture": "cartella facoltativa"}}
#
# Trucchi per i file vecchi (OpenGameArt): oggetti su "layer" nascosti (si rendono visibili), materiali Blender Internal
# senza nodi (si collega la texture di colore col nome più simile), texture già impacchettate (non vanno scartate).
import bpy, sys, os, re, json, difflib

LATO = int(os.environ.get("LATO", "512"))   # i modelli d'ambiente bastano a 256
TEMP = os.path.join(os.environ.get("TMPDIR", "/tmp"), "converti_modelli")
os.makedirs(TEMP, exist_ok=True)


def apri(percorso):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    est = os.path.splitext(percorso)[1].lower()
    if est == ".blend":
        bpy.ops.wm.open_mainfile(filepath=percorso)
    elif est in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=percorso)
    elif est == ".obj":
        bpy.ops.wm.obj_import(filepath=percorso)
    elif est == ".fbx":
        bpy.ops.import_scene.fbx(filepath=percorso)
    elif est == ".dae":
        bpy.ops.wm.collada_import(filepath=percorso)
    for lc in bpy.context.view_layer.layer_collection.children:
        lc.exclude = False
        lc.hide_viewport = False
    for o in bpy.data.objects:
        if o.name not in bpy.context.scene.collection.all_objects:
            bpy.context.scene.collection.objects.link(o)
        o.hide_viewport = False
        o.hide_set(False)


def colori_mancanti(cartella):
    if not cartella or not os.path.isdir(cartella):
        return
    tex = [f for f in os.listdir(cartella) if f.lower().endswith((".png", ".jpg", ".jpeg"))
           and not re.search(r"(norm|nrm|spec|_ao|_s\.|_n\.)", f.lower())]
    for img in bpy.data.images:
        if img.source == "FILE" and img.packed_file is None:
            n = os.path.basename(img.filepath.replace("\\", "/"))
            if os.path.exists(os.path.join(cartella, n)):
                img.filepath = os.path.join(cartella, n)
    for o in [o for o in bpy.data.objects if o.type == "MESH"]:
        for slot in o.material_slots:
            m = slot.material
            if m is None or not tex:
                continue
            m.use_nodes = True
            bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if bsdf is None or bsdf.inputs["Base Color"].is_linked:
                continue
            f = max(tex, key=lambda t: difflib.SequenceMatcher(None, t.lower(), (o.name + m.name).lower()).ratio())
            nodo = m.node_tree.nodes.new("ShaderNodeTexImage")
            nodo.image = bpy.data.images.load(os.path.join(cartella, f))
            m.node_tree.links.new(nodo.outputs["Color"], bsdf.inputs["Base Color"])


def ha_dati(img):
    try:
        return len(img.pixels) > 0
    except Exception:
        return False


def riduci_texture():
    # Copie senza dati ("tex.001" di un import precedente): si usa l'originale con lo stesso nome.
    for img in list(bpy.data.images):
        if img.source == "FILE" and not ha_dati(img):
            base = re.sub(r"\.\d{3}$", "", img.name)
            buona = next((i for i in bpy.data.images if i != img and re.sub(r"\.\d{3}$", "", i.name) == base and ha_dati(i)), None)
            if buona is not None:
                img.user_remap(buona)
            bpy.data.images.remove(img)
    for img in bpy.data.images:
        if img.source != "FILE" or img.size[0] == 0:
            continue
        try:
            w, h = img.size
            if max(w, h) > LATO:
                k = LATO / max(w, h)
                img.scale(max(1, int(w * k)), max(1, int(h * k)))
            # Su file: con le immagini impacchettate da un .glb l'esportatore di Blender 4.2 crea copie vuote.
            percorso = os.path.join(TEMP, re.sub(r"[^A-Za-z0-9_.-]", "_", img.name) + ".png")
            img.filepath_raw = percorso
            img.file_format = "PNG"
            img.save()
            if img.packed_file is not None:
                img.unpack(method="REMOVE")
            img.filepath = percorso
        except RuntimeError:
            pass


a = sys.argv[sys.argv.index("--") + 1:]
elenco = json.load(open(a[0]))
uscita = a[1]
os.makedirs(uscita, exist_ok=True)
for nome, info in elenco.items():
    apri(info["file"])
    colori_mancanti(info.get("texture", ""))
    tenere = [o for o in bpy.data.objects if o.type == "MESH"]
    if info.get("oggetto"):
        tenere = [o for o in tenere if o.name == info["oggetto"]]
    for o in bpy.data.objects:
        o.select_set(False)
    for o in tenere:
        o.select_set(True)
    # Le ossa e gli oggetti vuoti che reggono le mesh scelte (il pipistrello animato).
    for o in bpy.data.objects:
        if o.type in ("ARMATURE", "EMPTY") and any(t.parent == o or t.find_armature() == o for t in tenere):
            o.select_set(True)
    riduci_texture()
    bpy.ops.export_scene.gltf(filepath=os.path.join(uscita, nome + ".glb"), export_format="GLB",
            use_selection=True, export_animations=True)
    print("MODELLO", nome, [o.name for o in tenere])
