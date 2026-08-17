#version 330 compatibility
/* RENDERTARGETS: 0,1,3 */

#include "/settings.glsl"

uniform sampler2D lightmap;

in vec4 vertexColor;
in vec2 lightCoord;
flat in int materialId;

layout(location = 0) out vec4 sceneOut;
layout(location = 1) out vec4 metadataOut;
layout(location = 2) out vec4 emissiveOut;

void main() {
    bool emissive = materialId == DH_BLOCK_ILLUMINATED || materialId == DH_BLOCK_LAVA;
    vec3 lit = vertexColor.rgb * texture(lightmap, lightCoord).rgb;
    vec3 glow = vertexColor.rgb * EMISSIVE_BRIGHTNESS;
    if (materialId == DH_BLOCK_LAVA) glow = vec3(1.0, 0.4, 0.1) * EMISSIVE_BRIGHTNESS;

    sceneOut = vec4(emissive ? glow : lit, vertexColor.a);
    metadataOut = vec4(1.0, emissive ? 1.0 : 0.0, lightCoord.y, 0.0);
    emissiveOut = vec4(emissive ? glow : vec3(0.0), 1.0);
}
