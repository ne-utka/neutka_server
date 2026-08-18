#version 330

uniform sampler2D SceneSampler;
uniform sampler2D ItemEntitySampler;

layout(std140) uniform BloomConfig {
    float Threshold;
    float SoftKnee;
    float ItemBoost;
};

in vec2 texCoord;
out vec4 fragColor;

float brightness(vec3 color) {
    return max(max(color.r, color.g), color.b);
}

void main() {
    vec3 scene = texture(SceneSampler, texCoord).rgb;
    vec4 item = texture(ItemEntitySampler, texCoord);

    float level = brightness(scene);
    float knee = max(SoftKnee, 0.0001);
    float bloomWeight = smoothstep(Threshold - knee, Threshold + knee, level);
    vec3 sceneBloom = max(scene - vec3(Threshold - knee), vec3(0.0)) * bloomWeight;

    float coloredItem = step(0.98, item.a)
        * (1.0 - step(0.999, item.r) * step(0.999, item.g) * step(0.999, item.b));
    vec3 itemLight = item.rgb * coloredItem * ItemBoost;

    fragColor = vec4(sceneBloom + itemLight, 1.0);
}
