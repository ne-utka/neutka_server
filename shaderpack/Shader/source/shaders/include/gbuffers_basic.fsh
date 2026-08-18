/* RENDERTARGETS: 0,1 */

in vec4 vertexColor;
layout(location = 0) out vec4 sceneOut;
layout(location = 1) out vec4 maskOut;

void main() {
    sceneOut = vertexColor;
    // CazToon marks the basic opaque pass as outline-capable. Sky pixels have
    // no valid scene depth and are rejected later by the depth detector.
    maskOut = vec4(1.0, 0.0, 1.0, 0.0);
}
