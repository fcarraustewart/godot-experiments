#ifndef SWARM_MANAGER_H
#define SWARM_MANAGER_H

#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/multi_mesh_instance2d.hpp>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/transform2d.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <vector>

namespace godot {

struct NativeSwarmUnit {
    Vector2 position;
    Vector2 velocity;
    Vector2 acceleration;
    
    // Second Order Dynamics state
    Vector2 xp; // current position in sim
    Vector2 xd; // current velocity in sim
    
    float rotation;
    float scale;
    Color color;
};

class NativeSwarmManager : public Node2D {
    GDCLASS(NativeSwarmManager, Node2D);

private:
    std::vector<NativeSwarmUnit> units;
    
    // Boid Rules
    float separation_weight = 1.5f;
    float alignment_weight = 1.0f;
    float cohesion_weight = 1.0f;
    float target_attraction_weight = 2.0f;
    float perception_radius = 150.0f;
    float max_speed = 300.0f;
    
    // Dynamics (Second Order)
    float frequency = 2.0f;
    float damping = 0.6f;
    float response = 0.0f;
    float k1, k2, k3;
    
    Node2D* target_node = nullptr;
    MultiMeshInstance2D* multimesh_instance = nullptr;
    
    // Movement Tracking
    Vector2 last_global_pos;
    bool first_frame = true;

    // Organic Movement
    float sway_strength = 0.0f;
    float sway_speed = 1.0f;
    float time_passed = 0.0f;

    void _update_dynamics_parameters();
    void _calculate_boid_forces(int index, Vector2 &swarm_force);
    Vector2 _calculate_target_force(int index);

protected:
    static void _bind_methods();

public:
    NativeSwarmManager();
    ~NativeSwarmManager();

    void _physics_process(double delta) override;

    // API
    void setup_swarm(int count, double spawn_radius);
    void add_unit(Vector2 pos, Vector2 vel);
    void clear_swarm();

    Vector2 get_unit_position(int index) const;
    int get_unit_count() const { return (int)units.size(); }

    void set_unit_scale_at(int index, double scale);
    void set_unit_color_at(int index, Color color);

    void set_target_node(Node2D* p_target) { target_node = p_target; }
    Node2D* get_target_node() const { return target_node; }
    void set_multimesh_instance(MultiMeshInstance2D* p_mm) { multimesh_instance = p_mm; }

    // Global Properties
    void set_global_unit_scale(double s) { global_unit_scale = (float)s; }
    double get_global_unit_scale() const { return (double)global_unit_scale; }
    void set_base_color(Color c) { base_color = c; }
    Color get_base_color() const { return base_color; }

    // Properties
    void set_separation_weight(double w) { separation_weight = (float)w; }
    double get_separation_weight() const { return (double)separation_weight; }
    void set_alignment_weight(double w) { alignment_weight = (float)w; }
    double get_alignment_weight() const { return (double)alignment_weight; }
    void set_cohesion_weight(double w) { cohesion_weight = (float)w; }
    double get_cohesion_weight() const { return (double)cohesion_weight; }
    void set_target_attraction_weight(double w) { target_attraction_weight = (float)w; }
    double get_target_attraction_weight() const { return (double)target_attraction_weight; }
    void set_perception_radius(double r) { perception_radius = (float)r; }
    double get_perception_radius() const { return (double)perception_radius; }
    void set_max_speed(double s) { max_speed = (float)s; }
    double get_max_speed() const { return (double)max_speed; }
    
    void set_frequency(double f) { frequency = (float)f; _update_dynamics_parameters(); }
    double get_frequency() const { return (double)frequency; }
    void set_damping(double d) { damping = (float)d; _update_dynamics_parameters(); }
    double get_damping() const { return (double)damping; }
    void set_response(double r) { response = (float)r; _update_dynamics_parameters(); }
    double get_response() const { return (double)response; }

    void set_sway_strength(double s) { sway_strength = (float)s; }
    double get_sway_strength() const { return (double)sway_strength; }
    void set_sway_speed(double s) { sway_speed = (float)s; }
    double get_sway_speed() const { return (double)sway_speed; }

private:
    float global_unit_scale = 1.0f;
    Color base_color = Color(1, 1, 1, 1);
};

}

#endif
