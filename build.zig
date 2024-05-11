const std = @import("std");
const builtin = @import("builtin");

const Build = std.Build;

const content_dir = "res/";

pub fn build(b: *Build) void {
    const options = Options{
        .optimize = b.standardOptimizeOption(.{}),
        .target = b.standardTargetOptions(.{}),
    };

    const exe = b.addExecutable(.{
        .name = "Lava",
        .root_source_file = .{ .path = thisDir() ++ "/src/main.zig" },
        .target = options.target,
        .optimize = options.optimize,
    });

    linkGLFW(b, exe, &options);
    linkOpenGL(b, exe, &options);
    linkZGUI(b, exe, &options);

    const exe_options = b.addOptions();
    exe.root_module.addOptions("build_options", exe_options);
    exe_options.addOption([]const u8, "content_dir", content_dir);

    const install_content_step = b.addInstallDirectory(.{
        .source_dir = .{ .path = thisDir() ++ "/" ++ content_dir },
        .install_dir = .{ .custom = "" },
        .install_subdir = "bin/" ++ content_dir,
    });
    b.getInstallStep().dependOn(&install_content_step.step);
    b.step("content", "Install content").dependOn(&install_content_step.step);

    const install_exe = b.addInstallArtifact(exe, .{});
    install_exe.step.dependOn(&install_content_step.step);
    b.step("build", "Build demo").dependOn(&install_exe.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(&install_exe.step);
    b.step("run", "Run demo").dependOn(&run_cmd.step);
}

fn linkGLFW(b: *Build, exe: *Build.Step.Compile, options: *const Options) void {
    const name = "zglfw";
    const zglfw = b.dependency(name, .{
        .target = options.target,
    });
    exe.root_module.addImport(name, zglfw.module("root"));
    exe.linkLibrary(zglfw.artifact("glfw"));
}

fn linkOpenGL(b: *Build, exe: *Build.Step.Compile, options: *const Options) void {
    const name = "zopengl";
    const zopengl = b.dependency(name, .{
        .target = options.target,
    });
    exe.root_module.addImport(name, zopengl.module("root"));
}

fn linkZGUI(b: *Build, exe: *Build.Step.Compile, options: *const Options) void {
    const name = "zgui";
    const zgui = b.dependency(name, .{
        .target = options.target,
        .backend = .glfw_opengl3,
    });
    exe.root_module.addImport(name, zgui.module("root"));
    exe.linkLibrary(zgui.artifact("imgui"));
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}

pub const Options = struct {
    optimize: std.builtin.Mode,
    target: std.Build.ResolvedTarget,
};
