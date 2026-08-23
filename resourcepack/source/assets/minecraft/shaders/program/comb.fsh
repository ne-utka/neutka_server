#version 110

uniform sampler2D DiffuseSampler;
uniform sampler2D SecondSampler;
uniform sampler2D FirstSampler;
uniform vec2 InSize;

varying vec2 texCoord;
varying vec2 oneTexel;

void main()
{
    vec4 color_1 = texture2D(FirstSampler, texCoord);
    vec4 color_2 = texture2D(SecondSampler, texCoord);
    gl_FragColor = vec4(color_1.rgb + color_2.rgb,1.0);
}