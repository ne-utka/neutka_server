#ifndef NEUTKA_TAA_JITTER_GLSL
#define NEUTKA_TAA_JITTER_GLSL

#include "/settings.glsl"

#ifdef TAA_ENABLED
uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;

vec2 taaJitterOffset(int frameIndex) {
    const vec2 offsets[8] = vec2[8](
        vec2( 0.125, -0.375),
        vec2(-0.125,  0.375),
        vec2( 0.625,  0.125),
        vec2( 0.375, -0.625),
        vec2(-0.625,  0.625),
        vec2(-0.875, -0.125),
        vec2( 0.375,  0.875),
        vec2( 0.875, -0.875)
    );
    return offsets[frameIndex & 7] * TAA_JITTER_STRENGTH;
}

void applyTaaJitter(inout vec4 clipPosition) {
    vec2 resolution = max(vec2(viewWidth, viewHeight), vec2(1.0));
    clipPosition.xy += taaJitterOffset(frameCounter) * (2.0 / resolution) * clipPosition.w;
}
#else
void applyTaaJitter(inout vec4 clipPosition) {
}
#endif

#endif
