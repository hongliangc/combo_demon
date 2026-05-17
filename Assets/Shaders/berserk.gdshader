shader_type canvas_item;

uniform float progress: hint_range(0.0, 1.0) = 0.0;
const float TEXTURE_HEIGHT = 64.0;

void vertex(){
    float scale_factor = progress *2.0;
    vec2 scaled_vectex = VERTEX * (1.0 + scale_factor);
    float y_translation = TEXTURE_HEIGHT /2.0 * scale_factor;
    vec2 vertical_aligned_vertex = vec2(
        scaled_vectex.x,
        scaled_vectex.y - y_translation
    );
    VERTEX = vertical_aligned_vertex;
}

void fragment() {
    float adjusted_progress = 2.0 * progress;

    float scale_factor = 1.0 - 0.1 * adjusted_progress;

    vec2 base_uv = vec2(
        UV.x * scale_factor + 0.05 * adjusted_progress,
        UV.y * scale_factor + 0.1 * adjusted_progress
    );

    vec4 base_tex = texture(TEXTURE, base_uv);
    base_tex.a *= 1.0 - progress;

    vec4 berserk_tex = COLOR;
    berserk_tex.rgb = mix(berserk_tex.rgb, berserk_tex.rgb * 1.5, progress);

    COLOR = mix(base_tex, berserk_tex, berserk_tex.a * progress);
}