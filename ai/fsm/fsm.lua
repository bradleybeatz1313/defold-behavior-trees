--- fsm.lua
--- Finite State Machine with transition guards, enter/exit hooks,
--- and history for AI agent state management.
---
--- Usage:
---   local fsm = require("ai.fsm.fsm")
---   local machine = fsm.create({
---       initial = "idle",
---       states = {
---           idle = { enter = fn, update = fn, exit = fn },
---           patrol = { ... },
---       },
---       transitions = {
---           { from = "idle", to = "patrol", guard = fn },
---       }
---   })
---   fsm.update(machine, dt, context)

local M = {}

--- Create a new FSM instance.
--- @param config table { initial, states, transitions }
--- @return table FSM instance
function M.create(config)
    local machine = {
        current = config.initial or "idle",
        previous = nil,
        states = config.states or {},
        transitions = config.transitions or {},
        history = {},
        _time_in_state = 0,
        _max_history = config.max_history or 20,
    }

    -- Call initial state's enter
    local state = machine.states[machine.current]
    if state and state.enter then
        state.enter({})
    end

    return machine
end

--- Update the current state.
--- @param machine table FSM instance
--- @param dt number Delta time
--- @param context table Shared agent context
function M.update(machine, dt, context)
    machine._time_in_state = machine._time_in_state + dt

    -- Evaluate transitions from current state
    for _, trans in ipairs(machine.transitions) do
        if trans.from == machine.current or trans.from == "*" then
            if not trans.guard or trans.guard(context, machine) then
                M.transition(machine, trans.to, context)
                return
            end
        end
    end

    -- Update current state
    local state = machine.states[machine.current]
    if state and state.update then
        state.update(dt, context)
    end
end

--- Force a state transition.
--- @param machine table FSM instance
--- @param target string Target state name
--- @param context table Shared context
function M.transition(machine, target, context)
    if target == machine.current then return end

    local old_state = machine.states[machine.current]
    local new_state = machine.states[target]

    -- Exit current
    if old_state and old_state.exit then
        old_state.exit(context)
    end

    -- Record history
    table.insert(machine.history, {
        from = machine.current,
        to = target,
        time = machine._time_in_state
    })
    if #machine.history > machine._max_history then
        table.remove(machine.history, 1)
    end

    -- Transition
    machine.previous = machine.current
    machine.current = target
    machine._time_in_state = 0

    -- Enter new
    if new_state and new_state.enter then
        new_state.enter(context)
    end
end

--- Get time spent in current state.
--- @param machine table FSM instance
--- @return number Seconds in current state
function M.time_in_state(machine)
    return machine._time_in_state
end

--- Check if machine is in a specific state.
--- @param machine table FSM instance
--- @param state_name string State to check
--- @return boolean
function M.is_in(machine, state_name)
    return machine.current == state_name
end

--- Get last N state transitions for debugging.
--- @param machine table FSM instance
--- @param count number Number of entries
--- @return table Array of {from, to, time}
function M.get_history(machine, count)
    count = count or 5
    local result = {}
    local start = math.max(1, #machine.history - count + 1)
    for i = start, #machine.history do
        table.insert(result, machine.history[i])
    end
    return result
end

return M

--- Reset FSM to a given state, calling exit/enter hooks.
function M.reset(machine, initial_state, context)
    local old = machine.states[machine.current]
    if old and old.exit then old.exit(context or {}) end
    machine.current = initial_state
    machine.previous = nil
    machine._time_in_state = 0
    machine.history = {}
    local new = machine.states[machine.current]
    if new and new.enter then new.enter(context or {}) end
end

--- Clear transition history.
function M.clear_history(machine)
    machine.history = {}
end

--- Check if transitioning to target is currently valid.
function M.can_transition(machine, target, context)
    if not machine.states[target] then return false, "unknown state" end
    for _, t in ipairs(machine.transitions) do
        if (t.from == machine.current or t.from == "*") and t.to == target then
            if not t.guard or t.guard(context, machine) then return true, "ok" end
            return false, "guard blocked"
        end
    end
    return false, "no matching transition"
end

--- Count how many times a state has been entered (from history).
function M.visit_count(machine, state_name)
    local count = 0
    for _, e in ipairs(machine.history) do
        if e.to == state_name then count = count + 1 end
    end
    return count
end

--- Total transitions recorded in history.
function M.transition_count(machine)
    return #machine.history
end

--- Update max history buffer size at runtime.
function M.set_max_history(machine, max)
    machine._max_history = max
    while #machine.history > max do table.remove(machine.history, 1) end
end

--- Validate an FSM config before creation. Returns list of error strings.
function M.validate_config(config)
    local errors = {}
    if not config.initial then table.insert(errors, "missing initial") end
    for i, t in ipairs(config.transitions or {}) do
        if not t.from then table.insert(errors, "transition["..i.."] missing from") end
        if not t.to   then table.insert(errors, "transition["..i.."] missing to")   end
    end
    return errors
end

--- Register a global callback fired on every state transition.
function M.on_transition(machine, callback)
    machine._on_transition = callback
end

--- Push current state onto a stack and transition to a new one.
--- Use M.pop_state to return to the previous state.
function M.push_state(machine, new_state, context)
    machine._state_stack = machine._state_stack or {}
    table.insert(machine._state_stack, machine.current)
    M.transition(machine, new_state, context)
end

--- Pop the last pushed state and transition back to it.
function M.pop_state(machine, context)
    if not machine._state_stack or #machine._state_stack == 0 then return end
    local prev = table.remove(machine._state_stack)
    M.transition(machine, prev, context)
end

--- Returns a table of all defined state names.
function M.state_names(machine)
    local names = {}
    for name in pairs(machine.states) do table.insert(names, name) end
    table.sort(names)
    return names
end
