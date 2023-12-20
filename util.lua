local MODNAME = minetest.get_current_modname()
local function same_pos(pos1, pos2)
    return pos1.x == pos2.x and pos1.y == pos2.y and pos1.z == pos2.z
end

iaflyingships.pos_in_table = function(t, value)
    for k,v in ipairs(t) do
        if same_pos(v, value) then
            return true
        end
    end
    return false
end

iaflyingships.add_to_table = function(t, value)
    table.insert(t, value)
end

iaflyingships.remove_from_table = function(t, value)
    for k,v in ipairs(t) do
        if same_pos(v, value) then
            table.remove(t, k)
            break
        end
    end
end

iaflyingships.is_node_empty = function(pos)
    local name = minetest.get_node(pos).name
    if (name~="air" and minetest.registered_nodes[name].liquidtype=="none") then
        return false
    end

    return true
end

iaflyingships.send_message = function(user, msg)
    if user then
        --minetest.chat_send_player(user:get_player_name(), msg)
        minetest.chat_send_player(user, msg)
    end
end

do
    local quaternion = iaflyingships.math.quaternion
    local param_rotations = {}
    local function qhash(quat)
        if quat.w < 0 then
            quat = -quat
        end
        local result = 0
        if quat.x < 0 then
            result = result + 2
        elseif quat.x > 0 then
            result = result + 1
        end
        result = result * 3
        if quat.y < 0 then
            result = result + 2
        elseif quat.y > 0 then
            result = result + 1
        end
        result = result * 3
        if quat.z < 0 then
            result = result + 2
        elseif quat.z > 0 then
            result = result + 1
        end
        result = result * 2
        if quat.w > 0 then
            result = result + 1
        end
        return result
    end
    do
        local baseRots = {
            quaternion.new(0, 0, 0, 1),
            quaternion.new(1, 0, 0, 1),
            quaternion.new(-1, 0, 0, 1),
            quaternion.new(0, 0, -1, 1),
            quaternion.new(0, 0, 1, 1),
            quaternion.new(0, 0, 1, 0),
        }
        local locRots = {
            quaternion.new(0, 0, 0, 1),
            quaternion.new(0, 1, 0, 1),
            quaternion.new(0, 1, 0, 0),
            quaternion.new(0, -1, 0, 1),
        }

        for i = 0, 23 do
            local quat = baseRots[math.floor(i / 4) + 1]:restricted_quaternion_multiply(
                locRots[(i % 4) + 1]
            )
            param_rotations[i + 1] = quaternion.new(quat)
            param_rotations[qhash(quat) + 24] = i
        end
    end

    iaflyingships.facedir_to_rotate = function(param2)
        return quaternion.new(param_rotations[param2 + 1])
    end

    iaflyingships.rotate_to_facedir = function(quat)
        local result = param_rotations[qhash(quat) + 24]
        if result == nil then
            result = param_rotations[qhash(-quat) + 24]
        end
        return result
    end

    iaflyingships.rotate_facedir = function(quat, param2)
        local p = iaflyingships.facedir_to_rotate(param2)
        p = quat * p
        local result = iaflyingships.rotate_to_facedir(p)
        return result
    end
end
