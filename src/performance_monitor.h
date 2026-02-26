#ifndef PERFORMANCE_MONITOR_H
#define PERFORMANCE_MONITOR_H

#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/color.hpp>
#include <vector>

namespace godot {

class NativePerformanceMonitor : public Node2D {
    GDCLASS(NativePerformanceMonitor, Node2D);

private:
    std::vector<float> frame_times;
    int max_samples = 120;
    float spike_threshold = 0.020f; // 20ms
    Color graph_color = Color(0.0f, 1.0f, 0.0f, 0.7f);
    Color spike_color = Color(1.0f, 0.0f, 0.0f, 0.9f);
    Color bg_color = Color(0.0f, 0.0f, 0.0f, 0.5f);
    
    float last_fps = 0.0f;
    float fps_update_timer = 0.0f;

protected:
    static void _bind_methods();

public:
    NativePerformanceMonitor();
    ~NativePerformanceMonitor();

    void _process(double delta) override;
    void _draw() override;

    void set_max_samples(int p_samples) { max_samples = p_samples; }
    int get_max_samples() const { return max_samples; }
    
    void set_spike_threshold(float p_threshold) { spike_threshold = p_threshold; }
    float get_spike_threshold() const { return spike_threshold; }
};

}

#endif
