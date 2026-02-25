#include "reflection_manager.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/classes/material.hpp>

using namespace godot;

NativeReflectionManager::NativeReflectionManager() {}
NativeReflectionManager::~NativeReflectionManager() {}

void NativeReflectionManager::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process_reflections", "all_ponds", "reflection_nodes", "entities", "world_children", "player", "player_light", "moon_light", "current_frame", "screen_height"), &NativeReflectionManager::process_reflections);
}

void NativeReflectionManager::_collect_visual_nodes_recursive(Node *root, TypedArray<Node> &list) {
    if (Object::cast_to<Sprite2D>(root) || Object::cast_to<Line2D>(root) || Object::cast_to<Polygon2D>(root)) {
        String name = root->get_name();
        if (!name.contains("Ref_") && !name.contains("Reflection")) {
            list.push_back(root);
        }
    }

    TypedArray<Node> children = root->get_children();
    for (int i = 0; i < children.size(); i++) {
        Node *child = Object::cast_to<Node>(children[i]);
        if (child) {
            _collect_visual_nodes_recursive(child, list);
        }
    }
}

void NativeReflectionManager::process_reflections(TypedArray<Node2D> all_ponds, Dictionary reflection_nodes, TypedArray<Node2D> entities, TypedArray<Node> world_children, Node2D *player, Node2D *player_light, Node2D *moon_light, int current_frame, float screen_height) {
    if (!player) return;

    // 1. Update Entities (Player, Enemies)
    Array entity_keys = reflection_nodes.keys();
    for (int i = 0; i < entity_keys.size(); i++) {
        Node2D *entity = Object::cast_to<Node2D>(entity_keys[i]);
        Node2D *reflection = Object::cast_to<Node2D>(reflection_nodes[entity_keys[i]]);
        
        if (!entity || !reflection || !entity->is_inside_tree()) continue;

        reflection->set_visible(false);

        Node2D *best_pond = nullptr;
        float min_y_dist = 1000.0f;

        for (int j = 0; j < all_ponds.size(); j++) {
            Node2D *pond = Object::cast_to<Node2D>(all_ponds[j]);
            if (!pond) continue;

            Polygon2D *pond_water = Object::cast_to<Polygon2D>(pond->get_node_or_null("PondWater"));
            if (pond_water) {
                Rect2 local_bounds = Rect2(Vector2(), Vector2());
                PackedVector2Array polys = pond_water->get_polygon();
                for (int p = 0; p < polys.size(); p++) {
                    local_bounds = local_bounds.expand(polys[p]);
                }

                float pond_width = local_bounds.get_size().x;
                float x_dist = Math::abs(entity->get_global_position().x - pond->get_global_position().x);
                float y_dist = Math::abs(entity->get_global_position().y - pond->get_global_position().y);

                if (x_dist < (pond_width / 2.0f) + 200.0f) {
                    if (y_dist < min_y_dist) {
                        min_y_dist = y_dist;
                        best_pond = pond;
                    }
                }
            }
        }

        if (best_pond) {
            Node2D *re_cont = Object::cast_to<Node2D>(best_pond->get_node_or_null("PondWater/Reflections"));
            if (re_cont) {
                if (reflection->get_parent() != re_cont) {
                    if (reflection->get_parent()) reflection->get_parent()->remove_child(reflection);
                    re_cont->add_child(reflection);
                }
                _update_node_reflection(entity, reflection, best_pond);
            }
        }
    }

    // 2. Update Dynamic Visuals & Skills
    TypedArray<Node> visuals_to_reflect;

    for (int i = 0; i < entities.size(); i++) {
        Node *ent = Object::cast_to<Node>(entities[i]);
        if (ent && ent->is_inside_tree()) {
            _collect_visual_nodes_recursive(ent, visuals_to_reflect);
        }
    }

    for (int i = 0; i < world_children.size(); i++) {
        Node *child = Object::cast_to<Node>(world_children[i]);
        if (!child || !Object::cast_to<Node2D>(child)) continue;

        String name = child->get_name();
        if (name.contains("Pond") || name.contains("Ref_") || child == player_light || child == moon_light) continue;
        _collect_visual_nodes_recursive(child, visuals_to_reflect);
    }

    for (int i = 0; i < visuals_to_reflect.size(); i++) {
        Node2D *vis = Object::cast_to<Node2D>(visuals_to_reflect[i]);
        // Note: checking modulate alpha in C++ requires cast to CanvasItem
        CanvasItem *canvas_vis = Object::cast_to<CanvasItem>(vis);
        if (!vis || !vis->is_inside_tree() || !vis->is_visible_in_tree() || (canvas_vis && canvas_vis->get_modulate().a < 0.1f)) continue;

        float vis_x = vis->get_global_position().x;
        for (int j = 0; j < all_ponds.size(); j++) {
            Node2D *pond = Object::cast_to<Node2D>(all_ponds[j]);
            if (!pond) continue;

            if (Math::abs(pond->get_global_position().x - player->get_global_position().x) > 1200.0f) continue;
            if (vis->get_global_position().y > pond->get_global_position().y + 20.0f) continue;

            float dist_x = Math::abs(vis_x - pond->get_global_position().x);
            if (dist_x > 400.0f) continue;

            _reflect_node_in_pond(vis, pond, current_frame);
        }
    }

    // 3. Mark-and-Sweep Cleanup
    _prune_old_reflections(all_ponds, current_frame);
}

void NativeReflectionManager::_reflect_node_in_pond(Node2D *vis, Node2D *pond, int frame) {
    Node *water = pond->get_node_or_null("PondWater");
    if (!water) return;
    Node *re_cont = water->get_node_or_null("Reflections");
    if (!re_cont) return;

    String ref_name = "Ref_" + String::num_int64(vis->get_instance_id());
    Node2D *ref_node = Object::cast_to<Node2D>(re_cont->get_node_or_null(NodePath(ref_name)));

    if (!ref_node) {
        Line2D *vis_line = Object::cast_to<Line2D>(vis);
        Sprite2D *vis_sprite = Object::cast_to<Sprite2D>(vis);
        Polygon2D *vis_poly = Object::cast_to<Polygon2D>(vis);

        if (vis_line) {
            Line2D *newline = memnew(Line2D);
            newline->set_width(vis_line->get_width());
            newline->set_texture(vis_line->get_texture());
            newline->set_texture_mode(vis_line->get_texture_mode());
            newline->set_material(vis_line->get_material());
            ref_node = newline;
        } else if (vis_sprite) {
            Sprite2D *newsprite = memnew(Sprite2D);
            newsprite->set_texture(vis_sprite->get_texture());
            newsprite->set_hframes(vis_sprite->get_hframes());
            newsprite->set_vframes(vis_sprite->get_vframes());
            ref_node = newsprite;
        } else if (vis_poly) {
            Polygon2D *newpoly = memnew(Polygon2D);
            newpoly->set_polygon(vis_poly->get_polygon());
            newpoly->set_color(vis_poly->get_color());
            ref_node = newpoly;
        }

        if (ref_node) {
            ref_node->set_name(ref_name);
            re_cont->add_child(ref_node);
        }
    }

    if (ref_node) {
        ref_node->set_meta("last_f", frame);

        float pond_top_y = pond->get_global_position().y;
        Polygon2D *water_poly = Object::cast_to<Polygon2D>(water);
        if (water_poly) {
            float local_min_y = 0.0f;
            PackedVector2Array polys = water_poly->get_polygon();
            for (int i = 0; i < polys.size(); i++) {
                if (polys[i].y < local_min_y) local_min_y = polys[i].y;
            }
            pond_top_y += local_min_y;
        }

        float f_off = 0.0f;
        Variant v_f_off = vis->get("feet_offset");
        if (v_f_off.get_type() != Variant::NIL && v_f_off.get_type() == Variant::FLOAT) {
            f_off = v_f_off;
        }

        float vis_center_y = vis->get_global_position().y;
        ref_node->set_global_position(Vector2(vis->get_global_position().x, pond_top_y + (pond_top_y - (vis_center_y + f_off)) + f_off));
        
        CanvasItem *ref_canvas = Object::cast_to<CanvasItem>(ref_node);
        CanvasItem *vis_canvas = Object::cast_to<CanvasItem>(vis);
        
        if (ref_canvas && vis_canvas) {
            ref_canvas->set_visible(vis_canvas->is_visible());
            ref_canvas->set_modulate(Color(0.1f, 0.4f, 0.9f, 0.4f));
        }

        Line2D *vis_line = Object::cast_to<Line2D>(vis);
        Sprite2D *vis_sprite = Object::cast_to<Sprite2D>(vis);
        Polygon2D *vis_poly = Object::cast_to<Polygon2D>(vis);

        if (vis_line) {
            Line2D *ref_line = Object::cast_to<Line2D>(ref_node);
            if (ref_line) {
                ref_line->set_points(vis_line->get_points());
                ref_line->set_global_rotation(-(vis_line->get_global_rotation()));
                Vector2 s = ref_line->get_scale();
                s.y = -1;
                ref_line->set_scale(s);
            }
        } else if (vis_sprite) {
            Sprite2D *ref_sprite = Object::cast_to<Sprite2D>(ref_node);
            if (ref_sprite) {
                int max_frame = Math::max(0, ref_sprite->get_hframes() * ref_sprite->get_vframes() - 1);
                ref_sprite->set_frame(Math::clamp(vis_sprite->get_frame(), 0, max_frame));
                ref_sprite->set_flip_h(vis_sprite->is_flipped_h());
                ref_sprite->set_flip_v(!vis_sprite->is_flipped_v());
                ref_sprite->set_scale(vis_sprite->get_scale());
                ref_sprite->set_offset(vis_sprite->get_offset());
            }
        } else if (vis_poly) {
            Polygon2D *ref_poly = Object::cast_to<Polygon2D>(ref_node);
            if (ref_poly) {
                ref_poly->set_polygon(vis_poly->get_polygon());
                ref_poly->set_global_rotation(-(vis_poly->get_global_rotation()));
                Vector2 s = ref_poly->get_scale();
                s.y = -vis_poly->get_scale().y;
                ref_poly->set_scale(s);
            }
        }
    }
}

void NativeReflectionManager::_prune_old_reflections(TypedArray<Node2D> all_ponds, int frame) {
    for (int i = 0; i < all_ponds.size(); i++) {
        Node2D *pond = Object::cast_to<Node2D>(all_ponds[i]);
        if (!pond) continue;
        Node *water = pond->get_node_or_null("PondWater");
        if (!water) continue;
        Node *re_cont = water->get_node_or_null("Reflections");
        if (!re_cont) continue;

        TypedArray<Node> children = re_cont->get_children();
        for (int c = 0; c < children.size(); c++) {
            Node *ref = Object::cast_to<Node>(children[c]);
            if (ref && ref->has_meta("last_f")) {
                int last_f = ref->get_meta("last_f");
                if (last_f < frame) {
                    ref->queue_free();
                }
            }
        }
    }
}

void NativeReflectionManager::_update_node_reflection(Node2D *entity, Node2D *reflection, Node2D *pond) {
    Sprite2D *active_sprite = nullptr;

    if (entity->has_method("get_active_sprite")) {
        Variant res = entity->call("get_active_sprite");
        if (res.get_type() != Variant::NIL && res.get_type() == Variant::OBJECT) {
            active_sprite = Object::cast_to<Sprite2D>(res);
        }
    } else {
        Variant res = entity->get("sprite");
        if (res.get_type() != Variant::NIL && res.get_type() == Variant::OBJECT) {
            active_sprite = Object::cast_to<Sprite2D>(res);
        }
    }

    if (active_sprite && active_sprite->is_inside_tree() && active_sprite->is_visible_in_tree()) {
        reflection->set_visible(true);
        Sprite2D *rs = Object::cast_to<Sprite2D>(reflection->get_node_or_null("Sprite"));
        if (!rs) {
            rs = memnew(Sprite2D);
            rs->set_name("Sprite");
            reflection->add_child(rs);
        }

        float pond_surface_y = pond->get_global_position().y;
        Polygon2D *pond_water = Object::cast_to<Polygon2D>(pond->get_node_or_null("PondWater"));
        if (pond_water) {
            float local_min_y = 0.0f;
            PackedVector2Array polys = pond_water->get_polygon();
            for (int i = 0; i < polys.size(); i++) {
                if (polys[i].y < local_min_y) local_min_y = polys[i].y;
            }
            pond_surface_y += local_min_y;
        }

        reflection->set_global_position(Vector2(entity->get_global_position().x, reflection->get_global_position().y));

        float f_off = 0.0f;
        Variant v_f_off = entity->get("feet_offset");
        if (v_f_off.get_type() != Variant::NIL && v_f_off.get_type() == Variant::FLOAT) {
            f_off = v_f_off;
        }

        float vis_center_y = entity->get_global_position().y;
        float dy = pond_surface_y - (vis_center_y + f_off);
        reflection->set_global_position(Vector2(reflection->get_global_position().x, pond_surface_y + dy + f_off));

        rs->set_texture(active_sprite->get_texture());
        rs->set_hframes(active_sprite->get_hframes());
        rs->set_vframes(active_sprite->get_vframes());
        rs->set_frame(active_sprite->get_frame());
        rs->set_region_enabled(active_sprite->is_region_enabled());
        rs->set_region_rect(active_sprite->get_region_rect());
        rs->set_flip_h(active_sprite->is_flipped_h());
        rs->set_flip_v(true);
        rs->set_scale(active_sprite->get_scale());
        rs->set_modulate(Color(0.1f, 0.4f, 0.9f, 0.5f));
        rs->set_offset(active_sprite->get_offset());
    }
}
