#version 330 compatibility

#include "/settings.glsl"

/* RENDERTARGETS: 6 */

uniform sampler2D colortex5;

in vec2 texCoord;

layout(location = 0) out vec4 blurOut;

void main() {
    vec2 texel = vec2(BLOOM_RADIUS, 0.0) / vec2(textureSize(colortex5, 0));
    vec3 color = texture(colortex5, texCoord).rgb * 0.227027;
    color += texture(colortex5, texCoord + texel * 1.384615).rgb * 0.316216;
    color += texture(colortex5, texCoord - texel * 1.384615).rgb * 0.316216;
    color += texture(colortex5, texCoord + texel * 3.230769).rgb * 0.070270;
    color += texture(colortex5, texCoord - texel * 3.230769).rgb * 0.070270;
    blurOut = vec4(color, 1.0);
}
