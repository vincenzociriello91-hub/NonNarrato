#!/usr/bin/env python3
"""Genera tutti i suoni di NonNarrato per sintesi: niente registrazioni né pacchetti esterni.
I suoni nascono da rumore, toni e filtri calcolati qui (CC0 per costruzione).
Uso: python3 strumenti/genera_suoni.py [nome ...]   (senza nomi li rifà tutti)
Scrive arte/suoni/<nome>.wav (mono, 16 bit). Seme fisso: stesso risultato a ogni esecuzione."""
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


# ------------------------------------------------------------------ anelli (ambiente e musica)

def anello(x, sr, coda):
    # Rende un suono ripetibile senza scatti: la coda finale si somma all'inizio.
    c = int(coda * sr)
    corpo = x[:-c].copy()
    corpo[:c] += x[-c:] * np.linspace(1, 0, c)
    return corpo


def s_ambiente():
    sr = SR_LUNGHI
    n = 26.0
    tt = t(n, sr)
    drone = (np.sin(2 * np.pi * 41.0 * tt) + np.sin(2 * np.pi * 41.35 * tt) + 0.5 * np.sin(2 * np.pi * 61.7 * tt)) * 0.35
    vento = passa(rumore_marrone(n, sr), "lowpass", 380, 2, sr) * (0.6 + 0.4 * np.sin(2 * np.pi * tt / 13.0))
    gocce = np.zeros(len(tt))
    for _ in range(22):
        k = int(rng.uniform(0.2, n - 1.0) * sr)
        f = rng.uniform(900, 2200)
        g = tono(scorri(f, f * 0.6, 0.18, sr), 0.18, sr=sr) * decad(0.18, 0.03, sr) * rng.uniform(0.15, 0.4)
        gocce[k:k + len(g)] += g
    gocce = riverbero(gocce, 1.2, 0.6, sr, 3000)[: len(tt)]
    out = drone * 0.8 + vento * 0.6 + gocce
    return anello(out, sr, 2.0), sr


def s_musica():
    sr = SR_LUNGHI
    battuta = 4.0
    accordi = [(110.0, 130.8, 164.8), (87.3, 110.0, 130.8), (73.4, 87.3, 110.0), (82.4, 103.8, 123.5)]
    giri = 2
    n = battuta * len(accordi) * giri + 4.0  # 32 s di musica più la coda che torna all'inizio
    out = np.zeros(int(n * sr))
    melodia = [659.3, 587.3, 523.3, 493.9, 440.0, 523.3, 493.9, 415.3]
    pos = 0.0
    m = 0
    for _ in range(giri):
        for ac in accordi:
            k = int(pos * sr)
            durata = battuta + 1.5
            for f in ac:
                v = tono(f * (1 + 0.002 * rng.standard_normal()), durata, "sega", sr) + tono(f * 1.003, durata, "sega", sr)
                v = passa(v, "lowpass", 700, 2, sr) * inviluppo(int(durata * sr), 1.2, 2.5, sr, 2.0) * 0.12
                fine = min(len(out), k + len(v))
                out[k:fine] += v[: fine - k]
            basso = tono(ac[0] / 2, durata, "seno", sr) * inviluppo(int(durata * sr), 0.4, 2.5, sr, 2.0) * 0.25
            fine = min(len(out), k + len(basso))
            out[k:fine] += basso[: fine - k]
            for j in range(2):
                if rng.uniform() < 0.8:
                    kk = int((pos + 0.5 + j * 2.0 + rng.uniform(0, 0.4)) * sr)
                    c = campana(melodia[m % len(melodia)], 2.0, sr, tau=0.9) * 0.18
                    fine = min(len(out), kk + len(c))
                    out[kk:fine] += c[: fine - kk]
                    m += 1
            pos += battuta
    out = riverbero(out, 2.5, 0.5, sr, 2200)[: len(out)]
    return anello(out, sr, 4.0), sr


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
}
LUNGHI = {"ambiente": s_ambiente, "musica": s_musica}
LIVELLI = {"presa": 0.5, "bolle": 0.5, "passo": 0.5, "ui_tocco": 0.5, "ui_indietro": 0.5, "tiro_vuoto": 0.5, "ambiente": 0.7, "musica": 0.7}


def main():
    scelti = sys.argv[1:] or list(SUONI) + list(LUNGHI)
    for nome in scelti:
        if nome in SUONI:
            scrivi(nome, SUONI[nome](), LIVELLI.get(nome, 0.85))
        elif nome in LUNGHI:
            x, sr = LUNGHI[nome]()
            scrivi(nome, x, LIVELLI.get(nome, 0.8), sr, sfuma=0.0)
        else:
            print("sconosciuto:", nome)
            continue
        print("ok", nome)


if __name__ == "__main__":
    main()
