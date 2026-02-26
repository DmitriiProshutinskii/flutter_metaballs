#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uCenter1;
uniform vec2 uHalfSize1;
uniform float uCornerR1;
uniform vec2 uCenter2;
uniform float uRadius2;
uniform float uThreshold;
uniform vec2 uImageSize;

uniform sampler2D uImage;

out vec4 fragColor;

void main() {
    vec2 pos = FlutterFragCoord().xy;

    // Distance from ball 2 center to the RRect surface
    vec2 qDist = abs(uCenter2 - uCenter1) - (uHalfSize1 - uCornerR1);
    float surfDist = length(max(qDist, 0.0)) + min(max(qDist.x, qDist.y), 0.0) - uCornerR1;

    // Shrink ball 2 as it approaches the RRect
    float proximity = smoothstep(0.0, uRadius2 * 2.5, surfDist);
    float actualR2 = mix(uHalfSize1.y, uRadius2, proximity);

    // RRect field (SDF to skeleton)
    vec2 q = abs(pos - uCenter1) - (uHalfSize1 - uCornerR1);
    float d1 = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
    float f1 = (uCornerR1 * uCornerR1) / (d1 * d1 + 0.0001);

    // Circle field with dynamic radius
    vec2 d2 = pos - uCenter2;
    float f2 = (actualR2 * actualR2) / (dot(d2, d2) + 0.0001);

    float field = f1 + f2;

    float edge = 0.01;
    float alpha = smoothstep(uThreshold - edge, uThreshold + edge, field);

    float effectiveR = actualR2 / sqrt(uThreshold);
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
