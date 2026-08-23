mat2 mat2_rotate_z(float radians) {
    return mat2(
        cos(radians), -sin(radians),
        sin(radians), cos(radians)
    );
}

int hash(int x) {
    x += ( x << 10 );
    x ^= ( x >>  6 );
    x += ( x <<  3 );
    x ^= ( x >> 11 );
    x += ( x << 15 );
    return x;
}

vec4 sampleStain(vec4 inColor, vec4 col, vec2 stp, vec2 pos)
{
    vec2 lUV = gl_FragCoord.xy / ScreenSize;
    vec2 inst = vec2(sin(col.a * 1.1 + 0.5 + lUV.y * 20) + 0.8 * cos(col.a * 1.3 + 0.2 + lUV.x * 15),
                0.5 * sin(col.a * 1.8 + 0.5 + lUV.x * 16) + 0.3 * cos(col.a * 1.5 + 0.2 + lUV.y * 13)) * 0.005;
    float Ratio = ScreenSize.y / ScreenSize.x;
    vec2 uv = (lUV - 0.5 - pos - inst + vec2(0, (1 - col.a) * 0.03)) * vec2(1, -1) / vec2(Ratio, 1) * 1.4 + 0.5;
    
    if (uv != clamp(uv, 0, 1)) return inColor;

    vec4 color = texelFetch(Sampler0, ivec2(stp + uv * vec2(165, 177)), 0) * col;

    return vec4(mix(inColor.rgb, color.rgb, color.a), min(color.a + inColor.a, 1));
}

#define PI 3.1415926
