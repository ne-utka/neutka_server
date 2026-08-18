#version 110

uniform sampler2D DiffuseSampler;
uniform sampler2D GreenSampler;
uniform vec2 InSize;

varying vec2 texCoord;
varying vec2 oneTexel;

void main()
{
    vec2 onepixel;
    onepixel.x = 1.0 / InSize.x;
    onepixel.y = 1.0 / InSize.y;
    
    float weight[5];
    weight[0] = 0.227027 / 4.0;
    weight[1] = 0.1945946 / 4.0;
    weight[2] = 0.1216216 / 4.0;
    weight[3] = 0.054054 / 4.0;
    weight[4] = 0.016216 / 4.0;
    float alpha = texture2D(GreenSampler, texCoord).a;
    vec3 result = texture2D(GreenSampler, texCoord).rgb * weight[0];
    for(int i = 1; i < 5; i++)
    {
        result.rgb += texture2D(GreenSampler, texCoord + vec2(onepixel.x * float(i) , 0.0)).rgb * weight[i];
        result.rgb += texture2D(GreenSampler, texCoord - vec2(onepixel.x * float(i) , 0.0)).rgb * weight[i];
    }
    gl_FragColor = vec4(result, 1.0);
}