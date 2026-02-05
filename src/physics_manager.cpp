#include "physics_manager.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/core/math.hpp>

using namespace godot;

NativePhysicsManager::NativePhysicsManager() {}
NativePhysicsManager::~NativePhysicsManager() {}

void NativePhysicsManager::_physics_process(double delta) {
    if (delta <= 0) return;

    float i_delta = delta / 4.0f; // 4x Sub-stepping for stability
    
    for (auto &sim : sims) {
        for (int i = 0; i < 4; i++) {
            // Second Order Dynamics Math
            Vector2 x_acc = (sim.y + (sim.k3 * sim.xd) - sim.xp - (sim.k1 * sim.xd)) / sim.k2;
            sim.xd += x_acc * i_delta;
            sim.xp += sim.xd * i_delta;
        }
    }
}

Dictionary NativePhysicsManager::register_second_order(String id, Vector2 pos, float f, float zeta, float r) {
    SecondOrderSim n;
    n.id = id;
    n.xp = pos;
    n.y = pos;
    n.xd = Vector2(0, 0);
    
    float pi = Math_PI;
    n.k1 = zeta / (pi * f);
    n.k2 = 1.0f / pow(2.0f * pi * f, 2.0f);
    n.k3 = r * zeta / (2.0f * pi * f);
    
    sims.push_back(n);
    
    // We return a dictionary that acts as a reference handle for GDScript
    Dictionary d;
    d["id"] = id;
    d["type"] = "SECOND_ORDER";
    return d;
}

void NativePhysicsManager::unregister_object(Dictionary sim_dict) {
    String id = sim_dict.get("id", "");
    for (auto it = sims.begin(); it != sims.end(); ++it) {
        if (it->id == id) {
            sims.erase(it);
            break;
        }
    }
}

Vector2 NativePhysicsManager::get_second_order_pos(String id) {
    for (const auto &sim : sims) {
        if (sim.id == id) return sim.xp;
    }
    return Vector2(0, 0);
}

Vector2 NativePhysicsManager::get_second_order_velocity(String id) {
    for (const auto &sim : sims) {
        if (sim.id == id) return sim.xd;
    }
    return Vector2(0, 0);
}

void NativePhysicsManager::set_second_order_target(String id, Vector2 new_y) {
    for (auto &sim : sims) {
        if (sim.id == id) {
            sim.y = new_y;
            break;
        }
    }
}

void NativePhysicsManager::update_dynamics_for_sim(Dictionary sim_dict, float f, float zeta, float r) {
    String id = sim_dict.get("id", "");
    for (auto &sim : sims) {
        if (sim.id == id) {
            float pi = Math_PI;
            sim.k1 = zeta / (pi * f);
            sim.k2 = 1.0f / pow(2.0f * pi * f, 2.0f);
            sim.k3 = r * zeta / (2.0f * pi * f);
            break;
        }
    }
}

void NativePhysicsManager::_bind_methods() {
    ClassDB::bind_method(D_METHOD("register_second_order", "id", "pos", "f", "zeta", "r"), &NativePhysicsManager::register_second_order);
    ClassDB::bind_method(D_METHOD("unregister_object", "sim_dict"), &NativePhysicsManager::unregister_object);
    ClassDB::bind_method(D_METHOD("get_second_order_pos", "id"), &NativePhysicsManager::get_second_order_pos);
    ClassDB::bind_method(D_METHOD("get_second_order_velocity", "id"), &NativePhysicsManager::get_second_order_velocity);
    ClassDB::bind_method(D_METHOD("set_second_order_target", "id", "new_y"), &NativePhysicsManager::set_second_order_target);
    ClassDB::bind_method(D_METHOD("update_dynamics_for_sim", "sim_dict", "f", "zeta", "r"), &NativePhysicsManager::update_dynamics_for_sim);

    ClassDB::bind_method(D_METHOD("get_gravity"), &NativePhysicsManager::get_gravity);
    ClassDB::bind_method(D_METHOD("set_gravity", "gravity"), &NativePhysicsManager::set_gravity);
    ClassDB::bind_method(D_METHOD("get_floor_y"), &NativePhysicsManager::get_floor_y);
    ClassDB::bind_method(D_METHOD("set_floor_y", "floor_y"), &NativePhysicsManager::set_floor_y);

    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "gravity"), "set_gravity", "get_gravity");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "floor_y"), "set_floor_y", "get_floor_y");
}
