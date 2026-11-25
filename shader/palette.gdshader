shader_type canvas_item;
// Ultimo passaggio sull'immagine del gioco: porta ogni colore al più vicino della palette fissa.
// Lavora dopo luci, nebbia e particelle, così tutto resta coerente anche con le luci dinamiche.
// La tabella (lut) ha 32 fette da 32x32 affiancate: rosso in orizzontale, verde in verticale, blu = fetta.

uniform sampler2D schermo : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D lut : filter_nearest, repeat_disable;
uniform float forza : hint_range(0.0, 1.0) = 0.7;
uniform float retino : hint_range(0.0, 0.2) = 0.03;

const float LATO = 32.0;

float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x * 0.5 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

void fragment() {
	vec3 c = texture(schermo, SCREEN_UV).rgb;
	// Retino ordinato: trasforma le sfumature in una trama di pixel, come nella pixel art.
	vec3 d = clamp(c + (bayer4(FRAGCOORD.xy) - 0.5) * retino, 0.0, 1.0);
	vec3 i = floor(d * (LATO - 1.0) + 0.5);
	vec2 uv = vec2((i.b * LATO + i.r + 0.5) / (LATO * LATO), (i.g + 0.5) / LATO);
	vec3 q = texture(lut, uv).rgb;
	COLOR = vec4(mix(c, q, forza), 1.0);
}
