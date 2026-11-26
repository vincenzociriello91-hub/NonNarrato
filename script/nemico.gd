class_name Nemico
extends CharacterBody2D
# Nemici con un piccolo cervello: osservano, decidono, agiscono, verificano e ricordano.
#  - "scheletro": guerriero. Può partire addormentato, si risveglia se ti avvicini o se fai rumore,
#    pattuglia, ti insegue, ti cerca dove ti ha visto l'ultima volta e colpisce da vicino con un colpo
#    lento ma annunciato. Sceglie una tattica (diretto, attesa, affondo, finta) secondo quello che ha
#    funzionato contro di te finora, e a volte fa un balzo indietro quando attacchi.
#  - "mago": tiene le distanze e lancia sfere di luce (dritte, anticipate dove andrai, o a raffica).
#  - "arciere": tiene le distanze e tira dardi di balestra (dritti, anticipati, o due di fila).
#  - "pipistrello": dorme appeso, poi vola e scende in picchiata (dritto, girandoti alle spalle,
#    o aspettando che tu sia scoperto). Si colpisce mentre scende o risale, o da lontano.
#  - "bestione": lento e corazzato. Da davanti para i colpi di spada: si colpisce alle spalle,
#    dopo un suo colpo (quando è scoperto), con la magia o con le trappole. Colpisce forte e carica.
#  - "saltatore": piccolo e veloce, ti balza addosso (dritto, a zig-zag o dall'alto) e ti segue
#    saltando da una piattaforma all'altra.
#  - "mimic": un forziere vivo. Sembra un forziere qualsiasi finché non lo apri; allora si sveglia e ti
#    salta addosso a morsi (si muove come il saltatore). Battuto, lascia pozioni migliori.
# Bottino (vedi Bottino): i deboli niente; i forti lasciano quello dell'arma con cui li hai finiti
# e a volte pozioni.
# Una nemesi (vedi Memoria) è lo stesso nemico, ma più forte, con un nome, un titolo e una frase;
# a ogni ritorno ha una capacità in più (parata, combo, rinforzi, pelle dura, furia) e resiste all'arma
# che l'ha battuta.
# Chi ha imparato che colpisci da lontano ("schiva_tiri") schiva i tuoi tiri.
# Insieme: chi ti vede chiama i compagni vicini; chi arriva secondo ti gira alle spalle; al massimo
# due (tre nelle ultime ondate) attaccano nello stesso momento. Lo scheletro può parare e concatenare
# due colpi, il bestione fino a tre. Riconoscono la tua arma preferita (Memoria.lezione_arma).
# Veterani: ogni nemico ha un posto nella stanza (id_posto) che accumula esperienza fra un sogno e
# l'altro (Memoria.veterani); il livello e l'ondata in corso lo rendono più forte.

enum Stato { DORME, RISVEGLIO, FERMO, PATTUGLIA, INSEGUE, ATTACCO, LANCIA, COLPITO, MORTO }

var _ha_ruggito := false

const TIPI := {
	"scheletro": {"foglio": "scheletro", "vita": 4, "passo": 30.0, "corsa": 58.0, "vista": 180.0, "portata": 38.0},
	"mago": {"foglio": "mago", "vita": 3, "passo": 26.0, "corsa": 26.0, "vista": 250.0, "portata": 0.0},
	"arciere": {"foglio": "arciere", "vita": 3, "passo": 28.0, "corsa": 28.0, "vista": 260.0, "portata": 0.0},
	"pipistrello": {"foglio": "pipistrello", "vita": 2, "passo": 34.0, "corsa": 190.0, "vista": 190.0, "portata": 0.0},
	"bestione": {"foglio": "bestione", "vita": 8, "passo": 22.0, "corsa": 40.0, "vista": 190.0, "portata": 50.0},
	"saltatore": {"foglio": "saltatore", "vita": 3, "passo": 44.0, "corsa": 88.0, "vista": 210.0, "portata": 30.0},
	"mimic": {"foglio": "mimic", "vita": 6, "passo": 40.0, "corsa": 70.0, "vista": 240.0, "portata": 34.0},
}
const SALTANO := ["saltatore", "mimic"]   # si muovono a balzi (stesso cervello)
const SENZA_NEMESI := ["mimic"]           # non diventano nemesi: non c'è un posto dove ritrovarli
const TIRATORI := ["mago", "arciere"]
const GRAVITA := 1200.0
const ATTACCO_DURATA := 0.86
const ATTACCO_INIZIO := 0.40
const ATTACCO_FINE := 0.56
const TEMPI_BESTIONE := [1.14, 0.62, 0.78]   # durata, inizio e fine del colpo d'ascia
const FINTA_MOMENTO := 0.22
const AFFONDO_VELOCITA := 95.0
const AFFONDO_PORTATA := 14.0
const LANCIO_DURATA := 0.83
const LANCIO_MOMENTO := 0.45
const RICARICA_MAGO := 2.4
const VELOCITA_SFERA := 115.0
const VELOCITA_DARDO := 185.0
const UDITO := 150.0
const RICERCA_MASSIMA := 3.5
const BALZO_DURATA := 0.86
const GIRO_BESTIONE := 0.8      # secondi che il bestione impiega a girarsi
const CORPO_A_CORPO := ["scheletro", "bestione", "saltatore", "mimic"]
const RICHIAMO := 200.0          # chi ti vede chiama i compagni entro questa distanza
const COMBO_VELOCE := 0.72       # i colpi concatenati partono prima
const PARATA_NEMICO := 0.45

var tipo := "scheletro"
var dorme := false
var stato := Stato.PATTUGLIA
var verso := -1
var vita := 3
var sprite: SpriteAnimato
var nemesi := {}                 # se non è vuoto, questo nemico è una nemesi (record di Memoria)
var potere := 0
var tattica := ""
var annunciato := false
var id_posto := ""               # posto nella stanza: la sua esperienza resta fra un sogno e l'altro
var livello := 0                 # livello da veterano (Memoria)
var ondata := 1                  # ondata in cui è comparso: ogni ondata in più lo rende più forte
var evocato := false             # chiamato da una nemesi con "rinforzi": niente esperienza
var rialzato := false            # torna in un'ondata: si rialza da terra
var capacita: Array = []

var _dati := {}
var _t_stato := 0.0
var _t_ricarica := 1.0
var _t_senza_vista := 0.0
var _t_tattica := 0.0
var _t_pausa := 0.0
var _t_incastrato := 0.0          # cammina ma non si sposta (vedi _controlla_incastro)
var _x_prima := 0.0
var _x_inizio_incastro := 0.0
var _segno_incastro := 0.0
var _t_cassa_davanti := 0.0       # ha appena urtato una cassa nella direzione in cui va
var _verso_cassa := 0
var _t_balzo := 0.0
var _t_finestra := 0.0           # chi gioca ha appena finito un rotolo/uno scatto: è il momento
var _t_schiva := 0.0
var _t_giro := 0.0
var _colpo_dato := false
var _lanciato := false
var _secondo := false
var _affondo := false
var _finta := false
var _carica := false
var _in_balzo := false
var _mancati := 0
var _ultimo_visto := Vector2.ZERO
var _ha_ricordo := false
var _stato_giocatore_prima := -1
var _casa := Vector2.ZERO        # pipistrello: dove torna a volare
var _fase_volo := ""             # pipistrello: "giro", "scende", "risale"
var _meta_volo := Vector2.ZERO
var _caso := RandomNumberGenerator.new()
var _bersaglio: Area2D
var _colpo: Area2D
var _forma_colpo: CollisionShape2D
var _ombra: LightOccluder2D
var _centro_locale := Vector2.ZERO
var _forza := 0                  # livello + ondata: quanto è cresciuto
var _t_parata := 0.0
var _t_ricarica_parata := 0.0
var _combo_rimasti := 0
var _veloce := false
var _allertato := false
var _fianco := 0                 # -1/1: ti sta girando attorno per prenderti dall'altra parte
var _t_fianco := 0.0
var _furioso := false
var _rinforzi_chiamati := false
var _danno_inflitto := 0
var _t_vivo := 0.0
var _schivate := 0
var _ultima_famiglia := ""
var _t_bloccato := 0.0
var _ultima_arma := ""             # con cosa è arrivato l'ultimo colpo: decide il bottino
var bottino_lasciato: Array = []   # cosa ha lasciato morendo (per il rapporto e le prove)
var in_tregua := false             # prove del bot: fermo, intoccabile e senza corpo per gli altri
var _corpo := Vector2(14, 40)


func _ready() -> void:
	_dati = (TIPI.get(tipo, TIPI["scheletro"]) as Dictionary).duplicate()
	_caso.seed = hash(Vector2i(position)) + int(Memoria.sogni) * 7919
	if not nemesi.is_empty():
		potere = int(nemesi.get("potere", 1))
		_dati["vita"] = int(_dati["vita"]) + potere
		_dati["corsa"] = float(_dati["corsa"]) * (1.0 + 0.1 * potere)
		_dati["vista"] = float(_dati["vista"]) + 30.0 * potere
	# Veterano e ondata: un po' più di vita, velocità, vista e riflessi a ogni livello.
	if not evocato:
		livello = Memoria.livello_veterano(id_posto)
	_forza = livello + maxi(0, ondata - 1)
	_dati["vita"] = int(_dati["vita"]) + _forza / 2
	_dati["corsa"] = float(_dati["corsa"]) * (1.0 + 0.03 * _forza)
	_dati["vista"] = float(_dati["vista"]) + 8.0 * _forza
	capacita = (nemesi.get("capacita", []) as Array).duplicate()
	if livello >= 4 and not capacita.has("combo"):
		capacita.append("combo")
	if livello >= 7 and not capacita.has("parata"):
		capacita.append("parata")
	if livello >= 9 and not capacita.has("furia"):
		capacita.append("furia")
	if capacita.has("pelle_dura"):
		_dati["vita"] = int(_dati["vita"]) + 3
	vita = _dati["vita"]
	_casa = position
	collision_layer = Effetti.S_NEMICI
	collision_mask = Effetti.S_MONDO | Effetti.S_PIATTAFORME | Effetti.S_OGGETTI
	floor_snap_length = 4.0
	z_index = 5

	# Misure: corpo, zona in cui lo si colpisce, zona del suo colpo.
	var corpo := Vector2(14, 40)
	var bersaglio := Vector2(18, 40)
	var colpo := Vector2(34, 42)
	match tipo:
		"bestione":
			corpo = Vector2(22, 56)
			bersaglio = Vector2(26, 56)
			colpo = Vector2(48, 56)
		"saltatore":
			corpo = Vector2(12, 32)
			bersaglio = Vector2(16, 32)
			colpo = Vector2(30, 34)
		"pipistrello":
			corpo = Vector2(14, 12)
			bersaglio = Vector2(22, 18)
			colpo = Vector2(20, 16)
		"mimic":
			corpo = Vector2(30, 24)
			bersaglio = Vector2(34, 28)
			colpo = Vector2(40, 30)
	_corpo = corpo
	var vola := tipo == "pipistrello"
	if vola:
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		collision_mask = Effetti.S_MONDO   # vola attraverso le piattaforme
	var centro := 0.0 if vola else -1.0  # chi vola ha la posizione al centro del corpo, gli altri ai piedi

	var rett := RectangleShape2D.new()
	rett.size = corpo
	var forma := CollisionShape2D.new()
	forma.shape = rett
	forma.position = Vector2(0, corpo.y * 0.5 * centro)
	add_child(forma)

	sprite = SpriteAnimato.new()
	sprite.carica(_dati["foglio"])
	sprite.light_mask = Effetti.L_DAVANTI
	add_child(sprite)
	_applica_contorno()
	Impostazioni.cambiata.connect(_su_impostazione)

	_bersaglio = Area2D.new()
	_bersaglio.collision_layer = Effetti.S_BERSAGLI
	_bersaglio.collision_mask = 0
	_bersaglio.monitoring = false
	_bersaglio.set_meta("bersaglio", self)
	var rett_b := RectangleShape2D.new()
	rett_b.size = bersaglio
	var forma_b := CollisionShape2D.new()
	forma_b.shape = rett_b
	forma_b.position = Vector2(0, bersaglio.y * 0.5 * centro)
	_centro_locale = forma_b.position
	_bersaglio.add_child(forma_b)
	add_child(_bersaglio)

	_colpo = Area2D.new()
	_colpo.collision_layer = Effetti.S_COLPI_NEMICI
	_colpo.collision_mask = Effetti.S_BERSAGLIO_GIOCATORE
	_colpo.monitorable = false
	var rett_c := RectangleShape2D.new()
	rett_c.size = colpo
	_forma_colpo = CollisionShape2D.new()
	_forma_colpo.shape = rett_c
	_forma_colpo.position = Vector2(0, 0) if vola else Vector2(colpo.x * 0.6, -colpo.y * 0.5)
	_colpo.add_child(_forma_colpo)
	add_child(_colpo)

	_ombra = Effetti.occlusore(self, Rect2(-5, -6, 10, 10) if vola else Rect2(-5, -corpo.y + 2.0, 10, corpo.y - 4.0))
	if not nemesi.is_empty():
		_aspetto_nemesi()
	elif livello >= 5 and Dispositivo.profilo.get("luci_doppie", true):
		# Un veterano si riconosce dagli occhi accesi, più tenui di quelli di una nemesi.
		var occhi := Effetti.luce(Color(1.0, 0.6, 0.25), 18.0, 0.6, 12.0)
		occhi.position = Vector2(0, -2) if tipo == "pipistrello" else Vector2(0, -34)
		add_child(occhi)

	if dorme and sprite.ha("dorme"):
		stato = Stato.DORME
		sprite.riproduci("dorme")
		_bersaglio.monitorable = vola  # il pipistrello appeso si può colpire
		_ombra.visible = false
	elif rialzato and sprite.ha("risveglio"):
		stato = Stato.RISVEGLIO
		sprite.riproduci("risveglio", true)
		_bersaglio.monitorable = false
		_ombra.visible = false
	else:
		stato = Stato.PATTUGLIA
		sprite.riproduci("vola" if vola else "cammina")


func _aspetto_nemesi() -> void:
	# Si riconosce subito: tinta di sangue se ti ha battuto, di cenere se torna per vendetta, occhi accesi.
	sprite.modulate = Color(0.8, 0.82, 1.0) if nemesi.get("cicatrice", false) else Color(1.0, 0.7, 0.62)
	if Dispositivo.profilo.get("luci_doppie", true):
		var occhi := Effetti.luce(Color(1.0, 0.25, 0.2), 26.0, 0.9, 12.0)
		occhi.position = Vector2(0, -2) if tipo == "pipistrello" else Vector2(0, -34)
		add_child(occhi)


func centro() -> Vector2:
	# Il centro del corpo (dove mirano i tiri di chi gioca).
	return global_position + _centro_locale


func bersagliabile() -> bool:
	return stato != Stato.MORTO and _bersaglio != null and _bersaglio.monitorable


func tempi_attacco() -> Array:
	# Durata, inizio e fine della parte del colpo che fa male (il bot li legge per difendersi).
	var tempi: Array = TEMPI_BESTIONE if tipo == "bestione" else [ATTACCO_DURATA, ATTACCO_INIZIO, ATTACCO_FINE]
	if _veloce:
		return tempi.map(func(t: float) -> float: return t * COMBO_VELOCE)
	return tempi


func tregua(si: bool) -> void:
	# Per le prove tecniche del bot: fermo e intoccabile (poi torna com'era).
	in_tregua = si
	set_physics_process(not si)
	if stato == Stato.MORTO:
		return
	_bersaglio.set_deferred("monitorable", not si and stato not in [Stato.DORME, Stato.RISVEGLIO] or (not si and tipo == "pipistrello"))
	if si:
		velocity = Vector2.ZERO


func solido() -> bool:
	# Ha un corpo che non si attraversa: non chi è morto, chi dorme a terra, chi vola, chi è in tregua.
	return stato not in [Stato.MORTO, Stato.DORME] and tipo != "pipistrello" and not in_tregua and is_inside_tree()


const FORZIERE_MEZZO := 15.0   # metà della larghezza visibile di un forziere (Forziere: occlusore 28 px)
const CASSA_MEZZO := 17.0      # metà della cassa (Stanza._cassa: 34 px)
const SPAZIO := {"scheletro": 14.0, "mago": 13.0, "arciere": 13.0, "bestione": 20.0, "saltatore": 12.0, "mimic": 19.0}


func mezza_larghezza() -> float:
	# Quanto è largo da vedere (armi e mantelli compresi): due sprite a questa distanza non si coprono.
	return float(SPAZIO.get(tipo, _corpo.x * 0.5 + 3.0))


func estensione_verticale() -> Vector2:
	# [alto, basso] del corpo nel mondo (la posizione è ai piedi).
	return Vector2(global_position.y - _corpo.y, global_position.y)


func spingi(dx: float) -> void:
	# Spinto di lato da chi gioca o da un compagno: si sposta, ma non dentro i muri.
	if absf(dx) > 0.01:
		move_and_collide(Vector2(dx, 0.0))


func _separa_dai_compagni() -> void:
	# Due nemici non stanno uno dentro l'altro: ognuno si sposta di metà.
	if not solido():
		return
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		var altro := n as Nemico
		if altro == null or altro == self or not altro.solido():
			continue
		var dx := global_position.x - altro.global_position.x
		var mezzo := mezza_larghezza() + altro.mezza_larghezza()
		if absf(dx) >= mezzo:
			continue
		var v := altro.estensione_verticale()
		if global_position.y <= v.x + 2.0 or global_position.y - _corpo.y >= v.y - 2.0:
			continue
		var lato := signf(dx)
		if lato == 0.0:
			lato = 1.0 if get_instance_id() > altro.get_instance_id() else -1.0
		move_and_collide(Vector2(lato * (mezzo - absf(dx)) * 0.5, 0.0))


func _scosta_dagli_oggetti(delta: float) -> void:
	# Un nemico fermo non resta piantato dentro un forziere o una cassa (il mago della balconata
	# stava sopra il forziere, l'arciere mezzo dentro la cassa):
	# scivola piano di lato. Solo da fermo e a terra, mai verso un vuoto: chi cammina passa davanti
	# al forziere come davanti a un mobile, senza fermarsi (niente "camminare sul posto").
	if not solido() or tipo == "pipistrello" or not is_on_floor() or absf(velocity.x) > 8.0:
		return
	if stato == Stato.ATTACCO:
		return
	var oggetti: Array = get_tree().get_nodes_in_group("forzieri") + get_tree().get_nodes_in_group("casse")
	for n: Node in oggetti:
		var f := n as Node2D
		if f == null or absf(f.global_position.y - global_position.y) > 12.0:
			continue
		var dx := global_position.x - f.global_position.x
		var mezzo := mezza_larghezza() + (CASSA_MEZZO if n.is_in_group("casse") else FORZIERE_MEZZO)
		if absf(dx) >= mezzo:
			continue
		var lato := signf(dx) if dx != 0.0 else -1.0
		var passo := minf(mezzo - absf(dx), 60.0 * delta)
		var da := global_position + Vector2(lato * (passo + mezza_larghezza()), -4.0)
		var domanda := PhysicsRayQueryParameters2D.create(da, da + Vector2(0.0, 26.0),
				Effetti.S_MONDO | Effetti.S_PIATTAFORME | Effetti.S_OGGETTI)
		if get_world_2d().direct_space_state.intersect_ray(domanda).is_empty():
			lato = -lato   # da quella parte c'è il vuoto: si va dall'altra
			passo = minf(mezzo + absf(dx), 60.0 * delta)
		move_and_collide(Vector2(lato * passo, 0.0))
		return


func _guarda_casse(delta: float) -> void:
	# Una cassa davanti fa da muro per un attimo: il contatto con un corpo rigido va e viene,
	# e prima il nemico ci tremava contro camminando sul posto.
	_t_cassa_davanti = maxf(0.0, _t_cassa_davanti - delta)
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var corpo := c.get_collider() as Node
		if corpo != null and corpo.is_in_group("casse") and signf(c.get_normal().x) == -float(verso):
			_t_cassa_davanti = 0.3
			_verso_cassa = verso


func _sfonda_barili() -> void:
	# Un barile sulla strada: il nemico lo sfonda passando (invece di restarci incastrato o di attraversarlo).
	# Chi è di ronda invece torna indietro (_pattuglia lo vede come un muro): prima scheletro e bestione
	# rompevano i barili vicini appena partito il sogno, senza motivo.
	if stato == Stato.PATTUGLIA:
		return
	for i in get_slide_collision_count():
		var corpo := get_slide_collision(i).get_collider() as Node
		if corpo != null and corpo.get_parent() is Rompibile and absf(get_slide_collision(i).get_normal().x) > 0.5:
			(corpo.get_parent() as Rompibile).subisci(1, global_position, 0.0)
			Rapporto.conta("barili_sfondati")


func sta_parando() -> bool:
	return _t_parata > 0.0


func colpi_in_arrivo() -> int:
	# Quanti colpi aggiungerà alla combinazione in corso (chi gioca lo impara dal ritmo; il bot lo legge qui).
	return _combo_rimasti if stato == Stato.ATTACCO else 0


func barcolla(durata: float) -> void:
	# Colpito su uno scudo, stordito, o con la guardia rotta: resta scoperto per un po'.
	if stato in [Stato.MORTO, Stato.DORME, Stato.RISVEGLIO]:
		return
	_carica = false
	_in_balzo = false
	_combo_rimasti = 0
	_t_parata = 0.0
	_cambia(Stato.COLPITO)
	_t_stato = 0.3 - durata   # COLPITO finisce a 0,3
	velocity.x = 0.0
	sprite.riproduci("colpito", true)
	Rapporto.conta("nemici_barcollano")


func _physics_process(delta: float) -> void:
	_t_stato += delta
	_t_tattica += delta
	_t_ricarica = maxf(0.0, _t_ricarica - delta)
	_t_pausa = maxf(0.0, _t_pausa - delta)
	_t_balzo = maxf(0.0, _t_balzo - delta)
	_t_finestra = maxf(0.0, _t_finestra - delta)
	_t_schiva = maxf(0.0, _t_schiva - delta)
	_t_parata = maxf(0.0, _t_parata - delta)
	_t_ricarica_parata = maxf(0.0, _t_ricarica_parata - delta)
	_t_fianco = maxf(0.0, _t_fianco - delta)
	if stato != Stato.MORTO:
		_t_vivo += delta
	var vola := tipo == "pipistrello" and stato != Stato.MORTO
	if not vola:
		velocity.y = minf(velocity.y + GRAVITA * delta, 500.0)

	# Osserva.
	var g := get_tree().get_first_node_in_group("giocatore") as Giocatore
	var dx := 0.0
	var dy := 0.0
	var visto := false
	var sentito := false
	if g != null and g.stato != Giocatore.Stato.MORTO:
		dx = g.global_position.x - global_position.x
		dy = g.global_position.y - global_position.y
		var quota := 200.0 if tipo in TIRATORI or vola else (120.0 if tipo in SALTANO else 80.0)
		visto = absf(dx) < float(_dati["vista"]) and absf(dy) < quota and _vede(g)
		sentito = _sente(g, dx, dy)
		_osserva_giocatore(g)
		if visto or sentito:
			_ultimo_visto = g.global_position
			_ha_ricordo = true
		if visto and not annunciato and not nemesi.is_empty() and stato != Stato.DORME:
			_annuncia()
		if visto and not _allertato and stato not in [Stato.DORME, Stato.RISVEGLIO, Stato.MORTO]:
			_allertato = true
			_chiama_compagni(g)
		_controlla_furia()
		if _reagisci_al_colpo(g, dx, dy):
			move_and_slide()
			sprite.flip_h = verso < 0
			return
		if stato in [Stato.INSEGUE, Stato.FERMO, Stato.PATTUGLIA] and _schiva_tiri():
			move_and_slide()
			sprite.flip_h = verso < 0
			return

	if tipo == "pipistrello" and stato not in [Stato.COLPITO, Stato.MORTO]:
		_pipistrello(g, delta, dx, dy, visto or sentito)
	else:
		match stato:
			Stato.DORME:
				velocity.x = 0.0
				if g != null and ((absf(dx) < 120.0 and absf(dy) < 70.0) or sentito):
					_risvegliati()
			Stato.RISVEGLIO:
				velocity.x = 0.0
				if _t_stato >= sprite.durata("risveglio"):
					_bersaglio.set_deferred("monitorable", true)
					_ombra.visible = true
					_cambia(Stato.INSEGUE)
			Stato.PATTUGLIA:
				_pattuglia(visto or sentito)
			Stato.FERMO:
				_tiratore(g, dx, dy, visto, delta)
			Stato.INSEGUE:
				if tipo in SALTANO:
					_saltatore(g, delta, dx, dy, visto)
				else:
					_insegui(g, delta, dx, dy, visto)
			Stato.ATTACCO:
				if _in_balzo:
					_balzo(g)
				else:
					_attacca(g)
			Stato.LANCIA:
				_lancia(g)
			Stato.COLPITO:
				if tipo == "pipistrello":
					velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
				else:
					velocity.x = move_toward(velocity.x, 0.0, 420.0 * delta)
				if _t_stato >= 0.3:
					_cambia(Stato.FERMO if tipo in TIRATORI else Stato.INSEGUE)
					if tipo == "pipistrello":
						_fase_volo = "risale"
			Stato.MORTO:
				velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
				if _t_stato >= 2.6:
					sprite.modulate.a = maxf(0.0, sprite.modulate.a - delta * 1.6)
					if sprite.modulate.a <= 0.0:
						queue_free()

	_x_prima = global_position.x
	move_and_slide()
	if stato != Stato.MORTO:
		_sfonda_barili()
		_guarda_casse(delta)
		_separa_dai_compagni()
		_scosta_dagli_oggetti(delta)
		_controlla_incastro(delta)
	sprite.flip_h = verso < 0


# ------------------------------------------------------------------ percezione

func _vede(g: Giocatore) -> bool:
	# Niente vista attraverso i muri.
	var da := global_position + (Vector2.ZERO if tipo == "pipistrello" else Vector2(0, -30))
	var a := g.global_position + Vector2(0, -22)
	var domanda := PhysicsRayQueryParameters2D.create(da, a, Effetti.S_MONDO)
	return get_world_2d().direct_space_state.intersect_ray(domanda).is_empty()


func _sente(g: Giocatore, dx: float, dy: float) -> bool:
	# Colpi, rotoli, scatti e scavalchi fanno rumore.
	var rumore := g.stato in [Giocatore.Stato.ATTACCO, Giocatore.Stato.ROTOLATA, Giocatore.Stato.SCHIVATA, Giocatore.Stato.SCAVALCO, Giocatore.Stato.TIRO]
	return rumore and absf(dx) < UDITO and absf(dy) < 90.0


func _osserva_giocatore(g: Giocatore) -> void:
	# Appena finisce un rotolo o uno scatto, chi gioca è scoperto per un attimo.
	var ora := int(g.stato)
	if _stato_giocatore_prima in [Giocatore.Stato.ROTOLATA, Giocatore.Stato.SCHIVATA] and ora == Giocatore.Stato.NORMALE:
		_t_finestra = 0.4
	_stato_giocatore_prima = ora


func _annuncia() -> void:
	annunciato = true
	var testo := Memoria.incontro(nemesi)
	Suoni.suona("nemesi", global_position)
	if testo != "":
		get_tree().call_group("hud", "messaggio", testo, 4.0, true)


func _lezione() -> String:
	return nemesi.get("lezione", "") if not nemesi.is_empty() else Memoria.lezione_attuale()


func _schiva_tiri() -> bool:
	# Chi ha imparato che colpisci da lontano scansa i tuoi tiri (il bestione no: si fida della corazza).
	if tipo == "bestione" or _t_schiva > 0.0 or _lezione() != "schiva_tiri":
		return false
	for t: Node in get_tree().get_nodes_in_group("tiri_eroe"):
		var tiro := t as Proiettile
		var d := global_position + Vector2(0, -16) - tiro.global_position
		if d.length() < 80.0 and d.dot(tiro.velocita) > 0.0 and absf(d.y) < 40.0:
			_t_schiva = 1.2
			var via := signf(d.x) if d.x != 0.0 else float(-verso)
			if tipo == "pipistrello":
				velocity = Vector2(via * 60.0, -170.0)
			elif is_on_floor():
				velocity = Vector2(via * 120.0, -230.0)
			else:
				return false
			Rapporto.conta("tiri_schivati_dai_nemici")
			return true
	return false


# ------------------------------------------------------------------ comportamenti

func _risvegliati() -> void:
	Suoni.suona("pipistrello" if tipo == "pipistrello" else ("mimic_ruggito" if tipo == "mimic" else "risveglio"), global_position, -4.0)
	_cambia(Stato.RISVEGLIO)
	sprite.riproduci("risveglio", true)
	Rapporto.evento("risveglio", {"x": roundi(global_position.x), "tipo": tipo})


func _pattuglia(allerta: bool) -> void:
	velocity.x = verso * float(_dati["passo"])
	var chiuso := false
	if is_on_floor() and (is_on_wall() or _vuoto_davanti() or _corpo_davanti()):
		verso = -verso   # anche contro un compagno: si torna indietro invece di spingerlo sul posto
		velocity.x = verso * float(_dati["passo"])
		if _vuoto_davanti() or _corpo_davanti() or test_move(global_transform, Vector2(verso * 2.0, 0.0)):
			# Chiuso da tutte e due le parti (fra un barile e chi gioca, per esempio): si sta fermi
			# invece di girarsi a ogni fotogramma camminando sul posto.
			verso = -verso
			velocity.x = 0.0
			chiuso = true
	sprite.riproduci("fermo" if chiuso else "cammina")
	if allerta:
		_cambia(Stato.FERMO if tipo in TIRATORI else Stato.INSEGUE)


func _scegli_tattica() -> void:
	var prima := tattica
	var lezione := _lezione()
	for i in 3:
		tattica = Memoria.scegli_tattica(tipo, lezione, _caso)
		if tattica != prima or _mancati < 2:
			break
	_mancati = 0
	_t_tattica = 0.0


func _insegui(g: Giocatore, delta: float, dx: float, dy: float, visto: bool) -> void:
	if tattica == "":
		_scegli_tattica()
	if not visto:
		# Non ti vede: va a cercarti dove ti ha visto (o sentito) l'ultima volta, poi si arrende.
		_t_senza_vista += delta
		if not _ha_ricordo or _t_senza_vista > RICERCA_MASSIMA:
			_ha_ricordo = false
			_t_senza_vista = 0.0
			_cambia(Stato.PATTUGLIA)
			return
		var verso_ricordo := _ultimo_visto.x - global_position.x
		if absf(verso_ricordo) < 10.0:
			_ha_ricordo = false
		else:
			verso = 1 if verso_ricordo > 0.0 else -1
		_cammina(float(_dati["passo"]) * 1.3)
		return
	_t_senza_vista = 0.0
	if _t_balzo > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		return
	if absf(dx) > 4.0 and not _carica:
		var voluto := 1 if dx > 0.0 else -1
		if tipo == "bestione" and voluto != verso:
			# Pesante: ci mette un attimo a girarsi, e alle spalle lo si può colpire.
			_t_giro += delta
			if _t_giro >= GIRO_BESTIONE:
				verso = voluto
				_t_giro = 0.0
		else:
			verso = voluto
			_t_giro = 0.0
	var distanza := absf(dx)
	var portata := float(_dati["portata"])
	var stessa_quota := absf(dy) < 44.0
	# Accerchiare: se un compagno ti è già addosso da questa parte, si passa dall'altra.
	if stessa_quota and not _carica and _accerchia(g, dx):
		return

	# Carica del bestione: corre dritto finché non ti raggiunge, sbatte o passa il tempo.
	if _carica:
		_colpisci_a_contatto(g, 1, 260.0)
		velocity.x = verso * 165.0
		sprite.riproduci("cammina", false, 2.2)
		if _t_tattica > 0.9 or is_on_wall() or _vuoto_davanti() or _colpo_dato or _corpo_davanti():
			_carica = false
			_t_pausa = 0.5        # dopo la carica resta scoperto un attimo
			_verifica_attacco()
		return

	# Difesa: se attacchi da vicino, a volte balza indietro (di più se ha imparato che attacchi per primo).
	if tipo == "scheletro" and g.attacco_in_carica() and distanza < 46.0 \
			and is_on_floor() and _t_ricarica <= 0.0 and _t_pausa <= 0.0:
		var p := 0.12 + 0.12 * potere + (0.3 if nemesi.get("lezione", "") == "arretra" else 0.0)
		if _caso.randf() < p:
			velocity = Vector2(-verso * 150.0, -110.0)
			_t_balzo = 0.3
			_t_ricarica = 0.35
			Rapporto.conta("balzi_nemici")
			return

	if _t_pausa > 0.0:
		velocity.x = 0.0
		sprite.riproduci("fermo")
		return

	var pronto := _t_ricarica <= 0.0 and is_on_floor() and stessa_quota and _posto_per_attaccare()
	match tattica:
		"attesa":
			# Resta appena fuori portata e colpisce quando sei scoperto (o dopo un po').
			var voluta := portata + 16.0
			if distanza > voluta + 8.0:
				_cammina(float(_dati["corsa"]))
			elif distanza < portata - 6.0:
				verso = -verso
				_cammina(float(_dati["passo"]))
				verso = -verso
			else:
				velocity.x = 0.0
				sprite.riproduci("fermo")
			var scoperto: bool = _t_finestra > 0.0 or g.attacco_scoperto()
			if pronto and distanza <= portata + 20.0 and (scoperto or _t_tattica > 2.2):
				_inizia_attacco(distanza > portata - 2.0, false)
		"affondo":
			if distanza > portata + 34.0:
				_cammina(float(_dati["corsa"]))
			elif pronto:
				_inizia_attacco(true, false)
			else:
				velocity.x = 0.0
				sprite.riproduci("fermo")
		"finta":
			if distanza > portata:
				_cammina(float(_dati["corsa"]))
			elif pronto:
				_inizia_attacco(false, true)
			else:
				velocity.x = 0.0
				sprite.riproduci("fermo")
		"carica":
			# Bestione: da lontano carica, da vicino colpisce.
			if pronto and distanza > 80.0 and distanza < 220.0 and _t_tattica > 0.6:
				_carica = true
				_colpo_dato = false
				_forma_colpo.position.x = 20.0 * verso
				_t_tattica = 0.0
				Rapporto.conta("cariche_bestione")
			elif distanza > portata:
				_cammina(float(_dati["corsa"]))
			elif pronto:
				_inizia_attacco(false, false)
			else:
				velocity.x = 0.0
				sprite.riproduci("fermo")
		_:
			if distanza > portata or not stessa_quota:
				_cammina(float(_dati["corsa"]))
			elif pronto:
				_inizia_attacco(false, false)
			else:
				velocity.x = 0.0
				sprite.riproduci("fermo")


func _cammina(velocita_voluta: float) -> void:
	var muro_davanti := (is_on_wall() and signf(get_wall_normal().x) == -float(verso)) \
			or (_t_cassa_davanti > 0.0 and verso == _verso_cassa)
	if _t_pausa > 0.0 or muro_davanti or (is_on_floor() and (_vuoto_davanti() or _corpo_davanti())):
		velocity.x = 0.0
		sprite.riproduci("fermo")
		return
	velocity.x = verso * velocita_voluta
	sprite.riproduci("cammina", false, 1.6 if velocita_voluta > float(_dati["passo"]) * 1.2 else 1.0)


func _controlla_incastro(delta: float) -> void:
	# Ultima difesa contro il "camminare sul posto": se vuole camminare ma per 0,4 s non si sposta
	# (un angolo, una cassa, un corpo che le altre regole non vedono), smette: la ronda si gira,
	# chi insegue si ferma un attimo a guardare invece di pestare i piedi.
	# Si misura lo spostamento su tutta la finestra: contro una cassa il corpo trema avanti e indietro
	# (si sposta un po' a ogni fotogramma) ma in mezzo secondo non va da nessuna parte.
	var vuole := absf(velocity.x) > 5.0 and sprite.animazione == "cammina" and is_on_floor()
	if not vuole or signf(velocity.x) != _segno_incastro:
		# Anche quando cambia direzione: una ronda che si gira contro un muro non è incastrata
		# (prima la finestra scavalcava la svolta e il bestione della sala faceva avanti e indietro sul posto).
		_t_incastrato = 0.0
		_segno_incastro = signf(velocity.x) if vuole else 0.0
		if not vuole:
			return
	if _t_incastrato == 0.0:
		_x_inizio_incastro = _x_prima
	_t_incastrato += delta
	if _t_incastrato < 0.4:
		return
	var fermo := absf(global_position.x - _x_inizio_incastro) < 3.0
	_t_incastrato = 0.0
	if not fermo:
		return
	Rapporto.conta("nemici_incastrati")
	if stato == Stato.PATTUGLIA:
		verso = -verso
	else:
		_t_pausa = maxf(_t_pausa, 0.6)
		_ha_ricordo = false   # se cercava dove ti aveva visto, lì non ci arriva: smette di cercare
	velocity.x = 0.0
	sprite.riproduci("fermo")


func _corpo_davanti() -> bool:
	# Dalla 0.1.22 i corpi sono solidi: chi gioca o un compagno fermo davanti, a contatto, non si attraversano.
	# Camminarci contro voleva dire "camminare sul posto" (bug del 26/11/2026): ci si ferma.
	if not solido():
		return false
	var mio := estensione_verticale()
	var g := get_tree().get_first_node_in_group("giocatore") as Giocatore
	if g != null and g.solido_per_i_nemici():
		var dx := g.global_position.x - global_position.x
		if signf(dx) == float(verso) and absf(dx) <= mezza_larghezza() + Giocatore.SPAZIO + 3.0 \
				and g.global_position.y > mio.x + 2.0 and g.global_position.y - 40.0 < mio.y - 2.0:
			return true
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		var altro := n as Nemico
		if altro == null or altro == self or not altro.solido():
			continue
		var dx := altro.global_position.x - global_position.x
		if signf(dx) != float(verso) or absf(dx) > mezza_larghezza() + altro.mezza_larghezza() + 3.0:
			continue
		var v := altro.estensione_verticale()
		if global_position.y > v.x + 2.0 and mio.x < v.y - 2.0:
			return true
	return false


func _inizia_attacco(affondo: bool, finta: bool, concatenato: bool = false) -> void:
	_veloce = concatenato
	if not concatenato:
		# Quanti colpi aggiungerà di fila: più è esperto, più spesso; la capacità "combo" lo garantisce.
		var massimo := 2 if tipo == "bestione" else 1
		if capacita.has("combo"):
			massimo += 1
		_combo_rimasti = 0
		if tipo in ["scheletro", "bestione"] and not finta:
			var p := 0.08 * _forza + (0.35 if capacita.has("combo") else 0.0)   # all'inizio quasi mai: lo imparano
			while _combo_rimasti < massimo and _caso.randf() < p:
				_combo_rimasti += 1
	_colpo_dato = false
	_affondo = affondo
	_finta = finta
	_in_balzo = false
	var base := float((_forma_colpo.shape as RectangleShape2D).size.x) * 0.6
	_forma_colpo.position.x = (base + (AFFONDO_PORTATA if affondo else 0.0)) * verso
	_cambia(Stato.ATTACCO)
	sprite.riproduci("attacco", true)


func _attacca(g: Giocatore) -> void:
	var tempi := tempi_attacco()
	velocity.x = 0.0
	if _affondo and _t_stato < float(tempi[1]) and not (is_on_wall() or _vuoto_davanti()):
		velocity.x = verso * AFFONDO_VELOCITA  # passo in avanti mentre carica il colpo
	if _finta and _t_stato >= FINTA_MOMENTO:
		# Finta: interrompe, aspetta che tu reagisca, poi colpisce davvero.
		_finta = false
		_cambia(Stato.INSEGUE)
		_t_pausa = 0.3
		_t_ricarica = 0.0
		_inizia_attacco_dopo_finta()
		return
	if not _colpo_dato and _t_stato >= float(tempi[1]) and _t_stato <= float(tempi[2]):
		for area in _colpo.get_overlapping_areas():
			if area.get_meta("bersaglio", null) == g and g != null:
				_colpo_dato = true
				var danno := 2 if tipo == "bestione" else 1
				if g.subisci(danno, global_position, 240.0 if tipo == "bestione" else 190.0, self):
					_danno_inflitto += danno
		if tipo == "bestione" and _t_stato - get_physics_process_delta_time() < float(tempi[1]):
			_scossa_ascia()
	if _t_stato >= float(tempi[0]):
		_verifica_attacco()
		# Combinazione: se sei ancora a portata, un altro colpo subito.
		if _combo_rimasti > 0 and g != null and g.stato != Giocatore.Stato.MORTO:
			var dx := g.global_position.x - global_position.x
			if absf(dx) < float(_dati["portata"]) + 26.0 and absf(g.global_position.y - global_position.y) < 40.0:
				_combo_rimasti -= 1
				verso = 1 if dx > 0.0 else -1
				Rapporto.conta("combo_nemici")
				_inizia_attacco(false, false, true)
				return
		_combo_rimasti = 0
		_veloce = false
		_t_ricarica = maxf(0.25, (0.9 if tipo == "bestione" else 0.5) - 0.06 * potere - 0.02 * _forza)
		if _furioso:
			_t_ricarica *= 0.6
		_cambia(Stato.INSEGUE)


func _scossa_ascia() -> void:
	Effetti.scoppio(get_parent(), global_position + Vector2(verso * 30.0, -2.0), Color(0.55, 0.52, 0.5, 0.7), 8, 60.0, 0.4, 200.0, false)
	var g := get_tree().get_first_node_in_group("giocatore") as Giocatore
	if g != null and g.global_position.distance_to(global_position) < 200.0:
		g.scuoti(3.0)


func _colpisci_a_contatto(g: Giocatore, danno: int, spinta: float) -> void:
	if g == null or _colpo_dato:
		return
	for area in _bersaglio_giocatore_vicino():
		if area.get_meta("bersaglio", null) == g:
			_colpo_dato = g.subisci(danno, global_position, spinta, self)
			if _colpo_dato:
				_danno_inflitto += danno
			return


func _bersaglio_giocatore_vicino() -> Array:
	_colpo.monitoring = true
	return _colpo.get_overlapping_areas()


func _inizia_attacco_dopo_finta() -> void:
	tattica = "finta_colpo"  # dopo la pausa colpisce senza altre finte
	await get_tree().create_timer(0.3, false).timeout
	if is_instance_valid(self) and stato == Stato.INSEGUE:
		_inizia_attacco(false, false)
		tattica = "finta"


func _verifica_attacco() -> void:
	# Verifica e ricorda: com'è andata questa tattica?
	var usata := "finta" if tattica == "finta_colpo" else tattica
	Memoria.esito_tattica(tipo, usata, _colpo_dato)
	if _colpo_dato:
		_mancati = 0
	else:
		_mancati += 1
	if _mancati >= 2 or _caso.randf() < 0.25:
		_scegli_tattica()


# ------------------------------------------------------------------ saltatore

func _saltatore(g: Giocatore, delta: float, dx: float, dy: float, visto: bool) -> void:
	# Ti segue saltando; da vicino ti balza addosso.
	if tattica == "":
		_scegli_tattica()
	if not visto:
		_insegui(g, delta, dx, dy, visto)
		return
	if absf(dx) > 4.0:
		verso = 1 if dx > 0.0 else -1
	if not is_on_floor():
		sprite.riproduci("salto")
		return
	var distanza := absf(dx)
	var pronto := _t_ricarica <= 0.0
	# Sei più in alto e vicino: salta su (le piattaforme si attraversano dal basso).
	if dy < -40.0 and distanza < 150.0 and pronto:
		velocity = Vector2(verso * 90.0, -430.0)
		_t_ricarica = 0.6
		Rapporto.conta("salti_saltatore")
		return
	# Sei più in basso: agguato, ti piomba addosso dal bordo.
	if dy > 40.0 and distanza < 120.0 and tattica == "agguato" and pronto:
		_inizia_balzo(g, true)
		return
	match tattica:
		"zig":
			if pronto and distanza < 150.0 and distanza > 40.0:
				if _t_tattica < 0.8:
					velocity = Vector2(-verso * 110.0, -200.0)   # saltello indietro, poi il balzo
					_t_tattica = 0.8
					_t_ricarica = 0.35
				else:
					_inizia_balzo(g, false)
			elif distanza <= 40.0:
				# Troppo vicino per il saltello: prima ti passava attraverso, coi corpi solidi restava
				# a camminarti contro all'infinito. Ora salta indietro per prendere la rincorsa, o morde.
				if pronto and absf(dy) < 60.0:
					velocity = Vector2(-verso * 140.0, -220.0)
					_t_tattica = 0.8
					_t_ricarica = 0.35
				else:
					velocity.x = 0.0
					sprite.riproduci("fermo")
			else:
				_cammina(float(_dati["corsa"]))
		_:
			if pronto and distanza < 140.0 and distanza > 30.0 and absf(dy) < 60.0:
				_inizia_balzo(g, false)
			elif distanza > 30.0:
				_cammina(float(_dati["corsa"]))
			elif pronto:
				_inizia_balzo(g, false)
			else:
				velocity.x = 0.0
				sprite.riproduci("fermo")


func _inizia_balzo(g: Giocatore, dall_alto: bool) -> void:
	_colpo_dato = false
	_in_balzo = true
	_affondo = false
	_finta = false
	var dx := g.global_position.x - global_position.x if g != null else verso * 80.0
	var salto := -200.0 if dall_alto else -310.0
	velocity = Vector2(clampf(dx * 2.0, -260.0, 260.0), salto)
	_forma_colpo.position.x = 12.0 * verso
	_cambia(Stato.ATTACCO)
	sprite.riproduci("balzo", true)
	Rapporto.conta("balzi_saltatore")


func _balzo(g: Giocatore) -> void:
	if _t_stato > 0.08:
		_colpisci_a_contatto(g, 2 if tipo == "mimic" else 1, 200.0 if tipo == "mimic" else 170.0)
	if is_on_floor() and _t_stato > 0.12:
		velocity.x = move_toward(velocity.x, 0.0, 30.0)
	if _t_stato >= BALZO_DURATA and is_on_floor():
		_in_balzo = false
		_verifica_attacco()
		_t_ricarica = maxf(0.3, 0.8 - 0.08 * potere) + (0.4 if tipo == "mimic" else 0.0)
		_t_pausa = 0.7 if tipo == "mimic" else 0.35   # atterrato: scoperto (il mimic pesa: ci mette di più)
		_cambia(Stato.INSEGUE)


# ------------------------------------------------------------------ pipistrello

func _pipistrello(g: Giocatore, delta: float, dx: float, dy: float, allerta: bool) -> void:
	if stato == Stato.DORME:
		velocity = Vector2.ZERO
		if g != null and ((absf(dx) < 110.0 and absf(dy) < 220.0 and _vede(g)) or (allerta and absf(dx) < 160.0)):
			stato = Stato.INSEGUE
			_fase_volo = "giro"
			_bersaglio.set_deferred("monitorable", true)
			_ombra.visible = true
			sprite.riproduci("vola")
			velocity = Vector2(0, 60)
			Rapporto.evento("risveglio", {"x": roundi(global_position.x), "tipo": tipo})
		return
	_t_senza_vista = 0.0 if allerta else _t_senza_vista + delta
	if g == null or (_t_senza_vista > 3.0 and _fase_volo == "giro"):
		# Non ti vede da un po': torna a girare attorno a dove dormiva.
		sprite.riproduci("vola")
		_vola_verso(_casa + Vector2(sin(_t_tattica * 1.3) * 40.0, cos(_t_tattica * 2.1) * 12.0), 60.0, delta)
		return
	stato = Stato.INSEGUE
	if tattica == "":
		_scegli_tattica()
	var corpo := g.global_position + Vector2(0, -22)
	match _fase_volo:
		"scende":
			sprite.riproduci("picchiata")
			velocity = velocity.move_toward((_meta_volo - global_position).normalized() * float(_dati["corsa"]), 900.0 * delta)
			_colpisci_a_contatto(g, 1, 120.0)
			if _t_stato > 0.9 or global_position.distance_to(_meta_volo) < 8.0 or _colpo_dato or is_on_floor() or is_on_wall():
				_fase_volo = "risale"
				_cambia(Stato.INSEGUE)
				_verifica_attacco()
		"risale":
			sprite.riproduci("vola")
			var su := Vector2(global_position.x - verso * 40.0, corpo.y - 80.0)
			_vola_verso(su, 110.0, delta)
			if global_position.y < corpo.y - 70.0 or _t_stato > 1.2:
				_fase_volo = "giro"
				_t_ricarica = maxf(0.6, 1.4 - 0.15 * potere)
				_cambia(Stato.INSEGUE)
		_:
			sprite.riproduci("vola")
			if absf(dx) > 4.0:
				verso = 1 if dx > 0.0 else -1
			# Si tiene sopra di te, un po' di lato; con "aggira" va dalla parte dove non guardi.
			var lato := -g.verso if tattica == "aggira" else (-1 if dx > 0.0 else 1)
			var posto := corpo + Vector2(lato * 46.0, -74.0 + sin(_t_tattica * 3.0) * 6.0)
			_vola_verso(posto, 95.0 * (1.0 + 0.1 * potere), delta)
			# Se il posto è irraggiungibile (sotto un soffitto) non resta a girare per sempre: scende lo stesso.
			if global_position.distance_to(posto) >= 40.0:
				_t_bloccato += delta
			else:
				_t_bloccato = 0.0
			var pronto := _t_ricarica <= 0.0 and (global_position.distance_to(posto) < 40.0 or _t_bloccato > 1.2)
			var scoperto := _t_finestra > 0.0 or g.stato in [Giocatore.Stato.ATTACCO, Giocatore.Stato.TIRO, Giocatore.Stato.USA]
			if pronto and (tattica != "attesa" or scoperto or _t_tattica > 3.0):
				_fase_volo = "scende"
				_colpo_dato = false
				_meta_volo = corpo + Vector2(g.velocity.x * 0.25, 4.0)
				_t_bloccato = 0.0
				_cambia(Stato.INSEGUE)
				Rapporto.conta("picchiate_pipistrello")


func _vola_verso(dove: Vector2, velocita_voluta: float, delta: float) -> void:
	var d := dove - global_position
	var voluta := d.normalized() * minf(velocita_voluta, d.length() * 4.0)
	velocity = velocity.move_toward(voluta, 500.0 * delta)


# ------------------------------------------------------------------ tiratori (mago, arciere)

func _tiratore(g: Giocatore, dx: float, dy: float, visto: bool, delta: float) -> void:
	velocity.x = 0.0
	sprite.riproduci("fermo")
	if not visto or g == null:
		_t_senza_vista += delta
		if _t_senza_vista > 2.0:
			_t_senza_vista = 0.0
			_cambia(Stato.PATTUGLIA)
		return
	_t_senza_vista = 0.0
	if absf(dx) > 4.0:
		verso = 1 if dx > 0.0 else -1
	# Tiene le distanze: se ti avvicini troppo sulla sua quota, arretra.
	if absf(dx) < (90.0 if tipo == "arciere" else 70.0) and absf(dy) < 30.0:
		verso = -verso
		_cammina(float(_dati["passo"]) * 1.4)
		verso = -verso
	if _t_ricarica <= 0.0:
		if tattica == "" or _caso.randf() < 0.35:
			_scegli_tattica()
		_lanciato = false
		_secondo = false
		_cambia(Stato.LANCIA)
		sprite.riproduci("lancia", true)


func _lancia(g: Giocatore) -> void:
	velocity.x = 0.0
	if not _lanciato and _t_stato >= LANCIO_MOMENTO:
		_lanciato = true
		_tira(g)
	if tipo == "arciere" and tattica == "doppio" and _lanciato and not _secondo and _t_stato >= LANCIO_MOMENTO + 0.22:
		_secondo = true
		_tira(g)
	if _t_stato >= LANCIO_DURATA:
		var ricarica := RICARICA_MAGO * (1.0 - 0.06 * potere) * (1.0 - 0.03 * _forza)
		if tipo == "mago" and tattica == "raffica":
			ricarica += 0.8
		elif tipo == "arciere":
			ricarica = 2.6 * (1.0 - 0.06 * potere) * (1.0 - 0.03 * _forza) + (0.7 if tattica == "doppio" else 0.0)
		_t_ricarica = ricarica * (0.6 if _furioso else 1.0)
		_cambia(Stato.FERMO)


func _tira(g: Giocatore) -> void:
	var da := global_position + Vector2(verso * 16.0, -30.0 if tipo == "arciere" else -34.0)
	var velocita := (VELOCITA_DARDO if tipo == "arciere" else VELOCITA_SFERA) * (1.0 + 0.05 * potere)
	var mira := da + Vector2(verso * 100.0, 0.0)
	if g != null:
		mira = g.global_position + Vector2(0.0, -22.0)
		if tattica == "anticipo":
			# Mira dove andrai, non dove sei.
			var tempo := da.distance_to(mira) / velocita
			mira += Vector2(g.velocity.x, clampf(g.velocity.y, -200.0, 200.0)) * tempo * 0.85
	var direzione := (mira - da).normalized()
	var angoli := [0.0]
	if tipo == "mago" and tattica == "raffica":
		angoli = [-0.2, 0.0, 0.2]
	for a: float in angoli:
		var colpo := Proiettile.new()
		colpo.tipo = "freccia" if tipo == "arciere" else "sfera"
		colpo.position = da
		colpo.velocita = direzione.rotated(a) * velocita
		colpo.autore = self
		colpo.tattica = tattica
		get_parent().add_child(colpo)
	Suoni.suona("dardo" if tipo == "arciere" else "sfera_nemica", da, -3.0, 0.85 if tipo == "arciere" else 1.0)
	if tipo == "arciere":
		Suoni.suona("dardo_nemico", da)  # solo didascalia (nessun file con questo nome)
	Rapporto.conta("dardi_nemici" if tipo == "arciere" else "magie_lanciate")


func esito_sfera(tattica_sfera: String, colpito: bool) -> void:
	Memoria.esito_tattica(tipo, tattica_sfera, colpito)


func _vuoto_davanti() -> bool:
	var da := global_position + Vector2(verso * 12.0, -4.0)
	var domanda := PhysicsRayQueryParameters2D.create(da, da + Vector2(0.0, 26.0),
			Effetti.S_MONDO | Effetti.S_PIATTAFORME | Effetti.S_OGGETTI)
	return get_world_2d().direct_space_state.intersect_ray(domanda).is_empty()


func _cambia(nuovo: Stato) -> void:
	# Suoni che servono a giocare: il colpo in carica si sente prima di vederlo, il bestione ruggisce quando ti scopre.
	if nuovo == Stato.ATTACCO and stato != Stato.ATTACCO:
		var avviso := "avviso_attacco"
		match tipo:
			"pipistrello":
				avviso = "pipistrello"
			"saltatore":
				avviso = "balzo"
			"mimic":
				avviso = "mimic_morso"
		Suoni.suona(avviso, global_position, -4.0)
	elif nuovo == Stato.INSEGUE and tipo == "bestione" and not _ha_ruggito:
		_ha_ruggito = true
		Suoni.suona("ruggito", global_position)
	stato = nuovo
	_t_stato = 0.0


# ------------------------------------------------------------------ insieme e reazioni

func _chiama_compagni(g: Giocatore) -> void:
	# Ti ha visto: lo dice ai compagni vicini (anche a chi dorme).
	var chiamati := 0
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		var altro := n as Nemico
		if altro == null or altro == self or altro.stato == Stato.MORTO:
			continue
		if altro.global_position.distance_to(global_position) > RICHIAMO:
			continue
		if altro.stato in [Stato.DORME, Stato.PATTUGLIA, Stato.FERMO]:
			altro._sveglia_da_richiamo(g.global_position)
			chiamati += 1
	if chiamati > 0:
		Rapporto.conta("richiami")
	# Una nemesi con "rinforzi" non viene da sola.
	if capacita.has("rinforzi") and not _rinforzi_chiamati and not evocato:
		_rinforzi_chiamati = true
		var aiuto := Nemico.new()
		aiuto.tipo = "saltatore" if tipo != "saltatore" else "scheletro"
		aiuto.evocato = true
		aiuto.ondata = ondata
		aiuto.position = global_position + Vector2(-verso * 30.0, -4.0 if tipo != "pipistrello" else 30.0)
		aiuto.add_to_group("nemici")
		get_parent().add_child.call_deferred(aiuto)
		Rapporto.conta("rinforzi")


func _sveglia_da_richiamo(dove: Vector2) -> void:
	_ultimo_visto = dove
	_ha_ricordo = true
	_allertato = true
	if stato == Stato.DORME:
		if tipo == "pipistrello":
			return   # il pipistrello si sveglia da solo, vedendoti
		_risvegliati()
	elif stato != Stato.FERMO or tipo not in TIRATORI:
		_cambia(Stato.FERMO if tipo in TIRATORI else Stato.INSEGUE)


func _posto_per_attaccare() -> bool:
	# Non tutti insieme: all'inizio uno alla volta, poi due, poi tre, man mano che crescono.
	var massimo := 1 + (1 if _forza >= 2 else 0) + (1 if _forza >= 6 else 0)
	var occupati := 0
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		var altro := n as Nemico
		if altro != null and altro != self and altro.stato == Stato.ATTACCO and altro.tipo in CORPO_A_CORPO:
			occupati += 1
	return occupati < massimo


func _accerchia(g: Giocatore, dx: float) -> bool:
	# Vero se in questo fotogramma si sta spostando per prenderti dall'altra parte.
	if tipo not in CORPO_A_CORPO or tipo in SALTANO or _forza < 1:
		return false   # ad accerchiare si impara: dalla seconda ondata, o da veterani
	var mio_lato := -1 if dx > 0.0 else 1    # da che parte di te sono
	if _t_fianco <= 0.0:
		_t_fianco = 0.6
		var prima := _fianco
		_fianco = 0
		for n: Node in get_tree().get_nodes_in_group("nemici"):
			var altro := n as Nemico
			if altro == null or altro == self or altro.tipo not in CORPO_A_CORPO or altro.stato in [Stato.MORTO, Stato.DORME]:
				continue
			var sua := altro.global_position.x - g.global_position.x
			if signf(sua) == float(mio_lato) and absf(sua) < 70.0 and absf(sua) < absf(dx) \
					and absf(altro.global_position.y - global_position.y) < 40.0:
				_fianco = -mio_lato
				if prima == 0:
					Rapporto.conta("accerchiamenti")
				break
	if _fianco == 0 or mio_lato == _fianco:
		return false
	var meta := g.global_position.x + _fianco * 40.0
	var verso_prima := verso
	verso = 1 if meta > global_position.x else -1
	if _corpo_davanti():
		# Coi corpi solidi non si passa attraverso chi gioca o un compagno: niente giro, si combatte da qui.
		verso = verso_prima
		_fianco = 0
		return false
	_cammina(float(_dati["corsa"]) * 1.15)
	return true


func _reagisci_al_colpo(g: Giocatore, dx: float, dy: float) -> bool:
	# Legge il tuo attacco. Vero se in questo fotogramma sta reagendo (parata o passo indietro).
	if _t_parata > 0.0:
		velocity.x = 0.0
		return true
	if stato not in [Stato.INSEGUE, Stato.FERMO, Stato.PATTUGLIA] or not g.attacco_in_carica():
		return false
	if absf(dy) > 40.0 or absf(dx) > 72.0 or signf(dx) != float(verso) or _t_ricarica_parata > 0.0:
		return false
	_t_ricarica_parata = 0.9
	var famiglia := g.famiglia_arma()
	var lezione := Memoria.lezione_arma() if nemesi.is_empty() else ""
	# Contro un'arma lenta: un passo indietro mentre carichi, poi si risponde subito.
	if lezione == "punisce_lente" and Armi.LENTE.has(famiglia) and tipo in CORPO_A_CORPO and is_on_floor() \
			and _caso.randf() < 0.3 + 0.04 * _forza:
		velocity = Vector2(-verso * 170.0, -90.0)
		_t_balzo = 0.25
		_t_ricarica = 0.0
		_schivate += 1
		Rapporto.conta("letture_arma")
		return true
	# Parata: lo scheletro per natura, gli altri se l'hanno imparata.
	if tipo == "scheletro" or (capacita.has("parata") and tipo in CORPO_A_CORPO):
		var p := 0.06 + 0.03 * _forza + (0.25 if capacita.has("parata") else 0.0)
		if lezione == "para_rapide" and Armi.RAPIDE.has(famiglia):
			p += 0.25
		if _caso.randf() < p:
			_t_parata = PARATA_NEMICO
			velocity.x = 0.0
			sprite.riproduci("parata" if sprite.ha("parata") else "fermo", true)
			Rapporto.conta("parate_nemici")
			return true
	return false


func _parato(da: Vector2) -> void:
	Effetti.scoppio(get_parent(), global_position + Vector2(verso * 14.0, -30.0), Color(1.0, 0.9, 0.6), 8, 90.0, 0.2, 100.0)
	_schivate += 1
	_t_ricarica = 0.0   # risponde subito
	var g := get_tree().get_first_node_in_group("giocatore") as Giocatore
	if g != null and g.global_position.distance_to(da) < 80.0:
		g.velocity.x = signf(g.global_position.x - global_position.x) * 140.0   # respinto


func _controlla_furia() -> void:
	if _furioso or not capacita.has("furia") or vita > maxi(1, int(int(_dati["vita"]) * 0.4)):
		return
	_furioso = true
	_dati["corsa"] = float(_dati["corsa"]) * 1.3
	sprite.modulate = sprite.modulate * Color(1.15, 0.75, 0.7)
	Rapporto.conta("furie")


# ------------------------------------------------------------------ danni

func esposto() -> bool:
	# Il bestione si può ferire solo quando è scoperto: dopo un suo colpo, dopo una carica, mentre incassa.
	if tipo != "bestione":
		return true
	if stato == Stato.COLPITO or _t_pausa > 0.0:
		return true
	return stato == Stato.ATTACCO and _t_stato >= float(TEMPI_BESTIONE[2])


func subisci(danno: int, da: Vector2, spinta: float, tipo_colpo: String = "", dettagli: Dictionary = {}) -> bool:
	if stato == Stato.MORTO or stato == Stato.RISVEGLIO:
		return false
	var davanti := signf(da.x - global_position.x) == float(verso)
	var famiglia: String = dettagli.get("famiglia", "")
	if famiglia != "":
		_ultima_famiglia = famiglia
	_ultima_arma = String(dettagli.get("munizione", tipo_colpo))
	# Parata: da davanti la spada e i tiri non passano, a meno che l'arma non rompa la guardia.
	if _t_parata > 0.0 and davanti and tipo_colpo in ["mischia", "tiro"]:
		if dettagli.get("rompe", false):
			Rapporto.conta("guardie_rotte")
			Effetti.scoppio(get_parent(), global_position + Vector2(verso * 12.0, -30.0), Color(1.0, 0.7, 0.4), 12, 120.0, 0.25, 100.0)
			_t_parata = 0.0
			barcolla(0.8)
			return true
		_parato(da)
		return false
	# La nemesi che hai battuto con quest'arma ha imparato a difendersene.
	if famiglia != "" and famiglia == String(nemesi.get("arma_nemica", "")) and davanti and _caso.randf() < 0.4:
		Rapporto.conta("resistenze_nemesi")
		_parato(da)
		return false
	if stato == Stato.DORME:
		if tipo == "pipistrello":
			vita = 0
			_muori(1.0)   # appeso e addormentato: un colpo basta
			return true
		_risvegliati()  # un colpo lo sveglia soltanto
		return false
	# Il bestione para da davanti, se non è scoperto (la magia e le trappole passano la corazza).
	if tipo == "bestione" and tipo_colpo not in ["magia", "trappola"] and not esposto() and davanti \
			and not dettagli.get("rompe", false):
		sprite.riproduci("parata", true)
		Effetti.scoppio(get_parent(), global_position + Vector2(verso * 14.0, -34.0), Color(1.0, 0.9, 0.6), 8, 90.0, 0.2, 100.0)
		Rapporto.conta("parate_bestione")
		return false
	vita -= danno
	Effetti.lampo(sprite)
	Effetti.numero_danno(get_parent(), centro() + Vector2(0, -14), danno)
	var lato := signf(global_position.x - da.x)
	if lato == 0.0:
		lato = 1.0
	if vita <= 0:
		_muori(lato)
		return true
	_carica = false
	_in_balzo = false
	_combo_rimasti = 0
	_t_parata = 0.0
	_cambia(Stato.COLPITO)
	if float(dettagli.get("stordisce", 0.0)) > 0.0:
		barcolla(float(dettagli["stordisce"]))
		return true
	if tipo == "bestione":
		velocity = Vector2(lato * spinta * 0.15, 0.0)   # pesante: quasi non si sposta
	elif tipo == "pipistrello":
		velocity = Vector2(lato * spinta * 0.6, -60.0)
	else:
		velocity = Vector2(lato * spinta * 0.7, -90.0)
	sprite.riproduci("colpito", true)
	return true


func _muori(lato: float) -> void:
	Suoni.suona("morte_nemico", global_position, 0.0, 0.7 if tipo == "bestione" else (1.5 if tipo == "pipistrello" else 1.0))
	_cambia(Stato.MORTO)
	velocity = Vector2(lato * 60.0, -80.0)
	collision_layer = 0
	if tipo == "pipistrello":
		motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
		collision_mask = Effetti.S_MONDO | Effetti.S_PIATTAFORME
	_bersaglio.set_deferred("monitorable", false)
	_ombra.visible = false
	z_index = 3
	sprite.riproduci("morte", true)
	Rapporto.conta("nemici_uccisi")
	Rapporto.conta("uccisi_" + tipo)
	Rapporto.evento("nemico_ucciso", {"tipo": tipo, "x": roundi(global_position.x), "y": roundi(global_position.y),
			"nemesi": Memoria.nome_completo(nemesi) if not nemesi.is_empty() else ""})
	Effetti.scoppio(get_parent(), global_position + Vector2(0, -22), Color(0.82, 0.8, 0.7, 0.8), 12, 80.0, 0.5, 220.0, false)
	if not evocato:
		var xp := 1.0 + _danno_inflitto * 2.0 + minf(4.0, _t_vivo / 20.0) + _schivate * 0.5 + (ondata - 1) * 0.5
		Memoria.veterano_morto(id_posto, xp, ondata)
	var frase := Memoria.nemico_sconfitto(self, _ultima_famiglia)
	if frase != "":
		get_tree().call_group("hud", "messaggio", frase, 3.0, true)
	_lascia_bottino()


func _lascia_bottino() -> void:
	# I deboli niente; i forti secondo l'arma del colpo finale (dardi, frecce, mana) e a volte pozioni.
	if evocato:
		return   # i rinforzi di una nemesi non portano niente
	bottino_lasciato = Bottino.per_nemico(tipo, _forza, not nemesi.is_empty(), _ultima_arma, _caso)
	if bottino_lasciato.is_empty():
		return
	Bottino.lascia(get_parent(), global_position + Vector2(0, -16), bottino_lasciato, false, _caso)
	Rapporto.evento("bottino", {"tipo": tipo, "arma": _ultima_arma,
			"cosa": bottino_lasciato.map(func(v: Dictionary) -> String: return Bottino.descrizione(v))})
	if tipo == "mimic":
		Rapporto.conta("mimic_battuti")


func _su_impostazione(chiave: String) -> void:
	if chiave == "acc/contorni" and is_instance_valid(sprite):
		_applica_contorno()


func _applica_contorno() -> void:
	# Accessibilità "contorni chiari": i nemici hanno un contorno rosso chiaro, ben distinto dal fondo.
	sprite.material = Effetti.materiale_contorno(Color(1.0, 0.42, 0.36)) if Impostazioni.leggi("acc/contorni") else null
