#version 330 compatibility

uniform sampler2D colortex0;

in vec2 texCoord;

void main() {
    gl_FragColor = texture(colortex0, texCoord);
}
