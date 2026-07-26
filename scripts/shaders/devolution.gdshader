// devolution.gdshader
// Drains the colour out of the player as their traits are lost.
//
// WHY THIS EXISTS. This used to be a modulate lerp toward a near-neutral grey, and a
// rendered check showed it failing at BOTH ends: at 3-of-14 traits gone the sprite was
// (0.910, 0.904, 0.919) — a 9% dim nobody would notice — and even at 14-of-14 it was
// only (0.580, 0.550, 0.620), so the cape was still vividly red. The cause is that
// modulate is a multiply: multiplying by grey can only DARKEN a sprite, it can never
// desaturate one. No choice of target colour fixes that, which is why this became a
// shader instead of a numbers change.
//
// Here saturation is removed directly — mixing toward luminance — and only then is what
// is left cooled and dimmed. That is what reads as a body losing its blood.
shader_type canvas_item;

// 0.0 = fully intact, 1.0 = every trait lost. Driven from
// player.gd::_update_body_appearance().
uniform float decay : hint_range(0.0, 1.0) = 0.0;

// Where a fully devolved body lands after desaturation. Slightly blue and well below
// white, so total loss reads as cold and drained rather than merely dark.
uniform vec3 drain_tint : source_color = vec3(0.62, 0.60, 0.72);

// Rec. 709 luma. Using perceptual weights rather than a flat average keeps the sprite's
// internal shading intact as it greys — a flat average flattens the character into a
// silhouette well before decay reaches 1.0.
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	// COLOR arrives as the texture sample already multiplied by modulate, so the
	// invincibility flicker (which writes only modulate.a) survives untouched: nothing
	// below writes alpha.
	float lum = dot(COLOR.rgb, LUMA);
	vec3 drained = mix(COLOR.rgb, vec3(lum), decay);
	COLOR.rgb = drained * mix(vec3(1.0), drain_tint, decay);
}
