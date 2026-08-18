#ifndef NEUTKA_SETTINGS_GLSL
#define NEUTKA_SETTINGS_GLSL

// Temporal anti-aliasing with an 8-sample jitter sequence and reprojected history.
#define TAA_ENABLED
#define TAA_BLEND 0.90 // [0.70 0.75 0.80 0.85 0.88 0.90 0.92 0.95]
#define TAA_JITTER_STRENGTH 1.00 // [0.00 0.25 0.50 0.75 1.00]

// 0 = disabled, 1 = standard, 2 = dungeons-style
#define OUTLINE_MODE 2 // [0 1 2]

// Positive values create bright outlines; negative values create dark outlines.
#define OUTLINE_BRIGHTNESS 0.20 // [-1.00 -0.75 -0.50 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.50 0.75 1.00]
#define OUTLINE_SATURATION 1.35 // [0.00 0.25 0.50 0.75 1.00 1.10 1.25 1.35 1.50 1.75 2.00 2.50 3.00]
#define OUTLINE_PIXEL_SIZE 2 // [1 2 3 4 5 6 8 10 12 16]

// Allow outlines on Voxy LOD geometry. Disabled by default to avoid noisy LOD edges.
//#define VOXY_LOD_OUTLINES

// CazToon-style distant Voxy face flattening. Samples the center of each atlas tile.
#define VOXY_FACE_FLATTEN_ENABLED
#define VOXY_FACE_FLATTEN_START 0.50 // [0.00 0.25 0.50 0.60 0.70 0.80 0.90 0.95]

// Fade native water texture detail into the smoother DH representation by distance.
#define WATER_LOD_SMOOTHING_ENABLED
#define WATER_BLUR_START 50.0 // [16.0 24.0 32.0 40.0 50.0 64.0 80.0 96.0 128.0 160.0]
#define WATER_BLUR_END 160.0 // [64.0 80.0 96.0 128.0 160.0 192.0 256.0 320.0 512.0]
#define WATER_BLUR_STRENGTH 1.00 // [0.00 0.25 0.50 0.75 1.00]

// CazToon-style material exclusions for foliage and waving vegetation.
//#define MAGICAL_TOUCH

// Fog suppression controls used by the standalone neutka atmosphere approximation.
#define OUTLINE_FOG_START 0.55 // [0.25 0.35 0.45 0.55 0.65 0.75 0.85]
#define OUTLINE_FOG_STRENGTH 1.00 // [0.00 0.25 0.50 0.75 1.00]

// Emissive metadata and color contribution.
#define EMISSIVE_BRIGHTNESS 1.30 // [0.50 0.75 1.00 1.30 1.50 2.00 3.00]
#define ENTITY_EMISSIVE_BRIGHTNESS 2.00 // [0.50 1.00 1.50 2.00 3.00 4.00]

#endif
