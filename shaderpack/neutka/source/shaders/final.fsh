#version 330 compatibility

#include "/settings.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D dhDepthTex;

uniform float near;
uniform float far;
uniform float dhNearPlane;
uniform float dhFarPlane;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float fogStart;
uniform float fogEnd;
uniform int isEyeInWater;

in vec2 texCoord;

bool validNativeDepth(float depth) {
    return depth > 0.00001 && depth < 0.999999;
}

bool validDhDepth(float depth) {
    return depth > 0.00001 && depth < 0.9999;
}

float linearNativeDepth(float depth) {
    return (near * far) / (depth * (near - far) + far);
}

float linearDhDepth(float depth) {
    return (dhNearPlane * dhFarPlane) /
           (depth * (dhNearPlane - dhFarPlane) + dhFarPlane);
}

struct SceneDepth {
    float raw;
    float linear;
    bool nativeGeometry;
    bool dhGeometry;
};

SceneDepth readSceneDepth(ivec2 pixel) {
    float nativeDepth = texelFetch(depthtex0, pixel, 0).r;
    float dhDepth = texelFetch(dhDepthTex, pixel, 0).r;
    bool nativeValid = validNativeDepth(nativeDepth);
    bool dhValid = validDhDepth(dhDepth);

    SceneDepth result;
    result.nativeGeometry = nativeValid;
    result.dhGeometry = !nativeValid && dhValid;

    if (result.dhGeometry) {
        result.raw = dhDepth;
        result.linear = linearDhDepth(dhDepth);
    } else {
        result.raw = nativeDepth;
        result.linear = nativeValid ? linearNativeDepth(nativeDepth) : far;
    }
    return result;
}

float standardOutline(SceneDepth center, SceneDepth a, SceneDepth b, SceneDepth c, SceneDepth d) {
    // CazToon's Standard mode uses its positive raw-depth Laplacian.
    float centerDepth = near / max(1.0 - center.raw, 0.000001);
    vec4 neighbourDepth = vec4(
        near / max(1.0 - a.raw, 0.000001),
        near / max(1.0 - b.raw, 0.000001),
        near / max(1.0 - c.raw, 0.000001),
        near / max(1.0 - d.raw, 0.000001)
    );
    return clamp(dot(neighbourDepth, vec4(1.0)) - centerDepth * 4.0, 0.0, 1.0);
}

float dungeonsOutline(SceneDepth center, SceneDepth a, SceneDepth b, SceneDepth c, SceneDepth d) {
    vec4 delta = vec4(a.linear, b.linear, c.linear, d.linear) - center.linear;
    float forwardStep = max(max(delta.x, delta.y), max(delta.z, delta.w));
    float diagonalContrast = max(abs(delta.x - delta.y), abs(delta.z - delta.w));
    float divisor = max(center.linear, 1.0);
    return smoothstep(0.10, 0.22, forwardStep / divisor)
         * smoothstep(0.05, 0.12, diagonalContrast / divisor);
}

float outlineAt(ivec2 pixel) {
    ivec2 size = textureSize(depthtex0, 0);
    ivec2 lo = ivec2(0);
    ivec2 hi = size - ivec2(1);
    int radius = OUTLINE_PIXEL_SIZE;

    SceneDepth center = readSceneDepth(clamp(pixel, lo, hi));
    if (!center.nativeGeometry && !center.dhGeometry) return 0.0;

    SceneDepth a = readSceneDepth(clamp(pixel + ivec2(-radius, -radius), lo, hi));
    SceneDepth b = readSceneDepth(clamp(pixel + ivec2( radius,  radius), lo, hi));
    SceneDepth c = readSceneDepth(clamp(pixel + ivec2(-radius,  radius), lo, hi));
    SceneDepth d = readSceneDepth(clamp(pixel + ivec2( radius, -radius), lo, hi));

    // Never draw a seam where native chunks hand over to Distant Horizons.
    if (center.nativeGeometry && (a.dhGeometry || b.dhGeometry || c.dhGeometry || d.dhGeometry)) return 0.0;
    if (center.dhGeometry && (a.nativeGeometry || b.nativeGeometry || c.nativeGeometry || d.nativeGeometry)) return 0.0;

    // Reject unstable DH tiles whose local linear-depth span is implausibly large.
    if (center.dhGeometry) {
        float maximumDepth = center.linear;
        float minimumDepth = center.linear;
        if (a.dhGeometry) { maximumDepth = max(maximumDepth, a.linear); minimumDepth = min(minimumDepth, a.linear); }
        if (b.dhGeometry) { maximumDepth = max(maximumDepth, b.linear); minimumDepth = min(minimumDepth, b.linear); }
        if (c.dhGeometry) { maximumDepth = max(maximumDepth, c.linear); minimumDepth = min(minimumDepth, c.linear); }
        if (d.dhGeometry) { maximumDepth = max(maximumDepth, d.linear); minimumDepth = min(minimumDepth, d.linear); }
        if (maximumDepth - minimumDepth > 100.0) return 0.0;
    }

#if OUTLINE_MODE == 1
    return standardOutline(center, a, b, c, d);
#elif OUTLINE_MODE == 2
    return dungeonsOutline(center, a, b, c, d);
#else
    return 0.0;
#endif
}

vec3 rgbToHsv(vec3 c) {
    vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float greenLodFilter(vec3 color, bool dhGeometry) {
    if (!dhGeometry) return 1.0;
    vec3 c = clamp(color, vec3(0.0), vec3(1.0));
    float maximumChannel = max(c.r, c.b);
    float greenExcess = c.g - maximumChannel;
    float greenRatio = c.g / max((c.r + c.b) * 0.5, 0.0001);

    vec3 hsv = rgbToHsv(c);
    float hueDistance = abs(hsv.x - 0.3333333);
    hueDistance = min(hueDistance, 1.0 - hueDistance);
    float greenHue = 1.0 - smoothstep(0.10, 0.18, hueDistance);

    float vegetation = greenHue
        * smoothstep(0.28, 0.60, hsv.y)
        * smoothstep(0.08, 0.35, hsv.z)
        * smoothstep(0.06, 0.18, greenExcess)
        * smoothstep(1.15, 1.75, greenRatio);
    return 1.0 - clamp(vegetation, 0.0, 1.0);
}

float fogSuppression(float distanceToPixel, float skylight, vec4 suppression) {
    float configuredEnd = max(fogEnd, fogStart + 1.0);
    float configuredStart = mix(fogStart, configuredEnd, OUTLINE_FOG_START);
    float atmosphericFog = smoothstep(configuredStart, configuredEnd, distanceToPixel) * OUTLINE_FOG_STRENGTH;
    float underwaterFog = isEyeInWater == 1 ? smoothstep(2.0, 32.0, distanceToPixel) : 0.0;
    float weatherFog = max(suppression.b, rainStrength * smoothstep(16.0, 96.0, distanceToPixel));
    float fogOpacity = clamp(max(atmosphericFog, max(underwaterFog, weatherFog)), 0.0, 1.0);

    float clearVisibility = 1.0 - smoothstep(0.0, 0.35, fogOpacity);
    float lowSkylight = 1.0 - smoothstep(1.0 / 15.0, 3.0 / 15.0, skylight);
    float caveVisibility = 1.0 - smoothstep(10.0, 40.0, distanceToPixel);
    return mix(clearVisibility, caveVisibility, lowSkylight) * (1.0 - rainStrength);
}

vec3 saturateAlongEdge(vec3 color, float saturation) {
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    return max(mix(vec3(luma), color, max(saturation, 0.0)), vec3(0.0));
}

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    vec4 scene = texture(colortex0, texCoord);

#if OUTLINE_MODE != 0
    vec4 metadata = texelFetch(colortex1, pixel, 0);
    vec4 suppression = texelFetch(colortex2, pixel, 0);
    SceneDepth center = readSceneDepth(pixel);

    float outlineMask = metadata.r;
    bool voxyGeometry = metadata.a > 0.999;
#ifndef VOXY_LOD_OUTLINES
    if (voxyGeometry) outlineMask = 0.0;
#endif

    float visibility = fogSuppression(center.linear, metadata.b, suppression);
    float cloudVisibility = 1.0 - smoothstep(0.02, 0.20, suppression.r);
    float translucentVisibility = 1.0 - step(0.01, suppression.g);
    float vegetationVisibility = greenLodFilter(scene.rgb, center.dhGeometry);

    float edge = outlineAt(pixel)
               * outlineMask
               * visibility
               * cloudVisibility
               * translucentVisibility
               * vegetationVisibility;

    scene.rgb *= 1.0 + edge * OUTLINE_BRIGHTNESS;
    scene.rgb = mix(scene.rgb, saturateAlongEdge(scene.rgb, OUTLINE_SATURATION), clamp(edge, 0.0, 1.0));
#endif

    gl_FragColor = scene;
}
