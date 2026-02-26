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

const int SAMPLES = 56;
const float GOLDEN_ANGLE = 2.39996;
const float MAX_BLUR = 20.0;

vec4 sampleBlurred(sampler2D tex, vec2 uv, vec2 pixToUv, float radius) {
    if (radius < 0.5) return texture(tex, uv);

    vec4 sum = vec4(0.0);
    float totalWeight = 0.0;
    float sigma = radius * 0.4;

    for (int i = 0; i < SAMPLES; i++) {
        float r = sqrt(float(i) / float(SAMPLES)) * radius;
        float theta = float(i) * GOLDEN_ANGLE;
        vec2 offset = vec2(cos(theta), sin(theta)) * r * pixToUv;
        float w = exp(-0.5 * r * r / (sigma * sigma));
        sum += texture(tex, clamp(uv + offset, 0.0, 1.0)) * w;
        totalWeight += w;
    }
    return sum / totalWeight;
}

void main() {
    vec2 pos = FlutterFragCoord().xy;

    float topEdge = uCenter1.y - uHalfSize1.y - 2.0;
    if (pos.y < topEdge) {
        fragColor = vec4(0.0);
        return;
    }

    // Distance from ball 2 center to the RRect surface
    vec2 qDist = abs(uCenter2 - uCenter1) - (uHalfSize1 - uCornerR1);
    float surfDist = length(max(qDist, 0.0)) + min(max(qDist.x, qDist.y), 0.0) - uCornerR1;

    // Shrink ball 2 as it approaches the RRect
    float proximity = smoothstep(0.0, uRadius2 * 2.5, surfDist);
    float actualR2 = mix(uHalfSize1.y, uRadius2, proximity);

    // RRect field
    vec2 q = abs(pos - uCenter1) - (uHalfSize1 - uCornerR1);
    float d1 = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
    float f1 = (uCornerR1 * uCornerR1) / (d1 * d1 + 0.0001);

    // Circle field with dynamic radius
    vec2 d2 = pos - uCenter2;
    float f2 = (actualR2 * actualR2) / (dot(d2, d2) + 0.0001);

    float field = f1 + f2;

    float edge = 0.01;
    float alpha = smoothstep(uThreshold - edge, uThreshold + edge, field);

    // Image mapping scales with the dynamic radius
    float effectiveR = actualR2 / sqrt(uThreshold);
    vec2 localPos = (pos - uCenter2) / effectiveR;

    float imgAspect = uImageSize.x / uImageSize.y;
    vec2 uv;
    vec2 pixToUv;
    if (imgAspect > 1.0) {
        uv = vec2(localPos.x / imgAspect * 0.5 + 0.5, localPos.y * 0.5 + 0.5);
        pixToUv = vec2(0.5 / (effectiveR * imgAspect), 0.5 / effectiveR);
    } else {
        uv = vec2(localPos.x * 0.5 + 0.5, localPos.y * imgAspect * 0.5 + 0.5);
        pixToUv = vec2(0.5 / effectiveR, 0.5 * imgAspect / effectiveR);
    }
    uv = clamp(uv, 0.0, 1.0);

    float blurProximity = 1.0 - smoothstep(0.0, uRadius2 / sqrt(uThreshold), surfDist);
    float blurRadius = MAX_BLUR * blurProximity;
    vec4 imgColor = sampleBlurred(uImage, uv, pixToUv, blurRadius);

    float t = smoothstep(0.35, 0.65, f2 / (f1 + f2));
    vec4 color = mix(vec4(0.0, 0.0, 0.0, 1.0), imgColor, t);

    fragColor = color * alpha;
}
