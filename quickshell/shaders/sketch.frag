// Wallpaper transition "sketch" (Wallpaper.qml): the new picture's outlines are drawn in,
// then its colours fill in behind them.
//   0.00-0.25  the old wallpaper dims, like a fresh sheet of paper
//   0.05-0.60  outlines of the new picture (edge detection) appear in the ink colour,
//              spreading from the middle with a slightly hand-drawn, uneven front
//   0.45-1.00  the new picture's colours fill in behind the same front; the lines fade
// Compile after editing: ../scripts/build-shaders  (makes sketch.frag.qsb next to this file)
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;   // 0 → 1
    vec2 texel;       // 1 / size in px, for the edge filter
    vec4 ink;         // outline colour (the theme's accent)
};
layout(binding = 1) uniform sampler2D oldTex;
layout(binding = 2) uniform sampler2D newTex;

float lum(vec2 uv) { return dot(texture(newTex, uv).rgb, vec3(0.299, 0.587, 0.114)); }

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { // smooth value noise
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void main() {
    vec2 uv = qt_TexCoord0;

    // Sobel edges of the new picture, sampled 1.5 px apart for slightly bolder lines
    vec2 t = texel * 1.5;
    float tl = lum(uv + t * vec2(-1, -1)), tc = lum(uv + t * vec2(0, -1)), tr = lum(uv + t * vec2(1, -1));
    float ml = lum(uv + t * vec2(-1, 0)),                                 mr = lum(uv + t * vec2(1, 0));
    float bl = lum(uv + t * vec2(-1, 1)),  bc = lum(uv + t * vec2(0, 1)),  br = lum(uv + t * vec2(1, 1));
    float gx = -tl - 2.0 * ml - bl + tr + 2.0 * mr + br;
    float gy = -tl - 2.0 * tc - tr + bl + 2.0 * bc + br;
    float edge = smoothstep(0.10, 0.45, length(vec2(gx, gy)));

    // When each spot gets reached: middle first, with a wobbly pencil-like front
    float aspect = texel.y / texel.x;
    vec2 d = (uv - 0.5) * vec2(aspect, 1.0);
    float order = clamp(length(d) / (0.5 * length(vec2(aspect, 1.0))), 0.0, 1.0) * 0.8
                + noise(uv * vec2(aspect, 1.0) * 7.0) * 0.2;

    float draw = smoothstep(order, order + 0.06, (progress - 0.05) / 0.55);
    float fill = smoothstep(order, order + 0.18, (progress - 0.45) / 0.5);

    vec3 oldc = texture(oldTex, uv).rgb;
    vec3 newc = texture(newTex, uv).rgb;
    vec3 paper = mix(oldc, oldc * 0.18, smoothstep(0.0, 0.25, progress));
    vec3 col = mix(paper, ink.rgb, edge * draw * (1.0 - fill));
    col = mix(col, newc, fill);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
