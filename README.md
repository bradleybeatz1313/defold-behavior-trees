# 🌳 AI Behavior Tree System — Defold

A modular, data-driven AI framework for the Defold engine featuring a full behavior tree library, finite state machine, and spatial perception system. Designed for extensibility in AI research environments.

![Defold](https://img.shields.io/badge/Defold-1.8-orange?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PC9zdmc+)
![Lua](https://img.shields.io/badge/Lua-5.1-blue?logo=lua)
![License](https://img.shields.io/badge/license-MIT-green)

---

## 🎯 Features

### Behavior Tree Library (`ai/behavior_tree/`)
- **8 node types**: Selector, Sequence, Parallel, Condition, Action, Inverter, Repeater, Cooldown
- **Random Selector** for non-deterministic behavior variety
- **Running state memory** — Selector/Sequence resume from last running child
- **Debug tracing** — Pretty-print full tree state for development
- **Declarative API** — Trees defined as nested Lua tables, no classes or OOP boilerplate

### Finite State Machine (`ai/fsm/`)
- **Guarded transitions** — Transition predicates evaluated each tick
- **Enter/exit hooks** — State lifecycle callbacks for animation and effect triggers
- **Wildcard transitions** — `from = "*"` matches any source state
- **State history** — Ring buffer of recent transitions for debugging and replay

### Perception System (`ai/perception/`)
- **FOV cone scanning** — Configurable angle and range per agent
- **Physics raycast LOS** — Line-of-sight checks against wall collision layer
- **Auditory events** — `emit_noise()` broadcasts to agents within loudness-scaled range
- **Faction awareness** — Agents only detect opposing factions
- **Agent registry** — Centralized tracking of all AI entities for efficient spatial queries

### Agent Controller (`entities/agent.script`)
- **BT + FSM hybrid** — Behavior tree drives decisions; FSM manages state enter/exit/animation
- **Defold message passing** — `take_damage`, `set_patrol_points`, `hear_noise` messages
- **Data-driven properties** — Speed, range, health, FOV exposed as `go.property()` in editor

---

## 📂 Project Structure

```
defold-behavior-trees/
├── game.project
├── ai/
│   ├── behavior_tree/
│   │   └── behavior_tree.lua    # Full BT library
│   ├── fsm/
│   │   └── fsm.lua              # State machine module
│   └── perception/
│       └── perception.lua       # Spatial awareness
├── entities/
│   └── agent.script             # Agent game object controller
├── main/
│   └── main.collection          # Main scene
└── utils/
```

---

## 🚀 Getting Started

1. Install [Defold Editor](https://defold.com/download/)
2. Clone and open `game.project`
3. Build and run (Ctrl+B)

---

## 🧪 Design Decisions

| Decision | Rationale |
|----------|-----------|
| BT + FSM hybrid | BT handles decision priority; FSM handles animation state and lifecycle hooks |
| Lua tables as BT nodes | Zero allocation, cache-friendly, no class overhead — critical for Defold's Lua VM |
| Centralized perception registry | Avoids O(n²) per-agent scanning; registry enables efficient spatial queries |
| `goto continue` over nested ifs | Cleaner loop control in perception scans; standard Lua 5.1+ pattern |

---

## 🔬 AI Research Applications

- **Pluggable behaviors** — Swap BT subtrees at runtime for A/B testing agent strategies
- **Full telemetry** — FSM history + BT debug trace enable behavior replay and analysis
- **Deterministic evaluation** — Seed-controlled RNG in random selector for reproducible experiments
- **Lightweight runtime** — Defold's small footprint makes it viable for headless batch simulations

---

## 📄 License

MIT

---

## Integration Guide

1. Copy `ai/` into your Defold project root.
2. Require the modules: `local bt = require("ai.behavior_tree.behavior_tree")`
3. Build a tree in `init()`, call `bt.run(tree, context)` each `update()`.
4. Pass a shared **context table** (blackboard) through all nodes.
