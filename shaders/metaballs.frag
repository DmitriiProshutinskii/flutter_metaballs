#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uCenter1;
uniform float uRadius1;
uniform vec2 uCenter2;
uniform float uRadius2;
uniform float uThreshold;

out vec4 fragColor;

void main() {
    vec2 pos = FlutterFragCoord().xy;

    vec2 d1 = pos - uCenter1;
    vec2 d2 = pos - uCenter2;

    float field = (uRadius1 * uRadius1) / (dot(d1, d1) + 0.0001)
                + (uRadius2 * uRadius2) / (dot(d2, d2) + 0.0001);

    float edge = 0.04;
    float alpha = smoothstep(uThreshold - edge, uThreshold + edge, field);

    fragColor = vec4(0.0, 0.0, 0.0, alpha);
}
