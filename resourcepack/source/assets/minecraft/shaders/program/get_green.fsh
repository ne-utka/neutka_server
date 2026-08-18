#version 110

uniform sampler2D DiffuseSampler;
uniform float Power;

varying vec2 texCoord;
varying vec2 oneTexel;

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    vec3 hsv = vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
    return hsv;
}

void main() {
    vec4 input = texture2D(DiffuseSampler, texCoord);
    float brightness = rgb2hsv(input.rgb).z;
    if(brightness >= Power) gl_FragColor = input;
    else gl_FragColor = input * pow(brightness / Power, 2.0) + vec4(0.0,0.0,0.0,1.0) * (1.0 - pow(brightness / Power, 2.0));
}