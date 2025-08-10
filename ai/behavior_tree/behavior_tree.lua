--- behavior_tree.lua
--- A modular, data-driven behavior tree library for Defold.
--- Supports Selector, Sequence, Parallel, Decorator, Condition, and Action nodes.
--- Trees are defined declaratively via nested tables and compiled at init time.
---
--- Usage:
---   local bt = require("ai.behavior_tree.behavior_tree")
---   local tree = bt.selector({
---       bt.sequence({ bt.condition(is_hungry), bt.action(find_food) }),
---       bt.action(wander)
---   })
---   bt.run(tree, context)

local M = {}

-- Node status constants
M.SUCCESS = "success"
M.FAILURE = "failure"
M.RUNNING = "running"

-- ============================================================
-- Node Constructors
-- ============================================================

--- Creates a Selector node (OR logic).
--- Tries each child in order. Returns SUCCESS on first child success,
--- FAILURE only if all children fail. Returns RUNNING if any child is running.
--- @param children table Array of child nodes
--- @param name string Optional node name for debugging
--- @return table Node
function M.selector(children, name)
    return {
        type = "selector",
        name = name or "selector",
        children = children or {},
        _running_child = nil
    }
end

--- Creates a Sequence node (AND logic).
--- Runs each child in order. Returns FAILURE on first child failure,
--- SUCCESS only if all children succeed. Returns RUNNING if any child is running.
--- @param children table Array of child nodes
--- @param name string Optional node name for debugging
--- @return table Node
function M.sequence(children, name)
    return {
        type = "sequence",
        name = name or "sequence",
        children = children or {},
        _running_child = nil
    }
end

--- Creates a Parallel node.
--- Runs all children simultaneously each tick.
--- Policy determines success/failure thresholds.
--- @param children table Array of child nodes
--- @param policy string "require_one" | "require_all" (default: "require_one")
--- @return table Node
function M.parallel(children, policy, name)
    return {
        type = "parallel",
        name = name or "parallel",
        children = children or {},
        policy = policy or "require_one"
    }
end

--- Creates a Condition node.
--- Evaluates a predicate function. Returns SUCCESS if true, FAILURE if false.
--- @param predicate function fn(context) -> boolean
--- @param name string Optional name
--- @return table Node
function M.condition(predicate, name)
    return {
        type = "condition",
        name = name or "condition",
        predicate = predicate
    }
end

--- Creates an Action node.
--- Executes a function that returns SUCCESS, FAILURE, or RUNNING.
--- @param action function fn(context) -> status
--- @param name string Optional name
--- @return table Node
function M.action(action, name)
    return {
        type = "action",
        name = name or "action",
        execute = action
    }
end

--- Creates an Inverter decorator.
--- Flips SUCCESS <-> FAILURE. RUNNING passes through.
--- @param child table Single child node
--- @return table Node
function M.inverter(child, name)
    return {
        type = "inverter",
        name = name or "inverter",
        child = child
    }
end

--- Creates a Repeater decorator.
--- Runs child N times or until failure.
--- @param child table Single child node
--- @param max_count number Repeat limit (-1 for infinite)
--- @return table Node
function M.repeater(child, max_count, name)
    return {
        type = "repeater",
        name = name or "repeater",
        child = child,
        max_count = max_count or -1,
        _count = 0
    }
end

--- Creates a Cooldown decorator.
--- Prevents child from running more than once per interval.
--- @param child table Single child node
--- @param cooldown number Seconds between allowed executions
--- @return table Node
function M.cooldown(child, cooldown_time, name)
    return {
        type = "cooldown",
        name = name or "cooldown",
        child = child,
        cooldown = cooldown_time,
        _last_run = 0
    }
end

--- Creates a Random Selector.
--- Shuffles children before evaluating (non-deterministic selector).
--- @param children table Array of child nodes
--- @return table Node
function M.random_selector(children, name)
    return {
        type = "random_selector",
        name = name or "random_selector",
        children = children or {}
    }
end

-- ============================================================
-- Tree Execution
-- ============================================================

--- Runs a behavior tree node with the given context.
--- @param node table The BT node to execute
--- @param context table Shared blackboard / agent state
--- @return string Status (SUCCESS, FAILURE, or RUNNING)
function M.run(node, context)
    local node_type = node.type

    if node_type == "selector" then
        return M._run_selector(node, context)

    elseif node_type == "sequence" then
        return M._run_sequence(node, context)

    elseif node_type == "parallel" then
        return M._run_parallel(node, context)

    elseif node_type == "condition" then
        if node.predicate(context) then
            return M.SUCCESS
        else
            return M.FAILURE
        end

    elseif node_type == "action" then
        return node.execute(context)

    elseif node_type == "inverter" then
        local result = M.run(node.child, context)
        if result == M.SUCCESS then return M.FAILURE
        elseif result == M.FAILURE then return M.SUCCESS
        else return M.RUNNING end

    elseif node_type == "repeater" then
        return M._run_repeater(node, context)

    elseif node_type == "cooldown" then
        return M._run_cooldown(node, context)

    elseif node_type == "random_selector" then
        return M._run_random_selector(node, context)

    else
        print("[BT] Unknown node type: " .. tostring(node_type))
        return M.FAILURE
    end
end


function M._run_selector(node, context)
    -- Resume from running child if applicable
    local start_index = 1
    if node._running_child then
        start_index = node._running_child
    end

    for i = start_index, #node.children do
        local result = M.run(node.children[i], context)
        if result == M.RUNNING then
            node._running_child = i
            return M.RUNNING
        elseif result == M.SUCCESS then
            node._running_child = nil
            return M.SUCCESS
        end
    end

    node._running_child = nil
    return M.FAILURE
end


function M._run_sequence(node, context)
    local start_index = 1
    if node._running_child then
        start_index = node._running_child
    end

    for i = start_index, #node.children do
        local result = M.run(node.children[i], context)
        if result == M.RUNNING then
            node._running_child = i
            return M.RUNNING
        elseif result == M.FAILURE then
            node._running_child = nil
            return M.FAILURE
        end
    end

    node._running_child = nil
    return M.SUCCESS
end


function M._run_parallel(node, context)
    local success_count = 0
    local failure_count = 0

    for _, child in ipairs(node.children) do
        local result = M.run(child, context)
        if result == M.SUCCESS then
            success_count = success_count + 1
        elseif result == M.FAILURE then
            failure_count = failure_count + 1
        end
    end

    if node.policy == "require_one" then
        if success_count > 0 then return M.SUCCESS end
        if failure_count == #node.children then return M.FAILURE end
    elseif node.policy == "require_all" then
        if success_count == #node.children then return M.SUCCESS end
        if failure_count > 0 then return M.FAILURE end
    end

    return M.RUNNING
end


function M._run_repeater(node, context)
    if node.max_count > 0 and node._count >= node.max_count then
        node._count = 0
        return M.SUCCESS
    end

    local result = M.run(node.child, context)
    if result == M.FAILURE then
        node._count = 0
        return M.FAILURE
    elseif result == M.SUCCESS then
        node._count = node._count + 1
        if node.max_count > 0 and node._count >= node.max_count then
            node._count = 0
            return M.SUCCESS
        end
        return M.RUNNING
    end

    return M.RUNNING
end


function M._run_cooldown(node, context)
    local now = socket.gettime and socket.gettime() or os.clock()
    if now - node._last_run < node.cooldown then
        return M.FAILURE
    end

    local result = M.run(node.child, context)
    if result ~= M.RUNNING then
        node._last_run = now
    end
    return result
end


function M._run_random_selector(node, context)
    -- Fisher-Yates shuffle
    local indices = {}
    for i = 1, #node.children do indices[i] = i end

    for i = #indices, 2, -1 do
        local j = math.random(1, i)
        indices[i], indices[j] = indices[j], indices[i]
    end

    for _, idx in ipairs(indices) do
        local result = M.run(node.children[idx], context)
        if result ~= M.FAILURE then
            return result
        end
    end

    return M.FAILURE
end


-- ============================================================
-- Debug / Visualization
-- ============================================================

--- Returns a flat trace of the last tree execution for debugging.
--- @param node table Root node
--- @param depth number Current depth (internal)
--- @return string Formatted tree state
function M.debug_trace(node, depth)
    depth = depth or 0
    local indent = string.rep("  ", depth)
    local lines = { indent .. "[" .. node.type .. "] " .. (node.name or "?") }

    if node.children then
        for _, child in ipairs(node.children) do
            table.insert(lines, M.debug_trace(child, depth + 1))
        end
    elseif node.child then
        table.insert(lines, M.debug_trace(node.child, depth + 1))
    end

    return table.concat(lines, "\n")
end


return M

--- Always succeeds regardless of context. Useful as a selector fallback.
function M.succeed_always(name)
    return M.action(function() return M.SUCCESS end, name or "succeed_always")
end

--- Always fails. Useful for forcing selector fallthrough during prototyping.
function M.fail_always(name)
    return M.action(function() return M.FAILURE end, name or "fail_always")
end

--- Subtree reference: embeds another tree lazily via a factory function.
function M.subtree(get_tree, name)
    return { type="action", name=name or "subtree",
             execute=function(ctx) return M.run(get_tree(ctx), ctx) end }
end

--- Guard decorator: only executes child if condition passes.
function M.guard(condition, child, name)
    return { type="action", name=name or "guard",
             execute=function(ctx)
                 if condition(ctx) then return M.run(child, ctx) end
                 return M.FAILURE
             end }
end
