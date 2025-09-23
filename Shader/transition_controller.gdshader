shader_type canvas_item;

uniform sampler2D from_scene;
uniform float progress : hint_range(0.0, 1.0);
uniform vec2 resolution = vec2(1920.0, 1080.0);
uniform float grid_size = 80.0;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 pixel = uv * resolution;

    // 计算格子索引
    vec2 grid = floor(pixel / grid_size);
    vec2 local = mod(pixel, grid_size) / grid_size;

    // 三角格切换效果：交错翻转
    float flip = mod(grid.x + grid.y, 2.0); // 交错翻转
    float t = clamp(progress * 2.0 - flip, 0.0, 1.0); // 控制每格延迟翻转

    // 模拟翻转：将 local x 翻转
    float rotate = mix(0.0, 1.0 - local.x, t);

    // 映射 UV 回原图
    vec2 flipped_uv = (grid + vec2(rotate, local.y)) * grid_size / resolution;

    // 采样旧画面
    COLOR = texture(from_scene, flipped_uv);
}
