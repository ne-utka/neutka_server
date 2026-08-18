#version 330 compatibility

/* RENDERTARGETS: 0 */

uniform sampler2D colortex0;

in vec2 texCoord;

void main() {
    // Keep the scene untouched until TAA has resolved it. CazToon applies its
    // outline in final, after temporal/spatial anti-aliasing.
    gl_FragColor = texture(colortex0, texCoord);
}
