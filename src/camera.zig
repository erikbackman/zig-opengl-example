const C = @import("c.zig");
const std = @import("std");
const pi = std.math.pi;
const cos = std.math.cos;
const sin = std.math.sin;

const math = @import("math.zig");
const Vec3 = math.Vec3;
const vec3 = math.vec3;
const Mat4 = math.Mat4;
const lookAt = math.lookAt;
const perspective = math.perspective;

pub const CameraMovement = enum {
    Forward,
    Backward,
    Left,
    Right,
    Up,
    Down,
};

const YAW = -90.0;
const PITCH = 0.0;

pub const Camera = struct {
    position: Vec3,
    front: Vec3,
    up: Vec3,
    right: Vec3,
    worldUp: Vec3,

    fov: f32,
    sensitivity: f32,
    yaw: f32,
    pitch: f32,
    speed: f32,

    pub fn init(position: Vec3, up: Vec3, yaw: f32, pitch: f32) Camera {
        var camera = Camera{
            .position = position,
            .front = vec3(0.0, 0.0, -1.0),
            .up = up,
            .right = vec3(-1.0, 0, 0, 0.0),
            .worldUp = up,
            .fov = 45.0,
            .sensitivity = 0.3,
            .yaw = yaw,
            .pitch = pitch,
        };
        camera.udpateCameraVectors();
        return camera;
    }

    pub fn default() Camera {
        var camera = Camera{
            .position = vec3(0.0, 0.0, 1.0),
            .front = vec3(0.0, 0.0, -1.0),
            .up = vec3(0.0, 1.0, 0.0),
            .right = vec3(-1.0, 0.0, 0.0),
            .worldUp = vec3(0.0, 1.0, 0.0),

            .fov = 45.0,
            .sensitivity = 0.3,
            .yaw = YAW,
            .pitch = PITCH,
            .speed = 2.0,
        };
        camera.updateCameraVectors();
        return camera;
    }

    pub fn getViewMatrix(self: *Camera) Mat4 {
        return lookAt(self.position, self.position.add(self.front), self.up);
    }

    pub fn getProjMatrix(self: *Camera, aspect: f32) Mat4 {
        return perspective(self.fov, aspect, 0.1, 100.0);
    }

    pub fn processKeyboard(self: *Camera, direction: CameraMovement, deltaTime: f32) void {
        const velocity = self.speed * deltaTime;
        switch (direction) {
            .Forward => self.position = self.position.add(self.front.mulScalar(velocity)),
            .Backward => self.position = self.position.sub(self.front.mulScalar(velocity)),
            .Left => self.position = self.position.sub(self.right.mulScalar(velocity)),
            .Right => self.position = self.position.add(self.right.mulScalar(velocity)),
            .Up => self.position = self.position.add(self.up.mulScalar(velocity)),
            .Down => self.position = self.position.sub(self.up.mulScalar(velocity)),
        }
    }

    pub fn processMouse(self: *Camera, xoffset: f64, yoffset: f64) void {
        self.yaw += @as(f32, @floatCast(xoffset * self.sensitivity));
        self.pitch += @as(f32, @floatCast(yoffset * self.sensitivity));

        if (self.pitch > 89.0) self.pitch = 89.0;
        if (self.pitch < -89.0) self.pitch = -89.0;

        self.updateCameraVectors();
    }

    // Calculates the front vector from the Camera's (updated) Euler Angles
    fn updateCameraVectors(self: *Camera) void {
        // Calculate the new Front vector
        var front: Vec3 = undefined;
        front.vals[0] = cos(self.yaw / 180.0 * pi) * cos(self.pitch / 180.0 * pi);
        front.vals[1] = sin(self.pitch / 180.0 * pi);
        front.vals[2] = sin(self.yaw / 180.0 * pi) * cos(self.pitch / 180.0 * pi);
        self.front = front.normalize();
        // Also re-calculate the Right and Up vector
        self.right = self.front.cross(self.worldUp).normalize();
        self.up = self.right.cross(self.front).normalize();
    }
};
