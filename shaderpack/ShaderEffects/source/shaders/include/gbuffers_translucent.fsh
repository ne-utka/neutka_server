/* RENDERTARGETS: 0,1,2 */

#include "/settings.glsl"

uniform sampler2D gtexture;
uniform sampler2D lightmap;

#ifdef APPLY_ENTITY_COLOR
uniform vec4 entityColor;
#endif

in vec2 texCoord;
in vec2 lightCoord;
in vec4 vertexColor;
in float emissiveLayer;
flat in int materialId;

layout(location = 0) out vec4 sceneOut;
layout(location = 1) out vec4 maskOut;
layout(location = 2) out vec4 suppressionOut;

#ifndef TRANSLUCENT_OUTLINE_MASK
#define TRANSLUCENT_OUTLINE_MASK 0.0
#endif
#ifndef SUPPRESSION_MASK
#define SUPPRESSION_MASK vec4(0.0)
#endif
#ifndef MATERIAL_CLASS
#define MATERIAL_CLASS 0.0
#endif

void main() {
    vec4 albedo = texture(gtexture, texCoord) * vertexColor;
    if (albedo.a < 0.01) discard;

#ifdef APPLY_ENTITY_COLOR
    albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
#endif

    vec3 lighting = texture(lightmap, lightCoord).rgb;
    float emissive = emissiveLayer;
#ifdef EMISSIVE
    emissive = 1.0;
#endif
    vec3 emissiveColor = albedo.rgb * EMISSIVE_BRIGHTNESS;
#ifdef APPLY_ENTITY_COLOR
    emissiveColor *= ENTITY_EMISSIVE_BRIGHTNESS;
#endif
    vec3 litColor = mix(albedo.rgb * lighting, emissiveColor, emissive);
    sceneOut = vec4(litColor, albedo.a);

    // Translucent surfaces replace the outline mask so geometry behind them
    // does not leak an outline through water, glass, or translucent entities.
    float outlineMask = TRANSLUCENT_OUTLINE_MASK;
    vec4 suppression = SUPPRESSION_MASK;
#ifdef DYNAMIC_BLOCK_TRANSLUCENCY
    int localId = materialId >= 10000 ? materialId - 10000 : materialId;
    bool water = localId == 1;
    outlineMask = water ? 0.0 : 0.95;
    suppression = vec4(0.0, water ? 1.0 : 0.0, 0.0, 0.0);
#endif
#ifdef DYNAMIC_ENTITY_TRANSLUCENCY
    outlineMask = albedo.a >= 0.9 ? 1.0 : 0.0;
#endif
    maskOut = vec4(outlineMask, emissive, clamp(lightCoord.y, 0.0, 1.0), MATERIAL_CLASS);
    suppressionOut = suppression;
}
