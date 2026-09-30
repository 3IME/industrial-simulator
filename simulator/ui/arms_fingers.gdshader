shader_type spatial;
// Pli des doigts pour les bras WRAD (maillage statique depouille) :
// les sommets au-dela du plan de la paume (y local < seuil) tournent
// autour d'un axe z local, proportionnellement a leur distance aux
// articulations. Les doigts sont empiles selon z : une bande centrale
// (l'index) peut se plier separement.

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap;
uniform float pli = 0.0;         // pli de tous les doigts (0..1)
uniform float pli_index = 0.0;   // pli supplementaire de l'index seul
uniform float sens = 1.0;        // cote vers lequel les doigts se replient
uniform float seuil_paume = -3.0;
uniform float longueur_doigt = 1.2;
uniform float index_z = -2.85;   // centre de la bande de l'index
uniform float index_largeur = 0.30;

void vertex() {
	if (VERTEX.y < seuil_paume) {
		float t = clamp((seuil_paume - VERTEX.y) / longueur_doigt, 0.0, 1.0);
		float bande = 1.0 - clamp(abs((VERTEX.z - index_z) / index_largeur), 0.0, 1.0);
		float angle = (pli + pli_index * bande) * 1.4 * t;
		float c = cos(angle);
		float s = sin(angle) * sens;
		float dy = VERTEX.y - seuil_paume;
		VERTEX = vec3(VERTEX.x * c - dy * s, VERTEX.x * s + dy * c + seuil_paume, VERTEX.z);
		NORMAL = normalize(vec3(NORMAL.x * c - NORMAL.y * s,
				NORMAL.x * s + NORMAL.y * c, NORMAL.z));
	}
}

void fragment() {
	ALBEDO = texture(tex_albedo, UV).rgb;
}
