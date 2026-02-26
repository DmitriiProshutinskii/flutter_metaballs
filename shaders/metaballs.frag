#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uCenter1;
uniform float uRadius1;
uniform vec2 uCenter2;
uniform float uRadius2;
uniform float uThreshold;
uniform vec2 uImageSize;

uniform sampler2D uImage;

out vec4 fragColor;

void main() {
    vec2 pos = FlutterFragCoord().xy;

    vec2 d1 = pos - uCenter1;
    vec2 d2 = pos - uCenter2;

    float f1 = (uRadius1 * uRadius1) / (dot(d1, d1) + 0.0001);
    float f2 = (uRadius2 * uRadius2) / (dot(d2, d2) + 0.0001);
    float field = f1 + f2;

    float edge = 0.01;
    float alpha = smoothstep(uThreshold - edge, uThreshold + edge, field);

    // Image in moving ball: UV from center2, cover aspect
    float effectiveR = uRadius2 / sqrt(uThreshold);
    vec2 localPos = (pos - uCenter2) / effectiveR;
    float imgAspect = uImageSize.x / uImageSize.y;
    vec2 uv;
    if (imgAspect > 1.0) {
        uv = vec2(localPos.x / imgAspect * 0.5 + 0.5, localPos.y * 0.5 + 0.5);
    } else {
        uv = vec2(localPos.x * 0.5 + 0.5, localPos.y * imgAspect * 0.5 + 0.5);
    }
    uv = clamp(uv, 0.0, 1.0);
    vec4 imgColor = texture(uImage, uv);

    float t = smoothstep(0.35, 0.65, f2 / (f1 + f2));
    vec4 color = mix(vec4(0.0, 0.0, 0.0, 1.0), imgColor, t);

    fragColor = color * alpha;
}
