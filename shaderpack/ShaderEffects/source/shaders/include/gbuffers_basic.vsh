#include "/include/taa_jitter.glsl"

out vec4 vertexColor;

void main() {
    gl_Position = ftransform();
    applyTaaJitter(gl_Position);
    vertexColor = gl_Color;
}
