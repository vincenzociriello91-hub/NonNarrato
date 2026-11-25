#!/usr/bin/env python3
"""Strumento di lavoro: scompatta i file GLB compressi con EXT_meshopt_compression,
che Godot non sa aprire (per esempio le animazioni di Mesh2Motion).

Uso:
    python3 strumenti/meshopt_decomprimi.py entrata.glb uscita.glb [altre coppie...]

Supporta la modalità ATTRIBUTES (formato 0) con i filtri NONE, OCTAHEDRAL, QUATERNION
ed EXPONENTIAL: è quello che serve per animazioni e scheletri. Le modalità TRIANGLES e
INDICES (mesh compresse) danno errore.
"""
import json
import struct
import sys

import numpy as np

BLOCCO_BYTE = 8192
GRUPPO = 16
BLOCCO_MASSIMO = 256
CODA_MINIMA_V0 = 32


def _blocco_vertici(dimensione: int) -> int:
    risultato = (BLOCCO_BYTE // dimensione) & ~(GRUPPO - 1)
    return min(risultato, BLOCCO_MASSIMO)


def _unzigzag(v: np.ndarray) -> np.ndarray:
    v = v.astype(np.int16)
    return ((-(v & 1)) ^ (v >> 1)).astype(np.uint8)


def _decodifica_gruppo(dati: bytes, pos: int, bit_log2: int):
    if bit_log2 == 0:
        return [0] * 16, pos
    if bit_log2 == 3:
        return list(dati[pos:pos + 16]), pos + 16
    bit = 1 << bit_log2          # 2 oppure 4
    impacchettati = bit * 2      # 4 oppure 8 byte
    sentinella = (1 << bit) - 1
    extra = pos + impacchettati
    valori = []
    for b in dati[pos:pos + impacchettati]:
        for _ in range(8 // bit):
            v = b >> (8 - bit)
            b = (b << bit) & 0xFF
            if v == sentinella:
                valori.append(dati[extra])
                extra += 1
            else:
                valori.append(v)
    return valori, extra


def _decodifica_byte(dati: bytes, pos: int, quanti: int):
    gruppi = quanti // GRUPPO
    dim_testata = (gruppi + 3) // 4
    testata = dati[pos:pos + dim_testata]
    pos += dim_testata
    uscita = []
    for g in range(gruppi):
        bit_log2 = (testata[g // 4] >> ((g % 4) * 2)) & 3
        valori, pos = _decodifica_gruppo(dati, pos, bit_log2)
        uscita.extend(valori)
    return np.array(uscita, dtype=np.uint8), pos


def decodifica_attributi(dati: bytes, quanti: int, dimensione: int) -> bytes:
    if (dati[0] & 0xF0) != 0xA0:
        raise ValueError("intestazione non valida")
    versione = dati[0] & 0x0F
    if versione != 0:
        raise ValueError("formato %d non supportato (solo 0)" % versione)
    coda = max(dimensione, CODA_MINIMA_V0)
    if len(dati) < 1 + coda:
        raise ValueError("dati troppo corti")
    ultimo = np.frombuffer(dati[len(dati) - dimensione:], dtype=np.uint8).copy()
    fine = len(dati) - coda
    uscita = np.zeros((quanti, dimensione), dtype=np.uint8)
    blocco = _blocco_vertici(dimensione)
    pos = 1
    for inizio in range(0, quanti, blocco):
        n = min(blocco, quanti - inizio)
        allineati = (n + GRUPPO - 1) & ~(GRUPPO - 1)
        for k in range(dimensione):
            delta, pos = _decodifica_byte(dati, pos, allineati)
            if pos > fine:
                raise ValueError("dati finiti prima del previsto")
            valori = np.cumsum(_unzigzag(delta[:n]).astype(np.uint32)) + int(ultimo[k])
            uscita[inizio:inizio + n, k] = (valori & 0xFF).astype(np.uint8)
            ultimo[k] = uscita[inizio + n - 1, k]
    return uscita.tobytes()


def filtro_quaternione(raw: bytes, quanti: int) -> bytes:
    d = np.frombuffer(raw, dtype=np.int16).reshape(quanti, 4).astype(np.int32)
    scala = 1.0 / np.sqrt(2.0)
    sf = (d[:, 3] | 3).astype(np.float32)
    ss = scala / sf
    x = d[:, 0] * ss
    y = d[:, 1] * ss
    z = d[:, 2] * ss
    ww = 1.0 - x * x - y * y - z * z
    w = np.sqrt(np.maximum(ww, 0.0))

    def a_int(v):
        return (v * 32767.0 + np.where(v >= 0, 0.5, -0.5)).astype(np.int32)

    xf, yf, zf, wf = a_int(x), a_int(y), a_int(z), a_int(w)
    qc = d[:, 3] & 3
    uscita = np.zeros((quanti, 4), dtype=np.int16)
    righe = np.arange(quanti)
    uscita[righe, (qc + 1) & 3] = xf
    uscita[righe, (qc + 2) & 3] = yf
    uscita[righe, (qc + 3) & 3] = zf
    uscita[righe, (qc + 0) & 3] = wf
    return uscita.tobytes()


def filtro_ottaedrico(raw: bytes, quanti: int, passo: int) -> bytes:
    if passo == 4:
        d = np.frombuffer(raw, dtype=np.int8).reshape(quanti, 4).astype(np.float32)
        massimo = 127.0
        tipo = np.int8
    else:
        d = np.frombuffer(raw, dtype=np.int16).reshape(quanti, 4).astype(np.float32)
        massimo = 32767.0
        tipo = np.int16
    one = d[:, 2]
    x = d[:, 0] / one
    y = d[:, 1] / one
    z = 1.0 - np.abs(x) - np.abs(y)
    t = np.maximum(-z, 0.0)
    x = x - np.where(x >= 0, t, -t)
    y = y - np.where(y >= 0, t, -t)
    lunghezza = np.sqrt(x * x + y * y + z * z)
    s = massimo / np.maximum(lunghezza, 1e-12)
    uscita = np.stack([np.round(x * s), np.round(y * s), np.round(z * s), d[:, 3]], axis=1)
    return uscita.astype(tipo).tobytes()


def filtro_esponenziale(raw: bytes) -> bytes:
    v = np.frombuffer(raw, dtype=np.int32)
    e = v >> 24
    m = (v << 8) >> 8
    return np.ldexp(m.astype(np.float64), e).astype(np.float32).tobytes()


def scompatta(entrata: str, uscita: str) -> None:
    f = open(entrata, "rb").read()
    magia = struct.unpack_from("<I", f, 0)[0]
    if magia != 0x46546C67:
        raise ValueError("non è un file GLB")
    lunghezza_json = struct.unpack_from("<I", f, 12)[0]
    doc = json.loads(f[20:20 + lunghezza_json])
    pos = 20 + lunghezza_json
    binario = b""
    if pos < len(f):
        lunghezza_bin = struct.unpack_from("<I", f, pos)[0]
        binario = f[pos + 8:pos + 8 + lunghezza_bin]

    nuovo = bytearray()
    for vista in doc.get("bufferViews", []):
        est = vista.get("extensions", {}).get("EXT_meshopt_compression")
        if est is None:
            if vista["buffer"] != 0:
                raise ValueError("vista non compressa fuori dal buffer principale")
            inizio = vista.get("byteOffset", 0)
            pezzo = binario[inizio:inizio + vista["byteLength"]]
        else:
            if est.get("mode") != "ATTRIBUTES":
                raise ValueError("modalità %s non supportata" % est.get("mode"))
            inizio = est.get("byteOffset", 0)
            compressi = binario[inizio:inizio + est["byteLength"]]
            pezzo = decodifica_attributi(compressi, est["count"], est["byteStride"])
            filtro = est.get("filter", "NONE")
            if filtro == "QUATERNION":
                pezzo = filtro_quaternione(pezzo, est["count"])
            elif filtro == "EXPONENTIAL":
                pezzo = filtro_esponenziale(pezzo)
            elif filtro == "OCTAHEDRAL":
                pezzo = filtro_ottaedrico(pezzo, est["count"], est["byteStride"])
            elif filtro != "NONE":
                raise ValueError("filtro %s non supportato" % filtro)
            del vista["extensions"]["EXT_meshopt_compression"]
            if not vista["extensions"]:
                del vista["extensions"]
        while len(nuovo) % 4:
            nuovo.append(0)
        vista["buffer"] = 0
        vista["byteOffset"] = len(nuovo)
        vista["byteLength"] = len(pezzo)
        nuovo.extend(pezzo)
    while len(nuovo) % 4:
        nuovo.append(0)

    doc["buffers"] = [{"byteLength": len(nuovo)}]
    for chiave in ("extensionsUsed", "extensionsRequired"):
        if chiave in doc:
            doc[chiave] = [e for e in doc[chiave] if e != "EXT_meshopt_compression"]
            if not doc[chiave]:
                del doc[chiave]

    testo = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    while len(testo) % 4:
        testo += b" "
    totale = 12 + 8 + len(testo) + 8 + len(nuovo)
    with open(uscita, "wb") as g:
        g.write(struct.pack("<III", 0x46546C67, 2, totale))
        g.write(struct.pack("<II", len(testo), 0x4E4F534A))
        g.write(testo)
        g.write(struct.pack("<II", len(nuovo), 0x004E4942))
        g.write(bytes(nuovo))


def main() -> None:
    argomenti = sys.argv[1:]
    if not argomenti or len(argomenti) % 2:
        print(__doc__)
        sys.exit(1)
    for i in range(0, len(argomenti), 2):
        scompatta(argomenti[i], argomenti[i + 1])
        print("scompattato:", argomenti[i + 1])


if __name__ == "__main__":
    main()
