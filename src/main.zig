const C = @import("c.zig");
const std = @import("std");
const Shader = @import("shader.zig").Shader;
const Camera = @import("camera.zig").Camera;
const CameraMovement = @import("camera.zig").CameraMovement;
const math = @import("math.zig");
const panic = std.debug.panic;

var camera = Camera.default();

const winWidth: u32 = 800;
const winHeight: u32 = 600;

var deltaTime: f32 = 0.0;
var lastFrame: f32 = 0.0;

var firstMouse = false;
var lastX: f64 = 0.0;
var lastY: f64 = 0.0;

pub fn main() !void {
    if (C.glfwInit() == 0) {
        panic("Failed to init glfw\n", .{});
    }
    const window = C.glfwCreateWindow(winWidth, winHeight, "Zig OpenGL Example", null, null);
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
        // Front
        -0.5, -0.5, 0.0, 0.0, 0.5, 0.0, // near bot left
        0.5, -0.5, 0.0, 0.0, 0.5, 0.0, // near bot right
        0.5, 0.5, 0.0, 0.0, 0.5, 0.0, // near top right
        -0.5, 0.5, 0.0, 0.0, 0.5, 0.0, // near top left
    };

    const indices = [_]u32{
        0, 1, 2, 2, 0, 3,
    };
    const vertCount = 6 * indices.len;
    const pos = math.Vec3{ .vals = .{ 0, 0, 0 } };

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

    // Bind buffers
    C.glBindVertexArray(VAO);

    C.glBindBuffer(C.GL_ARRAY_BUFFER, VBO);
    C.glBufferData(C.GL_ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, C.GL_STATIC_DRAW);

    C.glBindBuffer(C.GL_ELEMENT_ARRAY_BUFFER, EBO);
    C.glBufferData(C.GL_ELEMENT_ARRAY_BUFFER, indices.len * @sizeOf(u32), &indices, C.GL_STATIC_DRAW);

    C.glVertexAttribPointer(0, 3, C.GL_FLOAT, C.GL_FALSE, 6 * @sizeOf(f32), null);
    C.glEnableVertexAttribArray(0);

    C.glVertexAttribPointer(1, 3, C.GL_FLOAT, C.GL_FALSE, 6 * @sizeOf(f32), @as(*anyopaque, @ptrFromInt(3 * @sizeOf(f32))));
    C.glEnableVertexAttribArray(1);

    C.glBindBuffer(C.GL_ARRAY_BUFFER, 0);

    C.glBindVertexArray(0);

    // main loop
    while (C.glfwWindowShouldClose(window) == 0) {
        const frameTime = @as(f32, @floatCast(C.glfwGetTime()));
        deltaTime = frameTime - lastFrame;
        lastFrame = frameTime;

        // input
        handleInput(window);

        // render
        C.glClearColor(0.1, 0.1, 0.1, 1.0);
        C.glClear(C.GL_COLOR_BUFFER_BIT | C.GL_DEPTH_BUFFER_BIT);

        // activate shader
        program.use();

        // camera
        program.setMat4("view", camera.getViewMatrix());
        program.setMat4("proj", camera.getProjMatrix(@as(f32, winWidth) / @as(f32, winHeight)));

        // render quads
        C.glBindVertexArray(VAO);
        program.setMat4("model", math.translation(pos));
        C.glDrawElements(C.GL_TRIANGLES, vertCount, C.GL_UNSIGNED_INT, null);

        // glfw
        C.glfwSwapBuffers(window);
        C.glfwPollEvents();
    }
}

pub fn handleInput(window: ?*C.GLFWwindow) void {
    if (C.glfwGetKey(window, C.GLFW_KEY_ESCAPE) == C.GLFW_PRESS)
        C.glfwSetWindowShouldClose(window, 1);

    if (C.glfwGetKey(window, C.GLFW_KEY_W) == C.GLFW_PRESS)
        camera.processKeyboard(.Forward, deltaTime);
    if (C.glfwGetKey(window, C.GLFW_KEY_S) == C.GLFW_PRESS)
        camera.processKeyboard(.Backward, deltaTime);
    if (C.glfwGetKey(window, C.GLFW_KEY_A) == C.GLFW_PRESS)
        camera.processKeyboard(.Left, deltaTime);
    if (C.glfwGetKey(window, C.GLFW_KEY_D) == C.GLFW_PRESS)
        camera.processKeyboard(.Right, deltaTime);
    if (C.glfwGetKey(window, C.GLFW_KEY_Q) == C.GLFW_PRESS)
        camera.processKeyboard(.Down, deltaTime);
    if (C.glfwGetKey(window, C.GLFW_KEY_E) == C.GLFW_PRESS)
        camera.processKeyboard(.Up, deltaTime);
}

pub fn sizeCallback(_: ?*C.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    C.glViewport(0, 0, width, height);
}

pub fn mouseCallback(window: ?*C.GLFWwindow, x: f64, y: f64) callconv(.C) void {
    if (firstMouse) {
        lastX = x;
        lastY = y;
        firstMouse = false;
    }
    const xoffset: f64 = x - lastX;
    const yoffset: f64 = lastY - y;

    if (C.glfwGetMouseButton(window, C.GLFW_MOUSE_BUTTON_LEFT) == C.GLFW_PRESS) {
        camera.processMouse(xoffset, yoffset);
    }
    lastX = x;
    lastY = y;
}

pub fn initGL() void {
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
    C.glPointSize(10.0);
}
