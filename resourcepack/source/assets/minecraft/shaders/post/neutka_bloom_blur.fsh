#version 330

uniform sampler2D InSampler;

layout(std140) uniform SamplerInfo {
    vec2 OutSize;
    vec2 InSize;
};

layout(std140) uniform BlurConfig {
    vec2 Direction;
    float Radius;
};

in vec2 texCoord;
out vec4 fragColor;

void main() {
    vec2 texel = Direction / InSize;
    float radius = clamp(Radius, 1.0, 8.0);
    vec3 sum = texture(InSampler, texCoord).rgb * 0.20;
    float weightSum = 0.20;

    for (int i = 1; i <= 8; ++i) {
        float enabled = 1.0 - step(radius + 0.5, float(i));
        float x = float(i) / radius;
        float weight = exp(-2.4 * x * x) * enabled;
        sum += texture(InSampler, texCoord + texel * float(i)).rgb * weight;
        sum += texture(InSampler, texCoord - texel * float(i)).rgb * weight;
        weightSum += 2.0 * weight;
    }

    fragColor = vec4(sum / max(weightSum, 0.0001), 1.0);
}
