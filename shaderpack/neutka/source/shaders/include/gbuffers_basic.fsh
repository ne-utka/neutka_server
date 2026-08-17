/* RENDERTARGETS: 0 */

in vec4 vertexColor;
layout(location = 0) out vec4 sceneOut;

void main() {
    sceneOut = vertexColor;
}
