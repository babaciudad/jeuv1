// Passe de trait plein écran : elle DÉTOURE, elle ne repeint pas.
//
// CE QUI A CHANGÉ, ET POURQUOI
//
// Elle posterisait l'image sur six valeurs et la repeignait en bichromie
// encre-sépia-papier. C'était une erreur, et elle a coûté cher : dehors tout
// partait en blanc, dedans tout partait en noir, et un personnage devenait
// une silhouette découpée sans un gramme de modelé. On ne peut pas juger un
// personnage à travers ça — il n'y a plus rien à voir. Le rendu était
// « pas clair » parce qu'on l'avait aplati à la main.
//
// La bonne moitié de l'effet, c'est le TRAIT : le contour de silhouette et
// l'arête interne, qui donnent le côté illustration. Elle est gardée. La
// posterisation, la bichromie et la hachure sont éteintes par leurs réglages
// dans `ink.tres` — le code les garde pour qu'on puisse les remonter d'un cran
// si on veut, mais leur place par défaut est à zéro.
//
// Ce qui a été AJOUTÉ depuis : le trait n'a plus une épaisseur unique. Il
// s'ouvre dans l'ombre et se referme en pleine lumière (voir `ink_width_lit`
// et `ink_width_shade`). C'est la moitié du travail d'un dessinateur, et ça
// coûte trois lignes.
//
// Le reste de l'image est le rendu PBR tel quel. C'est l'ÉCLAIRAGE qui doit
// faire le travail, pas un filtre posé par-dessus.
//
// Fonctionne en Forward+ uniquement : `hint_normal_roughness_texture` n'existe
// pas dans le rendu de compatibilité. Sans elle, les contours disparaîtraient
// silencieusement.
shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled,
	cull_disabled, shadows_disabled, ambient_light_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;

group_uniforms trait;
// Épaisseur du trait, en pixels.
uniform float ink_width : hint_range(0.5, 4.0) = 1.35;
// Sensibilité au décroché de profondeur : c'est ce qui détoure les silhouettes.
uniform float depth_edge : hint_range(0.1, 8.0) = 1.6;
// Sensibilité au pli de normale : c'est ce qui dessine les arêtes internes,
// l'angle d'un pilier, le pli d'une manche.
uniform float normal_edge : hint_range(0.1, 4.0) = 0.85;
uniform vec4 ink_color : source_color = vec4(0.06, 0.05, 0.09, 1.0);
// Au-delà de cette distance, on cesse de tracer : sinon le fond du couloir
// devient une pelote de traits.
uniform float ink_fade_start = 22.0;
uniform float ink_fade_end = 44.0;
// LE TRAIT S'ÉPAISSIT DANS L'OMBRE.
//
// Un trait d'épaisseur constante, c'est du détourage automatique : il dit
// « voici un bord » et rien d'autre. Un dessinateur ne fait jamais ça — il
// appuie là où la forme s'enfonce dans l'ombre et il allège là où la lumière
// frappe, et c'est ce seul écart qui fait qu'un dessin a du volume au lieu
// d'être un patron découpé.
//
// Ces deux nombres sont des FACTEURS sur `ink_width` : l'un pour ce qui est en
// pleine lumière, l'autre pour ce qui est au fond de l'ombre.
uniform float ink_width_lit : hint_range(0.2, 1.5) = 0.68;
uniform float ink_width_shade : hint_range(0.5, 4.0) = 2.10;
// Entre ces deux luminances se fait le passage du trait épais au trait fin.
uniform float ink_shade_low : hint_range(0.0, 1.0) = 0.10;
uniform float ink_shade_high : hint_range(0.0, 1.0) = 0.46;
// Et il n'appuie pas seulement plus large : il appuie plus NOIR. Un trait fin
// et dense se lit comme un trait de plume, un trait large et pâle comme une
// ombre — l'inverse de ce qu'on veut.
uniform float ink_shade_bite : hint_range(0.0, 1.0) = 0.35;

group_uniforms aplats;
// Nombre de valeurs. Trois à cinq : au-delà on retombe dans le dégradé, en
// dessous on perd le volume.
uniform int bands : hint_range(2, 8) = 5;
uniform float band_mix : hint_range(0.0, 1.0) = 0.9;

// La gamme de la gravure, en trois points : encre, sépia, papier. C'est ELLE
// la direction artistique — tout ce qui n'émet pas de lumière propre y passe,
// pierre, bois, armure et chair confondus. Une image tenue par trois couleurs
// se lit comme une intention ; la même en couleurs libres se lit comme une
// scène 3D mal éclairée.
uniform vec4 tone_ink : source_color = vec4(0.17, 0.14, 0.15, 1.0);
uniform vec4 tone_sepia : source_color = vec4(0.46, 0.34, 0.25, 1.0);
uniform vec4 tone_paper : source_color = vec4(0.95, 0.90, 0.78, 1.0);
uniform float duotone : hint_range(0.0, 1.0) = 0.88;

// Ce qui est DÉJÀ coloré garde sa couleur : la flamme, le vitrail, l'éclat
// d'un sort. C'est la gravure rehaussée à la main — et accessoirement, c'est
// ce qui garde le jeu lisible, puisque le repère d'arme jaune doit survivre à
// n'importe quelle passe de rendu.
uniform float color_keep : hint_range(0.0, 1.0) = 0.92;
uniform float color_threshold : hint_range(0.0, 1.0) = 0.10;
uniform float saturation : hint_range(0.0, 2.0) = 1.05;

// Étalonnage, AVANT la gamme. Sans lui, une scène nocturne dont toutes les
// valeurs vivent entre 0 et 0,3 se retrouve entièrement du côté encre : la
// gravure devient une page noire. Ces deux nombres disent quelle luminance
// compte pour du noir d'encre et laquelle compte pour du papier nu.
uniform float black_point : hint_range(0.0, 0.5) = 0.02;
// Assez HAUT pour que seuls les vrais eclats atteignent le papier nu. A 0,38,
// toute surface bien eclairee -- un plafond de couloir sous une torche --
// depassait le point blanc et devenait un aplat sature sans detail : un
// bandeau creme en haut de l'ecran qu'on prenait pour un bug d'affichage.
// C'est la meme cause que l'arene noire : une plage fixe sur une scene dont
// les salles vont du simple au decuple. L'exposition automatique fait le gros
// du travail, ce reglage ne fait plus que la finition.
uniform float white_point : hint_range(0.05, 1.0) = 0.60;

group_uniforms hachure;
// La hachure est la signature de la gravure. Sans elle, une image posterisée
// et détourée reste du cel-shading ; avec elle, on lit du burin sur cuivre.
// Elle ne s'applique QUE dans les valeurs basses : hachurer les lumières
// salirait l'image au lieu de la creuser.
uniform bool hatch_enabled = true;
uniform float hatch_scale = 220.0;
uniform float hatch_strength : hint_range(0.0, 1.0) = 0.32;
// Au-dessus de ce niveau, plus une seule hachure.
uniform float hatch_ceiling : hint_range(0.0, 1.0) = 0.46;

group_uniforms papier;
uniform float grain_amount : hint_range(0.0, 0.4) = 0.020;
uniform float grain_scale = 640.0;
uniform float vignette : hint_range(0.0, 1.5) = 0.28;

void vertex() {
	// Quad plein écran : on écrit POSITION directement, sans passer par les
	// matrices — le maillage n'est pas dans le monde, il EST l'écran.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_projection) {
	float raw = texture(depth_tex, uv).r;
	vec4 view = inv_projection * vec4(vec3(uv * 2.0 - 1.0, raw), 1.0);
	return -view.z / view.w;
}

vec3 view_normal(vec2 uv) {
	return texture(normal_tex, uv).rgb * 2.0 - 1.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.7321, 289.113))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// Le tampon d'écran est en LINÉAIRE HDR, pas en valeurs d'affichage : une
	// zone qui apparaît à 0,20 à l'écran vaut 0,035 ici. Étalonner sans faire
	// la conversion revient à traiter toute la scène comme du noir — c'est ce
	// qui a coûté trois rendus avant d'être compris.
	//
	// On décode donc vers l'affichage, on peint, et on ré-encode en sortie.
	// L'ACES de l'environnement s'applique ensuite à ce ré-encodage : ce n'est
	// pas un aller-retour exact, mais son écrasement des hautes lumières rend
	// service ici — il empêche le papier de brûler dès qu'une torche entre
	// dans le champ. `white_point` est réglé en connaissance de cela.
	vec3 base = pow(clamp(texture(screen_tex, uv).rgb, vec3(0.0), vec3(1.0)),
		vec3(1.0 / 2.2));

	// Combien ce pixel est dans l'ombre, de 0 (plein soleil) à 1 (fond noir).
	// Lu sur l'image DÉJÀ ÉCLAIRÉE, donc le trait suit le soleil, les torches
	// et les faisceaux de saumure sans qu'on ait rien à lui dire.
	float raw_luma = dot(base, vec3(0.2126, 0.7152, 0.0722));
	float shade_here = 1.0 - smoothstep(ink_shade_low, ink_shade_high, raw_luma);
	float pen = mix(ink_width_lit, ink_width_shade, shade_here);
	// La croix de Roberts s'ouvre d'autant : c'est l'écartement des quatre
	// prises qui décide de la LARGEUR de la bande détectée, donc de
	// l'épaisseur du trait. Rien d'autre à faire.
	vec2 step_uv = ink_width * pen / VIEWPORT_SIZE;

	// --- Contour -----------------------------------------------------------
	// Croix de Roberts sur la profondeur ET sur la normale. La profondeur
	// détoure les silhouettes, la normale dessine les plis internes ; l'une
	// sans l'autre donne soit un pochoir, soit un gribouillis.
	float d0 = linear_depth(uv, INV_PROJECTION_MATRIX);
	float d1 = linear_depth(uv + vec2(step_uv.x, 0.0), INV_PROJECTION_MATRIX);
	float d2 = linear_depth(uv + vec2(0.0, step_uv.y), INV_PROJECTION_MATRIX);
	float d3 = linear_depth(uv + step_uv, INV_PROJECTION_MATRIX);
	vec3 n0 = view_normal(uv);
	// Le seuil grandit avec la distance : sans cela, un sol vu en fuite est
	// un décroché permanent et se retrouve entièrement hachuré.
	//
	// Il grandit AUSSI quand la surface fuit. `n0.z` est la composante vue de
	// la normale : 1 pour une face qui regarde la caméra, 0 pour une face vue
	// par la tranche. Sur un sol pris à hauteur d'homme, la bande juste sous
	// l'horizon est vue par la tranche : deux pixels voisins y sont distants
	// de plusieurs mètres, le décroché sature, et la passe d'encre remplissait
	// toute cette bande en NOIR PLEIN. C'était la barre noire qui traversait
	// chaque plan du jeu — prise pour un défaut d'éclairage pendant des jours,
	// alors qu'aucune lumière n'était en cause : un test à ambiante rouge vif
	// laissait la bande parfaitement noire.
	float facing = max(abs(n0.z), 0.10);
	// Le seuil suit l'ÉCARTEMENT de la croix. Sans ce facteur, ouvrir la croix
	// dans l'ombre ne ferait pas un trait plus large : ça ferait un décroché
	// mécaniquement plus grand partout, donc un seuil franchi partout, donc
	// des pâtés noirs dans toutes les zones sombres. On veut que le trait
	// change de largeur, pas que l'image change de sensibilité.
	float slope = max(d0, 0.6) * 0.03 * pen / facing;
	float depth_diff = (abs(d0 - d3) + abs(d1 - d2)) / slope;

	vec3 n1 = view_normal(uv + vec2(step_uv.x, 0.0));
	vec3 n2 = view_normal(uv + vec2(0.0, step_uv.y));
	vec3 n3 = view_normal(uv + step_uv);
	// Même correction pour le pli de normale, et pour la même raison.
	float normal_diff = ((1.0 - dot(n0, n3)) + (1.0 - dot(n1, n2))) / pen;

	float edge = max(depth_diff * depth_edge, normal_diff * 6.0 * normal_edge);
	edge = smoothstep(0.55, 1.25, edge);
	// Le trait s'efface au loin : le fond du couloir doit rester lisible.
	edge *= 1.0 - smoothstep(ink_fade_start, ink_fade_end, d0);

	// --- Aplats ---------------------------------------------------------
	float luma = clamp((raw_luma - black_point)
		/ max(white_point - black_point, 0.001), 0.0, 1.0);
	float steps = float(bands);
	// +0.5 : on vise le MILIEU de chaque bande, pas son bord. Sans cela, la
	// valeur la plus claire de l'image ne peut jamais atteindre le papier.
	float banded = (floor(luma * steps) + 0.5) / steps;
	banded = mix(luma, banded, band_mix);

	// Gamme en trois points : encre → sépia → papier.
	// La moitié sombre monte en racine, pas en droite : sur une gravure, la
	// matière reste lisible dans les ombres. Une rampe linéaire écrasait tout
	// le sol en noir plein dès qu'on baissait l'exposition d'un cran.
	vec3 engraved = banded < 0.5
		? mix(tone_ink.rgb, tone_sepia.rgb, pow(banded * 2.0, 0.62))
		: mix(tone_sepia.rgb, tone_paper.rgb, (banded - 0.5) * 2.0);

	// Rehaut : plus un pixel était coloré, plus il garde sa couleur. La pierre
	// est grise, donc elle passe entièrement en sépia ; une flamme ne l'est
	// pas, donc elle reste orange.
	float chroma = max(base.r, max(base.g, base.b))
		- min(base.r, min(base.g, base.b));
	float keep = smoothstep(color_threshold, color_threshold + 0.22, chroma)
		* color_keep;
	vec3 tinted = base * (banded / max(raw_luma, 0.001));
	vec3 color = mix(mix(base, engraved, duotone), tinted, keep);

	float grey = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(grey), color, saturation);

	// --- Hachure ---------------------------------------------------------
	// Largeur de trait FIXE, densité rendue par l'opacité. Élargir le trait
	// avec l'ombre semblait plus juste — en pratique les traits se touchaient
	// et la moitié sombre de l'image devenait un aplat noir, ce qui a coûté
	// deux rendus avant d'être compris.
	if (hatch_enabled) {
		float ratio = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
		vec2 pixel = vec2(SCREEN_UV.x * ratio, SCREEN_UV.y) * hatch_scale;
		float shade = 1.0 - smoothstep(0.0, hatch_ceiling, banded);
		float wave = abs(fract((pixel.x + pixel.y * 1.7) * 0.5) - 0.5) * 2.0;
		float line = smoothstep(0.58, 0.86, wave);
		// La contre-taille ne mord que dans le plus sombre, comme un graveur
		// qui repasse.
		float cross_wave = abs(fract((pixel.x - pixel.y * 1.7) * 0.5 + 0.37) - 0.5) * 2.0;
		float cross_line = smoothstep(0.66, 0.90, cross_wave)
			* smoothstep(0.68, 0.95, shade);
		float lines = clamp(line + cross_line, 0.0, 1.0);
		color = mix(color, tone_ink.rgb, lines * shade * hatch_strength);
	}

	// --- Papier ------------------------------------------------------------
	// Grain en espace écran : le papier ne bouge pas quand la caméra tourne,
	// c'est ce qui fait qu'on croit à une page plutôt qu'à un filtre.
	float grain = hash(floor(SCREEN_UV * grain_scale)) - 0.5;
	color += grain * grain_amount;

	float radius = length(SCREEN_UV - vec2(0.5));
	color *= 1.0 - smoothstep(0.34, 0.85, radius) * vignette;

	// L'encre passe par-dessus tout, y compris le grain et la vignette : un
	// trait délavé n'est plus un trait. Et elle mord plus fort dans l'ombre :
	// même encre, plus de pression.
	vec3 pressed = ink_color.rgb * (1.0 - shade_here * ink_shade_bite);
	color = mix(color, pressed, edge);

	ALBEDO = pow(clamp(color, vec3(0.0), vec3(1.0)), vec3(2.2));
}
