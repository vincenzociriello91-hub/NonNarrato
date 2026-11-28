#!/usr/bin/env python3
"""Genera tutti i suoni di NonNarrato per sintesi: niente registrazioni né pacchetti esterni.
I suoni nascono da rumore, toni e filtri calcolati qui (CC0 per costruzione).
Uso: python3 strumenti/genera_suoni.py [nome ...]   (senza nomi li rifà tutti)
Scrive arte/suoni/<nome>.wav (mono, 16 bit) e, per musica e ambiente, <nome>.ogg (stereo). Seme fisso: stesso risultato a ogni esecuzione."""
import sys
import wave
from pathlib import Path

import numpy as np
from scipy import signal

SR = 44100
SR_LUNGHI = 32000
CARTELLA = Path(__file__).resolve().parent.parent / "arte" / "suoni"
rng = np.random.default_rng(1977)


# ------------------------------------------------------------------ mattoni

def t(durata, sr=SR):
    return np.arange(int(durata * sr)) / sr


def rumore(durata, sr=SR):
    return rng.uniform(-1.0, 1.0, int(durata * sr))


def rumore_marrone(durata, sr=SR):
    r = np.cumsum(rng.uniform(-1.0, 1.0, int(durata * sr)))
    r = signal.lfilter([1.0], [1.0, -0.995], np.diff(r, prepend=0.0))
    return r / (np.max(np.abs(r)) + 1e-9)


def passa(x, tipo, freq, ordine=2, sr=SR):
    nyq = sr * 0.5
    if isinstance(freq, (list, tuple)):
        wn = [min(f / nyq, 0.99) for f in freq]
    else:
        wn = min(freq / nyq, 0.99)
    b, a = signal.butter(ordine, wn, btype=tipo)
    return signal.lfilter(b, a, x)


def banda_mobile(x, f0, f1, larghezza=0.6, sr=SR, pezzi=24):
    # Filtro passa-banda che scorre da f0 a f1 (a blocchi, sfumati).
    n = len(x)
    out = np.zeros(n)
    passo = max(1, n // pezzi)
    for i in range(0, n, passo):
        k = i / max(1, n - 1)
        f = f0 * (f1 / f0) ** k
        inizio = max(0, i - passo // 2)
        blocco = x[inizio: i + passo * 3 // 2]
        y = passa(blocco, "bandpass", [f * (1 - larghezza / 2), f * (1 + larghezza / 2)], 2, sr)
        out[inizio:inizio + len(y)] += y * np.hanning(len(y))
    return out


def inviluppo(n, attacco, decadimento, sr=SR, curva=4.0):
    a = int(attacco * sr)
    e = np.ones(n)
    if a > 0:
        e[:a] = np.linspace(0.0, 1.0, a) ** 0.6
    resto = n - a
    if resto > 0:
        e[a:] = np.exp(-curva * np.linspace(0.0, 1.0, resto) * (resto / sr) / max(decadimento, 1e-4))
    return e


def decad(durata, tau, sr=SR):
    return np.exp(-t(durata, sr) / tau)


def tono(freq, durata, forma="seno", sr=SR, fase=0.0):
    tt = t(durata, sr)
    if np.isscalar(freq):
        ph = 2 * np.pi * freq * tt + fase
    else:
        ph = 2 * np.pi * np.cumsum(freq[: len(tt)]) / sr + fase
    if forma == "seno":
        return np.sin(ph)
    if forma == "quadra":
        return np.sign(np.sin(ph))
    if forma == "sega":
        return 2.0 * ((ph / (2 * np.pi)) % 1.0) - 1.0
    if forma == "triangolo":
        return 2.0 * np.abs(2.0 * ((ph / (2 * np.pi)) % 1.0) - 1.0) - 1.0
    raise ValueError(forma)


def scorri(f0, f1, durata, sr=SR):
    return f0 * (f1 / f0) ** np.linspace(0.0, 1.0, int(durata * sr))


def corda(freq, durata, smorza=0.996, sr=SR):
    # Karplus-Strong: una corda pizzicata (balestra, arco).
    n = int(durata * sr)
    periodo = max(2, int(sr / freq))
    buf = rng.uniform(-1, 1, periodo)
    out = np.zeros(n)
    for i in range(n):
        j = i % periodo
        out[i] = buf[j]
        buf[j] = smorza * 0.5 * (buf[j] + buf[(j + 1) % periodo])
    return out


def campana(freq, durata, sr=SR, armoniche=((1.0, 1.0), (2.76, 0.45), (5.4, 0.25), (8.93, 0.12)), tau=0.6):
    out = np.zeros(int(durata * sr))
    for k, amp in armoniche:
        out += amp * tono(freq * k, durata, sr=sr) * decad(durata, tau / (1 + k * 0.4), sr)
    return out


def metallo(base, durata, sr=SR, tau=0.25):
    out = np.zeros(int(durata * sr))
    for k, amp in ((1.0, 1.0), (2.51, 0.7), (4.27, 0.5), (6.68, 0.35), (9.1, 0.2)):
        out += amp * tono(base * k * rng.uniform(0.99, 1.01), durata, sr=sr) * decad(durata, tau / (1 + k * 0.3), sr)
    return out


def riverbero(x, durata=0.8, quantita=0.25, sr=SR, scuro=2500):
    ir = rumore(durata, sr) * decad(durata, durata / 5, sr)
    ir = passa(ir, "lowpass", scuro, 1, sr)
    ir[0] = 0
    bagnato = signal.fftconvolve(x, ir)[: len(x) + int(durata * sr)]
    bagnato /= np.max(np.abs(bagnato)) + 1e-9
    asciutto = np.concatenate([x, np.zeros(len(bagnato) - len(x))])
    return asciutto + quantita * bagnato * np.max(np.abs(x))


def somma(*parti):
    n = max(len(p) for p in parti)
    out = np.zeros(n)
    for p in parti:
        out[: len(p)] += p
    return out


def ritarda(x, secondi, sr=SR):
    return np.concatenate([np.zeros(int(secondi * sr)), x])


def n_(durata, sr=SR):
    return int(durata * sr)


def scrivi(nome, x, livello=0.85, sr=SR, sfuma=0.004):
    x = np.asarray(x, dtype=np.float64)
    x -= np.mean(x)
    picco = np.max(np.abs(x)) + 1e-9
    x = x / picco * livello
    f = int(sfuma * sr)
    if f > 0 and len(x) > 2 * f:
        x[:f] *= np.linspace(0, 1, f)
        x[-f:] *= np.linspace(1, 0, f)
    dati = (np.clip(x, -1, 1) * 32767).astype("<i2")
    CARTELLA.mkdir(parents=True, exist_ok=True)
    with wave.open(str(CARTELLA / f"{nome}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(dati.tobytes())


# ------------------------------------------------------------------ suoni del personaggio

def s_passo():
    tonfo = passa(rumore(0.09), "lowpass", 420) * decad(0.09, 0.018)
    grana = passa(rumore(0.03), "bandpass", [1800, 4200]) * decad(0.03, 0.006) * 0.35
    return somma(tonfo, grana)


def s_salto():
    soffio = banda_mobile(rumore(0.16), 500, 1600, 0.8) * inviluppo(n_(0.16), 0.02, 0.08)
    stoffa = passa(rumore(0.06), "bandpass", [900, 2600]) * decad(0.06, 0.012) * 0.5
    return somma(soffio, stoffa)


def s_atterra():
    tonfo = passa(rumore(0.16), "lowpass", 260) * decad(0.16, 0.035)
    sub = tono(scorri(90, 50, 0.12), 0.12) * decad(0.12, 0.03) * 0.8
    grana = passa(rumore(0.05), "bandpass", [1500, 3800]) * decad(0.05, 0.01) * 0.3
    return somma(tonfo, sub, grana)


def s_rotola():
    n = rumore(0.38)
    mod = 0.6 + 0.4 * np.sin(2 * np.pi * 18 * t(0.38))
    return passa(n, "bandpass", [250, 900]) * mod * inviluppo(len(n), 0.03, 0.18)


def s_schiva():
    return banda_mobile(rumore(0.17), 2400, 700, 0.7) * inviluppo(n_(0.17), 0.01, 0.07)


def s_fendente():
    soffio = banda_mobile(rumore(0.2), 3200, 900, 0.6) * inviluppo(n_(0.2), 0.008, 0.07)
    lama = tono(2600, 0.1) * decad(0.1, 0.03) * 0.08
    return somma(soffio, lama)


def s_colpo():
    botta = passa(rumore(0.07), "lowpass", 1300) * decad(0.07, 0.014)
    osso = passa(rumore(0.04), "bandpass", [1500, 3200]) * decad(0.04, 0.007) * 0.7
    tonfo = tono(scorri(120, 70, 0.1), 0.1) * decad(0.1, 0.025) * 0.9
    return somma(botta, osso, tonfo)


def s_colpito():
    botta = passa(rumore(0.14), "lowpass", 700) * decad(0.14, 0.03)
    sub = tono(scorri(110, 40, 0.25), 0.25) * decad(0.25, 0.07)
    sporco = np.tanh(passa(rumore(0.1), "bandpass", [300, 1200]) * 4) * decad(0.1, 0.02) * 0.4
    return somma(botta, sub, sporco)


def s_parata():
    colpo = metallo(510, 0.6, tau=0.22)
    clic = passa(rumore(0.02), "highpass", 2500) * decad(0.02, 0.004)
    return riverbero(somma(colpo, clic), 0.4, 0.15)


def s_morte():
    n = 1.6
    drone = tono(scorri(140, 38, n), n, "sega") * inviluppo(n_(n), 0.05, 0.9)
    drone = passa(drone, "lowpass", 600)
    soffio = passa(rumore(n), "lowpass", 900) * inviluppo(n_(n), 0.4, 0.8) * 0.4
    return riverbero(somma(drone, soffio), 1.2, 0.35)


def s_tiro_vuoto():
    return passa(rumore(0.03), "bandpass", [2000, 5000]) * decad(0.03, 0.005)


# ------------------------------------------------------------------ magie e tiri

def s_magia():
    n = 0.45
    accordo = sum(tono(scorri(f, f * 1.5, n), n) for f in (440, 554, 659)) / 3
    luccichio = passa(rumore(n), "highpass", 5000) * (0.5 + 0.5 * np.sin(2 * np.pi * 30 * t(n))) * 0.25
    return riverbero(somma(accordo, luccichio) * inviluppo(n_(n), 0.03, 0.2), 0.6, 0.3)


def s_carica_pronta():
    return riverbero(campana(1318, 0.5, tau=0.3), 0.4, 0.2)


def s_esplosione():
    n = 0.9
    scoppio = passa(rumore(n), "lowpass", 1400) * decad(n, 0.16)
    boato = tono(scorri(80, 30, n), n) * decad(n, 0.25)
    return riverbero(somma(scoppio, boato * 1.2), 0.9, 0.3)


def s_dardo():
    corda_breve = corda(330, 0.25, 0.99) * decad(0.25, 0.06)
    soffio = banda_mobile(rumore(0.15), 2500, 1200, 0.7) * inviluppo(n_(0.15), 0.005, 0.06) * 0.6
    return somma(corda_breve, ritarda(soffio, 0.01))


def s_freccia():
    corda_lunga = corda(160, 0.4, 0.995) * decad(0.4, 0.1)
    soffio = banda_mobile(rumore(0.3), 2000, 900, 0.6) * inviluppo(n_(0.3), 0.01, 0.12) * 0.5
    return somma(corda_lunga, ritarda(soffio, 0.02))


def s_sfera_nemica():
    n = 0.4
    vibra = 300 * (1 + 0.06 * np.sin(2 * np.pi * 11 * t(n)))
    corpo = tono(vibra, n) * inviluppo(n_(n), 0.04, 0.2)
    nebbia = passa(rumore(n), "bandpass", [600, 1500]) * inviluppo(n_(n), 0.05, 0.2) * 0.4
    return riverbero(somma(corpo, nebbia), 0.5, 0.3)


def s_impatto_tiro():
    return somma(passa(rumore(0.06), "lowpass", 2000) * decad(0.06, 0.012),
                 tono(scorri(400, 150, 0.06), 0.06) * decad(0.06, 0.015) * 0.6)


def s_balestra():
    return somma(corda(280, 0.22, 0.99) * decad(0.22, 0.05),
                 passa(rumore(0.02), "highpass", 3000) * decad(0.02, 0.003) * 0.6)


# ------------------------------------------------------------------ nemici

def s_morte_nemico():
    out = np.zeros(n_(0.6))
    for _ in range(9):
        inizio = n_(rng.uniform(0.0, 0.35))
        clic = passa(rumore(0.04), "bandpass", [rng.uniform(900, 1800), rng.uniform(2500, 4500)]) * decad(0.04, 0.006)
        out[inizio:inizio + len(clic)] += clic * rng.uniform(0.4, 1.0)
    tonfo = passa(rumore(0.2), "lowpass", 250) * decad(0.2, 0.05)
    return somma(out, ritarda(tonfo, 0.3))


def s_risveglio():
    out = np.zeros(n_(0.45))
    for _ in range(6):
        inizio = n_(rng.uniform(0.0, 0.3))
        clic = passa(rumore(0.03), "bandpass", [1200, 3500]) * decad(0.03, 0.005)
        out[inizio:inizio + len(clic)] += clic * rng.uniform(0.3, 0.9)
    soffio = passa(rumore(0.45), "bandpass", [200, 600]) * inviluppo(n_(0.45), 0.1, 0.2) * 0.4
    return somma(out, soffio)


def s_avviso_attacco():
    # Il nemico carica il colpo: stridio che sale (segnale importante per schivare).
    n = 0.28
    stridio = banda_mobile(rumore(n), 900, 3200, 0.3) * inviluppo(n_(n), 0.2, 0.06)
    return somma(stridio, tono(scorri(500, 900, n), n, "triangolo") * inviluppo(n_(n), 0.2, 0.05) * 0.15)


def s_ruggito():
    n = 0.9
    base = passa(rumore(n), "bandpass", [140, 420]) * (0.7 + 0.3 * np.sin(2 * np.pi * 23 * t(n)))
    gola = tono(scorri(85, 60, n), n, "sega") * 0.35
    return riverbero(np.tanh(somma(base, passa(gola, "lowpass", 500)) * 2.5) * inviluppo(n_(n), 0.08, 0.4), 0.7, 0.3)


def s_pipistrello():
    n = 0.12
    return tono(scorri(4800, 2600, n), n) * inviluppo(n_(n), 0.005, 0.04) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 60 * t(n))))


def s_balzo():
    return somma(banda_mobile(rumore(0.2), 400, 1200, 0.8) * inviluppo(n_(0.2), 0.02, 0.08),
                 tono(scorri(70, 110, 0.15), 0.15) * decad(0.15, 0.05) * 0.6)


# ------------------------------------------------------------------ ambiente e oggetti

def s_raccogli():
    return riverbero(somma(campana(1318, 0.35, tau=0.25), ritarda(campana(1976, 0.45, tau=0.3), 0.07)), 0.4, 0.2)


def s_cura():
    note = (523, 659, 784, 1046)
    out = somma(*[ritarda(campana(f, 0.6, tau=0.35) * 0.7, i * 0.06) for i, f in enumerate(note)])
    return riverbero(out, 0.6, 0.3)


def s_forziere():
    n = 0.45
    tremolio = 1 + 0.03 * np.sin(2 * np.pi * 9 * t(n)) + 0.02 * rng.standard_normal(n_(n))
    cigolio = tono(scorri(110, 180, n) * tremolio, n, "sega")
    cigolio = passa(cigolio, "bandpass", [300, 1500]) * inviluppo(n_(n), 0.05, 0.25) * 0.5
    tonfo = passa(rumore(0.12), "lowpass", 400) * decad(0.12, 0.03)
    return somma(cigolio, ritarda(tonfo, 0.4), ritarda(campana(1046, 0.5, tau=0.3) * 0.5, 0.5))


def s_leva():
    return somma(metallo(180, 0.3, tau=0.08) * 0.6, passa(rumore(0.05), "lowpass", 900) * decad(0.05, 0.01))


def s_porta():
    n = 1.0
    pietra = passa(rumore_marrone(n), "lowpass", 320) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t(n)) ** 2)
    pietra *= inviluppo(n_(n), 0.1, 0.5)
    tonfo = passa(rumore(0.2), "lowpass", 200) * decad(0.2, 0.05)
    return somma(pietra, ritarda(tonfo, 0.85))


def s_spuntoni():
    return somma(passa(rumore(0.2), "highpass", 3500) * decad(0.2, 0.04), metallo(1400, 0.25, tau=0.06) * 0.4)


def s_pendolo():
    return banda_mobile(rumore(0.35), 600, 1800, 0.6) * np.sin(np.linspace(0, np.pi, n_(0.35)))


def s_crollo():
    out = np.zeros(n_(1.0))
    for _ in range(16):
        inizio = n_(rng.uniform(0.0, 0.7))
        sasso = passa(rumore(0.12), "lowpass", rng.uniform(250, 900)) * decad(0.12, 0.03)
        out[inizio:inizio + len(sasso)] += sasso * rng.uniform(0.3, 1.0)
    polvere = passa(rumore(1.0), "bandpass", [400, 1600]) * inviluppo(n_(1.0), 0.05, 0.5) * 0.3
    return riverbero(somma(out, polvere), 0.6, 0.25)


def s_barile():
    out = np.zeros(n_(0.5))
    for _ in range(7):
        inizio = n_(rng.uniform(0.0, 0.18))
        legno = passa(rumore(0.09), "bandpass", [rng.uniform(300, 600), rng.uniform(1200, 2200)]) * decad(0.09, 0.02)
        out[inizio:inizio + len(legno)] += legno * rng.uniform(0.4, 1.0)
    return somma(out, tono(scorri(180, 120, 0.12), 0.12) * decad(0.12, 0.03) * 0.5)


def s_bracere():
    n = 0.7
    soffio = passa(rumore(n), "lowpass", 1800) * inviluppo(n_(n), 0.12, 0.3)
    scoppiettio = np.zeros(n_(n))
    for _ in range(12):
        k = n_(rng.uniform(0.05, 0.6))
        scoppiettio[k:k + 200] += rng.uniform(0.3, 1.0) * decad(200 / SR, 0.001)
    return somma(soffio, passa(scoppiettio, "highpass", 1500) * 0.5)


def s_piastra():
    return somma(passa(rumore(0.06), "lowpass", 800) * decad(0.06, 0.012), metallo(320, 0.2, tau=0.05) * 0.3)


def s_ondata():
    n = 2.4
    corno = sum(tono(f * (1 + 0.003 * np.sin(2 * np.pi * 0.7 * t(n))), n, "sega") for f in (55, 82.4, 110.2)) / 3
    corno = passa(corno, "lowpass", 700) * inviluppo(n_(n), 0.5, 1.2)
    return riverbero(corno, 1.5, 0.45, scuro=1500)


def s_nemesi():
    n = 1.8
    grappolo = sum(tono(f, n, "sega") for f in (98, 103.8, 116.5, 138.6)) / 4
    grappolo = passa(grappolo, "lowpass", 900) * inviluppo(n_(n), 0.6, 0.9)
    return riverbero(grappolo, 1.4, 0.4, scuro=1800)


def s_sogno_quieto():
    out = somma(*[campana(f, 2.0, tau=1.2) * 0.6 for f in (220, 261.6, 329.6, 440)])
    return riverbero(out, 1.5, 0.4)


def s_ui_tocco():
    return tono(1250, 0.03) * decad(0.03, 0.007)


def s_ui_indietro():
    return tono(scorri(900, 600, 0.04), 0.04) * decad(0.04, 0.01)


def s_ui_apri():
    return somma(banda_mobile(rumore(0.18), 500, 1400, 0.7) * inviluppo(n_(0.18), 0.05, 0.06) * 0.6,
                 ritarda(tono(1100, 0.04) * decad(0.04, 0.01), 0.12))


# ------------------------------------------------------------------ arrampicata, acqua, crolli

def s_presa():
    # Mano che afferra la roccia: grattata secca e piccolo tonfo.
    grattata = passa(rumore(0.07), "bandpass", [1200, 3800]) * decad(0.07, 0.012)
    tonfo = passa(rumore(0.05), "lowpass", 500) * decad(0.05, 0.01) * 0.6
    return somma(grattata, tonfo)


def s_affanno():
    # Senza fiato: soffio che scende, senza voce.
    n = 0.5
    return banda_mobile(rumore(n), 900, 400, 0.8) * inviluppo(n_(n), 0.04, 0.25)


def s_tuffo():
    n = 0.7
    schizzo = passa(rumore(n), "bandpass", [600, 5000]) * inviluppo(n_(n), 0.004, 0.18)
    tonfo = tono(scorri(140, 60, 0.2), 0.2) * decad(0.2, 0.05) * 0.8
    gocce = np.zeros(n_(n))
    for _ in range(10):
        k = n_(rng.uniform(0.08, 0.55))
        f = rng.uniform(900, 2400)
        g = tono(scorri(f, f * 1.6, 0.05), 0.05) * decad(0.05, 0.012) * rng.uniform(0.2, 0.5)
        gocce[k:k + len(g)] += g[: max(0, len(gocce) - k)]
    return somma(schizzo, tonfo, gocce)


def s_bolle():
    out = np.zeros(n_(0.45))
    for _ in range(5):
        k = n_(rng.uniform(0.0, 0.35))
        f = rng.uniform(300, 700)
        b = tono(scorri(f, f * 2.2, 0.06), 0.06) * decad(0.06, 0.02) * rng.uniform(0.4, 1.0)
        out[k:k + len(b)] += b[: max(0, len(out) - k)]
    return passa(out, "lowpass", 2500)


def s_respiro():
    # Riemersione: un respiro profondo (solo aria, niente voce).
    n = 0.6
    return passa(rumore(n), "bandpass", [500, 2400]) * np.sin(np.linspace(0, np.pi, n_(n))) ** 1.5


def s_muro_rotto():
    out = s_crollo()
    colpo = passa(rumore(0.12), "lowpass", 600) * decad(0.12, 0.03)
    return somma(colpo * 1.5, out)


def s_legno_rotto():
    out = np.zeros(n_(0.5))
    for _ in range(9):
        k = n_(rng.uniform(0.0, 0.2))
        schianto = passa(rumore(0.08), "bandpass", [rng.uniform(500, 900), rng.uniform(1800, 3500)]) * decad(0.08, 0.015)
        out[k:k + len(schianto)] += schianto * rng.uniform(0.4, 1.0)
    return somma(out, tono(scorri(220, 140, 0.1), 0.1) * decad(0.1, 0.025) * 0.5)


def s_crepa():
    # Un colpo su una struttura che si sta crepando.
    return somma(passa(rumore(0.1), "lowpass", 900) * decad(0.1, 0.02),
                 passa(rumore(0.05), "bandpass", [1500, 3500]) * decad(0.05, 0.008) * 0.6)


def s_carica():
    # Un colpo che si carica: ronzio che sale (grave, con un fruscio che si schiarisce), circa 0,9 s.
    n = 0.9
    f = scorri(75, 290, n)
    corpo = passa(tono(f, n, "sega"), "lowpass", 1100) * 0.8
    ottava = tono(f * 2.0, n) * 0.35
    fruscio = banda_mobile(rumore(n), 400, 3000, 0.7) * 0.22
    crescendo = np.linspace(0.2, 1.0, n_(n)) ** 1.6
    coda = np.ones(n_(n))
    coda[-n_(0.05):] = np.linspace(1.0, 0.0, n_(0.05))
    return somma(corpo, ottava, fruscio) * crescendo * coda


def s_carica_piena():
    # Il colpo è carico: tintinnio netto di metallo, due tocchi ravvicinati.
    primo = metallo(1850, 0.3, tau=0.1)
    secondo = ritarda(metallo(2480, 0.3, tau=0.09) * 0.7, 0.07)
    clic = passa(rumore(0.02), "highpass", 3500) * decad(0.02, 0.004) * 0.6
    return somma(primo, secondo, clic)


def s_colpo_pesante():
    # Botto grave e corto: un colpo che pesa (sub che cala, tonfo, un crac sottile in cima).
    sub = tono(scorri(105, 36, 0.28), 0.28) * decad(0.28, 0.07)
    tonfo = passa(rumore(0.14), "lowpass", 520) * decad(0.14, 0.03)
    crac = passa(rumore(0.04), "bandpass", [1200, 3000]) * decad(0.04, 0.006) * 0.55
    return somma(sub * 1.1, tonfo, crac)


def s_parata_perfetta():
    # Metallo squillante, più acuto e più lungo di una parata normale, con un lampo di tintinnio in cima.
    corpo = metallo(780, 0.8, tau=0.3)
    squillo = campana(2637, 0.6, tau=0.25) * 0.5
    clic = passa(rumore(0.025), "highpass", 3000) * decad(0.025, 0.005) * 0.9
    return riverbero(somma(corpo, squillo, clic), 0.5, 0.18)


def s_esecuzione():
    # Il colpo grave e, dietro, la coda: un soffio che si spegne e un rimbombo che scende.
    colpo = somma(tono(scorri(120, 38, 0.3), 0.3) * decad(0.3, 0.08) * 1.1,
                  passa(rumore(0.12), "lowpass", 700) * decad(0.12, 0.03),
                  passa(rumore(0.04), "bandpass", [1300, 3200]) * decad(0.04, 0.006) * 0.5)
    n = 0.7
    soffio = banda_mobile(rumore(n), 1900, 220, 0.8) * inviluppo(n_(n), 0.02, 0.35) * 0.55
    rimbombo = tono(scorri(70, 32, n), n) * inviluppo(n_(n), 0.02, 0.4) * 0.5
    return riverbero(somma(colpo, ritarda(somma(soffio, rimbombo), 0.08)), 0.9, 0.25)


def s_stordito():
    # Breve e sordo: il rintocco di una testa scossa.
    n = 0.22
    rintocco = tono(scorri(310, 150, n), n, "triangolo") * decad(n, 0.07)
    tonfo = passa(rumore(0.08), "lowpass", 420) * decad(0.08, 0.02)
    return passa(somma(rintocco * 0.8, tonfo), "lowpass", 1400)


# ------------------------------------------------------------------ anelli (ambiente e musica)

def s_bevi():
    # Tre sorsi: gorgoglio a bolle che sale, poi un tintinnio di vetro.
    n = 0.55
    out = np.zeros(n_(n))
    for i in range(3):
        k = n_(0.04 + i * 0.13)
        f = 220 + i * 60
        g = tono(scorri(f, f * 1.9, 0.09), 0.09) * decad(0.09, 0.03) * 0.7
        g = g + passa(rumore(0.09), "bandpass", [300, 1200]) * decad(0.09, 0.02) * 0.25
        out[k:k + len(g)] += g[: max(0, len(out) - k)]
    vetro = ritarda(campana(2637, 0.3, tau=0.12) * 0.25, 0.45)
    return riverbero(somma(out, vetro), 0.3, 0.15)


def s_pozione_cade():
    # Una boccetta che tocca terra: due tintinnii di vetro.
    return somma(campana(2093, 0.25, tau=0.08) * 0.6, ritarda(campana(2794, 0.2, tau=0.06) * 0.35, 0.06))


def s_mimic_ruggito():
    # Coperchio che sbatte e un ringhio di legno: scricchiolio basso e gola rauca.
    n = 0.8
    legno = passa(rumore(0.12), "bandpass", [180, 900]) * decad(0.12, 0.03) * 1.2
    gola = tono(scorri(110, 70, n), n, "sega") * (0.6 + 0.4 * np.sin(2 * np.pi * 31 * t(n))) * 0.4
    ringhio = passa(rumore(n), "bandpass", [120, 500]) * (0.6 + 0.4 * np.sin(2 * np.pi * 17 * t(n)))
    corpo = np.tanh(somma(passa(gola, "lowpass", 600), ringhio) * 2.2) * inviluppo(n_(n), 0.05, 0.35)
    return riverbero(somma(legno, ritarda(corpo, 0.05)), 0.6, 0.3)


def s_mimic_morso():
    # Il coperchio che si chiude di scatto: colpo di legno secco con un clic.
    colpo = passa(rumore(0.09), "bandpass", [250, 1800]) * decad(0.09, 0.015)
    clic = tono(scorri(900, 500, 0.03), 0.03) * decad(0.03, 0.006) * 0.5
    return somma(colpo, ritarda(clic, 0.01), tono(scorri(120, 80, 0.12), 0.12) * decad(0.12, 0.03) * 0.5)


def anello(x, sr, coda):
    # Rende un suono ripetibile senza scatti: la coda finale si somma all'inizio.
    c = int(coda * sr)
    corpo = x[:-c].copy()
    corpo[:c] += x[-c:] * np.linspace(1, 0, c)
    return corpo


def piega(x, n):
    # Rende un brano lungo esattamente n campioni e ripetibile senza scatti: la coda oltre n si somma all'inizio.
    out = np.zeros((n,) + x.shape[1:])
    m = min(len(x), n)
    out[:m] = x[:m]
    resto = x[n:]
    while len(resto) > 0:
        k = min(len(resto), n)
        out[:k] += resto[:k]
        resto = resto[n:]
    return out


def corda_veloce(freq, durata, smorza=0.994, sr=SR, chiaro=0.5):
    # Karplus-Strong calcolato con un filtro (molto più veloce del ciclo): corda pizzicata.
    n = int(durata * sr)
    p = max(2, int(round(sr / freq)))
    x = np.zeros(n)
    eccita = passa(rng.uniform(-1, 1, p), "lowpass", 400 + 6000 * chiaro, 1, sr)
    x[:p] = eccita
    a = np.zeros(p + 2)
    a[0] = 1.0
    a[p] = -smorza * 0.5
    a[p + 1] = -smorza * 0.5
    return signal.lfilter([1.0], a, x)


def stereo(sx, dx):
    n = max(len(sx), len(dx))
    out = np.zeros((n, 2))
    out[: len(sx), 0] = sx
    out[: len(dx), 1] = dx
    return out


def metti(out, k, suono, pan=0.0, vol=1.0):
    # Somma un suono mono (o stereo) nel brano stereo alla posizione k, con il panorama -1..1.
    if k >= len(out):
        return
    if suono.ndim == 1:
        sx = suono * vol * np.sqrt(0.5 * (1.0 - pan))
        dx = suono * vol * np.sqrt(0.5 * (1.0 + pan))
        suono = np.stack([sx, dx], axis=1)
    else:
        suono = suono * vol
    fine = min(len(out), k + len(suono))
    out[k:fine] += suono[: fine - k]


def riverbero_stereo(x, durata, quantita, sr, scuro=2500):
    # Due code di riverbero diverse a sinistra e a destra: il suono si allarga come in una cripta.
    sx = riverbero(x[:, 0], durata, quantita, sr, scuro)
    dx = riverbero(x[:, 1], durata, quantita, sr, scuro)
    return stereo(sx, dx)


def campana_risset(freq, durata, sr, tau=8.0):
    # Campana con parziali inarmoniche (alla Risset): rintocco cupo da cattedrale.
    parziali = ((0.56, 1.0), (0.92, 0.67), (1.19, 1.0), (1.71, 1.8), (2.0, 2.67), (2.74, 1.67), (3.0, 1.46), (3.76, 1.33), (4.07, 1.33))
    out = np.zeros(int(durata * sr))
    for i, (k, amp) in enumerate(parziali):
        out += amp * tono(freq * k * (1 + 0.0015 * i), durata, sr=sr) * decad(durata, tau / (1.0 + 0.55 * i), sr)
    return out


def voce_coro(freq, durata, sr, vocale_da="a", vocale_a="o"):
    # Coro sintetico: una sega con vibrato filtrata dalle formanti di una vocale che passa lentamente a un'altra.
    formanti = {"a": (800, 1150, 2900), "o": (450, 800, 2830), "u": (325, 700, 2530)}
    tt = t(durata, sr)
    vibrato = 1.0 + 0.0087 * np.sin(2 * np.pi * 5.0 * tt + rng.uniform(0, 6.28))
    sorgente = tono(freq * vibrato, durata, "sega", sr) + 0.3 * rumore(durata, sr) * 0.2
    meta = len(tt) // 2
    out = np.zeros(len(tt))
    for parte, vocale, peso in ((sorgente[:meta + sr], vocale_da, np.linspace(1, 0, meta + sr) ** 0.5),
                                (sorgente[meta - sr:], vocale_a, np.linspace(0, 1, len(tt) - meta + sr) ** 0.5)):
        y = np.zeros(len(parte))
        for j, f in enumerate(formanti[vocale]):
            y += passa(parte, "bandpass", [f * 0.88, f * 1.12], 2, sr) * (1.0, 0.5, 0.18)[j]
        y *= peso
        if vocale == vocale_da:
            out[: len(y)] += y
        else:
            out[meta - sr: meta - sr + len(y)] += y
    return out


# Musica a strati (0.1.29): tre brani lunghi uguali che suonano insieme e si alzano o abbassano col gioco.
# Mi frigio (la seconda minore Mi-Fa è il colore "minaccioso"), 60 battiti al minuto, 16 battute = 64 secondi.
MUSICA_SR = 32000
MUSICA_S = 64.0
BATTITO = 1.0
# Un accordo ogni 4 battute: Mi minore, Fa (II bemolle del frigio), Re minore, Do con la settima.
ACCORDI = [
    (82.41, (164.81, 196.00, 246.94)),
    (87.31, (174.61, 220.00, 261.63)),
    (73.42, (146.83, 174.61, 220.00)),
    (65.41, (130.81, 164.81, 196.00, 246.94)),
]


def s_musica_base():
    # Esplorazione: bordone basso (Mi + quinta + tritono), tappeto d'archi scuri, rintocchi rari.
    sr = MUSICA_SR
    n = int(MUSICA_S * sr)
    coda = 10.0
    durata = MUSICA_S + coda
    tt = t(durata, sr)
    out = np.zeros((len(tt), 2))
    # Bordone: frequenze dell'ondulazione intere sui 64 s, così il giro si ripete senza scatti.
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * (3.0 / MUSICA_S) * tt)
    for f, vol, pan in ((41.20, 1.0, -0.2), (41.38, 0.8, 0.2), (61.74, 0.5, 0.0), (58.27, 0.22, 0.4)):
        v = tono(f, durata, "sega", sr)
        v = passa(v, "lowpass", 260, 2, sr) * (0.55 + 0.45 * lfo)
        metti(out, 0, v, pan, vol * 0.18)
    # Archi: ogni accordo dura 16 s, entra in 3 s e sfuma in 6 s sopra il successivo.
    for i, (basso, note) in enumerate(ACCORDI):
        k = int(i * 16.0 * sr)
        d = 16.0 + 6.0
        env = inviluppo(int(d * sr), 3.0, 1e9, sr)
        rilascio = int(6.0 * sr)
        env[-rilascio:] *= np.linspace(1, 0, rilascio) ** 1.5
        for j, f in enumerate(note):
            for dt, pan in ((-0.004, -0.6), (0.004, 0.6)):
                v = tono(f * (1 + dt) * (1 + 0.0015 * j), d, "sega", sr)
                v = passa(v, "lowpass", 1300, 2, sr) * env
                metti(out, k, v, pan, 0.13)
            # Un velo un'ottava sopra (seno): sull'altoparlante del telefono i bassi non si sentono, questo sì.
            metti(out, k, tono(f * 2.003, d, sr=sr) * env, (-0.3, 0.3, 0.0, 0.15)[j % 4], 0.035)
        b = passa(tono(basso / 2, d, "sega", sr), "lowpass", 180, 2, sr) * env
        metti(out, k, b, 0.0, 0.22)
    # Rintocchi: pochi, lontani, in punti fissi (seme fisso) e non sopra il cambio d'accordo.
    for quando, f in ((5.0, 164.81), (19.5, 174.61), (29.0, 246.94), (41.5, 146.83), (52.0, 196.00), (60.5, 164.81)):
        c = campana_risset(f, 9.0, sr, tau=7.0)
        metti(out, int(quando * sr), c, rng.uniform(-0.5, 0.5), 0.07)
    out = riverbero_stereo(out, 3.2, 0.55, sr, 2000)
    return piega(out, n), sr


def s_musica_presenza():
    # Tensione: battito lento nel petto, un grappolo di note che vibra, un coro lontano che segue gli accordi.
    sr = MUSICA_SR
    n = int(MUSICA_S * sr)
    durata = MUSICA_S + 8.0
    out = np.zeros((int(durata * sr), 2))
    battito = somma(tono(scorri(62, 44, 0.16, sr), 0.16, sr=sr) * decad(0.16, 0.05, sr),
                    passa(rumore(0.04, sr), "lowpass", 220, 2, sr) * decad(0.04, 0.008, sr) * 0.4,
                    tono(124, 0.12, sr=sr) * decad(0.12, 0.03, sr) * 0.35)   # armonica: il battito si sente anche dal telefono
    for b in range(int(MUSICA_S / BATTITO)):
        if b % 2 == 0:
            k = int(b * BATTITO * sr)
            metti(out, k, battito, 0.0, 0.8)
            metti(out, k + int(0.27 * sr), battito, 0.0, 0.55)
    # Grappolo (Mi-Fa-Fa#) che sale e scende ogni 8 s, con un tremolo di 6 Hz.
    tt = t(MUSICA_S, sr)
    onda = (0.5 - 0.5 * np.cos(2 * np.pi * tt / 8.0)) ** 2
    tremolo = 0.75 + 0.25 * np.sin(2 * np.pi * 6.0 * tt)
    for f, pan in ((329.63, -0.5), (349.23, 0.5), (369.99, 0.0)):
        v = passa(tono(f, MUSICA_S, "triangolo", sr), "lowpass", 1800, 2, sr) * onda * tremolo
        metti(out, 0, v, pan, 0.06)
    for i, (_basso, note) in enumerate(ACCORDI):
        for j, f in enumerate(note[:3]):
            v = voce_coro(f, 15.0, sr, "a" if i % 2 == 0 else "o", "o" if i % 2 == 0 else "u")
            env = inviluppo(len(v), 3.5, 1e9, sr)
            env[-int(5 * sr):] *= np.linspace(1, 0, int(5 * sr))
            metti(out, int((i * 16.0 + 0.5) * sr), v * env, (-0.5, 0.5, 0.0)[j], 0.16)
    out = riverbero_stereo(out, 2.6, 0.5, sr, 2400)
    return piega(out, n), sr


def s_musica_lotta():
    # Combattimento: tamburi gravi in ottavi (sembra il doppio della velocità), corde pizzicate ostinate,
    # un colpo di metallo a ogni frase. Segue gli stessi accordi degli altri strati.
    sr = MUSICA_SR
    n = int(MUSICA_S * sr)
    durata = MUSICA_S + 6.0
    out = np.zeros((int(durata * sr), 2))
    tamburo = somma(tono(np.concatenate([scorri(110, 46, 0.18, sr), np.full(int(0.24 * sr), 46.0)]), 0.42, sr=sr) * decad(0.42, 0.11, sr),
                    passa(rumore(0.06, sr), "lowpass", 380, 2, sr) * decad(0.06, 0.012, sr) * 0.8)
    legno = passa(rumore(0.05, sr), "bandpass", [1800, 4200], 2, sr) * decad(0.05, 0.01, sr)
    ritmi = ([1, 0, 0, 1, 0, 0, 1, 0], [1, 0, 0, 1, 0, 1, 0, 0], [1, 0, 0, 1, 0, 0, 1, 0], [1, 0, 1, 0, 1, 1, 1, 1])
    ottavo = BATTITO / 2.0
    for battuta in range(16):
        ritmo = ritmi[battuta % 4]
        for j, colpo in enumerate(ritmo):
            k = int((battuta * 4 + j * 0.5) * sr)
            if colpo:
                accento = 1.0 if j == 0 else 0.7
                metti(out, k, tamburo * (0.97 + 0.06 * rng.uniform()), rng.uniform(-0.15, 0.15), 0.55 * accento)
            if j in (2, 6):
                metti(out, k, legno, 0.45 if j == 2 else -0.45, 0.10)
    # Corde pizzicate: la fondamentale dell'accordo, con la seconda minore e la terza (frigio), in sedicesimi.
    figura = [0, 0, 1, 0, 3, 0, 1, 0]
    for battuta in range(16):
        basso = ACCORDI[battuta // 4][0]
        scala = [basso, basso * 2 ** (1 / 12), basso * 2 ** (3 / 12), basso * 2 ** (3 / 12) * 1.0]
        for j in range(16):
            f = scala[figura[j % 8]]
            k = int((battuta * 4 + j * 0.25) * sr)
            c = corda_veloce(f, 0.6, 0.992, sr, 0.35)
            c = passa(c, "lowpass", 1400, 2, sr)
            metti(out, k, c, -0.3 if j % 2 else 0.3, 0.16 if j % 4 == 0 else 0.11)
    # Ottoni scuri a ogni frase di 4 battute: quinta vuota che si apre.
    for frase in range(4):
        basso = ACCORDI[frase][0]
        d = 3.0
        apre = np.linspace(300, 1400, int(d * sr))
        for f in (basso, basso * 1.5, basso * 2):
            v = tono(f, d, "sega", sr)
            v = banda_mobile(v, 300, 1300, 1.2, sr, 12) * inviluppo(int(d * sr), 0.25, 1.2, sr, 2.0)
            metti(out, int(frase * 16.0 * sr), v, 0.0, 0.10)
        met = metallo(basso * 4, 2.5, sr, 0.5)
        metti(out, int(frase * 16.0 * sr), met, 0.0, 0.06)
    out = riverbero_stereo(out, 1.4, 0.3, sr, 3000)
    return piega(out, n), sr


AMBIENTE_S = 48.0


def goccia(sr):
    f0 = rng.uniform(1300, 1800)
    d = 0.09
    frequenza = np.concatenate([scorri(f0, f0 * 0.42, 0.03, sr), np.full(int(d * sr), f0 * 0.42)])
    return tono(frequenza, d, sr=sr) * decad(d, 0.03, sr)


def s_ambiente_cripta():
    # Vento che passa fra le pietre, gocce che cadono lontano con molta eco, un rombo bassissimo.
    sr = MUSICA_SR
    n = int(AMBIENTE_S * sr)
    durata = AMBIENTE_S + 4.0
    tt = t(durata, sr)
    out = np.zeros((len(tt), 2))
    for lato, fase in ((-0.7, 0.0), (0.7, 2.1)):
        v = rumore_marrone(durata, sr)
        mod = 0.55 + 0.45 * np.sin(2 * np.pi * (2.0 / AMBIENTE_S) * tt + fase) * np.sin(2 * np.pi * (5.0 / AMBIENTE_S) * tt + fase * 0.5)
        v = banda_mobile(v, 180, 520, 0.9, sr, 16) * mod
        metti(out, 0, v, lato, 0.5)
    rombo = passa(rumore_marrone(durata, sr), "lowpass", 70, 2, sr)
    metti(out, 0, rombo, 0.0, 0.6)
    gocce = np.zeros((len(tt), 2))
    quando = 0.6
    while quando < AMBIENTE_S:
        metti(gocce, int(quando * sr), goccia(sr), rng.uniform(-0.9, 0.9), rng.uniform(0.12, 0.35))
        quando += rng.uniform(0.8, 4.0)
    out += riverbero_stereo(gocce, 2.2, 0.8, sr, 3500)[: len(tt)]
    return piega(out, n), sr


def s_ambiente_sotto():
    # Sotterraneo: acqua che scorre e gorgoglia, gocce più vicine, un bordone basso che si sente appena.
    sr = MUSICA_SR
    n = int(AMBIENTE_S * sr)
    durata = AMBIENTE_S + 4.0
    tt = t(durata, sr)
    out = np.zeros((len(tt), 2))
    for lato in (-0.6, 0.6):
        acqua = passa(rumore(durata, sr), "bandpass", [380, 1900], 2, sr)
        granuli = np.zeros(len(tt))
        for _ in range(int(durata * 30)):
            k = int(rng.uniform(0, len(tt) - 800))
            g = tono(rng.uniform(300, 900), 0.02, sr=sr) * np.hanning(int(0.02 * sr))
            granuli[k:k + len(g)] += g * rng.uniform(0.1, 0.5)
        mod = 0.7 + 0.3 * np.sin(2 * np.pi * (3.0 / AMBIENTE_S) * tt + lato)
        metti(out, 0, (acqua * 0.35 + granuli * 0.4) * mod, lato, 0.45)
    bordone = passa(tono(41.2, durata, "sega", sr), "lowpass", 120, 2, sr)
    metti(out, 0, bordone, 0.0, 0.10)
    gocce = np.zeros((len(tt), 2))
    quando = 0.3
    while quando < AMBIENTE_S:
        metti(gocce, int(quando * sr), goccia(sr), rng.uniform(-0.9, 0.9), rng.uniform(0.2, 0.45))
        quando += rng.uniform(0.6, 2.5)
    out += riverbero_stereo(gocce, 1.4, 0.6, sr, 4000)[: len(tt)]
    return piega(out, n), sr


def scrivi_ogg(nome, x, sr, livello, qualita=3):
    # Brani lunghi: OGG Vorbis stereo (molto più leggero del WAV), con ffmpeg.
    import subprocess
    import tempfile
    x = np.asarray(x, dtype=np.float64)
    x -= np.mean(x, axis=0)
    x = x / (np.max(np.abs(x)) + 1e-9) * livello
    dati = (np.clip(x, -1, 1) * 32767).astype("<i2")
    canali = 1 if dati.ndim == 1 else dati.shape[1]
    with tempfile.TemporaryDirectory() as cartella:
        wav = Path(cartella) / "brano.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(canali)
            w.setsampwidth(2)
            w.setframerate(sr)
            w.writeframes(dati.tobytes())
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav), "-c:a", "libvorbis",
                        "-q:a", str(qualita), "-map_metadata", "-1", str(CARTELLA / f"{nome}.ogg")], check=True)


SUONI = {
    "passo": s_passo, "salto": s_salto, "atterra": s_atterra, "rotola": s_rotola, "schiva": s_schiva,
    "fendente": s_fendente, "colpo": s_colpo, "colpito": s_colpito, "parata": s_parata, "morte": s_morte,
    "tiro_vuoto": s_tiro_vuoto, "magia": s_magia, "carica_pronta": s_carica_pronta, "esplosione": s_esplosione,
    "dardo": s_dardo, "freccia": s_freccia, "sfera_nemica": s_sfera_nemica, "impatto_tiro": s_impatto_tiro,
    "balestra": s_balestra, "morte_nemico": s_morte_nemico, "risveglio": s_risveglio,
    "avviso_attacco": s_avviso_attacco, "ruggito": s_ruggito, "pipistrello": s_pipistrello, "balzo": s_balzo,
    "raccogli": s_raccogli, "cura": s_cura, "forziere": s_forziere, "leva": s_leva, "porta": s_porta,
    "spuntoni": s_spuntoni, "pendolo": s_pendolo, "crollo": s_crollo, "barile": s_barile, "bracere": s_bracere,
    "piastra": s_piastra, "ondata": s_ondata, "nemesi": s_nemesi, "sogno_quieto": s_sogno_quieto,
    "ui_tocco": s_ui_tocco, "ui_indietro": s_ui_indietro, "ui_apri": s_ui_apri,
    "presa": s_presa, "affanno": s_affanno, "tuffo": s_tuffo, "bolle": s_bolle, "respiro": s_respiro,
    "muro_rotto": s_muro_rotto, "legno_rotto": s_legno_rotto, "crepa": s_crepa,
    "bevi": s_bevi, "pozione_cade": s_pozione_cade, "mimic_ruggito": s_mimic_ruggito, "mimic_morso": s_mimic_morso,
    "carica": s_carica, "carica_piena": s_carica_piena, "colpo_pesante": s_colpo_pesante,
    "parata_perfetta": s_parata_perfetta, "esecuzione": s_esecuzione, "stordito": s_stordito,
}
# Brani lunghi in OGG: livello di picco (gli strati della musica suonano insieme: la somma resta sotto 1).
LUNGHI = {"musica_base": (s_musica_base, 0.42), "musica_presenza": (s_musica_presenza, 0.30),
          "musica_lotta": (s_musica_lotta, 0.42), "ambiente_cripta": (s_ambiente_cripta, 0.55),
          "ambiente_sotto": (s_ambiente_sotto, 0.55)}
# I suoni della 0.1.43 non sono più forti di "colpo" (picco 0,62, 100 ms più rumorosi a -15,9 dB RMS).
LIVELLI = {"carica": 0.31, "carica_piena": 0.58, "colpo_pesante": 0.43, "parata_perfetta": 0.52, "esecuzione": 0.39, "stordito": 0.46,
           "pozione_cade": 0.5, "presa": 0.5, "bolle": 0.5, "passo": 0.5, "ui_tocco": 0.5, "ui_indietro": 0.5, "tiro_vuoto": 0.5}


def main():
    scelti = sys.argv[1:] or list(SUONI) + list(LUNGHI)
    for nome in scelti:
        if nome in SUONI:
            scrivi(nome, SUONI[nome](), LIVELLI.get(nome, 0.85))
        elif nome in LUNGHI:
            funzione, livello = LUNGHI[nome]
            x, sr = funzione()
            scrivi_ogg(nome, x, sr, livello)
        else:
            print("sconosciuto:", nome)
            continue
        print("ok", nome)


if __name__ == "__main__":
    main()
