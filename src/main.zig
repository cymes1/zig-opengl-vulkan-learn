const std = @import("std");

const zgui = @import("zgui");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");

const gl = zopengl.bindings;
const content_dir = @import("build_options").content_dir;
const window_title = "zig-gamedev: minimal zgpu glfw opengl3";

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    // Change current working directory to where the executable is located.
    {
        var buffer: [1024]u8 = undefined;
        const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
        std.posix.chdir(path) catch {};
    }

    const gl_major = 4;
    const gl_minor = 0;
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_compat_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);

    const window = try glfw.Window.create(800, 500, window_title, null);
    defer window.destroy();
    window.setSizeLimits(400, 400, -1, -1);

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    zgui.init(gpa);
    defer zgui.deinit();

    const scale_factor = scale_factor: {
        const scale = window.getContentScale();
        break :scale_factor @max(scale[0], scale[1]);
    };
    const dir = content_dir ++ "Roboto-Medium.ttf";
    _ = zgui.io.addFontFromFile(
        dir,
        std.math.floor(16.0 * scale_factor),
    );

    zgui.getStyle().scaleAllSizes(scale_factor);

    zgui.backend.init(window);
    defer zgui.backend.deinit();

    // ===================================
    const positions = [_]f32{
        -0.5, -0.5,
        0.0,  0.5,
        0.5,  -0.5,
    };
    var vao: u32 = 0;
    gl.genBuffers(1, &vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, vao);
    gl.bufferData(gl.ARRAY_BUFFER, positions.len * @sizeOf(f32), &positions, gl.STATIC_DRAW);

    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * @sizeOf(f32), null);

    const vertexShader = "#version 330 core\n" ++
        "\n" ++
        "layout(location = 0) in vec4 position;\n" ++
        "\n" ++
        "void main()\n" ++
        "{\n" ++
        "   gl_Position = position;\n" ++
        "}\n";
    const fragmentShader = "#version 330 core\n" ++
        "\n" ++
        "layout(location = 0) out vec4 color;\n" ++
        "\n" ++
        "void main()\n" ++
        "{\n" ++
        "   color = vec4(1.0, 0.0, 0.0, 1.0);\n" ++
        "}\n";
    const shader = createShader(vertexShader, fragmentShader);
    gl.useProgram(shader);
    // ===================================

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        glfw.pollEvents();

        gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0, 0, 0, 1.0 });

        // ===================================
        gl.useProgram(shader);
        gl.bindBuffer(gl.ARRAY_BUFFER, vao);
        gl.drawArrays(gl.TRIANGLES, 0, 3);
        // ===================================

        const fb_size = window.getFramebufferSize();

        zgui.backend.newFrame(@intCast(fb_size[0]), @intCast(fb_size[1]));

        // Set the starting window position and size to custom values
        zgui.setNextWindowPos(.{ .x = 20.0, .y = 20.0, .cond = .first_use_ever });
        zgui.setNextWindowSize(.{ .w = -1.0, .h = -1.0, .cond = .first_use_ever });

        if (zgui.begin("My window", .{})) {
            if (zgui.button("Press me!", .{ .w = 200.0 })) {
                std.debug.print("Button pressed\n", .{});
            }
        }
        zgui.end();

        zgui.backend.draw();

        window.swapBuffers();
    }
}

fn compileShader(shaderType: u32, source: [*:0]const u8) u32 {
    const id = gl.createShader(shaderType);
    gl.shaderSource(id, 1, &source, null);
    gl.compileShader(id);

    var result: i32 = undefined;
    gl.getShaderiv(id, gl.COMPILE_STATUS, &result);
    if (result == gl.FALSE) {
        var length: i32 = undefined;
        gl.getShaderiv(id, gl.INFO_LOG_LENGTH, &length);

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();
        const message = allocator.alloc(u8, @intCast(length)) catch return 0;
        defer allocator.free(message);

        const typeName = if (shaderType == gl.VERTEX_SHADER) "vertex" else "fragment";
        gl.getShaderInfoLog(id, length, &length, message.ptr);
        std.debug.print("\nFailed to compile {s} shader", .{typeName});
        std.debug.print("\n{s}\n", .{message});
        gl.deleteShader(id);
        return 0;
    }

    return id;
}

fn createShader(vertexShader: [*:0]const u8, fragmentShader: [*:0]const u8) u32 {
    const program = gl.createProgram();
    const vs = compileShader(gl.VERTEX_SHADER, vertexShader);
    const fs = compileShader(gl.FRAGMENT_SHADER, fragmentShader);

    gl.attachShader(program, vs);
    gl.attachShader(program, fs);
    gl.linkProgram(program);
    gl.validateProgram(program);
    gl.deleteShader(vs);
    gl.deleteShader(fs);
    return program;
}

const Vertex = struct {
    position: Position,
    color: Color,

    const Position = [2]f32;
    const Color = [3]f32;
};
