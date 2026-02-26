#include "physics_manager.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/core/math.hpp>

using namespace godot;

NativePhysicsManager::NativePhysicsManager() {}
NativePhysicsManager::~NativePhysicsManager() {}

void NativePhysicsManager::_physics_process(double delta) {
    if (delta <= 0) return;

    float i_delta = delta / 4.0f; // 4x Sub-stepping for stability
    
    // 1. Second Order Sims
    for (auto &sim : sims) {
        for (int i = 0; i < 4; i++) {
            Vector2 x_acc = (sim.y + (sim.k3 * sim.xd) - sim.xp - (sim.k1 * sim.xd)) / sim.k2;
            sim.xd += x_acc * i_delta;
            sim.xp += sim.xd * i_delta;
        }
    }

    // 2. Soft Body Sims (Verlet)
    Vector2 grav_vec = Vector2(0, gravity);
    for (auto &body : soft_bodies) {
        // Step 1: Integration
        for (size_t i = 0; i < body.points.size(); i++) {
            if (body.anchors.count(i)) {
                body.points[i] = body.anchors[i];
                continue;
            }

            Vector2 vel = (body.points[i] - body.prev_points[i]) * 0.95f; // Damping
            body.prev_points[i] = body.points[i];
            body.points[i] += vel + (grav_vec + body.forces) * delta;
        }

        // Step 2: Constraints (Relaxation)
        for (int iter = 0; iter < 12; iter++) {
            for (size_t i = 0; i < body.points.size() - 1; i++) {
                Vector2 p1 = body.points[i];
                Vector2 p2 = body.points[i+1];
                Vector2 diff = p2 - p1;
                float d = diff.length();
                if (d < 0.0001f) continue;

                float error = (d - body.constraint_dist) / d;
                
                float m1 = body.anchors.count(i) ? 0.0f : 0.5f;
                float m2 = body.anchors.count(i+1) ? 0.0f : 0.5f;
                
                if (m1 + m2 > 0) {
                    body.points[i] += diff * error * (m1 / (m1 + m2));
                    body.points[i+1] -= diff * error * (m2 / (m1 + m2));
                }
            }
        }
        // Reset per-frame forces
        body.forces = Vector2(0, 0);
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

Dictionary NativePhysicsManager::register_soft_body(String id, Array points, float constraint_dist) {
    SoftBodySim b;
    b.id = id;
    b.constraint_dist = constraint_dist;
    b.forces = Vector2(0, 0);
    
    for (int i = 0; i < points.size(); i++) {
        Vector2 p = points[i];
        b.points.push_back(p);
        b.prev_points.push_back(p);
    }
    
    soft_bodies.push_back(b);
    
    Dictionary d;
    d["id"] = id;
    d["type"] = "SOFT_BODY";
    return d;
}

void NativePhysicsManager::update_soft_body_anchors(String id, Dictionary anchors) {
    for (auto &body : soft_bodies) {
        if (body.id == id) {
            body.anchors.clear();
            Array keys = anchors.keys();
            for (int i = 0; i < keys.size(); i++) {
                int idx = keys[i];
                body.anchors[idx] = anchors[keys[i]];
            }
            break;
        }
    }
}

void NativePhysicsManager::apply_soft_body_force(String id, Vector2 force) {
    for (auto &body : soft_bodies) {
        if (body.id == id) {
            body.forces += force;
            break;
        }
    }
}

Array NativePhysicsManager::get_soft_body_points(String id) {
    Array res;
    for (const auto &body : soft_bodies) {
        if (body.id == id) {
            for (const auto &p : body.points) res.push_back(p);
            return res;
        }
    }
    return res;
}

void NativePhysicsManager::set_soft_body_prev_points(String id, Array prev_points) {
    for (auto &body : soft_bodies) {
        if (body.id == id) {
            for (int i = 0; i < prev_points.size() && (size_t)i < body.prev_points.size(); i++) {
                body.prev_points[i] = prev_points[i];
            }
            break;
        }
    }
}

void NativePhysicsManager::unregister_object(Dictionary sim_dict) {
    String id = sim_dict.get("id", "");
    String type = sim_dict.get("type", "");

    if (type == "SECOND_ORDER") {
        for (auto it = sims.begin(); it != sims.end(); ++it) {
            if (it->id == id) {
                sims.erase(it);
                break;
            }
        }
    } else if (type == "SOFT_BODY") {
        for (auto it = soft_bodies.begin(); it != soft_bodies.end(); ++it) {
            if (it->id == id) {
                soft_bodies.erase(it);
                break;
            }
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

void NativePhysicsManager::set_second_order_pos(String id, Vector2 new_xp) {
    for (auto &sim : sims) {
        if (sim.id == id) {
            sim.xp = new_xp;
            break;
        }
    }
}

void NativePhysicsManager::set_second_order_velocity(String id, Vector2 new_xd) {
    for (auto &sim : sims) {
        if (sim.id == id) {
            sim.xd = new_xd;
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
    ClassDB::bind_method(D_METHOD("register_soft_body", "id", "points", "constraint_dist"), &NativePhysicsManager::register_soft_body);
    ClassDB::bind_method(D_METHOD("update_soft_body_anchors", "id", "anchors"), &NativePhysicsManager::update_soft_body_anchors);
    ClassDB::bind_method(D_METHOD("apply_soft_body_force", "id", "force"), &NativePhysicsManager::apply_soft_body_force);
    ClassDB::bind_method(D_METHOD("get_soft_body_points", "id"), &NativePhysicsManager::get_soft_body_points);
    ClassDB::bind_method(D_METHOD("set_soft_body_prev_points", "id", "prev_points"), &NativePhysicsManager::set_soft_body_prev_points);

    ClassDB::bind_method(D_METHOD("unregister_object", "sim_dict"), &NativePhysicsManager::unregister_object);
    
    ClassDB::bind_method(D_METHOD("get_second_order_pos", "id"), &NativePhysicsManager::get_second_order_pos);
    ClassDB::bind_method(D_METHOD("get_second_order_velocity", "id"), &NativePhysicsManager::get_second_order_velocity);
    ClassDB::bind_method(D_METHOD("set_second_order_target", "id", "new_y"), &NativePhysicsManager::set_second_order_target);
    ClassDB::bind_method(D_METHOD("set_second_order_pos", "id", "new_xp"), &NativePhysicsManager::set_second_order_pos);
    ClassDB::bind_method(D_METHOD("set_second_order_velocity", "id", "new_xd"), &NativePhysicsManager::set_second_order_velocity);
    ClassDB::bind_method(D_METHOD("update_dynamics_for_sim", "sim_dict", "f", "zeta", "r"), &NativePhysicsManager::update_dynamics_for_sim);

    ClassDB::bind_method(D_METHOD("get_gravity"), &NativePhysicsManager::get_gravity);
    ClassDB::bind_method(D_METHOD("set_gravity", "gravity"), &NativePhysicsManager::set_gravity);
    ClassDB::bind_method(D_METHOD("get_floor_y"), &NativePhysicsManager::get_floor_y);
    ClassDB::bind_method(D_METHOD("set_floor_y", "floor_y"), &NativePhysicsManager::set_floor_y);

    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "gravity"), "set_gravity", "get_gravity");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "floor_y"), "set_floor_y", "get_floor_y");
}
