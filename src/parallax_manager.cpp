#include "parallax_manager.h"
#include <godot_cpp/classes/engine.hpp>

using namespace godot;

NativeParallaxManager::NativeParallaxManager() {}
NativeParallaxManager::~NativeParallaxManager() {}

void NativeParallaxManager::_bind_methods() {
    ClassDB::bind_method(D_METHOD("add_layer", "node", "factor"), &NativeParallaxManager::add_layer);
    ClassDB::bind_method(D_METHOD("add_layer_ext", "node", "factor", "auto_speed"), &NativeParallaxManager::add_layer_ext);
    ClassDB::bind_method(D_METHOD("remove_layer", "node"), &NativeParallaxManager::remove_layer);
    
    ClassDB::bind_method(D_METHOD("set_camera_node", "camera"), &NativeParallaxManager::set_camera_node);
    ClassDB::bind_method(D_METHOD("get_camera_node"), &NativeParallaxManager::get_camera_node);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "camera_node", PROPERTY_HINT_NODE_TYPE, "Node2D"), "set_camera_node", "get_camera_node");

    ClassDB::bind_method(D_METHOD("set_follow_horizontal", "follow"), &NativeParallaxManager::set_follow_horizontal);
    ClassDB::bind_method(D_METHOD("is_following_horizontal"), &NativeParallaxManager::is_following_horizontal);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "follow_horizontal"), "set_follow_horizontal", "is_following_horizontal");

    ClassDB::bind_method(D_METHOD("set_follow_vertical", "follow"), &NativeParallaxManager::set_follow_vertical);
    ClassDB::bind_method(D_METHOD("is_following_vertical"), &NativeParallaxManager::is_following_vertical);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "follow_vertical"), "set_follow_vertical", "is_following_vertical");
}

void NativeParallaxManager::add_layer(Node2D* p_node, Vector2 p_factor) {
    add_layer_ext(p_node, p_factor, Vector2(0, 0));
}

void NativeParallaxManager::add_layer_ext(Node2D* p_node, Vector2 p_factor, Vector2 p_auto_speed) {
    if (!p_node) return;
    ParallaxLayer layer;
    layer.node = p_node;
    layer.factor = p_factor;
    layer.base_pos = p_node->get_position();
    layer.auto_speed = p_auto_speed;
    layer.current_auto_offset = Vector2(0, 0);
    layers.push_back(layer);
}

void NativeParallaxManager::remove_layer(Node2D* p_node) {
    for (auto it = layers.begin(); it != layers.end(); ++it) {
        if (it->node == p_node) {
            layers.erase(it);
            break;
        }
    }
}

void NativeParallaxManager::_process(double delta) {
    if (Engine::get_singleton()->is_editor_hint()) return;
    if (!camera_node) return;

    Vector2 cam_pos = camera_node->get_global_position();
    
    for (auto &layer : layers) {
        if (!layer.node || !layer.node->is_inside_tree()) continue;

        // Apply auto-scrolling
        layer.current_auto_offset += layer.auto_speed * (float)delta;
        
        Vector2 parallax_offset = Vector2(0, 0);
        if (follow_horizontal) parallax_offset.x = cam_pos.x * layer.factor.x;
        if (follow_vertical) parallax_offset.y = cam_pos.y * layer.factor.y;
        
        layer.node->set_position(layer.base_pos + parallax_offset + layer.current_auto_offset);
    }
}
