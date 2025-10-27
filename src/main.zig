const std = @import("std");
const rl = @import("raylib");
const ui = @import("ui.zig");

var graphWidth: f32 = 0;
var graphHeight: f32 = 0;
var centerY: f32 = 0;

const wave_colors = [_]rl.Color{
    rl.Color.init(255, 0, 0, 255), // Red
    rl.Color.init(0, 255, 0, 255), // Green
    rl.Color.init(0, 0, 255, 255), // Blue
    rl.Color.init(255, 165, 0, 255), // Orange
    rl.Color.init(128, 0, 128, 255), // Purple
    rl.Color.init(0, 255, 255, 255), // Cyan
    rl.Color.init(255, 192, 203, 255), // Pink
    rl.Color.init(255, 255, 0, 255), // Yellow
};

const Margin = struct {
    left: f32,
    right: f32,
    top: f32,
    bottom: f32,
};

const Wave = struct {
    amplitude: f64,
    wavenumber: f64,
    frequency: f64,
    phase: f64,

    /// Evalute a given wave to find how high or low the
    /// wave is at a given position (x) and time (t).
    pub fn evaluate(self: *const Wave, x: f64, t: f64) f64 {
        return self.amplitude *
            std.math.sin(self.wavenumber * x - self.frequency * t + self.phase);
    }

    /// Superpose given waves to find the resultant ampltiude.
    ///
    /// x: Distance along the direction of propogation (m)
    /// t: Time (s)
    pub fn superpose(self: *const Wave, x: f64, t: f64, waves: []const Wave) f64 {
        var y: f64 = 0.0;
        y += self.evaluate(x, t);
        for (0..waves.len) |i| {
            const amplitude = evaluate(&waves[i], x, t);
            y += amplitude;
        }
        return y;
    }
};

fn drawGrid(margin: Margin, screenWidth: i32, screenHeight: i32, line_thickness: f32) anyerror!void {
    graphWidth = @as(f32, @floatFromInt(screenWidth)) - margin.left - margin.right;
    graphHeight = @as(f32, @floatFromInt(screenHeight)) - margin.top - margin.bottom;
    centerY = margin.top + graphHeight / 2.0;

    // Draw grid
    var grid_y: f32 = margin.top;
    while (grid_y <= margin.top + graphHeight) : (grid_y += graphHeight / 8.0) {
        rl.drawLineEx(
            rl.Vector2{ .x = margin.left, .y = grid_y },
            rl.Vector2{ .x = margin.left + graphWidth, .y = grid_y },
            line_thickness,
            rl.Color.init(220, 220, 220, 255),
        );
    }

    var grid_x: f32 = margin.left;
    while (grid_x <= margin.left + graphWidth) : (grid_x += graphWidth / 10.0) {
        rl.drawLineEx(
            rl.Vector2{ .x = grid_x, .y = margin.top },
            rl.Vector2{ .x = grid_x, .y = margin.top + graphHeight },
            line_thickness,
            rl.Color.init(220, 220, 220, 255),
        );
    }

    // Draw axes

    // X-axis
    rl.drawLineEx(
        rl.Vector2{ .x = margin.left, .y = centerY },
        rl.Vector2{ .x = margin.left + graphWidth, .y = centerY },
        line_thickness + 1,
        rl.Color.gray,
    );

    // Y-axis
    rl.drawLineEx(
        rl.Vector2{ .x = margin.left, .y = margin.top },
        rl.Vector2{ .x = margin.left, .y = margin.top + graphHeight },
        line_thickness + 1,
        rl.Color.gray,
    );
}

fn drawWaves(margin: Margin, screenWidth: i32, screenHeight: i32, line_thickness: f32, x_min: f64, x_max: f64, dpi_scale: rl.Vector2) anyerror!void {
    _ = screenWidth;
    _ = screenHeight;

    const time = rl.getTime();
    const scale = 60.0 * dpi_scale.y; // Scale factor for wave amplitude
    const step = 0.02;

    for (0..current_waves.len) |i| {
        const color = wave_colors[i];

        var x: f64 = x_min;
        while (x <= x_max) : (x += step) {
            const z = current_waves[i].evaluate(x, time);
            const screenX: f32 = margin.left + @as(f32, @floatCast((x - x_min) / (x_max - x_min) * graphWidth));
            const screenY: f32 = centerY - @as(f32, @floatCast(z * scale));

            if (x + step <= x_max) {
                const next_z = current_waves[i].evaluate(x + step, time);
                const nextScreenX = margin.left + @as(f32, @floatCast((x + step - x_min) / (x_max - x_min) * graphWidth));
                const nextScreenY = centerY - @as(f32, @floatCast(next_z * scale));
                rl.drawLineEx(
                    rl.Vector2.init(screenX, screenY),
                    rl.Vector2.init(nextScreenX, nextScreenY),
                    line_thickness,
                    color,
                );
            }
        }
    }

    var x: f64 = x_min;
    while (x <= x_max) : (x += step) {
        const z = current_waves[0].superpose(x, time, current_waves[1..]);
        const screenX: f32 = margin.left + @as(f32, @floatCast((x - x_min) / (x_max - x_min) * graphWidth));
        const screenY: f32 = centerY - @as(f32, @floatCast(z * scale));

        if (x + step <= x_max) {
            const next_z = current_waves[0].superpose(x + step, time, current_waves[1..]);
            const nextScreenX = margin.left + @as(f32, @floatCast((x + step - x_min) / (x_max - x_min) * graphWidth));
            const nextScreenY = centerY - @as(f32, @floatCast(next_z * scale));
            rl.drawLineEx(
                rl.Vector2.init(screenX, screenY),
                rl.Vector2.init(nextScreenX, nextScreenY),
                line_thickness * 3,
                rl.Color.dark_green,
            );
        }
    }
}

const current_waves = [_]Wave{
    Wave{
        .amplitude = 0.8,
        .wavenumber = 2 * std.math.pi / 6.0, // wavelength = 6m
        .frequency = 2 * std.math.pi * 0.3, // 0.3 Hz
        .phase = 0.0,
    },
    Wave{
        .amplitude = 0.6,
        .wavenumber = 2 * std.math.pi / 3.0, // wavelength = 3m
        .frequency = 2 * std.math.pi * 0.5, // 0.5 Hz
        .phase = std.math.pi / 4.0,
    },
    Wave{
        .amplitude = 0.4,
        .wavenumber = 2 * std.math.pi / 1.5, // wavelength = 1.5m
        .frequency = 2 * std.math.pi * 0.8, // 0.8 Hz
        .phase = std.math.pi / 2.0,
    },
    Wave{
        .amplitude = 0.5,
        .wavenumber = -2 * std.math.pi / 4.0, // wavelength = 4m, opposite direction
        .frequency = 2 * std.math.pi * 0.4, // 0.4 Hz
        .phase = 0.0,
    },
};

pub fn main() anyerror!void {
    const logicalWidth: i32 = 1200;
    const logicalHeight: i32 = 600;
    var screenWidth: i32 = logicalWidth;
    var screenHeight: i32 = logicalHeight;

    var dpi_scale: rl.Vector2 = .{ .x = 1.0, .y = 1.0 };

    // Enable MSAA 4x
    rl.setConfigFlags(rl.ConfigFlags{ .msaa_4x_hint = true });

    rl.initWindow(screenWidth, screenHeight, "Wave Visualization");
    defer rl.closeWindow();

    // Get initial DPI scaling factor and adjust window size if needed
    dpi_scale = rl.getWindowScaleDPI();
    std.debug.print("DPI Scale: {}\n", .{dpi_scale});

    if (dpi_scale.x != 1.0 or dpi_scale.y != 1.0) {
        rl.setWindowSize(
            @intFromFloat(@as(f32, @floatFromInt(logicalWidth)) * dpi_scale.x),
            @intFromFloat(@as(f32, @floatFromInt(logicalHeight)) * dpi_scale.y),
        );
        screenWidth = rl.getScreenWidth();
        screenHeight = rl.getScreenHeight();
    }

    rl.setTargetFPS(60);

    // Load font
    const font = try rl.loadFontEx("src/fonts/Ubuntu-Light.ttf", 64, null);
    defer rl.unloadFont(font);
    rl.setTextureFilter(font.texture, .trilinear);

    const x_min = -10;
    const x_max = 10;

    var current_fps: f64 = 60.0;
    var target_fps: f64 = 60.0;

    // Callback functions for FPS field
    const getFps = struct {
        fn call(ctx: *anyopaque) f64 {
            const fps_ptr: *f64 = @ptrCast(@alignCast(ctx));
            return fps_ptr.*;
        }
    }.call;

    const setFps = struct {
        fn call(ctx: *anyopaque, value: f64) void {
            const fps_ptr: *f64 = @ptrCast(@alignCast(ctx));
            fps_ptr.* = value;
        }
    }.call;

    var fps_field = ui.TextField.init("FPS:", 24.0, 240.0, @ptrCast(&target_fps), getFps, setFps);

    while (!rl.windowShouldClose()) {
        // Check for DPI scaling changes at the start of each frame
        const current_dpi_scale = rl.getWindowScaleDPI();
        if (current_dpi_scale.x != dpi_scale.x or current_dpi_scale.y != dpi_scale.y) {
            dpi_scale = current_dpi_scale;
            rl.setWindowSize(
                @intFromFloat(@as(f32, @floatFromInt(logicalWidth)) * dpi_scale.x),
                @intFromFloat(@as(f32, @floatFromInt(logicalHeight)) * dpi_scale.y),
            );

            // Re-center window after resizing
            const pos = rl.getWindowPosition();
            rl.setWindowPosition(
                @intFromFloat(pos.x),
                @intFromFloat(pos.y),
            );

            screenWidth = rl.getScreenWidth();
            screenHeight = rl.getScreenHeight();

            std.debug.print("DPI changed: {} | Window size: {}x{}\n", .{ dpi_scale, screenWidth, screenHeight });
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.init(245, 245, 245, 255));

        // Graph dimensions
        const margins = Margin{
            .left = 60.0,
            .right = 40.0,
            .top = 40.0,
            .bottom = 60.0,
        };

        // Calculate line thickness based on DPI scale (minimum 1)
        const line_thickness = @max(1.0, 1.5 * dpi_scale.x);

        try drawGrid(margins, screenWidth, screenHeight, line_thickness);
        try drawWaves(margins, screenWidth, screenHeight, line_thickness, x_min, x_max, dpi_scale);

        try fps_field.draw(rl.Vector2{ .x = margins.left + 10.0, .y = margins.top + 10.0 }, dpi_scale, font);

        // Update FPS based on target FPS
        if (current_fps != target_fps) {
            rl.setTargetFPS(@intFromFloat(target_fps));
            current_fps = target_fps;
        }
    }
}
