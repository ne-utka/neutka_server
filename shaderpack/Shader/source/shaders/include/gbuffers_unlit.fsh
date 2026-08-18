/* RENDERTARGETS: 0 */

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 texCoord;
in vec4 vertexColor;
layout(location = 0) out vec4 sceneOut;

void main() {
    vec4 color = texture(gtexture, texCoord) * vertexColor;
    if (color.a < alphaTestRef) discard;
    sceneOut = color;
}
