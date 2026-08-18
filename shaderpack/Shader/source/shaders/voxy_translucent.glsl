#include "/settings.glsl"

layout(location = 0) out vec4 voxySceneOut;
layout(location = 1) out vec4 voxyMetadataOut;
layout(location = 2) out vec4 voxySuppressionOut;

uint neutkaVoxyBlockId(uint customId) {
    return customId >= 10000u ? customId - 10000u : customId;
}

void voxy_emitFragment(VoxyFragmentParameters parameters) {
    vec4 albedo = parameters.sampledColour * parameters.tinting;
    uint id = neutkaVoxyBlockId(parameters.customId);
    bool water = id == 1u;
    bool emissive = id >= 20u && id <= 31u;
    float skylight = clamp(parameters.lightMap.y, 0.0, 1.0);
    vec3 lit = albedo.rgb * mix(0.18, 1.0, max(skylight, parameters.lightMap.x));
    vec3 glow = albedo.rgb * EMISSIVE_BRIGHTNESS;

    voxySceneOut = vec4(emissive ? glow : lit, albedo.a);
    voxyMetadataOut = vec4(water ? 0.0 : 1.0, emissive ? 1.0 : 0.0, skylight, 1.0);
    voxySuppressionOut = vec4(0.0, water ? 1.0 : 0.0, 0.0, 0.0);
}
