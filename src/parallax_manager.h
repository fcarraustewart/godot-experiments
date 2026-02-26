#ifndef PARALLAX_MANAGER_H
#define PARALLAX_MANAGER_H

#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <vector>

namespace godot {

struct ParallaxLayer {
    Node2D* node = nullptr;
    Vector2 factor;
    Vector2 base_pos;
};

class NativeParallaxManager : public Node2D {
    GDCLASS(NativeParallaxManager, Node2D);

private:
    std::vector<ParallaxLayer> layers;
    Node2D* camera_node = nullptr;
    Vector2 last_cam_pos;
    bool follow_horizontal = true;
    bool follow_vertical = true;

protected:
    static void _bind_methods();

public:
    NativeParallaxManager();
    ~NativeParallaxManager();

    void _process(double delta) override;

    void add_layer(Node2D* p_node, Vector2 p_factor);
    void remove_layer(Node2D* p_node);
    
    void set_camera_node(Node2D* p_cam) { camera_node = p_cam; }
    Node2D* get_camera_node() const { return camera_node; }

    void set_follow_horizontal(bool p_follow) { follow_horizontal = p_follow; }
    bool is_following_horizontal() const { return follow_horizontal; }
    void set_follow_vertical(bool p_follow) { follow_vertical = p_follow; }
    bool is_following_vertical() const { return follow_vertical; }
};

}

#endif
