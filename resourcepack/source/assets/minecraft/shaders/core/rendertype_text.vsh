#version 330

#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:dynamictransforms.glsl>
#moj_import <minecraft:projection.glsl>
#moj_import <minecraft:sample_lightmap.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV2;

uniform sampler2D Sampler2;

out float sphericalVertexDistance;
out float cylindricalVertexDistance;
out vec4 vertexColor;
out vec2 texCoord0;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    sphericalVertexDistance = fog_spherical_distance(Position);
    cylindricalVertexDistance = fog_cylindrical_distance(Position);
    vertexColor = Color * sample_lightmap(Sampler2, UV2);
    texCoord0 = UV0;

    // NoShadow behavior (https://github.com/PuckiSilver/NoShadow)
    ivec3 iColor = ivec3(Color.xyz * 255 + vec3(0.5));
    if (iColor == ivec3(78, 92, 36) && (
        Position.z == 2200.03 || // Actionbar
        Position.z == 2400.06 || // Subtitle
        Position.z == 2400.12 || // Title
        Position.z == 50.03 ||   // Opened Chat
        Position.z == 2650.03 || // Closed Chat
        Position.z == 200.03 ||  // Advancement Screen
        Position.z == 400.03 ||  // Items
        Position.z == 1000.03 || // Bossbar
        Position.z == 2800.03 || // Scoreboard List
        Position.z == 2000       // Scoreboard Sidebar (Has no shadow, remove tint for consistency)
        )) { // Regular text
        vertexColor.rgb = sample_lightmap(Sampler2, UV2).rgb; // Remove color from no shadow marker
    } else if (iColor == ivec3(19, 23, 9) && (
        Position.z == 2200 || // Actionbar
        Position.z == 2400 || // Subtitle | Title
        Position.z == 50 ||   // Opened Chat
        Position.z == 2650 || // Closed Chat
        Position.z == 200 ||  // Advancement Screen
        Position.z == 400 ||  // Items
        Position.z == 1000 || // Bossbar
        Position.z == 2800    // Scoreboard List
        )) { // Shadow
        gl_Position = vec4(2,2,2,1); // Move shadow off screen
    }
}
