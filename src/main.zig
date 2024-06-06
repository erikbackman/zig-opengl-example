const C = @import("c.zig");
const std = @import("std");
const Shader = @import("shader.zig").Shader;
const Camera = @import("camera.zig").Camera;
const CameraMovement = @import("camera.zig").CameraMovement;
const math = @import("math.zig");
const panic = std.debug.panic;

const WIN_W: u32 = 800;
const WIN_H: u32 = 600;

var camera = Camera.default();

var delta_time: f32 = 0.0;
var last_frame_time: f32 = 0.0;

var first_mouse = false;
var last_x: f64 = 0.0;
var last_y: f64 = 0.0;

pub fn main() !void {
    if (C.glfwInit() == 0) {
        panic("Failed to init glfw\n", .{});
    }
    const window = C.glfwCreateWindow(WIN_W, WIN_H, "Zig OpenGL Example", null, null);
    defer {
        C.glfwDestroyWindow(window);
        C.glfwTerminate();
    }
    if (window == null) {
        panic("Failed to create window\n", .{});
    }

    C.glfwMakeContextCurrent(window);
    _ = C.glfwSetFramebufferSizeCallback(window, sizeCallback);
    _ = C.glfwSetCursorPosCallback(window, mouseCallback);

    // GL
    initGL();

    // Shader Program
    const allocator = std.heap.page_allocator;

    var program: Shader = try Shader.init(allocator, "shader.vert", "shader.frag");
    defer program.deinit();

    // Vertex Data
    const vertices = [_]f32{
        // Position       Normal
        // Back
        -0.5, -0.5, -0.5, 0.0, 0.0, -1.0, // far bot left
        0.5, -0.5, -0.5, 0.0, 0.0, -1.0, // far bot right
        0.5, 0.5, -0.5, 0.0, 0.0, -1.0, // far top right
        -0.5, 0.5, -0.5, 0.0, 0.0, -1.0, // far top left
        // Front
        -0.5, -0.5, 0.5, 0.0, 0.0, 1.0, // near bot left
        0.5, -0.5, 0.5, 0.0, 0.0, 1.0, // near bot right
        0.5, 0.5, 0.5, 0.0, 0.0, 1.0, // near top right
        -0.5, 0.5, 0.5, 0.0, 0.0, 1.0, // near top left
        // Left
        -0.5, -0.5, -0.5, -1.0, 0.0, 0.0, // far bot left
        -0.5, -0.5, 0.5, -1.0, 0.0, 0.0, // near bot left
        -0.5, 0.5, 0.5, -1.0, 0.0, 0.0, // near top left
        -0.5, 0.5, -0.5, -1.0, 0.0, 0.0, // far top left
        // Right
        0.5, -0.5, -0.5, 1.0, 0.0, 0.0, // far bot right
        0.5, -0.5, 0.5, 1.0, 0.0, 0.0, // near bot right
        0.5, 0.5, 0.5, 1.0, 0.0, 0.0, // near top right
        0.5, 0.5, -0.5, 1.0, 0.0, 0.0, // far top right
        // Bot
        -0.5, -0.5, -0.5, 0.0, -1.0, 0.0, // far bot left
        -0.5, -0.5, 0.5, 0.0, -1.0, 0.0, // near bot left
        0.5, -0.5, 0.5, 0.0, -1.0, 0.0, // near bot right
        0.5, -0.5, -0.5, 0.0, -1.0, 0.0, // far bot right
        // Top
        -0.5, 0.5, -0.5, 0.0, 1.0, 0.0, // far top left
        -0.5, 0.5, 0.5, 0.0, 1.0, 0.0, // near top left
        0.5, 0.5, 0.5, 0.0, 1.0, 0.0, // near top right
        0.5, 0.5, -0.5, 0.0, 1.0, 0.0, // far top right
    };

    const indices = [_]u32{
        0,  1,  2,  2,  0,  3,
        4,  5,  6,  6,  4,  7,
        8,  9,  10, 10, 8,  11,
        12, 13, 14, 14, 12, 15,
        16, 17, 18, 18, 16, 19,
        20, 21, 22, 22, 20, 23,
    };
    const vertex_count = 6 * indices.len;
    const cube_pos = math.Vec3{ .vals = .{ 0, 0, 0 } };

    // Init buffers
    var VAO: c_uint = undefined;
    var VBO: c_uint = undefined;
    var EBO: c_uint = undefined;

    C.glGenVertexArrays(1, &VAO);
    defer C.glDeleteVertexArrays(1, &VAO);
    C.glGenBuffers(1, &VBO);
    defer C.glDeleteBuffers(1, &VBO);
    C.glGenBuffers(1, &EBO);
    defer C.glDeleteBuffers(1, &EBO);

    // Upload vertex data
    C.glBindBuffer(C.GL_ARRAY_BUFFER, VBO);
    C.glBufferData(C.GL_ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, C.GL_STATIC_DRAW);

    // Configure VAO
    C.glBindVertexArray(VAO);
    // Upload index data
    C.glBindBuffer(C.GL_ELEMENT_ARRAY_BUFFER, EBO);
    C.glBufferData(C.GL_ELEMENT_ARRAY_BUFFER, indices.len * @sizeOf(u32), &indices, C.GL_STATIC_DRAW);

    C.glVertexAttribPointer(0, 3, C.GL_FLOAT, C.GL_FALSE, 6 * @sizeOf(f32), null);
    C.glEnableVertexAttribArray(0);

    C.glVertexAttribPointer(1, 3, C.GL_FLOAT, C.GL_FALSE, 6 * @sizeOf(f32), @as(*anyopaque, @ptrFromInt(3 * @sizeOf(f32))));
    C.glEnableVertexAttribArray(1);

    // main loop
    while (C.glfwWindowShouldClose(window) == 0) {
        const frame_time: f32 = @floatCast(C.glfwGetTime());
        delta_time = frame_time - last_frame_time;
        last_frame_time = frame_time;

        handleInput(window);

        //// Render
        C.glClearColor(0.1, 0.1, 0.1, 1.0);
        C.glClear(C.GL_COLOR_BUFFER_BIT | C.GL_DEPTH_BUFFER_BIT);

        // Activate shader
        program.use();
        program.setVec3("objectColor", 1.0, 0.5, 0.3);
        program.setVec3("lightColor", 1.0, 1.0, 1.0);
        program.setVec3("lightPos", 1.2, 1.0, 2.0);

        // Camera
        program.setMat4("view", camera.getViewMatrix());
        program.setMat4("proj", camera.getProjMatrix(@as(f32, WIN_W) / @as(f32, WIN_H)));

        // Render cube
        C.glBindVertexArray(VAO);
        program.setMat4("model", math.translation(cube_pos));
        C.glDrawElements(C.GL_TRIANGLES, vertex_count, C.GL_UNSIGNED_INT, null);

        C.glfwSwapBuffers(window);
        C.glfwPollEvents();
    }
}

fn handleInput(window: ?*C.GLFWwindow) void {
    if (C.glfwGetKey(window, C.GLFW_KEY_ESCAPE) == C.GLFW_PRESS)
        C.glfwSetWindowShouldClose(window, 1);

    if (C.glfwGetKey(window, C.GLFW_KEY_W) == C.GLFW_PRESS)
        camera.processKeyboard(.Forward, delta_time);
    if (C.glfwGetKey(window, C.GLFW_KEY_S) == C.GLFW_PRESS)
        camera.processKeyboard(.Backward, delta_time);
    if (C.glfwGetKey(window, C.GLFW_KEY_A) == C.GLFW_PRESS)
        camera.processKeyboard(.Left, delta_time);
    if (C.glfwGetKey(window, C.GLFW_KEY_D) == C.GLFW_PRESS)
        camera.processKeyboard(.Right, delta_time);
    if (C.glfwGetKey(window, C.GLFW_KEY_Q) == C.GLFW_PRESS)
        camera.processKeyboard(.Down, delta_time);
    if (C.glfwGetKey(window, C.GLFW_KEY_E) == C.GLFW_PRESS)
        camera.processKeyboard(.Up, delta_time);
}

fn sizeCallback(_: ?*C.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    C.glViewport(0, 0, width, height);
}

fn mouseCallback(window: ?*C.GLFWwindow, x: f64, y: f64) callconv(.C) void {
    if (first_mouse) {
        last_x = x;
        last_y = y;
        first_mouse = false;
    }
    const xoffset: f64 = x - last_x;
    const yoffset: f64 = last_y - y;

    if (C.glfwGetMouseButton(window, C.GLFW_MOUSE_BUTTON_LEFT) == C.GLFW_PRESS) {
        camera.processMouse(xoffset, yoffset);
    }
    last_x = x;
    last_y = y;
}

fn initGL() void {
    if (C.gladLoadGLLoader(@ptrCast(&C.glfwGetProcAddress)) == 0) {
        panic("Failed to init GLAD\n", .{});
    }
    C.glfwSwapInterval(1);

    C.glClearColor(0, 0, 0, 0);
    C.glClearDepth(1.0);
    C.glDepthMask(C.GL_TRUE);
    C.glDepthFunc(C.GL_LEQUAL);
    C.glBlendFunc(C.GL_SRC_ALPHA, C.GL_ONE_MINUS_SRC_ALPHA);
    C.glEnable(C.GL_DEPTH_TEST);
    C.glEnable(C.GL_MULTISAMPLE);
    C.glEnable(C.GL_BLEND);
}
