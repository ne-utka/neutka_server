#include "/include/taa_jitter.glsl"

out vec2 texCoord;
out vec4 vertexColor;

void main() {
    gl_Position = ftransform();
    applyTaaJitter(gl_Position);
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vertexColor = gl_Color;
}
