#include "/settings.glsl"

layout(location = 0) out vec4 voxySceneOut;
layout(location = 1) out vec4 voxyMetadataOut;

uint neutkaVoxyBlockId(uint customId) {
    return customId >= 10000u ? customId - 10000u : customId;
}

void voxy_emitFragment(VoxyFragmentParameters parameters) {
    vec4 albedo = parameters.sampledColour * parameters.tinting;
    uint id = neutkaVoxyBlockId(parameters.customId);
    bool excluded = id == 60u || id == 61u || id == 62u;
    if (excluded) discard;

    bool emissive = ((id >= 20u && id <= 59u) && id != 46u && id != 56u && id != 57u)
                 || (id >= 83u && id <= 89u)
                 || (id >= 95u && id <= 97u);
    float skylight = clamp(parameters.lightMap.y, 0.0, 1.0);
    vec3 lit = albedo.rgb * mix(0.18, 1.0, max(skylight, parameters.lightMap.x));
    vec3 glow = albedo.rgb * EMISSIVE_BRIGHTNESS;
    if (id == 39u) glow = vec3(1.0, 0.4, 0.1) * EMISSIVE_BRIGHTNESS;

    voxySceneOut = vec4(emissive ? glow : lit, 1.0);
    voxyMetadataOut = vec4(1.0, emissive ? 1.0 : 0.0, skylight, 1.0);
}
