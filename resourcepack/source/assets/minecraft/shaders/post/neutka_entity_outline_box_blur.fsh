#version 330

layout(std140) uniform SamplerInfo {
    vec2 OutSize;
    vec2 InSize;
};

layout(std140) uniform BlurConfig {
    vec2 BlurDir;
    float Radius;
};

uniform sampler2D InSampler;

in vec2 texCoord;

out vec4 fragColor;

void main() {
    vec2 oneTexel = 1.0 / InSize;
    vec2 sampleStep = oneTexel * BlurDir;

    vec4 blurred = vec4(0.0);
    for (float offset = -Radius + 0.5; offset <= Radius; offset += 2.0) {
        blurred += texture(InSampler, texCoord + sampleStep * offset);
    }
    blurred += texture(InSampler, texCoord + sampleStep * Radius) / 2.0;
    fragColor = vec4((blurred / (Radius + 0.5)).rgb, blurred.a);
}
