class_name Giocatore
extends CharacterBody2D
# Il Non Narrato: corre, salta, attacca (due colpi in fila), rotola e scatta in avanti o
# all'indietro, scavalca ostacoli bassi e si aggrappa ai bordi, afferra le casse per tirarle,
# usa leve e apre forzieri (tasto "afferra" accanto all'oggetto), colpisce da lontano con magia,
# dardi e frecce (tasto "tira"; con su si mira in alto; "cambia_arma" sceglie quale).
# Si arrampica sulle pareti ruvide (stamina: scalare e restare aggrappati la consumano, a terra si
# recupera) e nuota (sott'acqua il respiro cala; finito il respiro si perde vita).
# I tempi sono nel codice e non dipendono dalle animazioni, così il comportamento
# è lo stesso su ogni dispositivo.

signal vita_cambiata(vita: int, massima: int)
signal armi_cambiate
signal morto
signal effetti_cambiati

enum Stato { NORMALE, ATTACCO, ROTOLATA, SCHIVATA, COLPITO, MORTO, SCAVALCO, PRESA, USA, TIRO, PARATA, ARRAMPICATA, NUOTO }

const VELOCITA := 150.0
const ACCELERAZIONE := 1500.0
const ATTRITO := 1900.0
const ACCELERAZIONE_ARIA := 1000.0
const SALTO := 390.0
const GRAVITA_SU := 1000.0
const GRAVITA_GIU := 1500.0
const CADUTA_MASSIMA := 540.0
const TAGLIO_SALTO := 0.45          # salto più basso se si lascia subito il tasto
const TEMPO_COYOTE := 0.10          # si può ancora saltare un attimo dopo il bordo
const TEMPO_MEMORIA := 0.12         # il salto premuto un attimo prima di toccare terra vale
const APICE_VELOCITA := 50.0        # sotto questa velocità verticale si è "in cima" al salto...
const APICE_GRAVITA := 0.55         # ...e la gravità pesa meno (tenendo premuto il salto)
const SPIGOLO := 6.0                # testa contro uno spigolo: ci si sposta fino a tanto e si continua a salire
const ROTOLATA_DURATA := 0.40
const ROTOLATA_VELOCITA := 250.0
const ROTOLATA_PAUSA := 0.25
const SCHIVATA_DURATA := 0.20
const SCHIVATA_VELOCITA := 290.0
const SCATTO_VELOCITA := 320.0
const SCHIVATA_PAUSA := 0.35
# I colpi da mischia (quanti, danno, portata, tempi) dipendono dall'arma: vedi Armi.
const VITA_MASSIMA := 8             # nemici più duri (0.1.15): più margine per imparare
const PROTEZIONE_DOPO_COLPO := 0.9
const SPINTA_CASSE := 70.0
const TEMPO_GIRO := 0.2             # direzione indietro + rotola/schiva entro questo tempo = mossa all'indietro
const GIRO_VISIVO := 0.12           # girandosi il corpo passa di fronte a chi guarda invece di ribaltarsi di colpo
const SCAVALCO_DURATA := 0.32
const ISSATA_DURATA := 0.46         # issata dal bordo (0.1.33): aggancio, trazione, sul bordo
const ISSATA_DA := 30.0             # bordi più alti di così sopra i piedi: ci si appende e ci si issa
const APPESO_SOTTO := 48.0          # appesi al bordo i piedi stanno tanto più in basso (mani sul bordo)
const SCAVALCO_DA_TERRA := 40.0     # ostacoli fino a questa altezza si scavalcano da terra (su + direzione)
const APPIGLIO_IN_ARIA := 62.0      # in aria ci si aggrappa a bordi fino a questa altezza sopra i piedi
const PRESA_VELOCITA := 70.0
const PRESA_DISTANZA := 30.0        # centro cassa - centro giocatore per poterla afferrare
const USO_DISTANZA := 26.0          # leve e forzieri si usano da qui
const USO_DURATA := 0.38
# Armi a distanza: animazione, durata, quando parte il colpo, velocità, danno, e l'attacco proprio:
#  - magia: tenendo premuto si carica una sfera grande che esplode e colpisce tutti attorno;
#  - dardi: tenendo premuto parte una raffica (un dardo dopo l'altro, fino a quattro);
#  - frecce: l'arco va caricato: più lo tieni, più la freccia è veloce e forte; a carica piena trapassa.
const ARMI_DISTANZA := {
	"magia": {"nome": "Magia", "anim": "tiro_magia", "durata": 0.42, "momento": 0.2, "velocita": 230.0, "danno": 2,
			"carica": 0.7, "danno_carica": 3, "raggio": 46.0},
	"dardi": {"nome": "Dardi", "anim": "tiro_dardo", "durata": 0.3, "momento": 0.12, "velocita": 380.0, "danno": 1,
			"raffica": 4, "intervallo": 0.13},
	"frecce": {"nome": "Frecce", "anim": "tiro_freccia", "durata": 0.5, "momento": 0.3, "velocita": 220.0, "danno": 1,
			"carica": 0.9, "velocita_carica": 430.0, "danno_carica": 3},
}
const ORDINE_ARMI: Array[String] = ["magia", "dardi", "frecce"]
const MIRA_CONO := 0.55            # aiuto alla mira: angolo (in radianti) entro cui il tiro si raddrizza
const MIRA_PORTATA := 260.0
const ENERGIA_MASSIMA := 100.0
const COSTO_MAGIA := 34.0
const COSTO_MAGIA_CARICA := 60.0
const RICARICA_ENERGIA := 14.0        # al secondo
const MUNIZIONI_MASSIME := {"dardi": 12, "frecce": 10}
const MUNIZIONI_INIZIALI := {"dardi": 8, "frecce": 5}
# Cosa tiene in mano mentre tira (pezzi del manichino).
const IN_MANO := {"magia": [], "dardi": ["Viandante__Knife"], "frecce": ["Viandante__1H_Crossbow"]}

# Arrampicata (pareti ruvide, vedi Stanza.SCALABILI) e stamina.
const STAMINA_MASSIMA := 100.0
const STAMINA_SCALA := 20.0         # al secondo salendo o scendendo
const STAMINA_APPESO := 8.0         # al secondo restando fermi aggrappati
const STAMINA_SALTO_MURO := 18.0
const STAMINA_RECUPERO := 45.0      # al secondo, con i piedi a terra
const STAMINA_ATTESA := 0.35        # a terra da almeno tanto prima di recuperare
const STAMINA_RIPRESA := 25.0       # senza fiato non ci si riaggrappa finché non torna a questo livello
const ARRAMPICATA_VELOCITA := 74.0
const CICLO_SCALATA := 0.7          # un ciclo di arrampicata (due prese) a leva piena: ~26 px di salita per presa
const SPINTA_SCALATA := 0.85        # il corpo sale a strattoni: veloce mentre la mano tira, lento mentre l'altra va su
const SPAZIO := 14.0                   # mezza larghezza "visiva" (mantello compreso): più del corpo fisico, perché gli sprite non si coprano
const SCOSTA_DAL_MURO := 5.0           # sulla parete lo sprite si stacca un po': mani e piedi toccano la roccia, non ci entrano
const SALTO_MURO := Vector2(165.0, 330.0)
# Nuoto (Stanza.ACQUE) e respiro.
const RESPIRO_MASSIMO := 100.0
const RESPIRO_CONSUMO := 9.0        # al secondo con la testa sott'acqua: circa 11 secondi
const RESPIRO_RECUPERO := 60.0
# Pozioni (0.1.19): l'effetto dura qualche secondo e si somma (più se ne prendono insieme, più è forte e lungo).
const POZIONE_TAGLIE := {"piccola": [1.0, 4.0], "media": [2.0, 6.0], "grande": [3.0, 9.0]}   # forza, secondi
const EFFETTO_FORZA_MAX := 6.0
const EFFETTO_TEMPO_MAX := 24.0
const CURA_PER_FORZA := 0.4             # vita al secondo per ogni punto di forza
const STAMINA_PER_FORZA := 30.0
const MANA_PER_FORZA := 22.0
const VELOCITA_PER_FORZA := 0.1         # +10% per punto di forza...
const VELOCITA_POZIONE_MASSIMA := 0.5   # ...fino a +50%
const ANNEGA_OGNI := 1.4            # senza respiro: un cuore ogni tanti secondi
const NUOTO_VELOCITA := 96.0
const NUOTO_SPINTA := 420.0
const NUOTO_SALTO := 330.0          # salto fuori dall'acqua dalla superficie

const ALTO := Vector2(14, 44)
const BASSO := Vector2(14, 20)

var stato := Stato.NORMALE
var verso := 1
var vita := VITA_MASSIMA
var arma_distanza := "magia"
var energia := ENERGIA_MASSIMA
var munizioni := MUNIZIONI_INIZIALI.duplicate()

var sprite: SpriteAnimato
var ombra: Ombra                 # ombra corta sul pavimento (macchia e sagome)
var camera: Camera2D

var _t_stato := 0.0
var _t_coyote := 0.0
var _t_memoria_salto := 0.0
var _t_pausa_rotolata := 0.0
var _t_pausa_schivata := 0.0
var _t_protetto := 0.0
var _t_attraversa := 0.0
var _t_atterra := 0.0
var _spinta := 0.0                # quanto è inclinata la leva (0-1): poco = si cammina
var _t_giro_visivo := 0.0         # mezzo giro in corso (vedi GIRO_VISIVO)
var _vx_prima := 0.0              # velocità orizzontale del fotogramma prima (per l'inclinazione)
var _colpo_numero := 0
var _arma := {}                     # Armi.attuali() all'inizio della combinazione
var _colpo_ora := {}                # il colpo in corso
var _colpo_prenotato := false
var _gia_colpiti: Array = []
var _scatto_usato := false
var _schivata_in_aria := false
var _velocita_caduta := 0.0
var _scossa := 0.0                 # "trauma" della telecamera (0..1): ogni colpo ne aggiunge, cala da solo
var _t_scossa := 0.0
var _rumore_scossa: FastNoiseLite
const SCOSSA_MASSIMA := 14.0       # pixel della tela a trauma pieno
const SCOSSA_CALO := 1.8           # trauma perso al secondo
const SCOSSA_RITMO := 22.0         # quante "onde" al secondo (rumore morbido, non tremolio a caso)
var _morte_segnalata := false
var _verso_prima := 1
var _t_girato := 0.0
var _dir_rotolata := 1
var _dir_schivata := 1
var _schivata_avanti := false
var _scavalco_da := Vector2.ZERO
var _scavalco_a := Vector2.ZERO
var _issata := false              # lo scavalco in corso è un'issata dal bordo
var _fase_scalata := 0.0          # 0-1: dove si è nel ciclo dell'arrampicata (0 e 0,5 = una mano arriva in alto)
var _maschera := 0
var _cassa: RigidBody2D
var _scarto_cassa := 0.0
var _tirata_contata := false
var _colpito_da: Node
var _tiro_partito := false
var _mira_in_alto := false
var _carica := 0.0
var _carica_piena := false
var _raffica := 0
var _t_raffica := 0.0
var _tiro_alternato := false        # accessibilità "premi una volta": il tiro si carica senza tenere premuto
var _resto_danni := 0.0             # accessibilità "danni ricevuti": le frazioni di danno si sommano
var _t_passo := 0.0
var stamina := STAMINA_MASSIMA
var respiro := RESPIRO_MASSIMO
var effetti := {}                       # pozioni attive: tipo -> {"forza", "tempo", "durata"}
var _cura_accumulata := 0.0
var _t_scia := 0.0
var sott_acqua := false             # la testa è sotto la superficie
const Z_NORMALE := 10
const Z_SOTT_ACQUA := 16                # sopra il velo dell'acqua (Acqua: z 15)
const TINTA_SOTT_ACQUA := Color(0.95, 1.15, 1.35)   # oltre 1 schiarisce: la figura è scura
var in_acqua := false
var _esausto := false
var _t_a_terra := 0.0
var _t_annega := 0.0
var _t_stacco := 0.0                # dopo un salto dal muro non ci si riaggrappa subito
var _t_bolle := 0.0
var _lato_muro := 1                 # da che parte è la parete a cui si è aggrappati
var _zona_muro := Rect2()
var _superficie := 0.0

var _forma: CollisionShape2D
var _rett: RectangleShape2D
var _colpo: Area2D
var _forma_colpo: CollisionShape2D
var _bersaglio: Area2D


func _ready() -> void:
	collision_layer = Effetti.S_GIOCATORE
	collision_mask = Effetti.S_MONDO | Effetti.S_PIATTAFORME | Effetti.S_OGGETTI
	floor_snap_length = 4.0
	z_index = Z_NORMALE

	_rett = RectangleShape2D.new()
	_forma = CollisionShape2D.new()
	_forma.shape = _rett
	add_child(_forma)
	_imposta_forma(ALTO)

	sprite = FiguraViva.new()  # aspetto dato dall'equipaggiamento, fotografato dal manichino 3D
	sprite.carica("protagonista")
	sprite.light_mask = Effetti.L_DAVANTI
	add_child(sprite)
	sprite.riproduci("fermo")

	# Zona colpita dalla spada.
	_colpo = Area2D.new()
	_colpo.collision_layer = Effetti.S_COLPI_GIOCATORE
	_colpo.collision_mask = Effetti.S_BERSAGLI
	_colpo.monitorable = false
	var rett_colpo := RectangleShape2D.new()
	rett_colpo.size = Vector2(40, 48)
	_forma_colpo = CollisionShape2D.new()
	_forma_colpo.shape = rett_colpo
	_forma_colpo.position = Vector2(24, -24)
	_colpo.add_child(_forma_colpo)
	add_child(_colpo)

	# Zona in cui il giocatore può essere colpito.
	_bersaglio = Area2D.new()
	_bersaglio.collision_layer = Effetti.S_BERSAGLIO_GIOCATORE
	_bersaglio.collision_mask = 0
	_bersaglio.monitoring = false
	_bersaglio.set_meta("bersaglio", self)
	var rett_bersaglio := RectangleShape2D.new()
	rett_bersaglio.size = Vector2(12, 38)
	var forma_bersaglio := CollisionShape2D.new()
	forma_bersaglio.shape = rett_bersaglio
	forma_bersaglio.position = Vector2(0, -21)
	_bersaglio.add_child(forma_bersaglio)
	add_child(_bersaglio)

	camera = Camera2D.new()
	camera.position = Vector2(0, -40)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)
	camera.make_current()

	# Un tenue alone freddo: il Non Narrato si vede sempre, anche nel buio.
	var aura := Effetti.luce(Color(0.6, 0.68, 1.0), 110.0, 1.0, 60.0)
	aura.position = Vector2(0, -26)
	add_child(aura)

	Effetti.occlusore(self, Rect2(-5, -40, 10, 38), false)   # niente ombra: vedi Effetti.occlusore
	ombra = Ombra.aggiungi(self, sprite, 24.0)   # ombra corta e sfumata sul pavimento


func limiti(riquadro: Rect2i, di_colpo: bool = true) -> void:
	# di_colpo = false: la telecamera scivola ai nuovi limiti (passando fra stanza e sotterraneo).
	camera.limit_left = riquadro.position.x
	camera.limit_top = riquadro.position.y
	camera.limit_right = riquadro.end.x
	camera.limit_bottom = riquadro.end.y
	if di_colpo:
		camera.reset_smoothing()


func _process(delta: float) -> void:
	# Scossa alla Eiserloh (GDC 2016): spostamento = trauma² × rumore morbido. Più colpi vicini si sommano,
	# un colpo solo resta leggero; il rumore continuo evita il tremolio a scatti del caso puro.
	if _scossa > 0.0:
		_scossa = maxf(0.0, _scossa - SCOSSA_CALO * delta)
		_t_scossa += delta * SCOSSA_RITMO
		if _rumore_scossa == null:
			_rumore_scossa = FastNoiseLite.new()
			_rumore_scossa.noise_type = FastNoiseLite.TYPE_PERLIN
			_rumore_scossa.frequency = 1.0
		var forza := _scossa * _scossa * SCOSSA_MASSIMA * 1.4
		camera.offset = Vector2(_rumore_scossa.get_noise_2d(_t_scossa, 0.0), _rumore_scossa.get_noise_2d(0.0, _t_scossa + 50.0)) * forza
	else:
		camera.offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_scorri_tempi(delta)
	var a_terra := is_on_floor()
	if a_terra:
		_t_coyote = TEMPO_COYOTE
		_scatto_usato = false
	if Input.is_action_just_pressed("salta"):
		_t_memoria_salto = TEMPO_MEMORIA

	_controlla_acqua()
	match stato:
		Stato.NORMALE:
			_normale(delta, a_terra)
		Stato.ATTACCO:
			_attacco(delta, a_terra)
		Stato.ROTOLATA:
			_rotolata(delta)
		Stato.SCHIVATA:
			_schivata(delta)
		Stato.COLPITO:
			_colpito(delta)
		Stato.MORTO:
			_da_morto(delta)
		Stato.SCAVALCO:
			_scavalco(delta)
		Stato.PRESA:
			_presa(delta)
		Stato.USA:
			_uso(delta)
		Stato.TIRO:
			_tiro(delta, a_terra)
		Stato.PARATA:
			_parata(delta)
		Stato.ARRAMPICATA:
			_arrampicata(delta)
		Stato.NUOTO:
			_nuoto(delta)

	_velocita_caduta = velocity.y
	move_and_slide()
	if stato == Stato.NORMALE and is_on_ceiling() and _velocita_caduta < -60.0:
		_scansa_spigolo(_velocita_caduta)
	_spingi_oggetti(delta)
	_separa_dai_nemici()
	if is_on_floor() and not a_terra:
		_atterrato()
	_aggiorna_aspetto()


func _scorri_tempi(delta: float) -> void:
	if energia < ENERGIA_MASSIMA:
		var prima := colpi_rimasti("magia")
		energia = minf(ENERGIA_MASSIMA, energia + RICARICA_ENERGIA * _dote_magia("magia_ricarica") * delta)
		if colpi_rimasti("magia") != prima:
			armi_cambiate.emit()
	if Input.is_action_just_pressed("cambia_arma") and stato != Stato.MORTO:
		cambia_arma()
	_t_coyote = maxf(0.0, _t_coyote - delta)
	_t_memoria_salto = maxf(0.0, _t_memoria_salto - delta)
	_t_pausa_rotolata = maxf(0.0, _t_pausa_rotolata - delta)
	_t_pausa_schivata = maxf(0.0, _t_pausa_schivata - delta)
	_t_protetto = maxf(0.0, _t_protetto - delta)
	_t_atterra = maxf(0.0, _t_atterra - delta)
	_t_passo -= delta
	if _t_passo <= 0.0 and stato == Stato.NORMALE and is_on_floor() and absf(velocity.x) > 40.0:
		_t_passo = clampf(0.3 * VELOCITA / absf(velocity.x), 0.25, 0.55)   # passi lenti quando si cammina
		Suoni.suona("passo", global_position, -8.0)
	_t_girato = maxf(0.0, _t_girato - delta)
	_t_giro_visivo = maxf(0.0, _t_giro_visivo - delta)
	_t_stacco = maxf(0.0, _t_stacco - delta)
	_aggiorna_fiato(delta)
	_aggiorna_effetti(delta)
	if stato != Stato.ARRAMPICATA and sprite.position.x != 0.0:
		sprite.position.x = 0.0   # lasciata la parete in qualunque modo (in cima, colpiti, in acqua)
	if _t_attraversa > 0.0:
		_t_attraversa -= delta
		if _t_attraversa <= 0.0:
			set_collision_mask_value(2, true)


# ------------------------------------------------------------------ stati

func _normale(delta: float, a_terra: bool) -> void:
	var direzione := Input.get_axis("sinistra", "destra")
	_spinta = absf(direzione)
	if absf(direzione) > 0.01:
		var nuovo := 1 if direzione > 0.0 else -1
		if nuovo != verso:
			_verso_prima = verso
			_t_girato = TEMPO_GIRO
			_t_giro_visivo = GIRO_VISIVO
			verso = nuovo
	_muovi(delta, a_terra, direzione)
	_gravita(delta)

	# Pareti ruvide: in aria verso la parete, oppure su accanto alla parete, ci si aggrappa.
	if _puo_aggrapparsi(direzione, a_terra):
		_inizia_arrampicata()
		return
	# Scavalcare: da terra con su + direzione contro un ostacolo basso; in aria ci si aggrappa da soli al bordo.
	if absf(direzione) > 0.01:
		var arrivo: Variant = null
		if a_terra and Input.is_action_pressed("su"):
			arrivo = _appiglio(SCAVALCO_DA_TERRA, 6.0)  # il raggio guarda solo subito davanti
		elif not a_terra and velocity.y > -60.0:
			arrivo = _appiglio(APPIGLIO_IN_ARIA, 8.0)
		if arrivo != null:
			# Da terra si scavalca sempre; in aria un bordo alto si prende con le mani e ci si issa.
			_inizia_scavalco(arrivo, not a_terra and global_position.y - (arrivo as Vector2).y > ISSATA_DA)
			return
	# Leve e forzieri: basta premere "afferra" accanto.
	if a_terra and Input.is_action_just_pressed("afferra"):
		var oggetto := interagibile_vicino()
		if oggetto != null:
			_inizia_uso(oggetto)
			return
	# Afferrare una cassa vicina: tenendo premuto si spinge o si tira.
	if a_terra and Input.is_action_pressed("afferra"):
		var cassa := vicino_cassa()
		if cassa != null:
			_inizia_presa(cassa)
			return

	if _t_memoria_salto > 0.0 and _t_coyote > 0.0:
		if a_terra and Input.is_action_pressed("giu") and _su_piattaforma():
			# Giù + salto: si scende attraverso la piattaforma.
			_t_attraversa = 0.25
			set_collision_mask_value(2, false)
			position.y += 2.0
		else:
			velocity.y = -SALTO
			_conta("salti")
			_polvere(5)
			# Slancio: un attimo allungato verso l'alto (lo schiacciamento lo fa l'atterraggio).
			sprite.scale = Vector2(0.9, 1.12)
			sprite.create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			Suoni.suona("salto", global_position, -4.0)
		_t_memoria_salto = 0.0
		_t_coyote = 0.0
	if Input.is_action_just_released("salta") and velocity.y < 0.0:
		velocity.y *= TAGLIO_SALTO

	if Input.is_action_just_pressed("rotola") and a_terra and _t_pausa_rotolata <= 0.0:
		_inizia_rotolata(direzione)
	elif Input.is_action_just_pressed("schiva") and a_terra and absf(direzione) < 0.01 and _ha_scudo() \
			and _t_pausa_schivata <= 0.0:
		_inizia_parata()
	elif Input.is_action_just_pressed("schiva") and _t_pausa_schivata <= 0.0 and (a_terra or not _scatto_usato):
		_inizia_schivata(a_terra, direzione)
	elif Input.is_action_just_pressed("attacca"):
		_arma = Armi.attuali()
		_inizia_attacco(1, a_terra)
	elif Input.is_action_just_pressed("tira"):
		_inizia_tiro()


func _inizia_attacco(numero: int, a_terra: bool) -> void:
	if _arma.is_empty():
		_arma = Armi.attuali()
	var lista: Array = _arma["colpi"]
	_colpo_ora = lista[clampi(numero - 1, 0, lista.size() - 1)]
	stato = Stato.ATTACCO
	_t_stato = 0.0
	_colpo_numero = numero
	_colpo_prenotato = false
	_gia_colpiti.clear()
	var portata := float(_colpo_ora["p"])
	(_forma_colpo.shape as RectangleShape2D).size = Vector2(portata, float(_colpo_ora["h"]))
	_forma_colpo.position = Vector2((portata * 0.5 + 4.0) * verso, -float(_colpo_ora["h"]) * 0.5)
	# Le animazioni sono due (attacco1, attacco2): si alternano e si adattano ai tempi dell'arma.
	var anim := "attacco1" if numero % 2 == 1 else "attacco2"
	var lunga := sprite.durata(anim)
	sprite.riproduci(anim, true, lunga / float(_colpo_ora["t"]) if lunga > 0.0 else 1.0)
	if a_terra:
		velocity.x = verso * float(_colpo_ora["passo"])
	_conta("attacchi")
	Memoria.registra_arma(String(_arma["famiglia"]))


func colpo_attuale() -> Dictionary:
	# Per i nemici e il bot: il colpo in corso (vuoto se non sta attaccando).
	return _colpo_ora if stato == Stato.ATTACCO else {}


func attacco_in_carica() -> bool:
	# Sta caricando un colpo che non fa ancora male.
	return stato == Stato.ATTACCO and _t_stato < float(_colpo_ora.get("da", 0.1))


func attacco_scoperto() -> bool:
	# Il colpo è finito ma non si è ancora ripreso: un buon momento per colpirlo.
	return stato == Stato.ATTACCO and _t_stato > float(_colpo_ora.get("a", 0.24))


func famiglia_arma() -> String:
	return Armi.famiglia(Equipaggiamento.indossati.get("arma", "spada_viandante"))


func _attacco(delta: float, a_terra: bool) -> void:
	var prima := _t_stato
	_t_stato += delta
	var direzione := Input.get_axis("sinistra", "destra")
	if a_terra:
		velocity.x = move_toward(velocity.x, 0.0, ATTRITO * 0.5 * delta)
	else:
		_muovi(delta, false, direzione)
	_gravita(delta)

	var da := float(_colpo_ora["da"])
	var a := float(_colpo_ora["a"])
	if prima < da and _t_stato >= da:
		_fendente()
	if _t_stato >= da and _t_stato <= a:
		_colpisci()
	if Input.is_action_just_pressed("attacca") and _t_stato >= minf(0.06, da):
		_colpo_prenotato = true

	if _t_stato > a:
		if Input.is_action_just_pressed("rotola") and a_terra and _t_pausa_rotolata <= 0.0:
			_inizia_rotolata(direzione)
			return
		if Input.is_action_just_pressed("schiva") and a_terra and absf(direzione) < 0.01 and _ha_scudo() \
				and _t_pausa_schivata <= 0.0:
			_inizia_parata()
			return
		if Input.is_action_just_pressed("schiva") and _t_pausa_schivata <= 0.0 and (a_terra or not _scatto_usato):
			_inizia_schivata(a_terra, direzione)
			return
		if _colpo_prenotato and _colpo_numero < (_arma["colpi"] as Array).size():
			if absf(direzione) > 0.01:
				verso = 1 if direzione > 0.0 else -1
			_inizia_attacco(_colpo_numero + 1, a_terra)
			return
	if _t_stato >= float(_colpo_ora["t"]):
		stato = Stato.NORMALE


func _colpisci() -> void:
	for area in _colpo.get_overlapping_areas():
		var chi: Variant = area.get_meta("bersaglio", null)
		if chi == null or not is_instance_valid(chi) or _gia_colpiti.has(chi):
			continue
		_gia_colpiti.append(chi)
		if not chi.has_method("subisci"):
			continue
		var danno := int(_colpo_ora["d"])
		var riuscito := false
		if chi is Nemico:
			var nemico := chi as Nemico
			# Pugnale: alle spalle (il nemico guarda dall'altra parte) fa di più.
			var spalle := nemico.verso == int(signf(nemico.global_position.x - global_position.x))
			if spalle and _arma.has("alle_spalle"):
				danno *= int(_arma["alle_spalle"])
				Rapporto.conta("colpi_alle_spalle")
			riuscito = nemico.subisci(danno, global_position, float(_colpo_ora["spinta"]), "mischia", {
				"famiglia": _arma.get("famiglia", "spada"), "rompe": _colpo_ora.get("rompe", false),
				"stordisce": float(_colpo_ora.get("stordisce", 0.0))})
		else:
			riuscito = chi.subisci(danno, global_position, float(_colpo_ora["spinta"]))
		if riuscito:
			var punto: Vector2 = (area as Area2D).global_position.lerp(global_position + Vector2(verso * 24.0, -24.0), 0.5)
			Effetti.scoppio(get_parent(), punto, Color(1.0, 0.9, 0.7), 8, 110.0, 0.22, 200.0)
			scuoti(2.0 + danno * 0.8)
			Controlli.vibra(0.3 + 0.1 * danno, 0.08)
			Suoni.suona("colpo", punto, 0.0, 1.1 - 0.06 * danno)
			Effetti.fermo_immagine(self, 0.04 + 0.015 * danno)


# ------------------------------------------------------------------ parata (con lo scudo)

func _ha_scudo() -> bool:
	return Armi.dote_mano(Equipaggiamento.indossati.get("mano_sinistra", "")) == "scudo"


func _inizia_parata() -> void:
	stato = Stato.PARATA
	_t_stato = 0.0
	velocity.x = 0.0
	_t_pausa_schivata = Armi.PARATA_DURATA + Armi.PARATA_PAUSA
	sprite.riproduci("fermo", true)   # col gruppo "scudo" la posa di riposo è lo scudo alzato
	_conta("parate_tentate")
	Suoni.suona("schiva", global_position, -10.0, 0.7)


func _parata(delta: float) -> void:
	_t_stato += delta
	velocity.x = move_toward(velocity.x, 0.0, ATTRITO * delta)
	_gravita(delta)
	if _t_stato >= Armi.PARATA_DURATA:
		stato = Stato.NORMALE


func sta_parando(da: Vector2) -> bool:
	# Para i colpi che arrivano da davanti, nei primi istanti della parata.
	return stato == Stato.PARATA and _t_stato <= Armi.PARATA_FINESTRA and int(signf(da.x - global_position.x)) == verso


func _conta(azione: String) -> void:
	# Nel rapporto e nella memoria del sogno: i nemici studiano le tue abitudini.
	Rapporto.conta(azione)
	Memoria.registra(azione)


func _all_indietro(direzione: float) -> bool:
	# Direzione opposta allo sguardo (o appena girati): la mossa va all'indietro e lo sguardo resta.
	if absf(direzione) <= 0.01:
		return false
	var dir := 1 if direzione > 0.0 else -1
	if stato == Stato.NORMALE and _t_girato > 0.0 and dir != _verso_prima:
		verso = _verso_prima
		return true
	if dir != verso:
		if stato == Stato.NORMALE:
			verso = dir
			return false
		return true
	return false


func _inizia_rotolata(direzione: float) -> void:
	var indietro := _all_indietro(direzione)
	_dir_rotolata = -verso if indietro else verso
	stato = Stato.ROTOLATA
	_t_stato = 0.0
	_imposta_forma(BASSO)
	Suoni.suona("rotola", global_position, -4.0)
	sprite.riproduci("rotolata_indietro" if indietro else "rotolata", true)
	_conta("rotolate")
	if indietro:
		Rapporto.conta("rotolate_indietro")
	_polvere(6)


func _rotolata(delta: float) -> void:
	_t_stato += delta
	var k := clampf(_t_stato / ROTOLATA_DURATA, 0.0, 1.0)
	velocity.x = _dir_rotolata * lerpf(ROTOLATA_VELOCITA, 150.0, k)
	_gravita(delta)
	if is_on_wall():
		if _spazio_in_piedi():
			_fine_rotolata()
			return
		_dir_rotolata = -_dir_rotolata  # in un cunicolo non ci si può alzare: si torna indietro
		verso = -verso
	if _t_stato >= ROTOLATA_DURATA:
		if _spazio_in_piedi():
			_fine_rotolata()
		elif not sprite.in_corso:
			sprite.riproduci("rotolata", true)  # sotto un soffitto basso si continua a rotolare


func _fine_rotolata() -> void:
	_imposta_forma(ALTO)
	stato = Stato.NORMALE
	_t_pausa_rotolata = ROTOLATA_PAUSA


func _inizia_schivata(a_terra: bool, direzione: float = 0.0) -> void:
	Suoni.suona("schiva", global_position, -4.0)
	# Senza direzione: a terra balzo all'indietro, in aria scatto in avanti.
	# Con la direzione dello sguardo: scatto in avanti; con quella opposta: scatto all'indietro.
	var indietro := _all_indietro(direzione)
	if absf(direzione) <= 0.01:
		_schivata_avanti = not a_terra
	else:
		_schivata_avanti = not indietro
	stato = Stato.SCHIVATA
	_t_stato = 0.0
	_schivata_in_aria = not a_terra
	_dir_schivata = verso if _schivata_avanti else -verso
	if _schivata_in_aria:
		_scatto_usato = true  # uno per salto
		velocity = Vector2(_dir_schivata * _velocita_schivata(), 0.0)
	else:
		velocity.x = _dir_schivata * _velocita_schivata()
		_polvere(4)
	sprite.riproduci("scatto" if _schivata_avanti else "schivata", true)
	Rapporto.conta("schivate")
	_conta("scatti_avanti" if _schivata_avanti else "scatti_indietro")


func _velocita_schivata() -> float:
	return SCATTO_VELOCITA if _schivata_avanti else SCHIVATA_VELOCITA


func _schivata(delta: float) -> void:
	_t_stato += delta
	var k := clampf(_t_stato / SCHIVATA_DURATA, 0.0, 1.0)
	if _schivata_in_aria:
		velocity = Vector2(_dir_schivata * lerpf(_velocita_schivata(), 140.0, k), 0.0)
	else:
		velocity.x = _dir_schivata * lerpf(_velocita_schivata(), 60.0, k)
		_gravita(delta)
	if _t_stato >= SCHIVATA_DURATA:
		stato = Stato.NORMALE
		_t_pausa_schivata = SCHIVATA_PAUSA


func _inizia_scavalco(arrivo: Vector2, appeso: bool = false) -> void:
	stato = Stato.SCAVALCO
	_t_stato = 0.0
	_scavalco_da = global_position
	_scavalco_a = arrivo
	velocity = Vector2.ZERO
	_maschera = collision_mask
	collision_mask = 0  # il percorso è già controllato: niente urti durante la salita
	# Un bordo alto preso in aria (o la cima di una parete) non si scavalca: ci si appende e ci si issa,
	# alla Prince of Persia.
	_issata = appeso
	sprite.riproduci("issata" if _issata else "scavalco", true)
	Rapporto.conta("issate" if _issata else "scavalchi")
	Controlli.vibra(0.15, 0.04)


func _scavalco(delta: float) -> void:
	# Prima su (con un filo di avanzamento), poi avanti fin sopra l'ostacolo.
	_t_stato += delta
	velocity = Vector2.ZERO
	if _issata:
		_issata_passo()
		return
	var k := clampf(_t_stato / SCAVALCO_DURATA, 0.0, 1.0)
	var meta_x := lerpf(_scavalco_da.x, _scavalco_a.x, 0.2)
	if k < 0.6:
		var u := k / 0.6
		global_position = Vector2(lerpf(_scavalco_da.x, meta_x, u), lerpf(_scavalco_da.y, _scavalco_a.y - 3.0, 1.0 - (1.0 - u) * (1.0 - u)))
	else:
		var u := (k - 0.6) / 0.4
		global_position = Vector2(lerpf(meta_x, _scavalco_a.x, u), _scavalco_a.y - 3.0 * (1.0 - u))
	if k >= 1.0:
		global_position = _scavalco_a
		collision_mask = _maschera
		stato = Stato.NORMALE
		_polvere(3)


func _issata_passo() -> void:
	# Aggancio (le mani arrivano sul bordo e il corpo si assesta appeso), trazione in su con un ginocchio
	# che sale, poi avanti fin sopra il bordo. I tempi seguono l'animazione "issata".
	var k := clampf(_t_stato / ISSATA_DURATA, 0.0, 1.0)
	# Appesi: mani sul bordo; al massimo 6 px più in basso di dove lo si è preso (mai dentro il pavimento).
	var appeso := Vector2(_scavalco_da.x, clampf(_scavalco_a.y + APPESO_SOTTO, _scavalco_a.y + ISSATA_DA, _scavalco_da.y + 6.0))
	var alto := Vector2(lerpf(_scavalco_da.x, _scavalco_a.x, 0.3), _scavalco_a.y - 2.0)
	if k < 0.2:
		var u := k / 0.2
		global_position = _scavalco_da.lerp(appeso, 1.0 - (1.0 - u) * (1.0 - u))
	elif k < 0.72:
		var u := (k - 0.2) / 0.52
		global_position = appeso.lerp(alto, u * u * (3.0 - 2.0 * u))
	else:
		global_position = alto.lerp(_scavalco_a, (k - 0.72) / 0.28)
	if k >= 1.0:
		global_position = _scavalco_a
		collision_mask = _maschera
		stato = Stato.NORMALE
		_polvere(3)


func vicino_cassa() -> RigidBody2D:
	# La cassa a portata di mano (a terra, accanto), oppure quella già afferrata.
	if stato == Stato.PRESA and is_instance_valid(_cassa):
		return _cassa
	if stato != Stato.NORMALE or not is_on_floor():
		return null
	var scelta: RigidBody2D = null
	var minima := PRESA_DISTANZA
	for c: RigidBody2D in get_tree().get_nodes_in_group("casse"):
		var dx := absf(c.global_position.x - global_position.x)
		if dx <= minima and absf(c.global_position.y - global_position.y) < 8.0:
			minima = dx
			scelta = c
	return scelta


func interagibile_vicino() -> Node2D:
	# La leva o il forziere a portata di mano (a terra, accanto), se c'è.
	if stato != Stato.NORMALE or not is_on_floor():
		return null
	var scelta: Node2D = null
	var minima := USO_DISTANZA
	for n: Node in get_tree().get_nodes_in_group("interagibili"):
		var o := n as Node2D
		if o == null or not o.call("puo_interagire"):
			continue
		var dx := absf(o.global_position.x - global_position.x)
		if dx <= minima and absf(o.global_position.y - global_position.y) < 14.0:
			minima = dx
			scelta = o
	return scelta


func cosa_vicina() -> String:
	# Per il tasto a schermo: cosa farebbe "afferra" qui ("" = niente).
	var oggetto := interagibile_vicino()
	if oggetto != null:
		return String(oggetto.call("etichetta"))
	return "Afferra" if vicino_cassa() != null else ""


func _inizia_uso(oggetto: Node2D) -> void:
	stato = Stato.USA
	_t_stato = 0.0
	velocity.x = 0.0
	if absf(oggetto.global_position.x - global_position.x) > 2.0:
		verso = 1 if oggetto.global_position.x > global_position.x else -1
	sprite.riproduci("usa", true)
	oggetto.call("interagisci", self)


func _uso(delta: float) -> void:
	_t_stato += delta
	velocity.x = move_toward(velocity.x, 0.0, ATTRITO * delta)
	_gravita(delta)
	if _t_stato >= USO_DURATA:
		stato = Stato.NORMALE


# ------------------------------------------------------------------ armi a distanza

func bocca() -> Vector2:
	# Da dove parte un tiro.
	return global_position + Vector2(verso * 14.0, -22.0)


func bersaglio_tiro(in_alto: bool) -> Nemico:
	# Aiuto alla mira (come nei giochi per telefono): il nemico più vicino dentro un cono di circa
	# 30 gradi attorno alla direzione del tiro, entro la portata e non dietro un muro.
	var base := Vector2(verso, -0.85).normalized() if in_alto else Vector2(verso, 0.0)
	var da := bocca()
	var migliore: Nemico = null
	var cono := cono_mira()
	if cono <= 0.0:
		return null
	var distanza := MIRA_PORTATA * (1.25 if cono > MIRA_CONO else 1.0)
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		var nemico := n as Nemico
		if nemico == null or not nemico.bersagliabile():
			continue
		var d := nemico.centro() - da
		var lunghezza := d.length()
		if lunghezza > distanza or lunghezza < 1.0 or absf(base.angle_to(d)) > cono:
			continue
		var raggio := PhysicsRayQueryParameters2D.create(da, nemico.centro(), Effetti.S_MONDO)
		if not get_world_2d().direct_space_state.intersect_ray(raggio).is_empty():
			continue
		migliore = nemico
		distanza = lunghezza
	return migliore


func direzione_tiro(in_alto: bool) -> Vector2:
	var n := bersaglio_tiro(in_alto)
	if n != null:
		return (n.centro() - bocca()).normalized()
	return Vector2(verso, -0.85).normalized() if in_alto else Vector2(verso, 0.0)


func cambia_arma() -> void:
	arma_distanza = ORDINE_ARMI[(ORDINE_ARMI.find(arma_distanza) + 1) % ORDINE_ARMI.size()]
	Rapporto.conta("cambi_arma")
	armi_cambiate.emit()


func _dote_magia(chiave: String) -> float:
	# Bastone e bacchetta rendono la magia più economica, più rapida o più veloce a ricaricarsi.
	return float((Armi.FAMIGLIE[famiglia_arma()] as Dictionary).get(chiave, 1.0))


func costo_magia(caricata: bool = false) -> float:
	return (COSTO_MAGIA_CARICA if caricata else COSTO_MAGIA) * _dote_magia("magia_costo")


func puo_tirare(arma: String = "") -> bool:
	var a := arma if arma != "" else arma_distanza
	if a == "magia":
		return energia >= costo_magia()
	return int(munizioni.get(a, 0)) > 0


func colpi_rimasti(arma: String = "") -> int:
	var a := arma if arma != "" else arma_distanza
	if a == "magia":
		return int(energia / costo_magia())
	return int(munizioni.get(a, 0))


func raccogli(cosa: String, quante: int) -> int:
	# Munizioni trovate (forzieri, barili): restituisce quante ne ha davvero prese.
	if not MUNIZIONI_MASSIME.has(cosa):
		return 0
	var prima: int = munizioni[cosa]
	munizioni[cosa] = mini(int(MUNIZIONI_MASSIME[cosa]), prima + quante)
	if munizioni[cosa] != prima:
		armi_cambiate.emit()
		Suoni.suona("raccogli", global_position, -4.0)
	return int(munizioni[cosa]) - prima


func _inizia_tiro() -> void:
	if not puo_tirare():
		Rapporto.conta("tiri_a_vuoto")
		Suoni.suona("tiro_vuoto", global_position)
		armi_cambiate.emit()   # l'indicatore lampeggia
		return
	stato = Stato.TIRO
	_t_stato = 0.0
	_tiro_partito = false
	_carica = 0.0
	_carica_piena = false
	_raffica = 0
	_t_raffica = 0.0
	_tiro_alternato = true
	# Con su si mira in alto (per chi vola o sta sulle piattaforme). La direzione esatta si decide
	# quando il colpo parte, con l'aiuto alla mira.
	_mira_in_alto = Input.is_action_pressed("su")
	var dati: Dictionary = ARMI_DISTANZA[arma_distanza]
	if sprite.has_method("mostra_in_mano"):
		sprite.call("mostra_in_mano", IN_MANO[arma_distanza])
	sprite.riproduci(String(dati["anim"]), true, 1.0 / _fattore_tiro())


func _fattore_tiro() -> float:
	# La bacchetta fa partire la magia prima.
	return _dote_magia("magia_veloce") if arma_distanza == "magia" else 1.0


func _tiene_tiro() -> bool:
	# "Tieni premuto" (predefinito) o "premi una volta": nel secondo modo una seconda pressione fa partire il tiro.
	if Impostazioni.leggi("acc/carica") != "alterna":
		return Input.is_action_pressed("tira")
	if _t_stato > 0.05 and Input.is_action_just_pressed("tira"):
		_tiro_alternato = false
	return _tiro_alternato


func cono_mira() -> float:
	# Aiuto alla mira: spento, normale o forte (accessibilità).
	match int(Impostazioni.leggi("acc/mira")):
		0:
			return 0.0
		2:
			return 0.95
	return MIRA_CONO


func carica_tiro() -> float:
	# Da 0 a 1: quanto è carico il tiro in corso (per la scritta e per il bot).
	var dati: Dictionary = ARMI_DISTANZA[arma_distanza]
	if stato != Stato.TIRO or not dati.has("carica"):
		return 0.0
	return clampf(_carica / float(dati["carica"]), 0.0, 1.0)


func _tiro(delta: float, a_terra: bool) -> void:
	_t_stato += delta
	var dati: Dictionary = ARMI_DISTANZA[arma_distanza]
	var fattore := _fattore_tiro()
	var momento := float(dati["momento"]) * fattore
	if a_terra:
		velocity.x = move_toward(velocity.x, 0.0, ATTRITO * delta)
	else:
		_muovi(delta, false, Input.get_axis("sinistra", "destra"))
	_gravita(delta)
	var tiene := _tiene_tiro()
	if not _tiro_partito:
		if _t_stato < momento:
			return
		var puo_caricare := dati.has("carica") and (arma_distanza != "magia" or energia >= costo_magia(true))
		if tiene and puo_caricare and not _carica_piena:
			# Si carica: la posa resta ferma finché non si lascia il tasto.
			_carica += delta
			_t_stato = momento
			sprite.velocita = 0.0
			if _carica >= float(dati["carica"]):
				_carica_piena = true
				Suoni.suona("carica_pronta", global_position, -8.0)
				Effetti.scoppio(get_parent(), bocca(), Color(1.0, 0.9, 0.6), 6, 40.0, 0.3, 0.0)
				Controlli.vibra(0.2, 0.05)
			return
		if tiene and _carica_piena:
			_t_stato = momento   # carico: parte quando si lascia
			return
		sprite.velocita = 1.0 / fattore
		_spara()
		_tiro_partito = true
	elif arma_distanza == "dardi" and tiene and _raffica < int(dati["raffica"]) and int(munizioni["dardi"]) > 0:
		# Raffica: finché si tiene premuto parte un dardo dopo l'altro.
		_t_raffica += delta
		_t_stato = minf(_t_stato, momento + 0.02)
		if _t_raffica >= float(dati["intervallo"]):
			_t_raffica = 0.0
			_spara()
	if _t_stato >= float(dati["durata"]) * fattore:
		if sprite.has_method("mostra_in_mano"):
			sprite.call("mostra_in_mano", [])
		stato = Stato.NORMALE


func _spara() -> void:
	var dati: Dictionary = ARMI_DISTANZA[arma_distanza]
	var colpo := Proiettile.new()
	colpo.tipo = {"magia": "magia_eroe", "dardi": "dardo", "frecce": "freccia_eroe"}[arma_distanza]
	colpo.danno = int(dati["danno"])
	var velocita := float(dati["velocita"])
	var k := carica_tiro() if dati.has("carica") else 0.0
	match arma_distanza:
		"magia":
			var caricata := _carica_piena and energia >= costo_magia(true)
			energia -= costo_magia(caricata)
			if caricata:
				colpo.danno = int(dati["danno_carica"])
				colpo.raggio_esplosione = float(dati["raggio"])
				Rapporto.conta("tiri_carichi")
		"dardi":
			munizioni["dardi"] = int(munizioni["dardi"]) - 1
			_raffica += 1
			if _raffica > 1:
				Rapporto.conta("dardi_in_raffica")
		"frecce":
			munizioni["frecce"] = int(munizioni["frecce"]) - 1
			colpo.danno = int(dati["danno"]) + roundi((int(dati["danno_carica"]) - int(dati["danno"])) * k)
			velocita = lerpf(velocita, float(dati["velocita_carica"]), k)
			if _carica_piena:
				colpo.perfora = 2   # a carica piena trapassa fino a tre nemici
				Rapporto.conta("tiri_carichi")
	var bersaglio := bersaglio_tiro(_mira_in_alto)
	if bersaglio != null and Proiettile.gravita_di(colpo.tipo) > 0.0:
		# Frecce e dardi cadono: si mira un po' più in alto per arrivare sul bersaglio.
		colpo.velocita = Proiettile.lancio(bocca(), bersaglio.centro(), velocita, Proiettile.gravita_di(colpo.tipo))
	else:
		colpo.velocita = direzione_tiro(_mira_in_alto) * velocita
	colpo.position = bocca()
	colpo.autore = self
	get_parent().add_child(colpo)
	Suoni.suona({"magia": "magia", "dardi": "dardo", "frecce": "freccia"}[arma_distanza], bocca(), -3.0)
	armi_cambiate.emit()
	_conta("tiri")
	Rapporto.conta("tiri_" + arma_distanza)


# ------------------------------------------------------------------ pozioni

func bevi(tipo: String, taglia: String) -> void:
	# Ogni pozione aggiunge forza e secondi all'effetto dello stesso tipo già in corso.
	if stato == Stato.MORTO or not Bottino.TIPI_POZIONE.has(tipo):
		return
	var t: Array = POZIONE_TAGLIE.get(taglia, POZIONE_TAGLIE["piccola"])
	var e: Dictionary = effetti.get(tipo, {"forza": 0.0, "tempo": 0.0, "durata": 0.0})
	var sommato := float(e["tempo"]) > 0.0
	e["forza"] = minf(EFFETTO_FORZA_MAX, float(e["forza"]) + float(t[0]))
	e["tempo"] = minf(EFFETTO_TEMPO_MAX, float(e["tempo"]) + float(t[1]))
	e["durata"] = e["tempo"]
	effetti[tipo] = e
	Suoni.suona("bevi", global_position, -2.0, 1.15 if taglia == "piccola" else (0.9 if taglia == "grande" else 1.0))
	Effetti.scoppio(get_parent(), global_position + Vector2(0, -22), Bottino.COLORI_POZIONE[tipo], 12, 70.0, 0.6, -70.0,
			true, 1.0, Vector2.UP, 60.0)
	_conta("pozioni_bevute")
	Rapporto.conta("pozioni_" + tipo)
	if sommato:
		Rapporto.conta("effetti_sommati")
	Rapporto.evento("pozione", {"tipo": tipo, "taglia": taglia, "forza": e["forza"], "secondi": snappedf(float(e["tempo"]), 0.1)})
	var testo := "Pozione %s di %s" % [taglia, Bottino.NOMI_POZIONE[tipo]]
	if sommato:
		testo += ": effetto più forte (×%d)" % int(e["forza"])
	get_tree().call_group("hud", "didascalia_oggetto", testo, Bottino.COLORI_POZIONE[tipo])
	effetti_cambiati.emit()


func forza_effetto(tipo: String) -> float:
	return float((effetti.get(tipo, {}) as Dictionary).get("forza", 0.0))


func moltiplicatore_velocita() -> float:
	return 1.0 + minf(VELOCITA_POZIONE_MASSIMA, VELOCITA_PER_FORZA * forza_effetto("velocita"))


func _aggiorna_effetti(delta: float) -> void:
	if effetti.is_empty() or stato == Stato.MORTO:
		return
	for tipo: String in effetti.keys():
		var e: Dictionary = effetti[tipo]
		var forza := float(e["forza"])
		e["tempo"] = float(e["tempo"]) - delta
		match tipo:
			"salute":
				_cura_accumulata += CURA_PER_FORZA * forza * delta
				if _cura_accumulata >= 1.0:
					_cura_accumulata -= 1.0
					cura(1)
			"stamina":
				stamina = minf(STAMINA_MASSIMA, stamina + STAMINA_PER_FORZA * forza * delta)
				if _esausto and stamina >= STAMINA_RIPRESA:
					_esausto = false
			"mana":
				energia = minf(ENERGIA_MASSIMA, energia + MANA_PER_FORZA * forza * delta)
			"velocita":
				_t_scia -= delta
				if _t_scia <= 0.0 and absf(velocity.x) > 60.0 and Dispositivo.profilo.get("particelle", 1.0) > 0.0:
					_t_scia = 0.12   # una scia dorata quando si corre
					Effetti.scoppio(get_parent(), global_position + Vector2(-signf(velocity.x) * 6.0, -18.0),
							Bottino.COLORI_POZIONE["velocita"], 3, 20.0, 0.35, 0.0, false)
		if float(e["tempo"]) <= 0.0:
			effetti.erase(tipo)
			if tipo == "salute":
				_cura_accumulata = 0.0
			effetti_cambiati.emit()


func cura(quanta: int) -> int:
	# Restituisce quanta vita ha davvero recuperato.
	if stato == Stato.MORTO:
		return 0
	var prima := vita
	vita = mini(VITA_MASSIMA, vita + quanta)
	if vita != prima:
		vita_cambiata.emit(vita, VITA_MASSIMA)
		Effetti.scoppio(get_parent(), global_position + Vector2(0, -24), Color(0.9, 0.3, 0.35), 10, 50.0, 0.6, -60.0)
		Suoni.suona("cura", global_position, -2.0)
	return vita - prima


func _inizia_presa(cassa: RigidBody2D) -> void:
	stato = Stato.PRESA
	_cassa = cassa
	verso = 1 if cassa.global_position.x > global_position.x else -1
	_scarto_cassa = cassa.global_position.x - global_position.x
	_tirata_contata = false
	velocity.x = 0.0
	add_collision_exception_with(cassa)  # finché la si tiene, la cassa segue senza urtare
	sprite.riproduci("presa", true)
	Rapporto.conta("prese")


func _presa(delta: float) -> void:
	if not Input.is_action_pressed("afferra") or not is_instance_valid(_cassa) or not is_on_floor() \
			or absf(_cassa.global_position.y - global_position.y) > 10.0:
		_lascia_cassa()
		return
	var direzione := Input.get_axis("sinistra", "destra")
	velocity.x = move_toward(velocity.x, direzione * PRESA_VELOCITA, ACCELERAZIONE * delta)
	_gravita(delta)
	# La cassa segue alla stessa distanza, sia spingendo sia tirando.
	var errore := (global_position.x + _scarto_cassa) - _cassa.global_position.x
	_cassa.sleeping = false
	_cassa.linear_velocity.x = velocity.x + errore * 20.0
	if absf(velocity.x) > 5.0 and signf(velocity.x) != float(verso) and not _tirata_contata:
		_tirata_contata = true
		Rapporto.conta("tirate")
	if Input.is_action_just_pressed("salta"):
		_lascia_cassa()


func _lascia_cassa() -> void:
	if is_instance_valid(_cassa):
		remove_collision_exception_with(_cassa)
		_cassa.linear_velocity.x = 0.0
	_cassa = null
	stato = Stato.NORMALE


func _colpito(delta: float) -> void:
	_t_stato += delta
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	_gravita(delta)
	if _t_stato >= 0.28:
		stato = Stato.NORMALE


func _da_morto(delta: float) -> void:
	_t_stato += delta
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	_gravita(delta)
	if _t_stato >= 1.4 and not _morte_segnalata:
		_morte_segnalata = true
		morto.emit()


# ------------------------------------------------------------------ danni

func intoccabile() -> bool:
	if stato == Stato.MORTO or _t_protetto > 0.0 or stato == Stato.SCHIVATA or stato == Stato.SCAVALCO:
		return true
	return stato == Stato.ROTOLATA and _t_stato > 0.03 and _t_stato < 0.33


func subisci(danno: int, da: Vector2, spinta: float, chi: Node = null) -> bool:
	if stato == Stato.MORTO:
		return false
	if sta_parando(da):
		Rapporto.conta("parate_riuscite")
		Suoni.suona("parata", global_position)
		Effetti.scoppio(get_parent(), global_position + Vector2(verso * 12.0, -26.0), Color(1.0, 0.92, 0.7), 10, 120.0, 0.25, 150.0)
		scuoti(2.0)
		velocity.x = -verso * 60.0
		if is_instance_valid(chi) and chi.has_method("barcolla"):
			chi.call("barcolla", 0.8)   # chi colpisce uno scudo resta scoperto
		return false
	if intoccabile():
		if stato == Stato.ROTOLATA or stato == Stato.SCHIVATA:
			Rapporto.conta("colpi_evitati")
		return false
	# Accessibilità "danni ricevuti": si toglie solo la parte scelta (0 = invincibile); le frazioni si sommano.
	var quota: float = clampf(Impostazioni.leggi("acc/danni"), 0.0, 1.0)
	_resto_danni += float(danno) * quota
	var tolti := floori(_resto_danni + 0.0001)
	_resto_danni -= tolti
	vita = maxi(0, vita - tolti)
	_colpito_da = chi   # una trappola (chi = null) non lascia il merito a un nemico di prima
	vita_cambiata.emit(vita, VITA_MASSIMA)
	Rapporto.conta("colpi_subiti")
	Rapporto.evento("colpito", {"vita": vita, "x": roundi(global_position.x), "y": roundi(global_position.y)})
	Controlli.vibra(0.8, 0.2)
	scuoti(5.0)
	Effetti.lampo(sprite)
	Effetti.fermo_immagine(self, 0.09)   # un attimo per capire cosa ti ha colpito
	Suoni.suona("colpito", global_position)
	if vita <= 0:
		_muori()
		return true
	_t_protetto = PROTEZIONE_DOPO_COLPO
	if stato == Stato.PRESA:
		_lascia_cassa()
	if stato == Stato.ARRAMPICATA:
		sprite.riponi_armi(false)   # colpito sulla parete: si stacca e cade
	if stato == Stato.NUOTO:
		velocity = Vector2(signf(global_position.x - da.x) * spinta * 0.4, 0.0)
		_t_protetto = PROTEZIONE_DOPO_COLPO
		return true   # in acqua niente spinta in aria: si resta a nuotare
	if stato != Stato.ROTOLATA:
		var lato := signf(global_position.x - da.x)
		if lato == 0.0:
			lato = -verso
		stato = Stato.COLPITO
		_t_stato = 0.0
		velocity = Vector2(lato * spinta, -170.0)
		sprite.riproduci("colpito", true)
	return true


func _muori() -> void:
	if stato == Stato.PRESA:
		_lascia_cassa()
	if stato != Stato.ROTOLATA or _spazio_in_piedi():
		_imposta_forma(ALTO)  # sotto un soffitto basso si resta bassi anche da morti
	stato = Stato.MORTO
	_t_stato = 0.0
	_bersaglio.set_deferred("monitorable", false)
	sprite.riproduci("morte", true)
	Rapporto.conta("morti")
	if is_instance_valid(_colpito_da):
		Memoria.nemico_ha_ucciso(_colpito_da)  # chi ti uccide se lo ricorderà
	var assassino := "trappola"
	if is_instance_valid(_colpito_da) and "tipo" in _colpito_da:
		assassino = String(_colpito_da.get("tipo"))
		if "livello" in _colpito_da:
			assassino += " (livello %d, ondata %d)" % [int(_colpito_da.get("livello")), int(_colpito_da.get("ondata"))]
	if assassino == "trappola" and respiro <= 0.0 and sott_acqua:
		assassino = "annegamento"
	sprite.riponi_armi(false)
	Rapporto.evento("morte", {"x": roundi(global_position.x), "y": roundi(global_position.y), "da": assassino})
	Suoni.suona("morte")
	Controlli.vibra(1.0, 0.4)


func scuoti(forza: float) -> void:
	# forza in pixel "di prima" (2 = colpo leggero, 5 = colpo subito): diventa trauma che si somma.
	if not Dispositivo.in_prova:
		_scossa = minf(1.0, _scossa + forza / 10.0 * clampf(Impostazioni.leggi("acc/scuotimento"), 0.0, 1.0))


func trauma() -> float:
	return _scossa


# ------------------------------------------------------------------ movimento

func _muovi(delta: float, a_terra: bool, direzione: float) -> void:
	var accelerazione := ACCELERAZIONE_ARIA
	if a_terra:
		accelerazione = ACCELERAZIONE if absf(direzione) > 0.01 else ATTRITO
	velocity.x = move_toward(velocity.x, direzione * VELOCITA * moltiplicatore_velocita(), accelerazione * delta)


# ------------------------------------------------------------------ arrampicata

func _stanza() -> Node:
	var p := get_parent()
	return p if p != null and p.has_method("zona_scalabile") else null


func _puo_aggrapparsi(direzione: float, a_terra: bool) -> bool:
	var stanza := _stanza()
	if stanza == null or _t_stacco > 0.0 or in_acqua:
		return false
	if _esausto or stamina <= 1.0:
		return false
	var zona: Dictionary = stanza.zona_scalabile(global_position + Vector2(0.0, -ALTO.y * 0.5))
	if zona.is_empty():
		return false
	var lato: int = zona["lato"]
	var verso_il_muro := absf(direzione) > 0.01 and int(signf(direzione)) == lato
	var su := Input.is_action_pressed("su")
	if a_terra:
		return su   # da terra: su accanto alla parete
	return verso_il_muro or (su and velocity.y > -150.0)


func _inizia_arrampicata() -> void:
	var zona: Dictionary = _stanza().zona_scalabile(global_position + Vector2(0.0, -ALTO.y * 0.5))
	_lato_muro = zona["lato"]
	_zona_muro = zona["rett"]
	verso = _lato_muro
	stato = Stato.ARRAMPICATA
	_t_stato = 0.0
	velocity = Vector2.ZERO
	sprite.position.x = -_lato_muro * SCOSTA_DAL_MURO
	sprite.riponi_armi(true)
	_fase_scalata = 0.0
	sprite.posa("arrampica", _fase_scalata)   # aggancio: una mano in alto, il ginocchio opposto sulla parete
	Suoni.suona("presa", global_position, -4.0)
	_conta("arrampicate")


func _arrampicata(delta: float) -> void:
	_t_stato += delta
	var su_giu := Input.get_axis("su", "giu")
	var direzione := Input.get_axis("sinistra", "destra")
	velocity.x = _lato_muro * 30.0   # spinge appena contro la parete
	# Il ciclo segue la leva (giù = all'indietro). Il corpo sale soprattutto mentre la mano in alto tira:
	# la mano resta ferma sulla roccia e il corpo le va incontro, poi l'altra mano va su (vedi "Arrampica").
	var fase_prima := _fase_scalata
	if absf(su_giu) > 0.1:
		_fase_scalata = fposmod(_fase_scalata - su_giu * moltiplicatore_velocita() * delta / CICLO_SCALATA, 1.0)
	velocity.y = su_giu * ARRAMPICATA_VELOCITA * moltiplicatore_velocita() * profilo_scalata(_fase_scalata)
	var spesa := STAMINA_SCALA if absf(su_giu) > 0.1 else STAMINA_APPESO
	if not Impostazioni.leggi("acc/stamina_infinita"):
		stamina = maxf(0.0, stamina - spesa * delta)
	var zona: Dictionary = _stanza().zona_scalabile(global_position + Vector2(0.0, -ALTO.y * 0.5))
	if Input.is_action_just_pressed("salta"):
		# Salto dal muro: sempre lontano dalla parete (costa stamina).
		_stacca(true)
		velocity = Vector2(-_lato_muro * SALTO_MURO.x, -SALTO_MURO.y)
		verso = -_lato_muro
		if not Impostazioni.leggi("acc/stamina_infinita"):
			stamina = maxf(0.0, stamina - STAMINA_SALTO_MURO)
		Suoni.suona("salto", global_position, -4.0)
		_conta("salti_dal_muro")
		return
	if stamina <= 0.0:
		# Senza fiato le mani scivolano: si cade e non ci si riaggrappa finché non si riprende.
		_esausto = true
		_stacca(false)
		velocity = Vector2(-_lato_muro * 40.0, 0.0)
		Suoni.suona("affanno", global_position)
		_conta("prese_perse")
		Rapporto.evento("stamina_finita", {"x": roundi(global_position.x), "y": roundi(global_position.y)})
		return
	if absf(direzione) > 0.01 and int(signf(direzione)) == -_lato_muro and _t_stato > 0.15:
		_stacca(false)   # direzione opposta alla parete: si lascia andare
		return
	if zona.is_empty():
		# Finita la parete: in cima si sale sul bordo, in fondo si torna a terra.
		if su_giu < 0.0:
			var arrivo: Variant = _appiglio(APPIGLIO_IN_ARIA + 10.0, 2.0)
			if arrivo != null:
				sprite.riponi_armi(false)
				_inizia_scavalco(arrivo, true)   # in cima alla parete: ci si issa sul bordo
				return
			velocity.y = 0.0
			global_position.y += 1.0
			return
		_stacca(false)
		return
	if is_on_floor() and su_giu > 0.1:
		_stacca(false)
		return
	# Fermi sulla parete si resta nella posa del ciclo (niente scatto verso un'altra posa).
	sprite.posa("arrampica", _fase_scalata)
	if absf(su_giu) > 0.1 and int(fase_prima * 2.0) != int(_fase_scalata * 2.0):
		Suoni.suona("presa", global_position, -10.0, 1.1)   # una mano arriva su una presa nuova


static func profilo_scalata(fase: float) -> float:
	# Velocità relativa nel ciclo (media 1): massima a metà trazione, minima mentre l'altra mano va su.
	return 1.0 + SPINTA_SCALATA * cos(TAU * (fposmod(fase * 2.0, 1.0) - 0.3))


func _stacca(salto: bool) -> void:
	stato = Stato.NORMALE
	sprite.position.x = 0.0
	_t_stacco = 0.28 if salto else 0.22
	sprite.velocita = 1.0
	sprite.riponi_armi(false)


func aggrappato() -> bool:
	return stato == Stato.ARRAMPICATA


# ------------------------------------------------------------------ nuoto e respiro

func _controlla_acqua() -> void:
	var stanza := _stanza()
	var prima := in_acqua
	var acqua: Dictionary = stanza.acqua_in(global_position + Vector2(0.0, -ALTO.y * 0.5)) if stanza != null else {}
	in_acqua = not acqua.is_empty()
	if in_acqua:
		_superficie = acqua["superficie"]
	var testa := global_position.y - ALTO.y + 6.0
	sott_acqua = in_acqua and testa > _superficie + 1.0
	# Sott'acqua il personaggio si disegna sopra il velo dell'acqua (z 15), tinto di blu:
	# sotto il velo scuro si vedeva appena (controllo da giocatore, 0.1.23).
	z_index = Z_SOTT_ACQUA if sott_acqua else Z_NORMALE
	Suoni.imposta_sott_acqua(sott_acqua)   # tutto ovattato con la testa sott'acqua
	sprite.self_modulate = TINTA_SOTT_ACQUA if sott_acqua else Color.WHITE
	if in_acqua and not prima:
		# Tuffo: schizzi e suono, il resto dello slancio si smorza.
		Effetti.scoppio(get_parent(), Vector2(global_position.x, _superficie), Color(0.55, 0.7, 0.85, 0.8), 14,
				80.0 + absf(velocity.y) * 0.2, 0.5, 300.0, false, 1.0, Vector2.UP, 50.0)
		Suoni.suona("tuffo", Vector2(global_position.x, _superficie), -2.0 if velocity.y > 200.0 else -6.0)
		_conta("tuffi")
	if in_acqua and stato in [Stato.NORMALE, Stato.ROTOLATA, Stato.SCHIVATA, Stato.ATTACCO, Stato.TIRO, Stato.ARRAMPICATA, Stato.PARATA]:
		if stato == Stato.ROTOLATA:
			_imposta_forma(ALTO)
		if stato == Stato.TIRO and sprite.has_method("mostra_in_mano"):
			sprite.call("mostra_in_mano", [])
		stato = Stato.NUOTO
		_t_stato = 0.0
		velocity *= 0.35
		sprite.riponi_armi(true)
	elif not in_acqua and stato == Stato.NUOTO:
		stato = Stato.NORMALE
		sprite.riponi_armi(false)


func _nuoto(delta: float) -> void:
	_t_stato += delta
	var direzione := Input.get_axis("sinistra", "destra")
	var su_giu := Input.get_axis("su", "giu")
	if absf(direzione) > 0.01:
		verso = 1 if direzione > 0.0 else -1
	velocity.x = move_toward(velocity.x, direzione * NUOTO_VELOCITA * moltiplicatore_velocita(), NUOTO_SPINTA * delta)
	var testa := global_position.y - ALTO.y + 6.0
	var alla_superficie := testa <= _superficie + 4.0
	var obiettivo_y := su_giu * NUOTO_VELOCITA
	if absf(su_giu) < 0.1:
		# Senza comandi si torna a galla e si resta con la testa fuori.
		obiettivo_y = -80.0 if not alla_superficie else (testa - (_superficie - 2.0)) * 6.0
	elif su_giu < 0.0 and alla_superficie:
		obiettivo_y = 0.0
	velocity.y = move_toward(velocity.y, obiettivo_y, NUOTO_SPINTA * delta)
	if Input.is_action_just_pressed("salta") and alla_superficie:
		velocity.y = -NUOTO_SALTO   # fuori dall'acqua (a riva o su un bordo vicino)
		global_position.y -= 2.0
		Suoni.suona("tuffo", Vector2(global_position.x, _superficie), -10.0, 1.4)
		_conta("uscite_dall_acqua")
	if sott_acqua:
		_t_bolle -= delta
		if _t_bolle <= 0.0:
			_t_bolle = 0.9
			Effetti.scoppio(get_parent(), global_position + Vector2(verso * 6.0, -ALTO.y + 4.0), Color(0.7, 0.85, 1.0, 0.7), 3,
					20.0, 0.8, -60.0, false, 0.8, Vector2.UP, 20.0)
			Suoni.suona("bolle", global_position, -12.0)
	var muove := absf(direzione) > 0.01 or absf(su_giu) > 0.1
	if sott_acqua or muove:
		sprite.riproduci("nuota")
		# Bracciate al passo con lo spostamento vero (0.1.35): ferme sott'acqua appena accennate.
		sprite.velocita = clampf(velocity.length() / (NUOTO_VELOCITA * moltiplicatore_velocita()), 0.3, 1.3)
	else:
		sprite.riproduci("galleggia")
		sprite.velocita = 1.0


func _aggiorna_fiato(delta: float) -> void:
	# Stamina: torna con i piedi a terra (o a galla). Respiro: cala con la testa sott'acqua.
	var a_terra := is_on_floor() and stato != Stato.ARRAMPICATA
	_t_a_terra = _t_a_terra + delta if (a_terra or (in_acqua and not sott_acqua)) else 0.0
	if _t_a_terra >= STAMINA_ATTESA and stamina < STAMINA_MASSIMA:
		stamina = minf(STAMINA_MASSIMA, stamina + STAMINA_RECUPERO * delta)
	if _esausto and stamina >= STAMINA_RIPRESA:
		_esausto = false
	if sott_acqua and stato != Stato.MORTO:
		if not Impostazioni.leggi("acc/respiro_infinito"):
			respiro = maxf(0.0, respiro - RESPIRO_CONSUMO * delta)
		if respiro <= 0.0:
			_t_annega += delta
			if _t_annega >= ANNEGA_OGNI:
				_t_annega = 0.0
				ferita_ambiente(1, "annegamento")
	else:
		if respiro < RESPIRO_MASSIMO * 0.35 and in_acqua and not sott_acqua and _t_annega >= 0.0:
			Suoni.suona("respiro", global_position, -4.0)
			_t_annega = -1.0   # un solo respiro profondo per riemersione
		if not sott_acqua:
			if _t_annega < 0.0 and respiro >= RESPIRO_MASSIMO * 0.35:
				_t_annega = 0.0
			respiro = minf(RESPIRO_MASSIMO, respiro + RESPIRO_RECUPERO * delta)


func ferita_ambiente(danno: int, causa: String) -> void:
	# Danno senza spinta (annegamento): stessa regola dei "danni ricevuti" e della protezione dopo un colpo.
	if stato == Stato.MORTO or _t_protetto > 0.0:
		return
	var quota: float = clampf(Impostazioni.leggi("acc/danni"), 0.0, 1.0)
	_resto_danni += float(danno) * quota
	var tolti := floori(_resto_danni + 0.0001)
	_resto_danni -= tolti
	vita = maxi(0, vita - tolti)
	_colpito_da = null
	vita_cambiata.emit(vita, VITA_MASSIMA)
	Rapporto.conta("danni_" + causa)
	Rapporto.evento("ferita", {"causa": causa, "vita": vita})
	Effetti.lampo(sprite)
	Suoni.suona("colpito", global_position, -4.0, 0.8)
	Controlli.vibra(0.5, 0.15)
	get_tree().call_group("hud", "didascalia", "[senza respiro]" if causa == "annegamento" else "[ferito]")
	if vita <= 0:
		_muori()
		return
	_t_protetto = 0.3


func _scansa_spigolo(vy: float) -> void:
	# Saltando si sbatte la testa contro lo spigolo di un ripiano per pochi pixel: si scivola di lato e si sale
	# lo stesso, invece di ricadere (correzione degli spigoli dei platform).
	for d in range(1, int(SPIGOLO) + 1):
		for lato: float in [-1.0, 1.0]:
			var spostato := global_transform.translated(Vector2(lato * d, 0.0))
			if not test_move(global_transform, Vector2(lato * d, 0.0)) and not test_move(spostato, Vector2(0.0, -4.0)):
				global_position.x += lato * d
				velocity.y = vy
				Rapporto.conta("spigoli_scansati")
				return


func _gravita(delta: float) -> void:
	var g := GRAVITA_SU if velocity.y < 0.0 else GRAVITA_GIU
	if stato == Stato.NORMALE and absf(velocity.y) < APICE_VELOCITA and Input.is_action_pressed("salta"):
		g *= APICE_GRAVITA   # in cima al salto si resta sospesi un attimo: c'è tempo per mirare l'atterraggio
	velocity.y = minf(velocity.y + g * delta, CADUTA_MASSIMA)


func _imposta_forma(misura: Vector2) -> void:
	_rett.size = misura
	_forma.position = Vector2(0.0, -misura.y * 0.5)


func _spazio_in_piedi() -> bool:
	return _libero(global_position)


func _appiglio(sopra: float, sotto: float) -> Variant:
	# Cerca, subito davanti, una superficie fra "sopra" e "sotto" pixel più in alto dei piedi
	# con spazio per stare in piedi: restituisce dove arrivare, oppure null.
	var fx := global_position.x + verso * (ALTO.x * 0.5 + 5.0)
	var domanda := PhysicsRayQueryParameters2D.create(Vector2(fx, global_position.y - sopra),
			Vector2(fx, global_position.y - sotto), Effetti.S_MONDO | Effetti.S_PIATTAFORME | Effetti.S_OGGETTI, [get_rid()])
	var esito := get_world_2d().direct_space_state.intersect_ray(domanda)
	if esito.is_empty() or (esito["normal"] as Vector2).y > -0.7:
		return null
	var arrivo := Vector2(global_position.x + verso * (ALTO.x * 0.5 + 9.0), (esito["position"] as Vector2).y - 0.5)
	return arrivo if _libero(arrivo) else null


func _libero(piedi: Vector2) -> bool:
	var prova := RectangleShape2D.new()
	prova.size = Vector2(ALTO.x - 2.0, ALTO.y - 2.0)
	var domanda := PhysicsShapeQueryParameters2D.new()
	domanda.shape = prova
	domanda.transform = Transform2D(0.0, piedi + Vector2(0.0, -ALTO.y * 0.5 - 1.0))
	domanda.collision_mask = Effetti.S_MONDO | Effetti.S_OGGETTI
	domanda.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(domanda, 1).is_empty()


func _su_piattaforma() -> bool:
	for i in get_slide_collision_count():
		var corpo := get_slide_collision(i).get_collider() as CollisionObject2D
		if corpo != null and (corpo.collision_layer & Effetti.S_PIATTAFORME) != 0:
			return true
	return false


func solido_per_i_nemici() -> bool:
	# Stessi casi di _separa_dai_nemici: rotolo, scatto, parete, acqua e scavalco passano attraverso.
	return stato not in [Stato.ROTOLATA, Stato.SCHIVATA, Stato.MORTO, Stato.ARRAMPICATA, Stato.NUOTO, Stato.SCAVALCO]


func _separa_dai_nemici() -> void:
	# Personaggio e nemici non si compenetrano: si spingono di lato (il bestione, pesante, quasi non si
	# sposta). Il rotolo e lo scatto passano attraverso apposta (servono a schivare); chi dorme a terra,
	# chi vola e chi è in tregua (prove del bot) non conta. Sopra la testa di un nemico si scivola giù.
	if not solido_per_i_nemici():
		return
	var mio_alto := global_position.y - ALTO.y
	for n: Node in get_tree().get_nodes_in_group("nemici"):
		var nemico := n as Nemico
		if nemico == null or not nemico.solido():
			continue
		var dx := global_position.x - nemico.global_position.x
		var mezzo := SPAZIO + nemico.mezza_larghezza()
		if absf(dx) >= mezzo:
			continue
		var verticale := nemico.estensione_verticale()
		if global_position.y <= verticale.x + 2.0 or mio_alto >= verticale.y - 2.0:
			continue
		var lato := signf(dx)
		if lato == 0.0:
			lato = -float(verso)
		var dentro := mezzo - absf(dx)
		var mia_parte := dentro * (0.85 if nemico.tipo == "bestione" else 0.5)
		move_and_collide(Vector2(lato * mia_parte, 0.0))
		nemico.spingi(-lato * (dentro - mia_parte))
		if signf(velocity.x) == -lato:
			velocity.x = 0.0   # contro un nemico non si cammina dentro
		Rapporto.conta("separazioni")


func _spingi_oggetti(delta: float) -> void:
	if stato != Stato.NORMALE and stato != Stato.ATTACCO:
		return
	for i in get_slide_collision_count():
		var urto := get_slide_collision(i)
		var corpo := urto.get_collider() as RigidBody2D
		if corpo != null and absf(urto.get_normal().x) > 0.8:
			var lato := -signf(urto.get_normal().x)
			corpo.sleeping = false
			# Velocità piena subito: con l'accelerazione l'attrito di una cassa ferma a volte la teneva inchiodata.
			if corpo.linear_velocity.x * lato < SPINTA_CASSE:
				corpo.linear_velocity.x = lato * SPINTA_CASSE


func _atterrato() -> void:
	if _velocita_caduta > 220.0:
		_t_atterra = 0.14
		_polvere(5)
		Controlli.vibra(0.2, 0.05)
		Suoni.suona("atterra", global_position, -3.0)
		# Schiacciato un attimo dall'atterraggio (il perno è ai piedi: resta appoggiato a terra).
		var peso := clampf((_velocita_caduta - 220.0) / 400.0, 0.0, 1.0)
		sprite.scale = Vector2(1.0 + 0.14 * peso, 1.0 - 0.14 * peso)
		var tw := sprite.create_tween()
		tw.tween_property(sprite, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ aspetto

func _aggiorna_aspetto() -> void:
	if stato != Stato.TIRO and sprite.has_method("mostra_in_mano"):
		sprite.call("mostra_in_mano", [])   # interrotto (colpito, morto...): via la balestra dalla mano
	# Girarsi: la prima metà guardando ancora dalla parte di prima, ruotando verso chi guarda; poi l'altra metà
	# già girati. Solo camminando, correndo e saltando (rotoli e schivate all'indietro non si girano).
	var mostrato := verso
	var giro := 0.0
	if _t_giro_visivo > 0.0 and stato == Stato.NORMALE and sprite.has_method("gira"):
		var k := 1.0 - _t_giro_visivo / GIRO_VISIVO
		mostrato = _verso_prima if k < 0.5 else verso
		giro = float(sprite.get("_rotazione_base")) * (1.0 - absf(1.0 - 2.0 * k))
	if sprite.has_method("gira"):
		sprite.call("gira", giro)
	sprite.flip_h = mostrato < 0
	var lampeggia := _t_protetto > 0.0 and stato != Stato.MORTO and int(_t_protetto * 14.0) % 2 == 0
	sprite.modulate.a = 0.35 if lampeggia else 1.0
	if stato == Stato.PRESA:
		if absf(velocity.x) < 5.0:
			sprite.riproduci("presa")
		else:
			sprite.riproduci("spinge" if signf(velocity.x) == float(verso) else "tira")
		return
	_aggiorna_piega()
	if stato != Stato.NORMALE:
		return
	if is_on_floor():
		if _t_atterra > 0.0:
			sprite.riproduci("atterra")
		elif absf(velocity.x) > 12.0:
			var passo := _spinta < 0.6   # leva appena inclinata: si cammina
			sprite.riproduci("passo" if passo else "corsa")
			# La falcata segue la velocità: i piedi non scivolano mentre si accelera o si frena.
			var piena := VELOCITA * moltiplicatore_velocita() * (0.5 if passo else 1.0)
			sprite.velocita = clampf(absf(velocity.x) / piena, 0.45, 1.4)
		else:
			sprite.riproduci("fermo")
	else:
		# In aria la posa segue la velocità verticale: slancio, gambe raccolte in cima, gambe tese prima di atterrare.
		sprite.posa("arco", (velocity.y + SALTO) / (SALTO + 300.0))


func _aggiorna_piega() -> void:
	# Peso del corpo (0.1.33): ci si piega in avanti nello slancio e indietro nella frenata, appena un po'.
	if not ("piega" in sprite):
		return
	var delta := get_physics_process_delta_time()
	var obiettivo := 0.0
	if stato == Stato.ARRAMPICATA and absf(velocity.y) > 5.0:
		obiettivo = deg_to_rad(4.0) * maxf(0.0, profilo_scalata(_fase_scalata) - 1.0)   # tirando ci si porta verso la parete
	elif stato == Stato.NORMALE and delta > 0.0:
		var spinta := (velocity.x - _vx_prima) / delta * float(verso)   # accelerazione verso dove si guarda
		if is_on_floor():
			obiettivo = clampf(spinta / ACCELERAZIONE, -1.0, 1.0) * deg_to_rad(8.0) \
					+ clampf(absf(velocity.x) / VELOCITA, 0.0, 1.0) * deg_to_rad(2.0)   # di corsa un filo in avanti
		else:
			obiettivo = clampf(velocity.x * float(verso) / VELOCITA, -1.0, 1.0) * deg_to_rad(3.0)
	_vx_prima = velocity.x
	var p: float = sprite.get("piega")
	sprite.set("piega", lerpf(p, obiettivo, 1.0 - exp(-14.0 * delta)) if absf(obiettivo - p) > 0.002 else obiettivo)


func _polvere(quanta: int) -> void:
	Effetti.scoppio(get_parent(), global_position + Vector2(0, -2), Color(0.55, 0.52, 0.5, 0.6), quanta, 38.0, 0.35, 40.0,
			false, 1.0, Vector2.UP, 80.0)


func _fendente() -> void:
	Suoni.suona("fendente", global_position, -2.0, 1.15 if Armi.famiglia(Equipaggiamento.indossati.get("arma", "")) in Armi.RAPIDE else (0.8 if Armi.famiglia(Equipaggiamento.indossati.get("arma", "")) in Armi.LENTE else 1.0))
	# Scia del colpo di spada: una mezzaluna chiara che svanisce subito.
	var punti := PackedVector2Array()
	var passi := 10
	var da := -1.25 if _colpo_numero == 1 else -0.9
	var a := 1.0 if _colpo_numero == 1 else 1.25
	for i in passi + 1:
		var angolo := lerpf(da, a, float(i) / passi)
		punti.append(Vector2(cos(angolo), sin(angolo)) * 30.0)
	for i in passi + 1:
		var angolo := lerpf(a, da, float(i) / passi)
		var raggio := 30.0 - 9.0 * sin(PI * float(i) / passi)
		punti.append(Vector2(cos(angolo), sin(angolo)) * raggio)
	var arco := Polygon2D.new()
	arco.polygon = punti
	arco.color = Color(0.8, 0.86, 1.0, 0.8)
	arco.material = Effetti.materiale_luminoso()
	arco.light_mask = 0
	arco.position = Vector2(verso * 8.0, -24.0)
	arco.scale.x = verso
	arco.z_index = 5
	add_child(arco)
	var tw := arco.create_tween()
	tw.tween_property(arco, "modulate:a", 0.0, 0.14)
	tw.tween_callback(arco.queue_free)
