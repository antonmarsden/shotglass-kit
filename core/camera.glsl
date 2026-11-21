// shotglass-kit/core: camera.glsl
//
// A pinhole camera for raymarched shots: aim it (kit_cam_look_at), turn a pixel into
// a ray (kit_cam_ray), place it from a few numbers that movie.toml can keyframe
// (kit_cam_orbit, kit_cam_dolly, kit_cam_dolly_zoom), and optionally blur what's out
// of focus (kit_cam_dof).
// Positions and distances are in scene units; angles in radians. World up is +y, and
// the camera looks down its own +z (the third column of the matrix), so a camera
// at (0, 0, 5) aimed at the origin sees +x on the right of the screen.
//
// Driven from movie.toml, a whole camera move is two or three uniforms:
//   uniforms.uOrbit = { keys = [[0, [0.0, 0.3]], [6, [1.2, 0.5]]], ease = "inout" }
//   uniforms.uDist  = { keys = [[0, 6.0], [6, 3.5]] }
//   vec3 ro = kit_cam_orbit(target, uOrbit, uDist);
//   vec3 rd = kit_cam_ray(kit_cam_look_at(ro, target, 0.0), fragCoord, iResolution.xy, 0.8);
// sound: yes

// kit_cam_look_at(ro, ta, roll): the camera's axes, as columns (right, up, forward),
// for a camera at ro looking at ta. Multiply a camera-space direction by it to get a
// world-space one.
//   ro    camera position
//   ta    the point it looks at; must differ from ro (if not, it looks down -z)
//   roll  radians; positive rolls the camera anticlockwise, so the picture turns
//         clockwise. 0 keeps the horizon level
//   ->    an orthonormal matrix. Looking straight down (within about 0.0001 radians),
//         "up" on screen is -z, and straight up it's +z
//   e.g. mat3 cam = kit_cam_look_at(vec3(0.0, 1.0, 5.0), vec3(0.0), 0.0);
mat3 kit_cam_look_at(vec3 ro, vec3 ta, float roll) {
    vec3 d = ta - ro;
    vec3 fw = dot(d, d) > 1e-20 ? normalize(d) : vec3(0.0, 0.0, -1.0);
    vec3 side = cross(fw, vec3(0.0, 1.0, 0.0));
    vec3 rt = dot(side, side) > 1e-8 ? normalize(side) : vec3(1.0, 0.0, 0.0);
    vec3 up = cross(rt, fw);
    float c = cos(roll), s = sin(roll);
    return mat3(c * rt + s * up, c * up - s * rt, fw);
}

// kit_cam_ray(cam, fragCoord, resolution, fov): the direction of the ray through a
// pixel, for a pinhole camera with axes cam. The aspect ratio comes from resolution,
// so circles stay round at any frame size.
//   cam         from kit_cam_look_at
//   fragCoord   pixel position, as passed to mainImage; add a sub-pixel offset
//               (-0.5..0.5) for anti-aliasing
//   resolution  frame size in pixels (iResolution.xy)
//   fov         vertical field of view, radians, clamped to 0.001..3.1
//               (0.8 is about 46 degrees, a normal lens)
//   ->          unit-length world-space direction
//   e.g. mat3 cam = kit_cam_look_at(vec3(0.0, 1.0, 5.0), vec3(0.0), 0.0);
//        vec3 rd = kit_cam_ray(cam, fragCoord, iResolution.xy, 0.8);
vec3 kit_cam_ray(mat3 cam, vec2 fragCoord, vec2 resolution, float fov) {
    vec2 sp = (2.0 * fragCoord - resolution) / max(resolution.y, 1.0);
    float h = tan(0.5 * clamp(fov, 0.001, 3.1));
    return normalize(cam * vec3(sp * h, 1.0));
}

// kit_cam_orbit(ta, angles, dist): a camera position on a sphere around ta, for
// orbiting a subject. Keyframe angles as one vec2 uniform and dist as a float.
//   ta      the point orbited (the look-at target)
//   angles  radians: x = yaw, round the vertical axis (0 puts the camera on +z of ta,
//           increasing swings it towards +x); y = pitch, above the horizon, clamped
//           to -1.55..1.55 so the camera never goes straight over the top
//   dist    distance from ta, scene units; clamped to >= 0
//   ->      camera position; aim it with kit_cam_look_at(ro, ta, roll)
//   e.g. vec3 ro = kit_cam_orbit(vec3(0.0), vec2(0.6 * iTime, 0.3), 5.0);
vec3 kit_cam_orbit(vec3 ta, vec2 angles, float dist) {
    float pitch = clamp(angles.y, -1.55, 1.55);
    float cp = cos(pitch);
    return ta + max(dist, 0.0) * vec3(cp * sin(angles.x), sin(pitch), cp * cos(angles.x));
}

// kit_cam_dolly(ro, ta, d): move the camera d units along the line towards ta,
// keeping its aim (a dolly in; negative d dollies out).
//   ro  camera position
//   ta  the point it looks at
//   d   scene units; clamped so the camera stops 0.001 short of ta. If ro = ta the
//       camera stays put
//   ->  the new camera position
//   e.g. vec3 ro = kit_cam_dolly(vec3(0.0, 1.0, 6.0), vec3(0.0), 2.0 * iShotProgress);
vec3 kit_cam_dolly(vec3 ro, vec3 ta, float d) {
    vec3 v = ta - ro;
    float len = length(v);
    if (len < 1e-6) return ro;
    return ro + v * (min(d, len - 0.001) / len);
}

// kit_cam_dolly_zoom(fov, dist0, dist): the field of view that keeps the subject the
// same size on screen when the camera moves from dist0 to dist away from it (the
// "vertigo" shot: dolly in while zooming out, and the background stretches).
//   fov    vertical field of view at dist0, radians, 0..3.1
//   dist0  distance to the subject at which fov applies, scene units, > 0
//   dist   current distance to the subject, scene units, > 0 (clamped to >= 0.0001)
//   ->     vertical field of view, radians, 0..pi (wider when dist < dist0)
//   e.g. float fov = kit_cam_dolly_zoom(0.5, 6.0, length(ro - ta));
float kit_cam_dolly_zoom(float fov, float dist0, float dist) {
    float h = tan(0.5 * clamp(fov, 0.0, 3.1)) * max(dist0, 0.0) / max(dist, 1e-4);
    return 2.0 * atan(h);
}

// kit_cam_dof(ro, rd, cam, aperture, focus, xi): depth of field. Moves the ray's
// origin to a random point on the lens and re-aims it at the same point on the focal
// plane, so things at distance focus stay sharp and the rest blurs. Average several
// rays per pixel (with different xi) for a smooth result; one ray per pixel gives
// grain instead of blur.
//   ro        in: camera position (the pinhole); out: the ray's new origin
//   rd        in: the pinhole ray from kit_cam_ray; out: the new direction, unit length
//   cam       the matrix rd came from (the lens lies in its right/up plane)
//   aperture  lens radius, scene units, >= 0 (0: no blur; 0.05 is a strong blur for a
//             subject 5 units away)
//   focus     distance to the plane in focus, along the camera's forward axis, > 0
//   xi        two random numbers in 0..1 (e.g. from kit_hash), different per ray
//   cost: a sqrt, a sin and a cos
//   e.g. vec3 ro = vec3(0.0, 1.0, 5.0);
//        mat3 cam = kit_cam_look_at(ro, vec3(0.0), 0.0);
//        vec3 rd = kit_cam_ray(cam, fragCoord, iResolution.xy, 0.8);
//        kit_cam_dof(ro, rd, cam, 0.04, 5.1, vec2(kit_hash(ivec3(ivec2(fragCoord), 0)),
//                                                 kit_hash(ivec3(ivec2(fragCoord), 1))));
void kit_cam_dof(inout vec3 ro, inout vec3 rd, mat3 cam, float aperture, float focus, vec2 xi) {
    // the focal point: where the pinhole ray meets the plane at distance focus
    vec3 fp = ro + rd * (max(focus, 0.0) / max(dot(rd, cam[2]), 1e-4));
    float r = max(aperture, 0.0) * sqrt(clamp(xi.x, 0.0, 1.0));
    float a = 6.28318531 * xi.y;
    ro += cam * vec3(r * cos(a), r * sin(a), 0.0);
    rd = normalize(fp - ro);
}
