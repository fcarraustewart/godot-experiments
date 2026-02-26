#include "performance_monitor.h"
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/font.hpp>
#include <godot_cpp/classes/theme_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

NativePerformanceMonitor::NativePerformanceMonitor() {
    frame_times.reserve(200);
}

NativePerformanceMonitor::~NativePerformanceMonitor() {}

void NativePerformanceMonitor::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_max_samples", "samples"), &NativePerformanceMonitor::set_max_samples);
    ClassDB::bind_method(D_METHOD("get_max_samples"), &NativePerformanceMonitor::get_max_samples);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "max_samples"), "set_max_samples", "get_max_samples");

    ClassDB::bind_method(D_METHOD("set_spike_threshold", "threshold"), &NativePerformanceMonitor::set_spike_threshold);
    ClassDB::bind_method(D_METHOD("get_spike_threshold"), &NativePerformanceMonitor::get_spike_threshold);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "spike_threshold"), "set_spike_threshold", "get_spike_threshold");
}

void NativePerformanceMonitor::_process(double delta) {
    if (Engine::get_singleton()->is_editor_hint()) return;

    float f_delta = (float)delta;
    frame_times.push_back(f_delta);
    if (frame_times.size() > (size_t)max_samples) {
        frame_times.erase(frame_times.begin());
    }

    fps_update_timer += f_delta;
    if (fps_update_timer >= 0.5f) {
        last_fps = 1.0f / f_delta;
        fps_update_timer = 0.0f;
    }

    queue_redraw();
}

void NativePerformanceMonitor::_draw() {
    if (Engine::get_singleton()->is_editor_hint()) return;
    if (frame_times.empty()) return;

    Vector2 size = Vector2(200, 100);
    draw_rect(Rect2(Vector2(0, 0), size), bg_color);
    
    // Draw Header
    draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 20)), Color(0, 0, 0, 0.4f));

    float x_step = size.x / max_samples;
    float y_scale = size.y * 30.0f; // Scale so 33ms (30fps) is full height roughly

    for (size_t i = 1; i < frame_times.size(); i++) {
        float h1 = frame_times[i - 1] * y_scale;
        float h2 = frame_times[i] * y_scale;
        
        Vector2 p1 = Vector2((i - 1) * x_step, size.y - h1);
        Vector2 p2 = Vector2(i * x_step, size.y - h2);

        Color c = (frame_times[i] > spike_threshold) ? spike_color : graph_color;
        draw_line(p1, p2, c, 1.5f);
    }

    // Draw FPS text at top
    String fps_text = "FPS: " + String::num(last_fps, 1);
    
    // Use Fallback font from ThemeDB
    Ref<Font> font = ThemeDB::get_singleton()->get_fallback_font();
    if (font.is_valid()) {
        draw_string(font, Vector2(8, 15), fps_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1));
        
        // Label for ms
        String ms_text = String::num(frame_times.back() * 1000.0f, 2) + " ms";
        draw_string(font, Vector2(size.x - 60, 15), ms_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.8));
    }
}
