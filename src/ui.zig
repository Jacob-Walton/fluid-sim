const std = @import("std");
const rl = @import("raylib");

pub const TextField = struct {
    label: []const u8,
    min: f64,
    max: f64,

    // Callbacks
    context: *anyopaque,
    getValue: *const fn (*anyopaque) f64,
    setValue: *const fn (*anyopaque, f64) void,

    // Internal state
    active: bool = false,
    text_buffer: [32:0]u8 = undefined,
    text_len: usize = 0,
    cursor_pos: usize = 0,

    pub fn init(
        label: []const u8,
        min: f64,
        max: f64,
        context: *anyopaque,
        getValue: *const fn (*anyopaque) f64,
        setValue: *const fn (*anyopaque, f64) void,
    ) TextField {
        var field = TextField{
            .label = label,
            .min = min,
            .max = max,
            .context = context,
            .getValue = getValue,
            .setValue = setValue,
        };
        field.syncBufferFromValue();
        return field;
    }

    fn syncBufferFromValue(self: *TextField) void {
        const value = self.getValue(self.context);
        const clamped = std.math.clamp(value, self.min, self.max);
        // Update the value if it was out of bounds
        if (value != clamped) {
            self.setValue(self.context, clamped);
        }
        const formatted = std.fmt.bufPrintZ(&self.text_buffer, "{d:.2}", .{clamped}) catch return;
        self.text_len = formatted.len;
        self.cursor_pos = self.text_len;
    }

    fn syncValueFromBuffer(self: *TextField) void {
        const text_slice = self.text_buffer[0..self.text_len];
        if (std.fmt.parseFloat(f64, text_slice)) |parsed| {
            const clamped = std.math.clamp(parsed, self.min, self.max);
            self.setValue(self.context, clamped);
            // Update the display to show the clamped value
            if (parsed != clamped) {
                self.syncBufferFromValue();
            }
        } else |_| {
            // If parsing fails, revert to current value
            self.syncBufferFromValue();
        }
    }

    pub fn draw(self: *TextField, pos: rl.Vector2, dpi_scale: rl.Vector2, font: rl.Font) anyerror!void {
        const label_width: f32 = 80.0 * dpi_scale.x;
        const field_width: f32 = 120.0 * dpi_scale.x;
        const field_height: f32 = 30.0 * dpi_scale.y;
        const padding: f32 = 5.0 * dpi_scale.x;

        // Draw label
        var label_buf: [128:0]u8 = undefined;
        const len = @min(self.label.len, label_buf.len - 1);
        @memcpy(label_buf[0..len], self.label[0..len]);
        label_buf[len] = 0;

        const label_font_size = 20.0 * dpi_scale.y;
        rl.drawTextEx(font, &label_buf, rl.Vector2{ .x = pos.x, .y = pos.y + 5 * dpi_scale.y }, label_font_size, 1.0, rl.Color.black);

        // Define field rectangle
        const field_x = pos.x + label_width;
        const field_rect = rl.Rectangle{
            .x = field_x,
            .y = pos.y,
            .width = field_width,
            .height = field_height,
        };

        // Check for mouse interaction
        const mouse_pos = rl.getMousePosition();
        const is_hovering = rl.checkCollisionPointRec(mouse_pos, field_rect);

        if (rl.isMouseButtonPressed(.left)) {
            if (is_hovering) {
                self.active = true;
                self.cursor_pos = self.text_len; // Move cursor to end when activating
            } else if (self.active) {
                // Clicked outside, deactivate and apply value
                self.active = false;
                self.syncValueFromBuffer();
            }
        }

        // Handle text input when active
        if (self.active) {
            // Handle left arrow
            if (rl.isKeyPressed(.left)) {
                if (self.cursor_pos > 0) {
                    self.cursor_pos -= 1;
                }
            }

            // Handle right arrow
            if (rl.isKeyPressed(.right)) {
                if (self.cursor_pos < self.text_len) {
                    self.cursor_pos += 1;
                }
            }

            // Handle Home key
            if (rl.isKeyPressed(.home)) {
                self.cursor_pos = 0;
            }

            // Handle End key
            if (rl.isKeyPressed(.end)) {
                self.cursor_pos = self.text_len;
            }

            // Handle backspace - delete character before cursor
            if (rl.isKeyPressed(.backspace) and self.cursor_pos > 0) {
                // Shift everything after cursor left
                var i: usize = self.cursor_pos - 1;
                while (i < self.text_len - 1) : (i += 1) {
                    self.text_buffer[i] = self.text_buffer[i + 1];
                }
                self.text_len -= 1;
                self.cursor_pos -= 1;
                self.text_buffer[self.text_len] = 0;
            }

            // Handle delete key - delete character at cursor
            if (rl.isKeyPressed(.delete) and self.cursor_pos < self.text_len) {
                // Shift everything after cursor left
                var i: usize = self.cursor_pos;
                while (i < self.text_len - 1) : (i += 1) {
                    self.text_buffer[i] = self.text_buffer[i + 1];
                }
                self.text_len -= 1;
                self.text_buffer[self.text_len] = 0;
            }

            // Handle enter - apply value and deactivate
            if (rl.isKeyPressed(.enter) or rl.isKeyPressed(.kp_enter)) {
                self.active = false;
                self.syncValueFromBuffer();
            }

            // Handle character input
            var char = rl.getCharPressed();
            while (char > 0) : (char = rl.getCharPressed()) {
                // Allow digits, decimal point, and minus sign
                if ((char >= '0' and char <= '9') or char == '.' or char == '-') {
                    if (self.text_len < self.text_buffer.len - 1) {
                        // Shift everything after cursor right
                        var i: usize = self.text_len;
                        while (i > self.cursor_pos) : (i -= 1) {
                            self.text_buffer[i] = self.text_buffer[i - 1];
                        }
                        // Insert character at cursor
                        self.text_buffer[self.cursor_pos] = @intCast(char);
                        self.text_len += 1;
                        self.cursor_pos += 1;
                        self.text_buffer[self.text_len] = 0;
                    }
                }
            }
        }

        // Draw field background
        const bg_color = if (self.active)
            rl.Color.init(255, 255, 200, 255)
        else if (is_hovering)
            rl.Color.init(240, 240, 240, 255)
        else
            rl.Color.init(255, 255, 255, 255);

        rl.drawRectangleRec(field_rect, bg_color);

        // Draw border
        const border_color = if (self.active)
            rl.Color.init(0, 120, 215, 255)
        else
            rl.Color.init(180, 180, 180, 255);

        rl.drawRectangleLinesEx(field_rect, 2.0 * dpi_scale.x, border_color);

        // Draw text value
        const text_to_draw = self.text_buffer[0..self.text_len :0];
        const font_size = 20.0 * dpi_scale.y;
        rl.drawTextEx(font, text_to_draw, rl.Vector2{ .x = field_x + padding, .y = pos.y + 5 * dpi_scale.y }, font_size, 1.0, rl.Color.black);

        // Draw cursor if active
        if (self.active) {
            const cursor_time = @mod(rl.getTime(), 1.0);
            if (cursor_time < 0.5) {
                // Measure text up to cursor position
                var cursor_text_buf: [32:0]u8 = undefined;
                @memcpy(cursor_text_buf[0..self.cursor_pos], self.text_buffer[0..self.cursor_pos]);
                cursor_text_buf[self.cursor_pos] = 0;
                const text_before_cursor = cursor_text_buf[0..self.cursor_pos :0];
                const text_size = rl.measureTextEx(font, text_before_cursor, font_size, 1.0);
                const cursor_x = field_x + padding + text_size.x;
                rl.drawRectangle(@intFromFloat(cursor_x), @intFromFloat(pos.y + 5 * dpi_scale.y), @intFromFloat(2.0 * dpi_scale.x), @intFromFloat(font_size), rl.Color.black);
            }
        }
    }
};
