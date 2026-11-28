class_name Regia
extends Node
# Telecamera da regista (0.1.43). Figlia del giocatore: comanda lo zoom (camera.zoom) e un piccolo
# spostamento (si somma alla scossa in Giocatore._process), più il rallentatore del gioco.
#  - colpo(forza): colpetto di zoom sui colpi forti, torna a 1 in 0,22 s; i colpi vicini non superano 1,10.
#  - primo_piano(punto, quanto, durata): zoom sull'esecuzione, con la telecamera che scivola verso il punto.
#  - rallenta(fattore, secondi): rallentatore (non nelle prove né col bot: lì conta soltanto).
#  - ultimo_nemico(): rallentatore + zoom + vibrazione quando muore l'ultimo nemico dell'ondata.
#  - campo largo: nelle zone alte e ampie (Stanza.ZONE_LARGHE) lo zoom scivola a 0,85 e si vede più mondo.
#    Solo se il profilo lo permette e le figure sono in doppia definizione: col mondo disegnato a
#    definizione normale uno zoom sotto 1 perderebbe pixel.
# Tutto si spegne con l'impostazione "gioco/regia" (e il rallentatore anche con "meno lampi").

const COLPO_ZOOM := 0.03            # per ogni punto di forza
const COLPO_MASSIMO := 0.10         # i colpi vicini non vanno oltre 1,10
const COLPO_DURATA := 0.22
const SALITA := 0.08                # primo piano: tempo per arrivare allo zoom
const DISCESA := 0.25               # ...e per tornare
const ZOOM_LARGO := 0.85
const LARGO_DURATA := 0.8           # tempo per passare da 1 a 0,85 (e ritorno)
const SPOSTAMENTO_MASSIMO := Vector2(70.0, 40.0)

var zoom_ora := 1.0                 # zoom della telecamera adesso (1 a riposo; per le prove)
var spostamento := Vector2.ZERO     # quanto la regia sposta la telecamera (lo somma Giocatore._process)
var in_campo_largo := false

var _g: Giocatore
var _base := 1.0                    # zoom di base: 1 oppure ZOOM_LARGO
var _picco := 0.0
var _t_colpo := 0.0
var _pp_attivo := false
var _pp_t := 0.0
var _pp_quanto := 1.0
var _pp_durata := 0.0
var _pp_punto := Vector2.ZERO
var _rallentando := false
var _numero_rallentatore := 0


func _ready() -> void:
	_g = get_parent() as Giocatore


func _exit_tree() -> void:
	if _rallentando:
		_ferma_rallentatore()   # la stanza cambia a metà rallentatore: la velocità non resta storta


static func attiva() -> bool:
	return bool(Impostazioni.leggi("gioco/regia"))


func _process(delta: float) -> void:
	if _g == null or _g.camera == null:
		return
	if not attiva():
		_spegni()
		return
	_t_colpo = maxf(0.0, _t_colpo - delta)
	if _pp_attivo:
		_pp_t += delta
		if _pp_t >= SALITA + _pp_durata + DISCESA:
			_pp_attivo = false
	_aggiorna_base(delta)
	_applica()


func _spegni() -> void:
	# Regia spenta: telecamera normale, niente rallentatore.
	if zoom_ora != 1.0 or spostamento != Vector2.ZERO:
		zoom_ora = 1.0
		spostamento = Vector2.ZERO
		_g.camera.zoom = Vector2.ONE
	_base = 1.0
	_t_colpo = 0.0
	_pp_attivo = false
	in_campo_largo = false
	if _rallentando:
		_ferma_rallentatore()


func _campo_largo_permesso() -> bool:
	return bool(Dispositivo.profilo.get("campo_largo", false)) and SpriteAnimato.densita_figure == 2


func _in_zona_larga() -> bool:
	# Con un po' di isteresi: si entra dentro il rettangolo, si esce un po' più in là (niente va e vieni sul bordo).
	var punto := _g.global_position + Vector2(0.0, -20.0)
	for r: Rect2 in Stanza.ZONE_LARGHE:
		if (r.grow(24.0) if in_campo_largo else r).has_point(punto):
			return true
	return false


func _aggiorna_base(delta: float) -> void:
	var dentro := _campo_largo_permesso() and _in_zona_larga()
	if dentro and not in_campo_largo:
		Rapporto.conta("regia_campo_largo")
	in_campo_largo = dentro
	_base = move_toward(_base, ZOOM_LARGO if dentro else 1.0, delta * (1.0 - ZOOM_LARGO) / LARGO_DURATA)


func _peso_primo_piano() -> float:
	if not _pp_attivo:
		return 0.0
	var k := 1.0
	if _pp_t < SALITA:
		k = _pp_t / SALITA
	elif _pp_t > SALITA + _pp_durata:
		k = 1.0 - (_pp_t - SALITA - _pp_durata) / DISCESA
	return smoothstep(0.0, 1.0, clampf(k, 0.0, 1.0))


func _applica() -> void:
	var k := _t_colpo / COLPO_DURATA
	var peso := _peso_primo_piano()
	zoom_ora = _base * maxf(1.0 + _picco * k * k, lerpf(1.0, _pp_quanto, peso))
	_g.camera.zoom = Vector2.ONE * zoom_ora
	if peso > 0.0:
		var centro := _g.global_position + _g.camera.position
		var voluto := ((_pp_punto - centro) * 0.5 * peso).clamp(-SPOSTAMENTO_MASSIMO, SPOSTAMENTO_MASSIMO)
		spostamento = _dentro_i_limiti(voluto)
	else:
		spostamento = Vector2.ZERO


func _dentro_i_limiti(voluto: Vector2) -> Vector2:
	# La vista spostata non esce dai limiti della stanza (stessa idea dei limiti della telecamera).
	var cam := _g.camera
	var meta := cam.get_viewport_rect().size / (cam.zoom * 2.0)
	var base := cam.get_screen_center_position() - cam.offset
	var obiettivo := base + voluto
	var minimo := Vector2(cam.limit_left, cam.limit_top) + meta
	var massimo := Vector2(cam.limit_right, cam.limit_bottom) - meta
	if massimo.x > minimo.x:
		obiettivo.x = clampf(obiettivo.x, minimo.x, massimo.x)
	else:
		obiettivo.x = base.x
	if massimo.y > minimo.y:
		obiettivo.y = clampf(obiettivo.y, minimo.y, massimo.y)
	else:
		obiettivo.y = base.y
	return obiettivo - base


func colpo(forza: float) -> void:
	if not attiva():
		return
	Rapporto.conta("regia_zoom")
	var ora := _picco * pow(_t_colpo / COLPO_DURATA, 2.0)
	_picco = minf(COLPO_MASSIMO, ora + COLPO_ZOOM * maxf(forza, 0.0))
	_t_colpo = COLPO_DURATA
	if _g != null and _g.camera != null:
		_applica()


func primo_piano(punto: Vector2, quanto: float = 1.18, durata: float = 0.5) -> void:
	if not attiva():
		return
	Rapporto.conta("regia_primi_piani")
	_pp_attivo = true
	_pp_t = 0.0
	_pp_quanto = maxf(1.0, quanto)
	_pp_durata = maxf(0.0, durata)
	_pp_punto = punto


func rallenta(fattore: float, durata_reale: float) -> void:
	# Rallentatore per durata_reale secondi veri. Nelle prove e col bot il tempo non cambia (i controlli
	# automatici hanno bisogno di tempi uguali), ma lo si conta lo stesso.
	if not attiva():
		return
	Rapporto.conta("rallentatori")
	if Dispositivo.in_prova or Dispositivo.bot_attivo or Impostazioni.leggi("acc/meno_lampi"):
		return
	Effetti.fattore_regia = clampf(fattore, 0.05, 1.0)
	Effetti.applica_velocita()
	_rallentando = true
	_numero_rallentatore += 1
	get_tree().create_timer(durata_reale, true, false, true).timeout.connect(_fine_rallentatore.bind(_numero_rallentatore))


func _fine_rallentatore(numero: int) -> void:
	if numero == _numero_rallentatore:   # se ne è partito un altro nel frattempo, finisce lui
		_ferma_rallentatore()


func _ferma_rallentatore() -> void:
	_rallentando = false
	Effetti.fattore_regia = 1.0
	Effetti.applica_velocita()


func ultimo_nemico() -> void:
	# Morto l'ultimo nemico dell'ondata: il tempo si dilata un attimo.
	rallenta(0.3, 0.7)
	colpo(2.0)
	Controlli.vibra_ritmo("ultimo_nemico")
