#ifndef REFLECTION_MANAGER_H
#define REFLECTION_MANAGER_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/polygon2d.hpp>
#include <godot_cpp/classes/sprite2d.hpp>
#include <godot_cpp/classes/line2d.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/array.hpp>

namespace godot {

class NativeReflectionManager : public Node {
    GDCLASS(NativeReflectionManager, Node);

protected:
    static void _bind_methods();

    void _reflect_node_in_pond(Node2D *vis, Node2D *pond, int frame);
    void _update_node_reflection(Node2D *entity, Node2D *reflection, Node2D *pond);
    void _prune_old_reflections(TypedArray<Node2D> all_ponds, int frame);

public:
    NativeReflectionManager();
    ~NativeReflectionManager();

    // The main entry point called from GDScript every frame
    void process_reflections(TypedArray<Node2D> all_ponds, Dictionary reflection_nodes, TypedArray<Node2D> entities, TypedArray<Node> world_children, Node2D *player, Node2D *player_light, Node2D *moon_light, int current_frame, float screen_height);
};

}

#endif
