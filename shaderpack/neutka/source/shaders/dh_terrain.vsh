#version 330 compatibility

#include "/include/taa_jitter.glsl"

out vec4 vertexColor;
out vec2 lightCoord;
flat out int materialId;

void main() {
    gl_Position = ftransform();
    applyTaaJitter(gl_Position);
    vertexColor = gl_Color;
    lightCoord = clamp((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy, 0.0, 1.0);
    materialId = dhMaterialId;
}
