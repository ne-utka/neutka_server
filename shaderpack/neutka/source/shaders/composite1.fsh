#version 330 compatibility

#include "/settings.glsl"

/* RENDERTARGETS: 0,4 */

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D dhDepthTex;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;
uniform mat4 dhProjectionInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;

in vec2 texCoord;

layout(location = 0) out vec4 sceneOut;
layout(location = 1) out vec4 historyOut;

bool finiteVector(vec2 value) {
    return !any(isnan(value)) && !any(isinf(value));
}

bool finiteVector(vec4 value) {
    return !any(isnan(value)) && !any(isinf(value));
}

bool validDepth(float depth) {
    return depth > 0.00001 && depth < 0.999999;
}

vec2 taaJitterOffset(int frameIndex) {
    const vec2 offsets[8] = vec2[8](
        vec2( 0.125, -0.375),
        vec2(-0.125,  0.375),
        vec2( 0.625,  0.125),
        vec2( 0.375, -0.625),
        vec2(-0.625,  0.625),
        vec2(-0.875, -0.125),
        vec2( 0.375,  0.875),
        vec2( 0.875, -0.875)
    );
    return offsets[frameIndex & 7] * TAA_JITTER_STRENGTH;
}

vec2 reprojectToPrevious(vec2 uv, float nativeDepth, float dhDepth, bool voxyGeometry) {
    vec2 resolution = max(vec2(viewWidth, viewHeight), vec2(1.0));
    vec2 currentJitter = voxyGeometry ? vec2(0.0) : taaJitterOffset(frameCounter);
    vec2 currentNdc = uv * 2.0 - 1.0 - currentJitter * (2.0 / resolution);

    bool nativeGeometry = validDepth(nativeDepth);
    bool dhGeometry = !nativeGeometry && validDepth(dhDepth);
    vec4 previousClip;

    if (nativeGeometry || dhGeometry) {
        float depth = dhGeometry ? dhDepth : nativeDepth;
        mat4 projectionInverse = dhGeometry ? dhProjectionInverse : gbufferProjectionInverse;
        vec4 viewPosition = projectionInverse * vec4(currentNdc, depth * 2.0 - 1.0, 1.0);
        if (!finiteVector(viewPosition) || abs(viewPosition.w) < 1.0e-7) return vec2(-1.0);
        viewPosition /= viewPosition.w;

        vec4 playerPosition = gbufferModelViewInverse * viewPosition;
        playerPosition.xyz += cameraPosition - previousCameraPosition;
        previousClip = gbufferPreviousProjection * gbufferPreviousModelView * playerPosition;
    } else {
        vec4 viewDirection = gbufferProjectionInverse * vec4(currentNdc, 1.0, 1.0);
        if (!finiteVector(viewDirection) || abs(viewDirection.w) < 1.0e-7) return vec2(-1.0);
        vec3 direction = normalize(viewDirection.xyz / viewDirection.w);
        vec3 playerDirection = mat3(gbufferModelViewInverse) * direction;
        vec3 previousViewDirection = mat3(gbufferPreviousModelView) * playerDirection;
        previousClip = gbufferPreviousProjection * vec4(previousViewDirection, 0.0);
    }

    if (!finiteVector(previousClip) || abs(previousClip.w) < 1.0e-7) return vec2(-1.0);
    vec2 previousUv = previousClip.xy / previousClip.w * 0.5 + 0.5;
    return finiteVector(previousUv) ? previousUv : vec2(-1.0);
}

void neighborhoodBounds(ivec2 pixel, out vec3 minimumColor, out vec3 maximumColor) {
    ivec2 size = textureSize(colortex0, 0);
    minimumColor = vec3(65504.0);
    maximumColor = vec3(-65504.0);
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            ivec2 samplePixel = clamp(pixel + ivec2(x, y), ivec2(0), size - ivec2(1));
            vec3 sampleColor = texelFetch(colortex0, samplePixel, 0).rgb;
            minimumColor = min(minimumColor, sampleColor);
            maximumColor = max(maximumColor, sampleColor);
        }
    }
}

void main() {
#ifndef TAA_ENABLED
    vec4 currentColor = texture(colortex0, texCoord);
    sceneOut = currentColor;
    historyOut = vec4(currentColor.rgb, 1.0);
    return;
#else
    vec2 resolution = max(vec2(viewWidth, viewHeight), vec2(1.0));
    vec2 halfTexel = 0.5 / resolution;

    // Rasterized geometry contains the current sub-pixel offset. Sample it at
    // that offset so the resolved image and its history stay on a stable grid.
    bool voxyAtCenter = texture(colortex1, texCoord).a > 0.999;
    vec2 currentJitter = voxyAtCenter ? vec2(0.0) : taaJitterOffset(frameCounter);
    vec2 currentUv = clamp(texCoord + currentJitter / resolution,
                           halfTexel, vec2(1.0) - halfTexel);

    vec4 currentColor = texture(colortex0, currentUv);
    float nativeDepth = texture(depthtex0, currentUv).r;
    float dhDepth = texture(dhDepthTex, currentUv).r;
    bool voxyGeometry = texture(colortex1, currentUv).a > 0.999;

    vec2 previousUv = reprojectToPrevious(currentUv, nativeDepth, dhDepth, voxyGeometry);
    bool validHistoryUv = all(greaterThan(previousUv, vec2(0.001)))
                       && all(lessThan(previousUv, vec2(0.999)));
    bool cameraStable = length(cameraPosition - previousCameraPosition) < 32.0;

    vec4 resolved = currentColor;
    if (frameCounter > 1 && validHistoryUv && cameraStable) {
        vec4 historyColor = texture(colortex4, previousUv);
        if (historyColor.a > 0.5 && finiteVector(historyColor)) {
            vec3 minimumColor;
            vec3 maximumColor;
            neighborhoodBounds(ivec2(currentUv * resolution), minimumColor, maximumColor);
            vec3 clippedHistory = clamp(historyColor.rgb, minimumColor, maximumColor);

            vec2 velocityPixels = (previousUv - texCoord) * vec2(viewWidth, viewHeight);
            float motion = length(velocityPixels);
            float motionRejection = smoothstep(0.75, 10.0, motion);
            float historyWeight = TAA_BLEND * mix(1.0, 0.12, motionRejection);

            float nativeLinear = validDepth(nativeDepth)
                ? 0.05 / max(1.0 - nativeDepth, 0.00001)
                : 1000.0;
            historyWeight *= smoothstep(0.35, 1.5, nativeLinear);
            resolved.rgb = mix(currentColor.rgb, clippedHistory, clamp(historyWeight, 0.0, 0.97));
        }
    }

    resolved.a = currentColor.a;
    sceneOut = resolved;
    historyOut = vec4(resolved.rgb, 1.0);
#endif
}
