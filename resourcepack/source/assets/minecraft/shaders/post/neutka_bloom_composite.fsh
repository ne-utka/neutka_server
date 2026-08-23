#version 330

uniform sampler2D SceneSampler;
uniform sampler2D BloomSampler;

layout(std140) uniform CompositeConfig {
    float BloomStrength;
    float Exposure;
    float Saturation;
    float VignetteStrength;
};

in vec2 texCoord;
out vec4 fragColor;

void main() {
    vec3 scene = texture(SceneSampler, texCoord).rgb;
    vec3 bloom = texture(BloomSampler, texCoord).rgb;
    vec3 color = scene * Exposure + bloom * BloomStrength;

    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luma), color, Saturation);

    vec2 centered = texCoord * 2.0 - 1.0;
    float edge = smoothstep(0.25, 1.35, dot(centered, centered));
    color *= 1.0 - edge * VignetteStrength;

    color = color / (vec3(1.0) + max(color - vec3(1.0), vec3(0.0)) * 0.35);
    fragColor = vec4(color, 1.0);
}
