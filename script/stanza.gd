class_name Stanza
extends Node2D
# La stanza di prova, in due parti.
#  - La cripta: più piani, torce che fanno ombra, oggetti da rompere e da spingere, due tipi di nemico
#    e un cunicolo in cui si passa solo rotolando.
#  - La galleria, oltre la terrazza: trappole (spuntoni a tempo, sega a pendolo, balestra con piastra),
#    una torre con un montacarichi e lastre che crollano, una sala con l'enigma della cassa sulla piastra,
#    un salone con l'enigma dei bracieri, forzieri e una grata che si apre con una leva.
# Tutto è costruito da codice, così ogni misura sta in un posto solo.

const LARGHEZZA := 2880
const CRIPTA := 1344               # la cripta finisce qui, poi comincia la galleria
const PAVIMENTO := 480
const FONDO := 528
const CIELO := -288                # quota più alta che la telecamera può mostrare
const RIQUADRO := 96
const INIZIO := Vector2(250, 480)

# Muro di fondo della cripta, un carattere per riquadro da 96 pixel (righe da y 0 a 480).
const MURO: Array[String] = [
	"mcmmomgmmomcmm",
	"mmgmommrmomgmm",
	"cmmmomammomkmm",
	"mmcmomgmcommmc",
	"mpmmomcmmomamm",
]
# Muro di fondo della galleria (da x 1344, righe da y -288 a 480).
const MURO_GALLERIA: Array[String] = [
	"mmomcmmomgmmocmm",
	"cmomgmmomammommc",
	"mmomcmgomcmmommm",
	"mgommmcommmgomcm",
	"mmocmamommcmomkm",
	"cmommmgomcmmomma",
	"mmomrmcommmaommm",
	"mcommgmmopmmocmm",
]
const SIGLE := {
	"m": "muro", "c": "muro_crepe", "a": "muro_arco", "g": "muro_grata",
	"r": "muro_rotto", "k": "muro_cancello", "p": "muro_porta", "o": "muro_colonna",
}
# Piattaforme attraversabili dal basso: x, y, larghezza.
const PIATTAFORME := [[300, 412, 96], [430, 344, 96], [580, 290, 192], [840, 356, 96], [980, 432, 96]]
const TORCE := [
	Vector2(268, 420), Vector2(560, 250), Vector2(884, 420), Vector2(1180, 330),
	Vector2(1420, 350), Vector2(1700, 410), Vector2(1960, 360), Vector2(2160, 300), Vector2(2420, 420),
	Vector2(2560, 300), Vector2(2770, 452), Vector2(2366, 70), Vector2(2730, 84), Vector2(2690, -84),
]
# Galleria: piattaforme attraversabili (x, y, larghezza) e lastre che crollano (nome, x sinistra, y).
const PIATTAFORME_GALLERIA := [[2016, 312, 64]]
const FRAGILI := [["crollo1", 1920, 248], ["crollo2", 2024, 184]]
const POSTI_BRACIERI := [2480, 2570, 2660]
const COLORE_FIAMMA := Color(1.0, 0.62, 0.32)
const RAGGIO_TORCIA := 250.0
const ENERGIA_TORCIA := 2.3
const PULVISCOLO := 170

var giocatore: Giocatore
var meccanismi := {}               # nome -> porta, leva, piastra, forziere, lastra fragile, enigma

var _mondo: StaticBody2D
var _torce: Array = []
var _nebbie: Array = []
var _pulviscolo: CPUParticles2D
var _tempo := 0.0
var _t_luci := 0.0


func _ready() -> void:
	_lontano()
	_muro_di_fondo()
	var buio := CanvasModulate.new()
	buio.color = Color(0.27, 0.27, 0.4)
	add_child(buio)
	_mondo = StaticBody2D.new()
	_mondo.collision_layer = Effetti.S_MONDO
	_mondo.collision_mask = 0
	add_child(_mondo)
	_solidi()
	_decorazioni()
	_luci()
	_oggetti()
	_galleria()
	_nemici()
	_crea_giocatore()
	_atmosfera()
	_primo_piano()
	Dispositivo.profilo_cambiato.connect(_applica_profilo)
	_applica_profilo()


func _process(delta: float) -> void:
	_tempo += delta
	for t: Dictionary in _torce:
		var fase: float = t["fase"]
		var tremolio := sin(_tempo * 13.0 + fase) * 0.5 + sin(_tempo * 7.3 + fase * 2.0) * 0.3 + sin(_tempo * 23.0 + fase * 3.0) * 0.2
		var energia: float = float(t["energia"]) * (0.9 + 0.1 * tremolio)
		(t["muro"] as PointLight2D).energy = energia
		(t["davanti"] as PointLight2D).energy = energia
	_t_luci -= delta
	if _t_luci <= 0.0:
		_t_luci = 0.25
		_aggiorna_luci()


# ------------------------------------------------------------------ costruzione

func _lontano() -> void:
	# Quel che si intravede dai varchi del muro: un abisso bluastro con colonne lontane.
	var strato := Parallax2D.new()
	strato.scroll_scale = Vector2(0.45, 0.7)
	strato.z_index = -100
	add_child(strato)
	var abisso := Polygon2D.new()
	abisso.polygon = PackedVector2Array([
		Vector2(-400, CIELO - 500), Vector2(LARGHEZZA + 400, CIELO - 500), Vector2(LARGHEZZA + 400, FONDO + 300), Vector2(-400, FONDO + 300),
	])
	var alto := Color(0.025, 0.025, 0.06)
	var basso := Color(0.07, 0.11, 0.2)
	abisso.vertex_colors = PackedColorArray([alto, alto, basso, basso])
	abisso.material = Effetti.materiale_piatto()
	abisso.light_mask = 0
	strato.add_child(abisso)
	for i in 20:
		var colonna := _sprite("pilastro", Vector2(40 + i * 150, FONDO - 30 + (i % 3) * 14), 0, 0, strato)
		colonna.material = Effetti.materiale_piatto()
		colonna.modulate = Color(0.09, 0.12, 0.2)
		colonna.scale = Vector2(1.0, 1.25)


func _muro_di_fondo() -> void:
	for r in MURO.size():
		for c in MURO[r].length():
			var nome: String = SIGLE[MURO[r][c]]
			var s := _sprite(nome, Vector2(c * RIQUADRO + RIQUADRO * 0.5, (r + 1) * RIQUADRO), Effetti.L_SFONDO, -50)
			s.modulate = Color(0.66, 0.66, 0.76)
	for r in MURO_GALLERIA.size():
		for c in MURO_GALLERIA[r].length():
			var nome: String = SIGLE[MURO_GALLERIA[r][c]]
			var dove := Vector2(CRIPTA + c * RIQUADRO + RIQUADRO * 0.5, CIELO + (r + 1) * RIQUADRO)
			var s := _sprite(nome, dove, Effetti.L_SFONDO, -50)
			s.modulate = Color(0.62, 0.64, 0.74)


func _solidi() -> void:
	_blocco(Rect2(0, PAVIMENTO, LARGHEZZA, 120), true, false)                 # pavimento
	_blocco(Rect2(0, CIELO - 48, 48, PAVIMENTO - CIELO + 48), false, false)   # parete sinistra
	_blocco(Rect2(LARGHEZZA - 48, CIELO - 48, 48, PAVIMENTO - CIELO + 48), false, false)   # parete destra
	_blocco(Rect2(48, 392, 152, 88), true, true)                              # ripiano alto a sinistra
	_blocco(Rect2(1104, 384, 384, 36), true, true)                            # terrazza, poi passerella nella galleria
	_blocco(Rect2(1104, 420, 96, 34), false, true)                            # sotto resta un cunicolo alto 26
	_blocco(Rect2(1296, CIELO - 48, 48, 368 - CIELO), false, false)           # muro fra cripta e galleria (varco sopra la terrazza)
	for p: Array in PIATTAFORME:
		_piattaforma(p[0], p[1], p[2])
	# Galleria.
	_blocco(Rect2(2112, 384, 96, 96), true, true)                             # zoccolo della torre
	_blocco(Rect2(2080, 136, 128, 36), true, true)                            # torre ovest
	_blocco(Rect2(2352, 120, 480, 36), true, true)                            # salone in alto
	_blocco(Rect2(2480, 352, 160, 36), true, true)                            # balconata della sala
	_blocco(Rect2(2680, 156, 152, 232), false, true)                          # pietra sopra la stanza del tesoro
	_blocco(Rect2(2600, -48, 168, 36), true, true)                            # nicchia segreta
	for p: Array in PIATTAFORME_GALLERIA:
		_piattaforma(p[0], p[1], p[2])


static func superfici() -> Array:
	# Dove si può stare in piedi (per il bot). Le misure vengono dagli stessi blocchi di _solidi().
	# "isolata": ci si entra solo dai passaggi speciali; "condizione": esiste solo quando è vera
	# (una lastra fragile non crollata, un gradino segreto alzato).
	var elenco: Array = [
		{"id": "pavimento", "x0": 200.0, "x1": 1104.0, "y": float(PAVIMENTO), "passante": false},
		{"id": "alcova", "x0": 1200.0, "x1": 1310.0, "y": float(PAVIMENTO), "passante": false, "isolata": true},
		{"id": "ripiano", "x0": 48.0, "x1": 200.0, "y": 392.0, "passante": false},
		{"id": "terrazza", "x0": 1104.0, "x1": 1488.0, "y": 384.0, "passante": false},
		{"id": "galleria", "x0": 1338.0, "x1": 2112.0, "y": float(PAVIMENTO), "passante": false},
		{"id": "zoccolo", "x0": 2112.0, "x1": 2208.0, "y": 384.0, "passante": false},
		{"id": "torre_ovest", "x0": 2080.0, "x1": 2208.0, "y": 136.0, "passante": false},
		{"id": "sala", "x0": 2208.0, "x1": 2680.0, "y": float(PAVIMENTO), "passante": false},
		{"id": "salone", "x0": 2352.0, "x1": 2784.0, "y": 120.0, "passante": false},
		{"id": "balconata", "x0": 2480.0, "x1": 2640.0, "y": 352.0, "passante": false},
		{"id": "tesoro", "x0": 2712.0, "x1": 2832.0, "y": float(PAVIMENTO), "passante": false, "isolata": true},
		{"id": "gradino", "x0": 2784.0, "x1": 2832.0, "y": 40.0, "passante": false, "condizione": "porta:gradino"},
		{"id": "nicchia", "x0": 2600.0, "x1": 2768.0, "y": -48.0, "passante": false},
	]
	for i in PIATTAFORME.size():
		var p: Array = PIATTAFORME[i]
		elenco.append({"id": "p%d" % i, "x0": float(p[0]), "x1": float(p[0] + p[2]), "y": float(p[1]), "passante": true})
	for p: Array in PIATTAFORME_GALLERIA:
		elenco.append({"id": "scalino", "x0": float(p[0]), "x1": float(p[0] + p[2]), "y": float(p[1]), "passante": true})
	for f: Array in FRAGILI:
		elenco.append({"id": f[0], "x0": float(f[1]), "x1": float(f[1]) + PiattaformaFragile.LARGHEZZA, "y": float(f[2]),
				"passante": true, "fragile": true, "condizione": "fragile:" + String(f[0])})
	return elenco


static func passaggi_speciali() -> Array:
	# Passaggi che il bot non può dedurre dalle superfici: il cunicolo (solo rotolando), le grate
	# (solo se aperte), il montacarichi. "vietato": niente passaggio automatico fra le due superfici.
	return [
		{"da": "pavimento", "a": "alcova", "tipo": "rotola", "stacco": 1078.0, "verso": 1},
		{"da": "alcova", "a": "pavimento", "tipo": "rotola", "stacco": 1222.0, "verso": -1},
		{"da": "alcova", "a": "galleria", "tipo": "passa", "stacco": 1300.0, "verso": 1, "meta": 1360.0, "condizione": "porta:porta_alcova"},
		{"da": "galleria", "a": "alcova", "tipo": "passa", "stacco": 1345.0, "verso": -1, "meta": 1262.0, "condizione": "porta:porta_alcova"},
		{"da": "sala", "a": "tesoro", "tipo": "passa", "stacco": 2672.0, "verso": 1, "meta": 2745.0, "condizione": "porta:porta_tesoro"},
		{"da": "tesoro", "a": "sala", "tipo": "passa", "stacco": 2722.0, "verso": -1, "meta": 2645.0, "condizione": "porta:porta_tesoro"},
		{"da": "sala", "a": "salone", "tipo": "ascensore", "stacco": 2320.0, "verso": 1, "meta": 2385.0},
		{"da": "salone", "a": "sala", "tipo": "ascensore", "stacco": 2320.0, "verso": -1, "meta": 2262.0},
		{"da": "salone", "a": "sala", "tipo": "vietato"},
	]


func condizione(nome: String) -> bool:
	# Per il bot: "porta:<nome>" è del tutto aperta? "fragile:<nome>" è al suo posto?
	var parti := nome.split(":")
	if parti.size() != 2 or not meccanismi.has(parti[1]):
		return true
	var m: Node = meccanismi[parti[1]]
	if parti[0] == "porta":
		return (m as Porta).del_tutto_aperta()
	if parti[0] == "fragile":
		return (m as PiattaformaFragile).presente
	return true


func _blocco(rett: Rect2, con_lastra: bool, fa_ombra: bool) -> void:
	var misura := RectangleShape2D.new()
	misura.size = rett.size
	var forma := CollisionShape2D.new()
	forma.shape = misura
	forma.position = rett.get_center()
	_mondo.add_child(forma)
	var pieno := rett
	if con_lastra:
		pieno = Rect2(rett.position.x, rett.position.y + 6.0, rett.size.x, rett.size.y - 6.0)
	_riempi("fondamenta", pieno, Effetti.L_DAVANTI, -10)
	if con_lastra:
		_lastre(rett.position.x, rett.end.x, rett.position.y, -9)
	if fa_ombra:
		Effetti.occlusore(self, rett)


func _piattaforma(x: float, y: float, larghezza: float) -> void:
	var corpo := StaticBody2D.new()
	corpo.collision_layer = Effetti.S_PIATTAFORME
	corpo.collision_mask = 0
	var misura := RectangleShape2D.new()
	misura.size = Vector2(larghezza, 8.0)
	var forma := CollisionShape2D.new()
	forma.shape = misura
	forma.position = Vector2(x + larghezza * 0.5, y + 4.0)
	forma.one_way_collision = true
	forma.one_way_collision_margin = 4.0
	corpo.add_child(forma)
	add_child(corpo)
	_lastre(x, x + larghezza, y, -8)
	Effetti.occlusore(self, Rect2(x, y, larghezza, 10.0))


func _lastre(x0: float, x1: float, y: float, z: int) -> void:
	# Lastre di pietra in fila: sono il piano su cui si cammina.
	var voce := SpriteAnimato.foglio("lastra")
	var x := x0
	while x < x1 - 1.0:
		var s := Sprite2D.new()
		s.texture = voce["texture"]
		s.centered = false
		s.region_enabled = true
		s.region_rect = Rect2(0.0, 0.0, minf(98.0, x1 - x + 2.0), 23.0)
		s.position = Vector2(x - 1.0, y - 9.0)
		s.light_mask = Effetti.L_DAVANTI
		s.z_index = z
		add_child(s)
		x += 96.0


func _riempi(nome: String, rett: Rect2, maschera: int, z: int) -> void:
	var voce := SpriteAnimato.foglio(nome)
	var s := Sprite2D.new()
	s.texture = voce["texture"]
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, rett.size)
	s.position = rett.position
	s.light_mask = maschera
	s.z_index = z
	add_child(s)


func _decorazioni() -> void:
	for x: float in [236.0, 716.0, 1052.0]:
		_sprite("pilastro", Vector2(x, PAVIMENTO + 3), Effetti.L_DAVANTI, -20)
		Effetti.occlusore(self, Rect2(x - 11.0, PAVIMENTO - 98.0, 22.0, 98.0))
	var stendardi := [["stendardo", Vector2(336, 330)], ["stendardo_scudo", Vector2(672, 190)], ["stendardo", Vector2(912, 300)]]
	for voce: Array in stendardi:
		var s := _sprite(voce[0], voce[1], Effetti.L_SFONDO, -45)
		s.modulate = Color(0.8, 0.8, 0.86)
	# Candele sul ripiano di sinistra, con una piccola luce.
	_sprite("candele", Vector2(72, 393), Effetti.L_DAVANTI, 0)
	var lume := Effetti.luce(Color(1.0, 0.72, 0.4), 90.0, 1.3, 50.0)
	lume.position = Vector2(72, 372)
	add_child(lume)
	_fiamma(Vector2(72, 371), 0.5)


func _luci() -> void:
	for dove: Vector2 in TORCE:
		var nodo := Node2D.new()
		nodo.position = dove
		nodo.z_index = -30
		add_child(nodo)
		_sprite("torcia", Vector2.ZERO, Effetti.L_DAVANTI, 0, nodo)
		# Due luci per torcia: una per il muro di fondo (con le ombre), una per ciò che sta davanti.
		var muro := Effetti.luce(COLORE_FIAMMA, RAGGIO_TORCIA, ENERGIA_TORCIA, 90.0)
		muro.position = Vector2(0, -22)
		muro.range_item_cull_mask = Effetti.L_SFONDO
		muro.shadow_item_cull_mask = Effetti.L_SFONDO
		nodo.add_child(muro)
		var davanti := Effetti.luce(COLORE_FIAMMA, RAGGIO_TORCIA, ENERGIA_TORCIA, 90.0)
		davanti.position = Vector2(0, -22)
		davanti.range_item_cull_mask = Effetti.L_DAVANTI
		nodo.add_child(davanti)
		_fiamma(dove + Vector2(0, -22), 1.0)
		_torce.append({"nodo": nodo, "muro": muro, "davanti": davanti, "fase": randf() * 10.0, "energia": ENERGIA_TORCIA})


func _fiamma(dove: Vector2, grandezza: float) -> void:
	var colori := Gradient.new()
	colori.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	colori.colors = PackedColorArray([Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.65, 0.2, 0.95), Color(0.85, 0.25, 0.08, 0.7), Color(0.4, 0.05, 0.02, 0.0)])
	# Alone caldo dietro la fiamma.
	var alone := Sprite2D.new()
	alone.texture = Effetti.texture_luce()
	alone.position = dove + Vector2(0, -3)
	alone.scale = Vector2.ONE * 0.3 * grandezza
	alone.modulate = Color(1.0, 0.55, 0.2, 0.55)
	alone.material = Effetti.materiale_luminoso()
	alone.light_mask = 0
	alone.z_index = -29
	add_child(alone)
	var f := CPUParticles2D.new()
	f.position = dove
	f.amount = maxi(8, Effetti.quantita(int(30 * grandezza)))
	f.lifetime = 0.5
	f.direction = Vector2.UP
	f.spread = 16.0
	f.initial_velocity_min = 14.0 * grandezza
	f.initial_velocity_max = 40.0 * grandezza
	f.gravity = Vector2(0, -30)
	f.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	f.emission_sphere_radius = 3.0 * grandezza
	f.scale_amount_min = 1.5
	f.scale_amount_max = 3.6 * grandezza
	f.color_ramp = colori
	f.material = Effetti.materiale_luminoso()
	f.light_mask = 0
	f.z_index = -29
	add_child(f)


func _oggetti() -> void:
	_cassa(Vector2(350, PAVIMENTO))
	_cassa(Vector2(770, PAVIMENTO))
	var barili := [
		["barile", Vector2(432, PAVIMENTO), 1], ["barile", Vector2(461, PAVIMENTO), 1], ["barile", Vector2(812, PAVIMENTO), 1],
		["barile_grande", Vector2(118, 392), 2], ["barile", Vector2(162, 392), 1], ["barile", Vector2(1226, PAVIMENTO), 1],
	]
	for voce: Array in barili:
		var b := Rompibile.new()
		b.foglio = voce[0]
		b.vita = voce[2]
		b.position = voce[1]
		b.add_to_group("rompibili")
		add_child(b)


func _cassa(dove: Vector2) -> RigidBody2D:
	var cassa := RigidBody2D.new()
	cassa.collision_layer = Effetti.S_OGGETTI
	cassa.collision_mask = Effetti.S_MONDO | Effetti.S_PIATTAFORME | Effetti.S_OGGETTI
	cassa.lock_rotation = true
	cassa.mass = 6.0
	cassa.linear_damp = 1.5
	var attrito := PhysicsMaterial.new()
	attrito.friction = 0.9
	cassa.physics_material_override = attrito
	cassa.position = dove
	cassa.z_index = 1
	var misura := RectangleShape2D.new()
	misura.size = Vector2(34, 32)
	var forma := CollisionShape2D.new()
	forma.shape = misura
	forma.position = Vector2(0, -16)
	cassa.add_child(forma)
	_sprite("cassa", Vector2.ZERO, Effetti.L_DAVANTI, 0, cassa)
	Effetti.occlusore(cassa, Rect2(-17, -32, 34, 32))
	cassa.add_to_group("casse")
	add_child(cassa)
	return cassa


func _galleria() -> void:
	# Decorazioni.
	for x: float in [1530.0, 2350.0]:
		_sprite("pilastro", Vector2(x, PAVIMENTO + 3), Effetti.L_DAVANTI, -20)
		Effetti.occlusore(self, Rect2(x - 11.0, PAVIMENTO - 98.0, 22.0, 98.0))
	for voce: Array in [["stendardo", Vector2(1880, 300)], ["stendardo_scudo", Vector2(2560, 60)], ["stendardo", Vector2(2420, 330)]]:
		var s := _sprite(voce[0], voce[1], Effetti.L_SFONDO, -45)
		s.modulate = Color(0.8, 0.8, 0.86)

	# Grata dell'alcova: si apre dalla galleria con una leva (una scorciatoia per tornare indietro).
	var grata := _porta("porta_alcova", Vector2(1321, PAVIMENTO), Vector2(20, 60), Vector2(0, 64), "grata_bassa")
	var leva := Leva.new()
	leva.nome = "leva_alcova"
	leva.bersaglio = grata
	leva.position = Vector2(1400, PAVIMENTO)
	add_child(leva)
	meccanismi["leva_alcova"] = leva
	_forziere("forziere_alcova", Vector2(1262, PAVIMENTO), false)

	# Trappole lungo la galleria.
	var punte := Spuntoni.new()
	punte.position = Vector2(1632, PAVIMENTO)
	add_child(punte)
	meccanismi["spuntoni"] = punte
	var pendolo := Pendolo.new()
	pendolo.position = Vector2(1840, PAVIMENTO - 172)
	pendolo.pavimento = PAVIMENTO
	pendolo.fase = 0.4
	add_child(pendolo)
	meccanismi["pendolo"] = pendolo
	var balestra := Balestra.new()
	balestra.verso = -1
	balestra.position = Vector2(2104, PAVIMENTO - 24)
	add_child(balestra)
	meccanismi["balestra"] = balestra
	var piastra_freccia := _piastra("piastra_freccia", Vector2(2010, PAVIMENTO), "scatto", balestra)
	piastra_freccia.ritardo = 0.0

	# La torre: lastre che crollano verso la torre ovest (con un forziere), montacarichi verso il salone.
	for f: Array in FRAGILI:
		var lastra := PiattaformaFragile.new()
		lastra.nome = f[0]
		lastra.position = Vector2(float(f[1]) + PiattaformaFragile.LARGHEZZA * 0.5, float(f[2]))
		add_child(lastra)
		meccanismi[f[0]] = lastra
	_forziere("forziere_torre", Vector2(2150, 136), false)
	var montacarichi := PiattaformaMobile.new()
	montacarichi.position = Vector2(2320, PAVIMENTO)
	montacarichi.basso = PAVIMENTO
	montacarichi.alto = 120.0
	montacarichi.carrucola = 30.0
	add_child(montacarichi)
	meccanismi["montacarichi"] = montacarichi
	var carrucola := Polygon2D.new()
	carrucola.polygon = PackedVector2Array([Vector2(-34, -4), Vector2(34, -4), Vector2(34, 4), Vector2(-34, 4)])
	carrucola.color = Color(0.22, 0.21, 0.27)
	carrucola.light_mask = Effetti.L_DAVANTI
	carrucola.position = Vector2(2320, 28)
	add_child(carrucola)

	# La sala: la cassa sulla balconata va spinta giù e poi sulla piastra, che tiene aperta la grata del tesoro.
	meccanismi["cassa_enigma"] = _cassa(Vector2(2566, 352))
	var grata_tesoro := _porta("porta_tesoro", Vector2(2696, PAVIMENTO), Vector2(20, 92), Vector2(0, -96), "grata")
	var piastra := _piastra("piastra_tesoro", Vector2(2400, PAVIMENTO), "tenuta", grata_tesoro)
	piastra.premuta.connect(func(da_cassa: bool) -> void:
		if da_cassa and not piastra.has_meta("risolto"):
			piastra.set_meta("risolto", true)
			Rapporto.conta("enigmi_risolti")
			Rapporto.evento("enigma", {"nome": "cassa"})
			get_tree().call_group("hud", "messaggio", "La grata resta alzata.", 2.0))
	_forziere("forziere_tesoro", Vector2(2780, PAVIMENTO), false)

	# Il salone: tre bracieri da accendere nell'ordine della tavoletta; si alza un gradino verso la nicchia
	# segreta, dove c'è il forziere d'oro.
	var gradino := _porta("gradino", Vector2(2808, 200), Vector2(48, 80), Vector2(0, -80), "")
	gradino.velocita = 70.0
	var enigma := EnigmaBracieri.new()
	enigma.position = Vector2(0, 120)
	enigma.posti = POSTI_BRACIERI
	enigma.tavoletta = Vector2(2412, -26)
	enigma.bersaglio = gradino
	add_child(enigma)
	meccanismi["bracieri"] = enigma
	_forziere("forziere_oro", Vector2(2662, -48), true)

	# Barili.
	for voce: Array in [["barile", Vector2(2150, 384), 1], ["barile", Vector2(2460, PAVIMENTO), 1],
			["barile_grande", Vector2(2742, 120), 2], ["barile", Vector2(2752, PAVIMENTO), 1]]:
		var b := Rompibile.new()
		b.foglio = voce[0]
		b.vita = voce[2]
		b.position = voce[1]
		b.add_to_group("rompibili")
		add_child(b)


func _porta(nome: String, dove: Vector2, misura: Vector2, spostamento: Vector2, foglio: String) -> Porta:
	var p := Porta.new()
	p.nome = nome
	p.position = dove
	p.misura = misura
	p.spostamento = spostamento
	p.foglio = foglio
	p.z_index = -11              # scorre dietro la pietra (nel pavimento o nel muro)
	add_child(p)
	meccanismi[nome] = p
	return p


func _piastra(nome: String, dove: Vector2, modo: String, bersaglio: Node) -> Piastra:
	var p := Piastra.new()
	p.nome = nome
	p.modo = modo
	p.bersaglio = bersaglio
	p.position = dove
	add_child(p)
	meccanismi[nome] = p
	return p


func _forziere(nome: String, dove: Vector2, oro: bool) -> Forziere:
	var f := Forziere.new()
	f.nome = nome
	f.oro = oro
	f.position = dove
	add_child(f)
	meccanismi[nome] = f
	return f


func _nemici() -> void:
	# Le nemesi che il sogno ricorda prendono il posto dei nemici dello stesso tipo
	# (prima quelli svegli, che s'incontrano a viso aperto).
	var da_mettere := {"scheletro": Memoria.nemesi_per("scheletro"), "mago": Memoria.nemesi_per("mago")}
	_nemico("scheletro", Vector2(940, PAVIMENTO), false, -1, da_mettere)
	_nemico("scheletro", Vector2(640, PAVIMENTO), true, -1, da_mettere)
	_nemico("mago", Vector2(700, 290), false, -1, da_mettere)
	# Galleria.
	_nemico("scheletro", Vector2(1480, PAVIMENTO), true, -1, da_mettere)
	_nemico("scheletro", Vector2(2540, PAVIMENTO), false, -1, da_mettere)
	_nemico("mago", Vector2(2610, 120), false, -1, da_mettere)


func _nemico(tipo: String, dove: Vector2, addormentato: bool, verso: int, nemesi_libere: Dictionary = {}) -> void:
	var n := Nemico.new()
	var libere: Array = nemesi_libere.get(tipo, [])
	if not libere.is_empty():
		n.nemesi = (libere.pop_front() as Dictionary).duplicate()
		addormentato = false  # una nemesi non dorme: ti aspetta
	n.tipo = tipo
	n.dorme = addormentato
	n.verso = verso
	n.position = dove
	n.add_to_group("nemici")
	add_child(n)


func _crea_giocatore() -> void:
	giocatore = Giocatore.new()
	giocatore.position = INIZIO
	giocatore.add_to_group("giocatore")
	add_child(giocatore)
	giocatore.limiti(Rect2i(0, CIELO, LARGHEZZA, FONDO - CIELO))


func _atmosfera() -> void:
	var nuvola: Texture2D = load("res://arte/ambiente/rumore.png")
	var shader: Shader = load("res://shader/nebbia.gdshader")
	# Nebbia alta, dietro ai personaggi, e una fascia bassa davanti a tutto.
	for dati: Array in [[Rect2(0, CIELO + 60, LARGHEZZA, PAVIMENTO - CIELO - 50), -40, 0.2, Vector2(13, 4.6)],
			[Rect2(0, 396, LARGHEZZA, 130), 30, 0.26, Vector2(11, 1)]]:
		var materiale := ShaderMaterial.new()
		materiale.shader = shader
		materiale.set_shader_parameter("rumore", nuvola)
		materiale.set_shader_parameter("densita", dati[2])
		materiale.set_shader_parameter("ripetizioni", dati[3])
		var velo := ColorRect.new()
		velo.material = materiale
		velo.position = (dati[0] as Rect2).position
		velo.size = (dati[0] as Rect2).size
		velo.z_index = dati[1]
		velo.light_mask = 0
		velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(velo)
		_nebbie.append(velo)

	# Pulviscolo sospeso nell'aria.
	var respiro := Gradient.new()
	respiro.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	respiro.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_pulviscolo = CPUParticles2D.new()
	_pulviscolo.position = Vector2(LARGHEZZA * 0.5, (CIELO + PAVIMENTO) * 0.5)
	_pulviscolo.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_pulviscolo.emission_rect_extents = Vector2(LARGHEZZA * 0.5, (PAVIMENTO - CIELO) * 0.5)
	_pulviscolo.amount = Effetti.quantita(PULVISCOLO)
	_pulviscolo.lifetime = 6.0
	_pulviscolo.preprocess = 6.0
	_pulviscolo.spread = 180.0
	_pulviscolo.initial_velocity_min = 2.0
	_pulviscolo.initial_velocity_max = 7.0
	_pulviscolo.gravity = Vector2(0, -1)
	_pulviscolo.color = Color(0.8, 0.72, 0.6, 0.3)
	_pulviscolo.color_ramp = respiro
	_pulviscolo.material = Effetti.materiale_luminoso()
	_pulviscolo.light_mask = 0
	_pulviscolo.z_index = 25
	add_child(_pulviscolo)


func _primo_piano() -> void:
	# Sagome scure vicinissime, che scorrono più in fretta del resto: danno profondità.
	var strato := Parallax2D.new()
	strato.scroll_scale = Vector2(1.35, 1.0)
	strato.z_index = 60
	add_child(strato)
	# Stanno solo ai margini (drappi in alto, capitelli spezzati in basso): non coprono mai l'azione.
	for dove: Vector2 in [Vector2(300, 112), Vector2(820, 112), Vector2(1330, 112), Vector2(1760, 112)]:
		var drappo := _sprite("stendardo", dove, 0, 0, strato)
		drappo.material = Effetti.materiale_piatto()
		drappo.modulate = Color(0.03, 0.03, 0.05)
		drappo.scale = Vector2(1.7, 1.6)
	for x: float in [140.0, 640.0, 1180.0, 1600.0, 2150.0, 2700.0, 3250.0, 3800.0]:
		var sagoma := _sprite("pilastro", Vector2(x, FONDO + 152), 0, 0, strato)
		sagoma.material = Effetti.materiale_piatto()
		sagoma.modulate = Color(0.03, 0.03, 0.05)
		sagoma.scale = Vector2(1.6, 1.7)


func _sprite(nome: String, dove: Vector2, maschera: int, z: int, genitore: Node = self) -> SpriteAnimato:
	var s := SpriteAnimato.new()
	s.carica(nome)
	s.position = dove
	s.light_mask = maschera
	s.z_index = z
	s.set_process(false)
	genitore.add_child(s)
	return s


# ------------------------------------------------------------------ qualità

func _applica_profilo() -> void:
	var profilo: Dictionary = Dispositivo.profilo
	var doppie: bool = profilo.get("luci_doppie", true)
	var morbide: bool = profilo.get("ombre_morbide", false)
	for t: Dictionary in _torce:
		var muro: PointLight2D = t["muro"]
		var davanti: PointLight2D = t["davanti"]
		muro.shadow_filter = Light2D.SHADOW_FILTER_PCF5 if morbide else Light2D.SHADOW_FILTER_NONE
		muro.shadow_filter_smooth = 1.5
		muro.range_item_cull_mask = Effetti.L_SFONDO if doppie else (Effetti.L_SFONDO | Effetti.L_DAVANTI)
		davanti.visible = doppie
	for velo: ColorRect in _nebbie:
		velo.visible = profilo.get("nebbia", true)
	if _pulviscolo != null:
		_pulviscolo.amount = Effetti.quantita(PULVISCOLO)
	_aggiorna_luci()


func _aggiorna_luci() -> void:
	# Accende solo le torce vicine alla vista; le ombre vanno alle più vicine, quante ne permette la qualità.
	var telecamera := get_viewport().get_camera_2d()
	if telecamera == null:
		return
	var centro := telecamera.get_screen_center_position()
	var mezza := get_viewport_rect().size * 0.5 + Vector2(200.0, 200.0)
	var con_ombra: int = Dispositivo.profilo.get("luci_con_ombra", 0)
	var in_vista: Array = []
	for t: Dictionary in _torce:
		var d := ((t["nodo"] as Node2D).position - centro).abs()
		var distanza := d.length()
		var accesa := d.x < mezza.x and d.y < mezza.y
		(t["muro"] as PointLight2D).enabled = accesa
		(t["davanti"] as PointLight2D).enabled = accesa
		if accesa:
			in_vista.append([distanza, t])
	in_vista.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in in_vista.size():
		((in_vista[i][1] as Dictionary)["muro"] as PointLight2D).shadow_enabled = i < con_ombra


func riscalda_luci(durata: float) -> void:
	# All'avvio, dietro il velo nero: tutte le luci accese e con ombra, così il dispositivo
	# prepara subito ciò che servirà, invece di farlo quando una torcia entra in vista.
	_t_luci = durata
	for t: Dictionary in _torce:
		for chiave in ["muro", "davanti"]:
			(t[chiave] as PointLight2D).enabled = true
		(t["muro"] as PointLight2D).shadow_enabled = true


func torce_con_ombra() -> int:
	var n := 0
	for t: Dictionary in _torce:
		var muro: PointLight2D = t["muro"]
		if muro.enabled and muro.shadow_enabled:
			n += 1
	return n
