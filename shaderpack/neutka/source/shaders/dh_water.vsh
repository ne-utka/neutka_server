#version 330 compatibility

out vec4 vertexColor;
out vec2 lightCoord;
flat out int materialId;

void main() {
    gl_Position = ftransform();
    vertexColor = gl_Color;
    lightCoord = clamp((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy, 0.0, 1.0);
    materialId = dhMaterialId;
}
