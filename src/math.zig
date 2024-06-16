const std = @import("std");
const sqrt = std.math.sqrt;
const tan = std.math.tan;
const max = std.math.max;
const min = std.math.min;

pub fn clamp(v: f32, lo: f32, hi: f32) f32 {
    return max(min(v, hi), lo);
}

pub fn swap(comptime T: type, a: *T, b: *T) void {
    const t = a.*;
    a.* = b.*;
    b.* = t;
}

fn Vector(comptime d: usize) type {
    return extern struct {
        vals: [d]f32,

        const Self = @This();

        // Constructors
        pub fn fill(v: f32) Self {
            var vals: [d]f32 = undefined;
            comptime var i = 0;
            inline while (i < d) : (i += 1) {
                vals[i] = v;
            }
            return Self{ .vals = vals };
        }

        pub fn zeros() Self {
            return Self.fill(0.0);
        }

        pub fn ones() Self {
            return Self.fill(1.0);
        }

        // Math Operations
        pub fn sum(self: Self) f32 {
            var total: f32 = 0.0;
            for (self.vals) |val| {
                total += val;
            }
            return total;
        }

        pub fn add(self: Self, other: Self) Self {
            const vs: @Vector(d, f32) = self.vals;
            const vo: @Vector(d, f32) = other.vals;

            return Self{ .vals = vs + vo };
        }

        pub fn sub(self: Self, other: Self) Self {
            const vs: @Vector(d, f32) = self.vals;
            const vo: @Vector(d, f32) = other.vals;

            return Self{ .vals = vs - vo };
        }

        pub fn mul(self: Self, other: Self) Self {
            const vs: @Vector(d, f32) = self.vals;
            const vo: @Vector(d, f32) = other.vals;

            return Self{ .vals = vs * vo };
        }

        pub fn mulScalar(self: Self, v: f32) Self {
            const vs: @Vector(d, f32) = self.vals;
            const vo: @Vector(d, f32) = Self.fill(v).vals;

            return Self{ .vals = vs * vo };
            //return self;
        }

        pub fn div(self: Self, other: Self) Self {
            const vs: @Vector(d, f32) = self.vals;
            const vo: @Vector(d, f32) = other.vals;

            return Self{ .vals = vs / vo };
        }

        pub fn dot(self: Self, other: Self) f32 {
            const product = self.mul(other);
            return product.sum();
        }

        pub fn normSq(self: Self) f32 {
            return self.dot(self);
        }

        pub fn norm(self: Self) f32 {
            return sqrt(self.normSq());
        }

        pub fn normalize(self: Self) Self {
            const n = self.norm();
            var vals = self.vals;
            for (vals, 0..) |_, i| {
                vals[i] /= n;
            }
            return Self{ .vals = vals };
        }

        pub fn cross(self: Self, other: Self) Self {
            if (d != 3) {
                @compileError("Cross product only defined for 3D vectors");
            }
            const vals = [3]f32{
                self.vals[1] * other.vals[2] - self.vals[2] * other.vals[1],
                self.vals[2] * other.vals[0] - self.vals[0] * other.vals[2],
                self.vals[0] * other.vals[1] - self.vals[1] * other.vals[0],
            };
            return Self{ .vals = vals };
        }
    };
}

pub const Vec2 = Vector(2);
pub const Vec3 = Vector(3);
pub const Vec4 = Vector(4);

pub fn vec3(x: f32, y: f32, z: f32) Vec3 {
    return Vec3{ .vals = [3]f32{ x, y, z } };
}

pub fn Matrix(comptime d: usize) type {
    return extern struct {
        vals: [d][d]f32,

        const Self = @This();

        pub fn zeros() Self {
            var vals: [d][d]f32 = undefined;
            comptime var i = 0;
            inline while (i < d) : (i += 1) {
                comptime var j = 0;
                inline while (j < d) : (j += 1) {
                    vals[i][j] = 0.0;
                }
            }
            return Self{ .vals = vals };
        }

        pub fn identity() Self {
            var vals: [d][d]f32 = undefined;
            comptime var i = 0;
            inline while (i < d) : (i += 1) {
                comptime var j = 0;
                inline while (j < d) : (j += 1) {
                    vals[i][j] = if (i == j) 1.0 else 0.0;
                }
            }
            return Self{ .vals = vals };
        }

        pub fn transpose(self: Self) Self {
            var vals: [d][d]f32 = undefined;
            comptime var i = 0;
            inline while (i < d) : (i += 1) {
                comptime var j = 0;
                inline while (j < d) : (j += 1) {
                    vals[i][j] = self.vals[j][i];
                }
            }
            return Self{ .vals = vals };
        }

        pub fn mul(self: Self, other: Self) Self {
            var vals: [d][d]f32 = undefined;
            const a = self.transpose();
            const b = other;

            comptime var i = 0;
            inline while (i < d) : (i += 1) {
                comptime var j = 0;
                inline while (j < d) : (j += 1) {
                    const row: @Vector(d, f32) = a.vals[j];
                    const col: @Vector(d, f32) = b.vals[i];
                    const prod: [d]f32 = row * col;

                    var sum: f32 = 0;
                    for (prod) |p| {
                        sum += p;
                    }
                    vals[i][j] = sum;
                }
            }

            return Self{ .vals = vals };
        }

        fn apply(self: Self, x: [d]f32) [d]f32 {
            var b: [d]f32 = undefined;

            for (0..d) |i| {
                const row: @Vector(d, f32) = self.vals[i];
                const vec: @Vector(d, f32) = x;
                b[i] = @reduce(.Add, row * vec);
            }
            return b;
        }

        pub fn print(self: Self) void {
            for (0..d) |i| {
                for (0..d) |j| {
                    std.debug.print("{d} ", .{self.vals[i][j]});
                }
                std.debug.print("\n", .{});
            }
            std.debug.print("\n", .{});
        }

        pub fn luDecompose(self: Self) ![3]Self {
            var perm: [d]usize = undefined;
            for (0..d) |i| perm[i] = i;
            var lower: Matrix(d) = Matrix(d).zeros();
            var upper: Matrix(d) = Matrix(d).zeros();
            var mat = self;

            for (0..d) |j| {
                var max_index = j;
                var max_value: f32 = 0;
                for (j..d) |i| {
                    const value = @abs(mat.vals[perm[i]][j]);
                    if (value > max_value) {
                        max_index = i;
                        max_value = value;
                    }
                }
                if (max_value <= std.math.floatEps(f32)) {
                    return error.SingularMatrix;
                }
                if (j != max_index)
                    swap(usize, &perm[j], &perm[max_index]);

                const jj = perm[j];
                for (j + 1..d) |i| {
                    const ii = perm[i];
                    mat.vals[ii][j] /= mat.vals[jj][j];
                    for (j + 1..d) |k| {
                        mat.vals[ii][k] -= mat.vals[ii][j] * mat.vals[jj][k];
                    }
                }
            }

            for (0..d) |j| {
                lower.vals[j][j] = 1;
                for (j + 1..d) |i|
                    lower.vals[i][j] = mat.vals[perm[i]][j];
                for (0..j + 1) |i|
                    upper.vals[i][j] = mat.vals[perm[i]][j];
            }

            var pivot: Self = Self.zeros();
            for (0..d) |i| pivot.vals[i][perm[i]] = 1;

            return .{ lower, upper, pivot };
        }

        pub fn luSolve(self: Self, b: [d]f32) ![d]f32 {
            const L, const U, const P = try self.luDecompose();

            // solve Ly = Pb using forward subst
            var y: [d]f32 = undefined;
            const Pb = P.apply(b);

            y[0] = Pb[0];
            for (1..d) |i| {
                var sum: f32 = 0;
                for (0..i) |k| sum += L.vals[i][k] * y[k];
                y[i] = Pb[i] - sum;
            }

            // solve Ux = y using backward subst
            var x = std.mem.zeroes([d]f32);
            x[d - 1] = y[d - 1] / U.vals[d - 1][d - 1];
            for (1..d) |n| {
                const row: usize = d - 1 - n;
                var sum: f32 = 0;
                for (1..d - row) |k| {
                    const col = d - k;
                    sum += U.vals[row][col] * x[col];
                }
                x[row] = (y[row] - sum) / U.vals[row][row];
            }

            return x;
        }
    };
}

pub const Mat2 = Matrix(2);
pub const Mat3 = Matrix(3);
pub const Mat4 = Matrix(4);

/// Transformation matrix for translation by v
pub fn translation(v: Vec3) Mat4 {
    return Mat4{
        .vals = [4][4]f32{
            .{ 1.0, 0.0, 0.0, 0.0 },
            .{ 0.0, 1.0, 0.0, 0.0 },
            .{ 0.0, 0.0, 1.0, 0.0 },
            .{ v.vals[0], v.vals[1], v.vals[2], 1.0 },
        },
    };
}

/// Transformation matrix for rotation around the z axis by a radians
pub fn rotation(angle: f32, axis: Vec3) Mat4 {
    const unit = axis.normalize();
    const x = unit.vals[0];
    const y = unit.vals[1];
    const z = unit.vals[2];

    const a = @cos(angle) + x * x * (1 - @cos(angle));
    const b = y * x * (1 - @cos(angle)) + z * @sin(angle);
    const c = z * x * (1 - @cos(angle)) - y * @sin(angle);

    const d = x * y * (1 - @cos(angle)) - z * @sin(angle);
    const e = @cos(angle) + y * y * (1 - @cos(angle));
    const f = z * y * (1 - @cos(angle)) + x * @sin(angle);

    const h = x * z * (1 - @cos(angle)) + y * @sin(angle);
    const i = y * z * (1 - @cos(angle)) - x * @sin(angle);
    const j = @cos(angle) + z * z * (1 - @cos(angle));

    return Mat4{
        .vals = [4][4]f32{
            .{ a, b, c, 0.0 },
            .{ d, e, f, 0.0 },
            .{ h, i, j, 0.0 },
            .{ 0.0, 0.0, 0.0, 1.0 },
        },
    };
}

pub fn scale(magnitude: Vec3) Mat4 {
    return Mat4{
        .vals = [4][4]f32{
            .{ magnitude.vals[0], 0.0, 0.0, 0.0 },
            .{ 0.0, magnitude.vals[1], 0.0, 0.0 },
            .{ 0.0, 0.0, magnitude.vals[2], 0.0 },
            .{ 0.0, 0.0, 0.0, 1.0 },
        },
    };
}

/// View matrix for camera at eye, looking at center, oriented by up
pub fn lookAt(eye: Vec3, center: Vec3, up: Vec3) Mat4 {
    const f = center.sub(eye).normalize();
    const s = f.cross(up).normalize();
    const u = s.cross(f);

    return Mat4{
        .vals = [4][4]f32{
            .{ s.vals[0], u.vals[0], -f.vals[0], 0.0 },
            .{ s.vals[1], u.vals[1], -f.vals[1], 0.0 },
            .{ s.vals[2], u.vals[2], -f.vals[2], 0.0 },
            .{ -s.dot(eye), -u.dot(eye), f.dot(eye), 1.0 },
        },
    };
}

/// Perspective projection matrix
pub fn perspective(fovy: f32, aspect: f32, znear: f32, zfar: f32) Mat4 {
    const tanhalffovy = tan(fovy / 2.0);

    const a = 1.0 / (aspect * tanhalffovy);
    const b = 1.0 / tanhalffovy;
    const c = -(zfar + znear) / (zfar - znear);
    const d = -(2.0 * zfar * znear) / (zfar - znear);

    return Mat4{
        .vals = [4][4]f32{
            .{ a, 0.0, 0.0, 0.0 },
            .{ 0.0, b, 0.0, 0.0 },
            .{ 0.0, 0.0, c, -1.0 },
            .{ 0.0, 0.0, d, 0.0 },
        },
    };
}

/// Orthographic projection matrix
pub fn ortho(left: f32, right: f32, bottom: f32, top: f32, znear: f32, zfar: f32) Mat4 {
    const a = 2.0 / (right - left);
    const b = 2.0 / (top - bottom);
    const c = -2.0 / (zfar - znear);
    const d = -(right + left) / (right - left);
    const e = -(top + bottom) / (top - bottom);
    const f = -(zfar + znear) / (zfar - znear);

    return Mat4{
        .vals = [4][4]f32{
            .{ a, 0.0, 0.0, 0.0 },
            .{ 0.0, b, 0.0, 0.0 },
            .{ 0.0, 0.0, c, -1.0 },
            .{ d, e, f, 0.0 },
        },
    };
}
