#version 110

uniform sampler2D DiffuseSampler;
uniform sampler2D ParticlesSampler;
uniform sampler2D ParticlesDepthSampler;

varying vec2 texCoord;
varying vec2 oneTexel;


void main() {
    vec4 input = texture2D(ParticlesSampler, texCoord);
    if(input.g > (input.b + input.r) * 2.0) gl_FragColor = vec4(0.0,0.0,0.0,0.0);
    else gl_FragColor = input;
}
