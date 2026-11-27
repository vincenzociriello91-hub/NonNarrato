shader_type canvas_item;
// Bagliore (0.1.36): su una tela piccola (un quarto del gioco) raccoglie solo le parti luminose
// dell'immagine (fiamme, magie, scintille, lame illuminate) e le sfoca. principale.gd la posa sopra
// all'immagine finale in vista.gdshader: niente "HDR" del motore, costa pochissimo su ogni telefono.

uniform float soglia = 0.5;     // sotto questa luminosità niente bagliore
uniform float raggio = 1.0;     // larghezza della sfocatura (1 leggero, 1,6 forte)

vec3 luce(sampler2D tex, vec2 uv) {
	vec3 c = texture(tex, uv).rgb;
	float l = max(c.r, max(c.g, c.b));
	return c * smoothstep(soglia, 1.0, l);
}

void fragment() {
	// Il passo è di 4 pixel del gioco (un pixel della tela piccola), allargato da "raggio".
	vec2 p = TEXTURE_PIXEL_SIZE * 4.0 * raggio;
	vec3 s = luce(TEXTURE, UV) * 0.2;
	s += (luce(TEXTURE, UV + vec2(p.x, 0.0)) + luce(TEXTURE, UV - vec2(p.x, 0.0))
		+ luce(TEXTURE, UV + vec2(0.0, p.y)) + luce(TEXTURE, UV - vec2(0.0, p.y))) * 0.1;
	s += (luce(TEXTURE, UV + p) + luce(TEXTURE, UV - p)
		+ luce(TEXTURE, UV + vec2(p.x, -p.y)) + luce(TEXTURE, UV + vec2(-p.x, p.y))) * 0.06;
	s += (luce(TEXTURE, UV + vec2(2.0 * p.x, 0.0)) + luce(TEXTURE, UV - vec2(2.0 * p.x, 0.0))
		+ luce(TEXTURE, UV + vec2(0.0, 2.0 * p.y)) + luce(TEXTURE, UV - vec2(0.0, 2.0 * p.y))) * 0.04;
	COLOR = vec4(s, 1.0);
}
