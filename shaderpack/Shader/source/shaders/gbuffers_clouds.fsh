#version 330 compatibility
/* RENDERTARGETS: 0,2 */

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 texCoord;
in vec4 vertexColor;

layout(location = 0) out vec4 sceneOut;
layout(location = 1) out vec4 suppressionOut;

void main() {
    vec4 color = texture(gtexture, texCoord) * vertexColor;
    if (color.a < alphaTestRef) discard;
    sceneOut = color;
    suppressionOut = vec4(color.a, 0.0, 0.0, 0.0);
}
