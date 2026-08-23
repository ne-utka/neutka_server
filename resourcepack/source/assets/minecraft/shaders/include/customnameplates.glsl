vec4 vertex = vec4(Position, 1.0);
if (Color.xyz == vec3(255., 254., 253.) / 255.) {
    gl_Position = ProjMat * ModelViewMat * vec4(Position + vec3(1, 1, 0), 1);
}