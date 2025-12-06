--- perception.lua
--- Spatial awareness system for AI agents in Defold.
--- Handles FOV cone checks, raycast line-of-sight, and
--- auditory event processing.

local M = {}

-- Registry of all agents for inter-agent awareness
local registered_agents = {}

--- Register an agent for perception queries.
function M.register(id, faction)
    registered_agents[id] = {
        id = id,
        faction = faction or "enemy",
        position = go.get_position(id),
        alive = true
    }
end

--- Unregister a destroyed agent.
function M.unregister(id)
    registered_agents[id] = nil
end

--- Update cached position for an agent.
function M.update_position(id)
    if registered_agents[id] then
        registered_agents[id].position = go.get_position(id)
    end
end

--- Scan for visible targets from a position.
--- @param origin vector3 Scanner position
--- @param range number Maximum sight distance
--- @param fov number Field of view in degrees
--- @param self_id hash ID of the scanning agent (excluded from results)
--- @return table { nearest_enemy, nearest_enemy_pos, nearest_enemy_dist, visible_count }
function M.scan(origin, range, fov, self_id)
    local result = {
        nearest_enemy = nil,
        nearest_enemy_pos = nil,
        nearest_enemy_dist = math.huge,
        visible_count = 0,
        visible_targets = {},
        last_noise = nil
    }

    local self_data = registered_agents[self_id]
    local self_faction = self_data and self_data.faction or "enemy"

    for id, agent in pairs(registered_agents) do
        if id == self_id or not agent.alive then
            goto continue
        end

        -- Skip same faction
        if agent.faction == self_faction then
            goto continue
        end

        local agent_pos = go.get_position(id)
        local to_agent = agent_pos - origin
        local distance = vmath.length(to_agent)

        -- Range check
        if distance > range then
            goto continue
        end

        -- FOV check
        local forward = vmath.vector3(1, 0, 0)  -- Default facing right
        local angle = math.deg(math.acos(
            vmath.dot(vmath.normalize(to_agent), forward)
        ))
        if angle > fov / 2 then
            goto continue
        end

        -- Line of sight raycast
        local ray_result = physics.raycast(origin, agent_pos, { hash("walls") })
        if ray_result then
            goto continue  -- Blocked by wall
        end

        -- Visible target found
        result.visible_count = result.visible_count + 1
        table.insert(result.visible_targets, {
            id = id,
            position = agent_pos,
            distance = distance
        })

        if distance < result.nearest_enemy_dist then
            result.nearest_enemy = id
            result.nearest_enemy_pos = agent_pos
            result.nearest_enemy_dist = distance
        end

        ::continue::
    end

    return result
end

--- Broadcast a noise event to all agents within range.
--- @param position vector3 Noise origin
--- @param loudness number Range multiplier
--- @param source_id hash ID of noise source
function M.emit_noise(position, loudness, source_id)
    for id, agent in pairs(registered_agents) do
        if id == source_id or not agent.alive then
            goto continue
        end

        local dist = vmath.length(agent.position - position)
        local hear_range = 120 * loudness

        if dist <= hear_range then
            msg.post(id, "hear_noise", { position = position })
        end

        ::continue::
    end
end

--- Mark an agent as dead (keeps in registry for corpse awareness).
function M.mark_dead(id)
    if registered_agents[id] then
        registered_agents[id].alive = false
    end
end

--- Get count of alive agents by faction.
function M.count_alive(faction)
    local count = 0
    for _, agent in pairs(registered_agents) do
        if agent.alive and (not faction or agent.faction == faction) then
            count = count + 1
        end
    end
    return count
end

return M

M.NOISE_LOW    = 0.2
M.NOISE_MEDIUM = 0.5
M.NOISE_HIGH   = 0.9

--- Returns a normalized alert level [0-1] based on stimulus intensity.
function M.alert_level(intensity)
    if intensity <= M.NOISE_LOW then return 0.0 end
    if intensity <= M.NOISE_MEDIUM then
        return (intensity - M.NOISE_LOW) / (M.NOISE_MEDIUM - M.NOISE_LOW) * 0.5
    end
    return 0.5 + (intensity - M.NOISE_MEDIUM) / (M.NOISE_HIGH - M.NOISE_MEDIUM) * 0.5
end
