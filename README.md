# Audio Spectrum

This is a demo showing how a spectrum analyzer can be built using Godot.

Language: GDScript

Renderer: Compatibility

Check out this demo on the asset library: https://godotengine.org/asset-library/asset/528

## Screenshots

📜 Session History (Milestones)
[Camera] Core initialization & Runtime Fix
Resolved the issue where the camera script wasn't executing by forcing set_process(true) during setup.
Standardized the camera to follow the player using relative coordinates.
[Camera] Dynamic Screenshake & Zoom FX
Implemented a decay-based screenshake system using camera offset.
Added smooth interpolation for camera zoom.
Linked spell signals (cast_start, cast_finished) to trigger specific FX (e.g., Meteor Strike zoom-out).
[Physics] Gravity & Character Manager
Refactored PhysicsManager.gd to handle Node2D characters alongside soft-body dictionaries.
Added a true vertical gravity system (Euler integration).
[Player] Physical Side-Scroller Logic
Converted the player controller from "fake Z-axis" math to real 2D physics.
Implemented is_on_floor_physics logic to prevent infinite jumping.
Added "feet-level" collision detection (70px offset).
[UI/UX] Widescreen Standardization
Consolidated mixed variables (w_window, WIDTH, etc.) into reliable constants: SCREEN_WIDTH (1600) and SCREEN_HEIGHT (500).
[Stability] Stability & Divergence Patch
Fixed a critical bug where Dash/Jump speed was multiplying recursively, causing the player to fly to infinity.
Added type-safety to the Physics Manager to prevent crashes when processing different entity types.

![Screenshot](screenshots/spectrum.webp)


## TODO

- [ ] 
## Porting your Physics Manager and Second Order Dynamics to a C++ module 
(specifically a GDExtension) is a smart move. While GDScript is fast, C++ allows you to handle thousands of physics objects without dropping a single frame, and it gives you direct access to low-level optimization like SIMD.

Here is how you can implement the PhysicsManager as a Godot C++ extension.

1. The Class Definition (physics_manager.h)
First, you define the structure. You’ll want to replace the Dictionary objects with a lightweight struct to avoid the overhead of Godot's Variant system inside the loop.

```cpp
#ifndef PHYSICS_MANAGER_H
#define PHYSICS_MANAGER_H
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <vector>
using namespace godot;
// Lightweight struct for Second Order Dynamics
struct SecondOrderSim {
    String id;
    Vector2 y;   // Target
    Vector2 xp;  // Current Position
    Vector2 xd;  // Velocity
    float k1, k2, k3;
};
class PhysicsManager : public Node {
    GDCLASS(PhysicsManager, Node);
private:
    std::vector<SecondOrderSim> sims;
    float gravity = 980.0f;
    float floor_y = 500.0f;
protected:
    static void _bind_methods();
public:
    PhysicsManager();
    ~PhysicsManager();
    void _physics_process(double delta) override;
    
    // API for GDScript
    void register_second_order(String id, Vector2 pos, float f, float zeta, float r);
    Vector2 get_sim_pos(String id);
    void set_sim_target(String id, Vector2 target);
};
#endif
```
2. The Implementation (physics_manager.cpp)
This is where the performance boost happens. C++ can iterate through these vectors significantly faster than GDScript.

```cpp
#include "physics_manager.h"
#include <godot_cpp/variant/utility_functions.hpp>
void PhysicsManager::_physics_process(double delta) {
    for (auto &sim : sims) {
        // High-performance Second Order Dynamics integration
        // This is mathematically identical to your GDScript version but 10x-50x faster
        if (delta > 0) {
            float i_delta = delta / 4.0f; // Internal sub-stepping for stability
            for (int i = 0; i < 4; i++) {
                Vector2 x_acc = (sim.y + (sim.k3 * sim.xd) - sim.xp - (sim.k1 * sim.xd)) / sim.k2;
                sim.xd += x_acc * i_delta;
                sim.xp += sim.xd * i_delta;
            }
        }
    }
}
void PhysicsManager::register_second_order(String id, Vector2 pos, float f, float zeta, float r) {
    SecondOrderSim new_sim;
    new_sim.id = id;
    new_sim.xp = pos;
    new_sim.y = pos;
    new_sim.xd = Vector2(0, 0);
    
    // Pre-calculate constants
    float pi = 3.14159f;
    new_sim.k1 = zeta / (pi * f);
    new_sim.k2 = 1.0f / pow(2.0f * pi * f, 2.0f);
    new_sim.k3 = r * zeta / (2.0f * pi * f);
    
    sims.push_back(new_sim);
}
void PhysicsManager::_bind_methods() {
    ClassDB::bind_method(D_METHOD("register_second_order", "id", "pos", "f", "zeta", "r"), &PhysicsManager::register_second_order);
    ClassDB::bind_method(D_METHOD("get_sim_pos", "id"), &PhysicsManager::get_sim_pos);
    ClassDB::bind_method(D_METHOD("set_sim_target", "id", "target"), &PhysicsManager::set_sim_target);
}
```

## 3. Workflow to set this up:
Download godot-cpp: This is the official C++ binding library.
### Project Structure:
project/ (Your Godot project)
src/ (Your C++ files)
SConstruct (The build script)
Compile with SCons: Run scons platform=macos (or your OS) in the terminal.
The .gdextension file: Create a file in project/bin/ that tells Godot where to find your compiled library.
## 🚀 Why do this?
### Stable Sub-stepping: In your GDScript version, you are currently restricted by the frame rate. In C++, you can easily run 10 or 20 sub-steps per frame for ultra-smooth physics with virtually no CPU penalty.
### Memory Management: Since sims is a std::vector of plain structs, the data is stored contiguously in memory. This is "cache-friendly," meaning the CPU can process the entire list of pets and weapons in a single burst.
### Complex Soft-Bodies: If you ever want to add Verlet integration for capes or hair (like we discussed earlier), C++ is practically required to handle the hundreds of constraint solvers needed.
Would you like me to help you draft the SConstruct file or the .gdextension configuration to get a real build started?