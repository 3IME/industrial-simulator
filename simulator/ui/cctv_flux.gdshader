shader_type canvas_item;
// Rendu "videosurveillance" d'un flux camera : distorsion, lignes de
// balayage, bruit, coupures occasionnelles, teinte par zone, scintillement.
// alarme > 0.5 : glitchs lourds (evenement de confinement).

uniform float intensite = 0.3;
uniform float alarme = 0.0;
uniform vec3 teinte = vec3(0.9, 1.0, 0.95);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	// legere distorsion horizontale
	uv.x += sin(uv.y * 90.0 + TIME * 2.0) * 0.0015;
	uv.y += sin(TIME * 13.0) * 0.0008;
	vec3 c = texture(TEXTURE, uv).rgb;
	// lignes de balayage
	c *= 0.88 + 0.12 * sin(uv.y * 260.0 + TIME * 8.0);
	// bruit video
	float bruit = hash(uv * vec2(320.0, 180.0) + vec2(TIME * 60.0, 0.0));
	c = mix(c, vec3(bruit), 0.05 + intensite * 0.14);
	// petites coupures occasionnelles
	float coupure = step(0.9965 + intensite * 0.003,
			hash(vec2(floor(TIME * 12.0), 7.0)));
	c = mix(c, vec3(0.02), coupure * (0.5 + intensite));
	// mode alarme : dechirures + neige
	if (alarme > 0.5) {
		float g = hash(vec2(floor(TIME * 20.0), floor(uv.y * 40.0)));
		vec2 uv2 = uv;
		uv2.x += (g - 0.5) * 0.12 * step(0.6, hash(vec2(floor(uv.y * 40.0), floor(TIME * 9.0))));
		c = texture(TEXTURE, uv2).rgb;
		c = mix(c, vec3(hash(uv + TIME * 7.0)), 0.45);
		c = mix(c, vec3(0.0), step(0.94, hash(vec2(floor(TIME * 3.0), 3.0))) * 0.85);
	}
	c *= teinte;
	c *= 0.95 + 0.05 * sin(TIME * 47.0);    // scintillement
	COLOR = vec4(c, 1.0);
}
