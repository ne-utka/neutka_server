#version 330 compatibility

#include "/settings.glsl"

/* RENDERTARGETS: 5 */

uniform sampler2D colortex0;
uniform sampler2D colortex1;

in vec2 texCoord;

layout(location = 0) out vec4 bloomOut;

void main() {
    vec3 scene = texture(colortex0, texCoord).rgb;
    float brightness = max(max(scene.r, scene.g), scene.b);
    float knee = 0.22;
    float weight = smoothstep(BLOOM_THRESHOLD - knee, BLOOM_THRESHOLD + knee, brightness);
    vec3 brightScene = max(scene - vec3(BLOOM_THRESHOLD - knee), vec3(0.0)) * weight;

    float emissive = texture(colortex1, texCoord).g;
    vec3 emissiveGlow = scene * emissive * BLOOM_EMISSIVE_BOOST;
    bloomOut = vec4(brightScene + emissiveGlow, 1.0);
}
