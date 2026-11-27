shader_type canvas_item;
// Ultimo passaggio sull'immagine del gioco, quando viene ingrandita sullo schermo:
//  - filtro di ingrandimento: 0 nitido (pixel pieni), 1 liscio (bordi dei pixel ammorbiditi),
//    2 SGSR (Snapdragon Game Super Resolution 1 di Qualcomm, ingrandimento con recupero dei bordi);
//  - luminosità (gamma) e contrasto;
//  - correzione per il daltonismo (1 protanopia, 2 deuteranopia, 3 tritanopia);
//  - bagliore (0.1.36): le parti luminose sfocate dalla tela piccola di bagliore.gdshader, sommate;
//  - colori del film (0.1.36): ombre fredde, luci calde, un po' meno saturazione, bordi più scuri.
// L'immagine arriva in "sorgente" (la imposta principale.gd): le funzioni non possono ricevere TEXTURE.
//
// La parte SGSR è un adattamento di sgsr1_shader_mobile.frag:
// Copyright (c) 2023, 2025, Qualcomm Innovation Center, Inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause (testo completo della licenza in CREDITS.md).

uniform sampler2D sorgente : filter_linear, repeat_disable;
uniform int filtro = 0;
uniform float nitidezza = 2.0;
uniform float gamma_scelta = 1.0;
uniform float contrasto = 1.0;
uniform int daltonismo = 0;
uniform sampler2D bagliore_tex : filter_linear, repeat_disable;
uniform float bagliore = 0.0;
uniform bool toni = false;

float luma(ivec2 p, ivec2 massimo, sampler2D tex) {
	// Come il modo "RGBA" di SGSR: il verde fa da luminosità.
	return texelFetch(tex, clamp(p, ivec2(0), massimo), 0).g;
}

float lanczos2_veloce(float x) {
	float wa = x - 4.0;
	float wb = x * wa - wa;
	wa *= wa;
	return wb * wa;
}

vec2 peso(float dx, float dy, float c, float std) {
	float x = (dx * dx + dy * dy) * 0.55 + clamp(abs(c) * std, 0.0, 1.0);
	float w = lanczos2_veloce(x);
	return vec2(w, w * c);
}

vec3 sgsr(sampler2D tex, vec2 uv) {
	vec3 colore = texture(tex, uv).rgb;
	ivec2 dim = textureSize(tex, 0);
	ivec2 massimo = dim - ivec2(1);
	vec2 punto = uv * vec2(dim) - 0.5;
	vec2 base = floor(punto);
	vec2 pl = punto - base;
	ivec2 p = ivec2(base);
	// I 12 campioni attorno al punto (vedi la versione originale con textureGather).
	float l_x = luma(p + ivec2(-1, 1), massimo, tex);
	float l_y = luma(p + ivec2(0, 1), massimo, tex);
	float l_z = luma(p, massimo, tex);
	float l_w = luma(p + ivec2(-1, 0), massimo, tex);
	float c = colore.g;
	float voto = abs(l_z - l_y) + abs(c - l_y) + abs(c - l_z);
	if (voto <= 8.0 / 255.0) {
		return colore;
	}
	float r_x = luma(p + ivec2(1, 1), massimo, tex);
	float r_y = luma(p + ivec2(2, 1), massimo, tex);
	float r_z = luma(p + ivec2(2, 0), massimo, tex);
	float r_w = luma(p + ivec2(1, 0), massimo, tex);
	float u_x = luma(p + ivec2(0, -1), massimo, tex);
	float u_y = luma(p + ivec2(1, -1), massimo, tex);
	float u_z = luma(p + ivec2(1, 2), massimo, tex);
	float u_w = luma(p + ivec2(0, 2), massimo, tex);
	float media = (l_y + l_z + r_x + r_w) * 0.25;
	vec4 sx = vec4(l_x, l_y, l_z, l_w) - media;
	vec4 dx = vec4(r_x, r_y, r_z, r_w) - media;
	vec4 su = vec4(u_x, u_y, u_z, u_w) - media;
	float cw = c - media;
	float somma = abs(sx.x) + abs(sx.y) + abs(sx.z) + abs(sx.w) + abs(dx.x) + abs(dx.y) + abs(dx.z) + abs(dx.w)
		+ abs(su.x) + abs(su.y) + abs(su.z) + abs(su.w);
	float std = 2.181818 / max(somma, 1e-4);
	vec2 a = peso(pl.x, pl.y + 1.0, su.x, std);
	a += peso(pl.x - 1.0, pl.y + 1.0, su.y, std);
	a += peso(pl.x - 1.0, pl.y - 2.0, su.z, std);
	a += peso(pl.x, pl.y - 2.0, su.w, std);
	a += peso(pl.x + 1.0, pl.y - 1.0, sx.x, std);
	a += peso(pl.x, pl.y - 1.0, sx.y, std);
	a += peso(pl.x, pl.y, sx.z, std);
	a += peso(pl.x + 1.0, pl.y, sx.w, std);
	a += peso(pl.x - 1.0, pl.y - 1.0, dx.x, std);
	a += peso(pl.x - 2.0, pl.y - 1.0, dx.y, std);
	a += peso(pl.x - 2.0, pl.y, dx.z, std);
	a += peso(pl.x - 1.0, pl.y, dx.w, std);
	float finale = a.y / a.x;
	float massimo_y = max(max(sx.y, sx.z), max(dx.x, dx.w));
	float minimo_y = min(min(sx.y, sx.z), min(dx.x, dx.w));
	finale = clamp(nitidezza * finale, minimo_y, massimo_y);
	float delta = clamp(finale - cw, -23.0 / 255.0, 23.0 / 255.0);
	return clamp(colore + vec3(delta), 0.0, 1.0);
}

vec3 liscio(sampler2D tex, vec2 uv) {
	// "Sharp bilinear": dentro il pixel colore pieno, solo il bordo si sfuma (largo un pixel dello schermo).
	vec2 dim = vec2(textureSize(tex, 0));
	vec2 pix = uv * dim;
	vec2 cucitura = floor(pix + 0.5);
	vec2 passo = max(fwidth(pix), vec2(1e-4));
	pix = cucitura + clamp((pix - cucitura) / passo, -0.5, 0.5);
	return texture(tex, pix / dim).rgb;
}

vec3 daltonizza(vec3 c, int tipo) {
	float l = 17.8824 * c.r + 43.5161 * c.g + 4.11935 * c.b;
	float m = 3.45565 * c.r + 27.1554 * c.g + 3.86714 * c.b;
	float s = 0.0299566 * c.r + 0.184309 * c.g + 1.46709 * c.b;
	if (tipo == 1) {
		l = 2.02344 * m - 2.52581 * s;
	} else if (tipo == 2) {
		m = 0.494207 * l + 1.24827 * s;
	} else {
		s = -0.395913 * l + 0.801109 * m;
	}
	vec3 visto = vec3(
		0.0809444479 * l - 0.130504409 * m + 0.116721066 * s,
		-0.0102485335 * l + 0.0540193266 * m - 0.113614708 * s,
		-0.000365296938 * l - 0.00412161469 * m + 0.693511405 * s);
	vec3 errore = c - visto;
	// Sposta ciò che non si distingue verso i colori che si vedono bene.
	return clamp(c + vec3(0.0, 0.7 * errore.r + errore.g, 0.7 * errore.r + errore.b), 0.0, 1.0);
}

vec3 nitido(sampler2D tex, vec2 uv) {
	ivec2 dim = textureSize(tex, 0);
	return texelFetch(tex, clamp(ivec2(floor(uv * vec2(dim))), ivec2(0), dim - ivec2(1)), 0).rgb;
}

vec3 colori_del_film(vec3 c, vec2 uv) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c *= mix(vec3(0.86, 0.93, 1.1), vec3(1.07, 1.0, 0.9), smoothstep(0.12, 0.65, l));   // ombre fredde, luci calde
	c = mix(vec3(l), c, 0.88);                                                          // colori più uniformi
	vec2 d = uv - 0.5;
	c *= 1.0 - dot(d, d) * 0.6;                                                         // bordi più scuri
	return c;
}

void fragment() {
	vec3 c;
	if (filtro == 2) {
		c = sgsr(sorgente, UV);
	} else if (filtro == 1) {
		c = liscio(sorgente, UV);
	} else {
		c = nitido(sorgente, UV);
	}
	if (bagliore > 0.0) {
		c += texture(bagliore_tex, UV).rgb * bagliore;
	}
	if (toni) {
		c = colori_del_film(c, UV);
	}
	if (daltonismo > 0) {
		c = daltonizza(clamp(c, 0.0, 1.0), daltonismo);
	}
	c = pow(max(c, vec3(0.0)), vec3(1.0 / gamma_scelta));
	c = clamp((c - 0.5) * contrasto + 0.5, 0.0, 1.0);
	COLOR = vec4(c, 1.0);
}
