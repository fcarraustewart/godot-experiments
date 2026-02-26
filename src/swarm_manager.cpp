#include "swarm_manager.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <cmath>

using namespace godot;

NativeSwarmManager::NativeSwarmManager() {
    _update_dynamics_parameters();
}

NativeSwarmManager::~NativeSwarmManager() {
}

void NativeSwarmManager::_bind_methods() {
    ClassDB::bind_method(D_METHOD("setup_swarm", "count", "spawn_radius"), &NativeSwarmManager::setup_swarm);
    ClassDB::bind_method(D_METHOD("add_unit", "pos", "vel"), &NativeSwarmManager::add_unit);
    ClassDB::bind_method(D_METHOD("clear_swarm"), &NativeSwarmManager::clear_swarm);
    ClassDB::bind_method(D_METHOD("get_unit_position", "index"), &NativeSwarmManager::get_unit_position);
    ClassDB::bind_method(D_METHOD("get_unit_count"), &NativeSwarmManager::get_unit_count);
    ClassDB::bind_method(D_METHOD("get_target_node"), &NativeSwarmManager::get_target_node);
    ClassDB::bind_method(D_METHOD("set_target_node", "target"), &NativeSwarmManager::set_target_node);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "target_node", PROPERTY_HINT_NODE_TYPE, "Node2D"), "set_target_node", "get_target_node");

    ClassDB::bind_method(D_METHOD("set_global_unit_scale", "s"), &NativeSwarmManager::set_global_unit_scale);
    ClassDB::bind_method(D_METHOD("get_global_unit_scale"), &NativeSwarmManager::get_global_unit_scale);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "unit_scale"), "set_global_unit_scale", "get_global_unit_scale");

    ClassDB::bind_method(D_METHOD("set_base_color", "c"), &NativeSwarmManager::set_base_color);
    ClassDB::bind_method(D_METHOD("get_base_color"), &NativeSwarmManager::get_base_color);
    ADD_PROPERTY(PropertyInfo(Variant::COLOR, "base_color"), "set_base_color", "get_base_color");

    ClassDB::bind_method(D_METHOD("set_unit_scale_at", "index", "scale"), &NativeSwarmManager::set_unit_scale_at);
    ClassDB::bind_method(D_METHOD("set_unit_color_at", "index", "color"), &NativeSwarmManager::set_unit_color_at);

    ClassDB::bind_method(D_METHOD("set_multimesh_instance", "mm"), &NativeSwarmManager::set_multimesh_instance);

    ClassDB::bind_method(D_METHOD("set_separation_weight", "w"), &NativeSwarmManager::set_separation_weight);
    ClassDB::bind_method(D_METHOD("get_separation_weight"), &NativeSwarmManager::get_separation_weight);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "separation_weight"), "set_separation_weight", "get_separation_weight");

    ClassDB::bind_method(D_METHOD("set_alignment_weight", "w"), &NativeSwarmManager::set_alignment_weight);
    ClassDB::bind_method(D_METHOD("get_alignment_weight"), &NativeSwarmManager::get_alignment_weight);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "alignment_weight"), "set_alignment_weight", "get_alignment_weight");

    ClassDB::bind_method(D_METHOD("set_cohesion_weight", "w"), &NativeSwarmManager::set_cohesion_weight);
    ClassDB::bind_method(D_METHOD("get_cohesion_weight"), &NativeSwarmManager::get_cohesion_weight);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "cohesion_weight"), "set_cohesion_weight", "get_cohesion_weight");

    ClassDB::bind_method(D_METHOD("set_target_attraction_weight", "w"), &NativeSwarmManager::set_target_attraction_weight);
    ClassDB::bind_method(D_METHOD("get_target_attraction_weight"), &NativeSwarmManager::get_target_attraction_weight);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "target_attraction_weight"), "set_target_attraction_weight", "get_target_attraction_weight");

    ClassDB::bind_method(D_METHOD("set_perception_radius", "r"), &NativeSwarmManager::set_perception_radius);
    ClassDB::bind_method(D_METHOD("get_perception_radius"), &NativeSwarmManager::get_perception_radius);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "perception_radius"), "set_perception_radius", "get_perception_radius");

    ClassDB::bind_method(D_METHOD("set_max_speed", "s"), &NativeSwarmManager::set_max_speed);
    ClassDB::bind_method(D_METHOD("get_max_speed"), &NativeSwarmManager::get_max_speed);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "max_speed"), "set_max_speed", "get_max_speed");

    ClassDB::bind_method(D_METHOD("set_frequency", "f"), &NativeSwarmManager::set_frequency);
    ClassDB::bind_method(D_METHOD("get_frequency"), &NativeSwarmManager::get_frequency);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "frequency"), "set_frequency", "get_frequency");

    ClassDB::bind_method(D_METHOD("set_damping", "d"), &NativeSwarmManager::set_damping);
    ClassDB::bind_method(D_METHOD("get_damping"), &NativeSwarmManager::get_damping);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "damping"), "set_damping", "get_damping");

    ClassDB::bind_method(D_METHOD("set_response", "r"), &NativeSwarmManager::set_response);
    ClassDB::bind_method(D_METHOD("get_response"), &NativeSwarmManager::get_response);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "response"), "set_response", "get_response");

    ClassDB::bind_method(D_METHOD("set_sway_strength", "s"), &NativeSwarmManager::set_sway_strength);
    ClassDB::bind_method(D_METHOD("get_sway_strength"), &NativeSwarmManager::get_sway_strength);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "sway_strength"), "set_sway_strength", "get_sway_strength");

    ClassDB::bind_method(D_METHOD("set_sway_speed", "s"), &NativeSwarmManager::set_sway_speed);
    ClassDB::bind_method(D_METHOD("get_sway_speed"), &NativeSwarmManager::get_sway_speed);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "sway_speed"), "set_sway_speed", "get_sway_speed");
}

void NativeSwarmManager::_update_dynamics_parameters() {
    float pi = 3.14159265f;
    k1 = damping / (pi * frequency);
    k2 = 1.0f / ((2.0f * pi * frequency) * (2.0f * pi * frequency));
    k3 = response * damping / (2.0f * pi * frequency);
}

void NativeSwarmManager::setup_swarm(int count, double spawn_radius) {
    units.clear();
    for (int i = 0; i < count; i++) {
        NativeSwarmUnit unit;
        float angle = ((float)rand() / RAND_MAX) * 2.0f * 3.1415f;
        float dist = ((float)rand() / RAND_MAX) * spawn_radius;
        unit.position = Vector2(cos(angle) * dist, sin(angle) * dist);
        unit.velocity = Vector2(((float)rand() / RAND_MAX - 0.5f), ((float)rand() / RAND_MAX - 0.5f)) * 50.0f;
        unit.acceleration = Vector2(0, 0);
        unit.xp = unit.position; // xp represents current local position in this refactor
        unit.xd = Vector2(0, 0);
        unit.rotation = 0;
        unit.scale = 1.0f;
        unit.color = Color(1, 1, 1, 1);
        units.push_back(unit);
    }
    
    if (multimesh_instance && multimesh_instance->get_multimesh().is_valid()) {
        multimesh_instance->get_multimesh()->set_instance_count(count);
    }
}

void NativeSwarmManager::add_unit(Vector2 pos, Vector2 vel) {
    NativeSwarmUnit unit;
    unit.position = get_global_transform().affine_inverse().xform(pos);
    unit.velocity = vel;
    unit.acceleration = Vector2(0, 0);
    unit.xp = unit.position;
    unit.xd = Vector2(0, 0);
    unit.rotation = 0;
    unit.scale = 1.0f;
    unit.color = Color(1, 1, 1, 1);
    units.push_back(unit);
    
    if (multimesh_instance && multimesh_instance->get_multimesh().is_valid()) {
        multimesh_instance->get_multimesh()->set_instance_count(units.size());
    }
}

void NativeSwarmManager::clear_swarm() {
    units.clear();
    if (multimesh_instance && multimesh_instance->get_multimesh().is_valid()) {
        multimesh_instance->get_multimesh()->set_instance_count(0);
    }
}

Vector2 NativeSwarmManager::get_unit_position(int index) const {
    if (index >= 0 && index < (int)units.size()) {
       return get_global_transform().xform(units[index].position);
    }
    return Vector2();
}

void NativeSwarmManager::set_unit_scale_at(int index, double scale) {
    if (index >= 0 && index < (int)units.size()) {
        units[index].scale = (float)scale;
    }
}

void NativeSwarmManager::set_unit_color_at(int index, Color color) {
    if (index >= 0 && index < (int)units.size()) {
        units[index].color = color;
    }
}

void NativeSwarmManager::_calculate_boid_forces(int index, Vector2 &swarm_force) {
    Vector2 separation = Vector2(0, 0);
    Vector2 alignment = Vector2(0, 0);
    Vector2 cohesion = Vector2(0, 0);
    int neighbors_count = 0;
    
    Vector2 pos = units[index].position;
    
    for (int i = 0; i < units.size(); i++) {
        if (i == index) continue;
        
        Vector2 other_pos = units[i].position;
        float dist_sq = pos.distance_squared_to(other_pos);
        
        if (dist_sq < perception_radius * perception_radius) {
            float dist = sqrt(dist_sq);
            if (dist > 0.001f) {
                separation += ((pos - other_pos) / dist) * (100.0f / dist);
            }
            
            alignment += units[i].velocity;
            cohesion += other_pos;
            neighbors_count++;
        }
    }
    
    if (neighbors_count > 0) {
        alignment /= (float)neighbors_count;
        cohesion /= (float)neighbors_count;
        cohesion = (cohesion - pos);
        
        swarm_force = (separation * separation_weight) + (alignment * alignment_weight) + (cohesion * cohesion_weight);
    } else {
        swarm_force = Vector2(0, 0);
    }
}

Vector2 NativeSwarmManager::_calculate_target_force(int index) {
    Vector2 target_local;
    if (target_node && target_node->is_inside_tree()) {
        target_local = get_global_transform().affine_inverse().xform(target_node->get_global_position());
    } else {
        target_local = Vector2(0, 0); // Origin of manager
    }
    return (target_local - units[index].position) * target_attraction_weight;
}

void NativeSwarmManager::_physics_process(double delta) {
    if (Engine::get_singleton()->is_editor_hint()) return;
    
    float f_delta = (float)delta;
    time_passed += f_delta * sway_speed;
    
    // World space anchoring: Counter-act manager movement
    Vector2 current_global = get_global_position();
    if (first_frame) {
        last_global_pos = current_global;
        first_frame = false;
    }
    Vector2 move_delta = current_global - last_global_pos;
    last_global_pos = current_global;

    for (int i = 0; i < units.size(); i++) {
        // Shift unit by manager movement to keep it "steady" in world space
        units[i].position -= move_delta;
        units[i].xp -= move_delta;

        Vector2 swarm_force;
        _calculate_boid_forces(i, swarm_force);
        Vector2 target_force = _calculate_target_force(i);
        
        Vector2 desired_velocity = (swarm_force + target_force).limit_length(max_speed);
        
        // Add organic sway if strength > 0
        if (sway_strength > 0.001f) {
            float unit_offset = (float)i * 0.5f;
            Vector2 sway(
                sinf(time_passed + unit_offset) * sway_strength,
                cosf(time_passed * 0.7f + unit_offset) * sway_strength * 0.5f
            );
            desired_velocity += sway;
        }

        if (desired_velocity.length_squared() < 10.0f) {
            desired_velocity += Vector2(((float)rand() / RAND_MAX - 0.5f), ((float)rand() / RAND_MAX - 0.5f)) * 20.0f;
        }
        
        // Second Order Dynamics Integration (local space)
        Vector2 target_pos = units[i].position + desired_velocity;
        
        // Sim update
        Vector2 x = target_pos;
        Vector2 xd = desired_velocity; // derived from desired move
        
        units[i].xp = units[i].xp + f_delta * units[i].xd;
        units[i].xd = units[i].xd + f_delta * (x + k3 * xd - units[i].xp - k1 * units[i].xd) / k2;
        
        // Final local position
        units[i].position = units[i].xp;
        units[i].velocity = units[i].xd;
        
        if (units[i].velocity.length_squared() > 10.0f) {
            units[i].rotation = units[i].velocity.angle() + (move_delta.length_squared() > 1.0f ? 0 : 0); 
        }
    }
    
    // Update MultiMesh (Direct local positions)
    if (multimesh_instance && multimesh_instance->get_multimesh().is_valid()) {
        Ref<MultiMesh> mm = multimesh_instance->get_multimesh();
        if (mm->get_instance_count() != (int)units.size()) {
            mm->set_instance_count(units.size());
        }
        
        for (int i = 0; i < units.size(); i++) {
            Transform2D xform;
            float final_scale = units[i].scale * global_unit_scale;
            xform.set_rotation_and_scale(units[i].rotation, Vector2(final_scale, final_scale));
            xform.set_origin(units[i].position);
            mm->set_instance_transform_2d(i, xform);
            
            if (mm->is_using_colors()) {
                mm->set_instance_color(i, units[i].color * base_color);
            }
        }
    }
}
