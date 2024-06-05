const std = @import("std");
const C = @import("c.zig");
const cwd = std.fs.cwd;
const panic = std.debug.panic;
const Allocator = std.mem.Allocator;

const Mat4 = @import("math.zig").Mat4;

pub const Shader = struct {
    id: c_uint,

    pub fn init(allocator: Allocator, vertPath: []const u8, fragPath: []const u8) !Shader {
        // vertex
        const vsFile = try cwd().openFile(vertPath, .{});
        defer vsFile.close();

        const vsSrc = try allocator.alloc(u8, try vsFile.getEndPos());
        defer allocator.free(vsSrc);

        _ = try vsFile.read(vsSrc);

        // fragment
        const fsFile = try cwd().openFile(fragPath, .{});
        defer fsFile.close();

        const fsSrc = try allocator.alloc(u8, try fsFile.getEndPos());
        defer allocator.free(fsSrc);

        _ = try fsFile.read(fsSrc);

        // compile
        const vertex = C.glCreateShader(C.GL_VERTEX_SHADER);
        const vertexSrcPtr: ?[*]const u8 = vsSrc.ptr;
        C.glShaderSource(vertex, 1, &vertexSrcPtr, null);
        C.glCompileShader(vertex);
        checkCompileErrors(vertex, "VERTEX");

        const fragment = C.glCreateShader(C.GL_FRAGMENT_SHADER);
        const fragmentSrcPtr: ?[*]const u8 = fsSrc.ptr;
        C.glShaderSource(fragment, 1, &fragmentSrcPtr, null);
        C.glCompileShader(fragment);
        checkCompileErrors(vertex, "FRAGMENT");

        const id = C.glCreateProgram();
        C.glAttachShader(id, vertex);
        C.glAttachShader(id, fragment);
        C.glLinkProgram(id);

        checkCompileErrors(id, "PROGRAM");

        C.glDeleteShader(vertex);
        C.glDeleteShader(fragment);

        return Shader{ .id = id };
    }

    pub fn deinit(self: Shader) void {
        C.glDeleteProgram(self.id);
    }

    pub fn use(self: Shader) void {
        C.glUseProgram(self.id);
    }

    pub fn setVec3(self: Shader, name: [:0]const u8, x: f32, y: f32, z: f32) void {
        C.glUniform3f(C.glGetUniformLocation(self.id, name), x, y, z);
    }

    pub fn setMat4(self: Shader, name: [:0]const u8, matrix: Mat4) void {
        C.glUniformMatrix4fv(C.glGetUniformLocation(self.id, name), 1, C.GL_FALSE, &matrix.vals[0][0]);
    }

    fn checkCompileErrors(shader: c_uint, errType: []const u8) void {
        var success: c_int = undefined;
        var infoLog: [1024]u8 = undefined;
        if (!std.mem.eql(u8, errType, "PROGRAM")) {
            C.glGetShaderiv(shader, C.GL_COMPILE_STATUS, &success);
            if (success == 0) {
                C.glGetShaderInfoLog(shader, 1024, null, &infoLog);
                panic("ERROR::SHADER::{s}::COMPILATION_FAILED\n{s}\n", .{ errType, infoLog });
            }
        } else {
            C.glGetShaderiv(shader, C.GL_LINK_STATUS, &success);
            if (success == 0) {
                C.glGetShaderInfoLog(shader, 1024, null, &infoLog);
                panic("ERROR::SHADER::LINKING_FAILED\n{s}\n", .{infoLog});
            }
        }
    }
};
