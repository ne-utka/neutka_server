out vec2 texCoord;
out vec2 lightCoord;
out vec4 vertexColor;
out float emissiveLayer;
flat out int materialId;

#ifdef USE_MC_ENTITY
attribute vec4 mc_Entity;
#endif

void main() {
    gl_Position = ftransform();
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vertexColor = gl_Color;
    emissiveLayer = (gl_MultiTexCoord1.x > 240.5 && gl_MultiTexCoord1.y > 239.5) ? 1.0 : 0.0;
#ifdef USE_MC_ENTITY
    materialId = int(mc_Entity.x);
#else
    materialId = 0;
#endif
}
