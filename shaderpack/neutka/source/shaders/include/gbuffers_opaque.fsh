/* RENDERTARGETS: 0,1 */

#include "/settings.glsl"

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;

#ifdef APPLY_ENTITY_COLOR
uniform vec4 entityColor;
uniform int entityId;
uniform int currentRenderedItemId;
#endif

in vec2 texCoord;
in vec2 lightCoord;
in vec4 vertexColor;
in float emissiveLayer;
flat in int materialId;

layout(location = 0) out vec4 sceneOut;
layout(location = 1) out vec4 maskOut;

#ifndef OUTLINE_MASK_VALUE
#define OUTLINE_MASK_VALUE 1.0
#endif

#ifndef MATERIAL_CLASS
#define MATERIAL_CLASS 0.0
#endif

bool isBlockEmissive(int id) {
    int localId = id >= 10000 ? id - 10000 : id;
    return (localId >= 20 && localId <= 59) ||
           (localId >= 83 && localId <= 89) ||
           (localId >= 95 && localId <= 97);
}

bool magicalTouchExcluded(int id) {
    int localId = id >= 10000 ? id - 10000 : id;
    return localId == 2 || localId == 3 || localId == 4 || localId == 5 ||
           localId == 15 || localId == 18 || localId == 19 || localId == 82 ||
           localId == 201 || localId == 60 || localId == 61 || localId == 62;
}

void main() {
    vec4 albedo = texture(gtexture, texCoord) * vertexColor;
    if (albedo.a < alphaTestRef) discard;

#ifdef APPLY_ENTITY_COLOR
    albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
#endif

    vec3 lighting = texture(lightmap, lightCoord).rgb;
    float emissive = isBlockEmissive(materialId) ? 1.0 : 0.0;

#ifdef APPLY_ENTITY_COLOR
    // Full-bright entity layers (eyes, emissive render layers) follow CazToon:
    // they glow, but do not participate in the post-process outline mask.
    emissive = max(emissive, emissiveLayer);
#ifdef EMISSIVE
    emissive = 1.0;
#endif

    if (entityId == 101 && albedo.r > 0.8 && albedo.g < 0.2 && albedo.b < 0.2) emissive = 1.0;
    if (entityId == 103 && albedo.r > 0.7 && albedo.g > 0.8 && albedo.b < 0.4) emissive = 0.8;
    if (entityId == 104 && albedo.r > 0.8 && albedo.g > 0.9 && albedo.b > 0.9) emissive = 0.9;
    if (entityId == 105) emissive = 0.7;
    if (entityId == 106 && albedo.r > 0.5 && albedo.g > 0.8 && albedo.b > 0.9) emissive = 0.8;
    if (entityId == 107 && albedo.r > 0.6 && albedo.g < 0.3 && albedo.b < 0.3) emissive = 0.9;
    if (entityId == 108 && albedo.r > 0.9 && albedo.g > 0.5 && albedo.b < 0.6) emissive = 0.6;
    if (entityId == 109 || entityId == 110) emissive = 1.0;

    bool heldItemEmissive = (currentRenderedItemId >= 10020 && currentRenderedItemId <= 10059)
                         || currentRenderedItemId == 10087 || currentRenderedItemId == 10089;
    if (heldItemEmissive) emissive = 1.0;
#endif

    vec3 litColor = albedo.rgb * lighting;
    vec3 emissiveColor = albedo.rgb * EMISSIVE_BRIGHTNESS;
#ifdef APPLY_ENTITY_COLOR
    emissiveColor *= ENTITY_EMISSIVE_BRIGHTNESS;
    if (heldItemEmissive) {
        emissiveColor = vec3(1.0, 0.85, 0.4) * EMISSIVE_BRIGHTNESS;
        if (currentRenderedItemId == 10021 || currentRenderedItemId == 10043) {
            emissiveColor = vec3(0.3, 0.7, 1.0) * EMISSIVE_BRIGHTNESS;
        }
    }
    if (entityId == 105) emissiveColor = albedo.rgb * 0.01;
    if (entityId == 109) emissiveColor = albedo.rgb * 0.15;
    if (entityId == 110) emissiveColor = albedo.rgb * EMISSIVE_BRIGHTNESS;
#endif
    litColor = mix(litColor, emissiveColor, emissive);

    float outlineMask = OUTLINE_MASK_VALUE;
#ifdef APPLY_ENTITY_COLOR
    if (emissiveLayer > 0.5) outlineMask = 0.0;
#ifdef EMISSIVE
    outlineMask = 0.0;
#endif
#endif
#ifdef MAGICAL_TOUCH
    if (magicalTouchExcluded(materialId)) outlineMask = 0.0;
#endif

    sceneOut = vec4(litColor, albedo.a);
    maskOut = vec4(outlineMask, emissive, clamp(lightCoord.y, 0.0, 1.0), MATERIAL_CLASS);
}
