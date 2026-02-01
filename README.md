# Godot Experiments: Audio-Driven Combat Demo

A polished Godot 4 experiment combining real-time audio spectrum analysis with a physics-driven combat system. This project features custom gravity, screenshake, dynamic zoom, and a complete state-machine based player controller.

![Screenshot](screenshots/spectrum.webp)

## 🚀 Features
- **Real-time Audio Spectrum**: Visualizes audio frequencies into dynamic background bars.
- **Custom Physics Manager**: Verlet-integration based soft bodies and a custom gravity system for characters.
- **Dynamic Game Camera**: Features lerped following, additive screenshake, and ability-based zoom (e.g., meteor strike zoom-out).
- **Advanced Player Controller**: Multi-state animations (Idle, Run, Jump, Dash, Attack, Cast) using region-cached spritesheets.

---

## 💻 Installation Guide (macOS)

### 1. Download Godot Engine
This project is optimized for **Godot v4.2.1.stable.official [b09f793f5]**.

1.  Visit the [Godot Download Archive](https://godotengine.org/download/archive/4.2.1-stable/).
2.  Download the **Godot_v4.2.1-stable_macos.universal.zip**.
3.  Extract the ZIP file and move the `Godot` app to your `/Applications` folder.

### 2. Clone/Download the Repository
If you haven't already, clone this repository to your local machine:
```bash
git clone <your-repo-url>
```
Or simply ensure the `godot-experiments/` folder is placed in your desired workspace.

### 3. Import the Project
1.  Open **Godot 4.2.1**.
2.  In the Project Manager, click the **Import** button on the right.
3.  Navigate to your `godot-experiments/` folder.
4.  Select the `project.godot` file and click **Open**.
5.  Click **Import & Edit**.

---

## 🔊 Audio Configuration
To see the spectrum bars moving, Godot needs a **Spectrum Analyzer** effect on the main audio bus:

1.  At the bottom of the Godot Editor, click the **Audio** tab.
2.  Locate the **Master** bus.
3.  In the right-hand panel (Effects), ensure there is an **AudioEffectSpectrumInstance** at **Index 0**.
    *   *Note: This is already configured in `default_bus_layout.tres`, but check here if bars aren't moving.*

---

## 🎮 Controls
| Action | Keybind |
| :--- | :--- |
| **Move Left / Right** | `A` / `D` |
| **Jump** | `Space` |
| **Shoulder Dash** | `Z` |
| **Sword Attack** | `4` |
| **Chain Lightning** | `3` |
| **Fire Chains** | `F` |
| **Meteor Strike** | `R` |
| **Toggle Mouse Aim**| `Right Click` (Hold) |

---

## 🛠 Project Structure
- `physics_manager.gd`: The core engine for gravity and floor collisions.
- `game_camera.gd`: Handles the complex screenshake and zoom logic.
- `player_controller.gd`: The brain of the main character's movement and animations.
- `show_spectrum.gd`: The main world logic where audio interacts with the environment.

---
**Happy Coding!** 🎙️⚔️
