#version 330 compatibility

#include "/settings.glsl"

/* RENDERTARGETS: 0 */

uniform sampler2D colortex0;
#ifdef BLOOM_ENABLED
uniform sampler2D colortex5;
#endif

in vec2 texCoord;

void main() {
    vec4 scene = texture(colortex0, texCoord);
    vec3 color = scene.rgb;

#ifdef BLOOM_ENABLED
    color += texture(colortex5, texCoord).rgb * BLOOM_STRENGTH;
#endif

#ifdef COLOR_GRADING_ENABLED
    color *= POST_EXPOSURE;
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luma), color, POST_SATURATION);
#endif

#ifdef VIGNETTE_ENABLED
    vec2 centered = texCoord * 2.0 - 1.0;
    float edge = smoothstep(0.25, 1.35, dot(centered, centered));
    color *= 1.0 - edge * VIGNETTE_STRENGTH;
#endif

    color = color / (vec3(1.0) + max(color - vec3(1.0), vec3(0.0)) * 0.35);
    gl_FragColor = vec4(color, scene.a);
}
