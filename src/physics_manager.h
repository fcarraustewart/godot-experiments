#ifndef PHYSICS_MANAGER_H
#define PHYSICS_MANAGER_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <vector>

namespace godot {

struct SecondOrderSim {
    String id;
    Vector2 y;   // Target
    Vector2 xp;  // Current Position
    Vector2 xd;  // Velocity
    float k1, k2, k3;
};

class NativePhysicsManager : public Node {
    GDCLASS(NativePhysicsManager, Node);

private:
    std::vector<SecondOrderSim> sims;
    float gravity = -800.0f; // Matching your GDScript gravity
    float floor_y = 450.0f;  // Matching your default floor

protected:
    static void _bind_methods();

public:
    NativePhysicsManager();
    ~NativePhysicsManager();

    void _physics_process(double delta) override;
    
    // GDExtension API
    Dictionary register_second_order(String id, Vector2 pos, float f, float zeta, float r);
    void unregister_object(Dictionary sim_dict);
    Vector2 get_second_order_pos(String id);
    Vector2 get_second_order_velocity(String id);
    void set_second_order_target(String id, Vector2 new_y);
    void update_dynamics_for_sim(Dictionary sim_dict, float f, float zeta, float r);

    // Getters/Setters
    void set_gravity(float p_gravity) { gravity = p_gravity; }
    float get_gravity() const { return gravity; }
    void set_floor_y(float p_floor_y) { floor_y = p_floor_y; }
    float get_floor_y() const { return floor_y; }
};

}

#endif
