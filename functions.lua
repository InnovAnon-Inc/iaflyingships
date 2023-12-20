local MODNAME = minetest.get_current_modname()
local msg_not_configured = string.format("This motor is not configured. Use %s"
        .. " on a ship not connected to ground and not larger then "
        .. "%d nodes.", iaflyingships.CONFIGURATOR_NODE, iaflyingships.MAX_BLOCKS_PER_SHIP)
local msg_too_large = string.format("The ship is too large! Check if it is connected to the ground,"
        .. "or decrease its size. Max ship size is %d nodes.", iaflyingships.MAX_BLOCKS_PER_SHIP)
local msg_cannot_move = "Cannot move: %s at %s"
local msg_connected = "Connected %d nodes to %s"

local meta_activated = "activated"

local function store_meta(meta, ship_nodes, move_to_nodes, rotate_to_nodes)
    meta:set_string(iaflyingships.META_CONNECTED, minetest.serialize(ship_nodes))
    meta:set_string(iaflyingships.META_BAKED_MOVE, minetest.serialize(move_to_nodes))
    meta:set_string(iaflyingships.META_BAKED_ROTATE, minetest.serialize(rotate_to_nodes))
end

local function load_meta(meta, pos, param2)
    local saved_positions = minetest.deserialize(meta:get_string(iaflyingships.META_CONNECTED))
    local baked_move_positions = minetest.deserialize(meta:get_string(iaflyingships.META_BAKED_MOVE))
    local baked_rotate_positions = minetest.deserialize(meta:get_string(iaflyingships.META_BAKED_ROTATE))

    if saved_positions and (baked_move_positions == nil or baked_rotate_positions == nil) then
        saved_positions, baked_move_positions, baked_rotate_positions =
            iaflyingships.bake_construction(pos, param2, saved_positions)
        store_meta(meta, saved_positions, baked_move_positions, baked_rotate_positions)
    end
    return saved_positions, baked_move_positions, baked_rotate_positions
end

local function is_unprotected(pos, owner)
    if pos and minetest.is_protected and minetest.is_protected(pos, owner) then
        return false, string.format(msg_cannot_move, "protected", minetest.pos_to_string(pos))
    else
        return true
    end
end

local function is_available(pos, owner)
    if not iaflyingships.is_node_empty(pos) then
        return false, string.format(msg_cannot_move, "obstructed", minetest.pos_to_string(pos))
    else
        return is_unprotected(pos, owner)
    end
end

local function boom(pos, radius)
	print('boom('..minetest.pos_to_string(pos)..', radius='..radius..')')
	if minetest.get_modpath("tnt") and tnt and tnt.boom
	and not minetest.is_protected(pos, "") then
		--local radius = 15
		local damage_radius = radius
		tnt.boom(pos, {
			radius = radius,
			damage_radius = damage_radius,
			--sound = self.sounds and self.sounds.explode,
			explode_center = true,
			tiles = {"tnt_smoke.png",},
		})
	end
end

local function collect_entities(objects, pos)
    local half_vec = vector.new(.5, .5, .5)
    for _,object in ipairs(minetest.get_objects_in_area(vector.subtract(pos, half_vec), vector.add(pos, half_vec))) do
        local entity = object:get_luaentity()
        local player_name = object:get_player_name()
        if object:is_player() or (entity and not (mesecon.is_mvps_unmov(entity.name))) then
            table.insert(objects, { entity = entity, object = object })
        end
    end
end

local function collect_near_entities(objects, list, source_rotate, origin)
    for i = 1, 6 do
        for _, close_pos in ipairs(list[i]) do
            collect_entities(
                objects,
                vector.add(source_rotate:rotate_no_scale(close_pos), origin)
            )
        end
    end
end

local function do_move(move_list, remove_list, object_list)
    -- Actually move nodes (set moved data to the new position nodes)
    for _,n in ipairs(move_list) do
        minetest.swap_node(n.pos, n.node)
        minetest.get_meta(n.pos):from_table(n.meta)
        local timer = minetest.get_node_timer(n.pos)
        if n.node_timer then
            timer:set(unpack(n.node_timer))
        else
            timer:stop()
        end
    end

    -- Remove nodes from old positions
    for _,remove_pos in pairs(remove_list) do
        minetest.swap_node(remove_pos, {name = "air"})
        minetest.get_meta(remove_pos):from_table({})
        minetest.get_node_timer(remove_pos):stop()
    end

    -- Move objects
    for _,obj_data in ipairs(object_list) do
        obj_data.object:set_pos(obj_data.new_pos)
        if obj_data.new_vel then
            obj_data.object:add_velocity(obj_data.new_vel)
        end
        if obj_data.new_look then
            obj_data.object:set_look_horizontal(obj_data.new_look)
        end
    end

    if type(mesecon) == "table" and type(mesecon.on_mvps_move) == "table" then
        for _, callback in ipairs(mesecon.on_mvps_move) do
            callback(move_list)
        end
    end
end

local function get_oposite_index(i)
    i = i - 1
    local mod = i % 2
    local r = i - mod
    return r + ((mod + 1) % 2) + 1
end

local quaternion = iaflyingships.math.quaternion

iaflyingships.get_connected_nodes = function(pos, param2)
    local list = {}

    local list_to_add = {}
    iaflyingships.add_to_table(list_to_add, pos)

    while #list_to_add > 0 do
        minetest.log("action", "Connecting nodes from " .. minetest.pos_to_string(pos))
        local just_added = {}

        for _,tpos in ipairs(list_to_add) do
            if not(iaflyingships.pos_in_table(list, tpos)) then
                iaflyingships.add_to_table(list, tpos)
                iaflyingships.add_to_table(just_added, tpos)
            end
        end

        list_to_add = {}

        if #list > iaflyingships.MAX_BLOCKS_PER_SHIP then
            return nil
        end

        for _,tpos in ipairs(just_added) do
            for i=1,#iaflyingships.DIRS do
                local npos = vector.add(tpos, iaflyingships.DIRS[i])

                local nodename = minetest.get_node(npos).name

                if nodename ~= "air" and not(iaflyingships.pos_in_table(list, npos)) then
                    iaflyingships.add_to_table(list_to_add, npos)
                end
            end
        end
    end

    if #list > 0 then
        for i, tpos in ipairs(list) do
            local t = vector.subtract(tpos, pos)
--            if param2 ~= nil then
                local q = iaflyingships.facedir_to_rotate(param2):conjugate()
                t = q:rotate_no_scale(t)
--            end
            list[i] = t
        end
        return list
    else
        return nil
    end
end

local function move_construction(
        nodes,
        no_intersect_move,
        direction_index,
        origin,
        origin_param,
        owner
        )
    local param2 = origin_param % 32
    local source_rotate = iaflyingships.facedir_to_rotate(param2)
    local direction = source_rotate:rotate_no_scale(minetest.wallmounted_to_dir(direction_index - 1))
    local new_origin = vector.add(direction, origin)
    local nodelist = {}

    -- Check for obstruction and protection
    local flag  = true
    local mymsg = nil
    local boom_pos = {}
    for _, svpos in ipairs(no_intersect_move[direction_index]) do
        local dest_pos = vector.add(source_rotate:rotate_no_scale(svpos), origin)
        local available, msg = is_available(dest_pos, owner)
        if not available then
            --return false, msg
	    flag  = false
	    mymsg = msg
	    table.insert(boom_pos, dest_pos) -- destination positions with collisions
        end
    end

    for _, svpos in ipairs(nodes) do
        local source_pos = vector.add(source_rotate:rotate_no_scale(svpos), origin)
        local unprotected, msg = is_unprotected(source_pos, owner)
        if not unprotected then
            return false, msg
        end
	if not flag then table.insert(boom_pos, source_pos) end -- source positions with collisions
        local dest_pos = vector.add(source_pos, direction)
        table.insert(nodelist, {
            pos = dest_pos,
            oldpos = source_pos
        })
    end

    if not flag then -- bye bye
	    assert(#boom_pos)
	    local minp = nil
	    local maxp = nil
	    for _, pos in ipairs(boom_pos) do
		if minp == nil then minp = vector.new(pos) end
		if maxp == nil then maxp = vector.new(pos) end
		--boom(pos)
		minp.x = math.min(minp.x, pos.x)
		minp.y = math.min(minp.y, pos.y)
		minp.z = math.min(minp.z, pos.z)
		maxp.x = math.max(maxp.x, pos.x)
		maxp.y = math.max(maxp.y, pos.y)
		maxp.z = math.max(maxp.z, pos.z)
	    end
	    local rad = vector.distance(minp, maxp)
	    --rad = math.floor(rad+0.5)
	    boom(vector.new(minp.x, minp.y, minp.z), rad)
	    boom(vector.new(minp.x, minp.y, maxp.z), rad)
	    boom(vector.new(minp.x, maxp.y, minp.z), rad)
	    boom(vector.new(minp.x, maxp.y, maxp.z), rad)
	    boom(vector.new(maxp.x, minp.y, minp.z), rad)
	    boom(vector.new(maxp.x, minp.y, maxp.z), rad)
	    boom(vector.new(maxp.x, maxp.y, minp.z), rad)
	    boom(vector.new(maxp.x, maxp.y, maxp.z), rad)
	    return flag, mymsg
    end

    -- Gather info about nodes and objects
    local remove_list = {}
    local objects = {}
    for index, move_node_entry in ipairs(nodelist) do
        local source_pos = move_node_entry.oldpos
        local node = minetest.get_node(source_pos)
        if node.name == "air" then
            table.insert(remove_list, index)
        else
            move_node_entry.node = node
            local timer = minetest.get_node_timer(source_pos)
            move_node_entry.meta = minetest.get_meta(source_pos):to_table()
            move_node_entry.node_timer = (
                timer:is_started() and { timer:get_timeout(), timer:get_elapsed() } or nil
            )
        end

        collect_entities(objects, source_pos)
    end

    collect_near_entities(objects, no_intersect_move, source_rotate, origin)

    for _,obj_data in ipairs(objects) do
        obj_data.new_pos = vector.add(obj_data.object:get_pos(), direction)
    end

    for i = #remove_list, 1, -1 do
        local remove_index = remove_list[i]
        remove_list[i] = nodelist[remove_index].pos
        table.remove(nodelist, remove_index)
    end

    local oposite_direction_index = get_oposite_index(direction_index)
    for _,svpos in ipairs(no_intersect_move[oposite_direction_index]) do
        table.insert(remove_list, vector.add(source_rotate:rotate_no_scale(svpos), new_origin))
    end

    do_move(nodelist, remove_list, objects)

    return true
end

local function move_by_motor(
    pos, direction_index, user
)
    local node = minetest.get_node(pos)
    local meta = minetest.get_meta(pos)
    local owner = meta:get_string("owner")
    local saved_positions, baked_move_positions, baked_rotate_positions = load_meta(meta, pos, node.param2)
    if saved_positions == nil then
        iaflyingships.send_message(user, msg_not_configured)
        return false
    end
    local result, msg = move_construction(
        saved_positions,
        baked_move_positions,
        direction_index,
        pos,
        node.param2,
        owner
    )

    if result then
        minetest.sound_play("move", {
            pos = pos
        })
    else
        iaflyingships.send_message(user, msg)
        minetest.sound_play("interrupted", {
            pos = pos
        })
    end
end

iaflyingships.directed_motor_on = function(pos, node)
    local meta = minetest.get_meta(pos)
    if meta:get_int(meta_activated) ~= 0 then
        return
    end

    -- TODO check fuel

    meta:set_int(meta_activated, 1)

    move_by_motor(pos, 5)
end

iaflyingships.directed_motor_off = function(pos, node)
    local meta = minetest.get_meta(pos)
    meta:set_int(meta_activated, 0)
end

iaflyingships.motor_on = function(pointed_thing, user, rear)
    if pointed_thing.type == "node" then
        local node = minetest.get_node(pointed_thing.under)
        if minetest.get_item_group(node.name, "flyingship_motor") > 0 then
            local direction = vector.subtract(pointed_thing.under, pointed_thing.above)
            local back_rotate = iaflyingships.facedir_to_rotate(node.param2):conjugate()
            local direction_index = minetest.dir_to_wallmounted(
                back_rotate:rotate_no_scale(direction)
            ) + 1

            if rear then
                direction_index = get_oposite_index(direction_index)
            end

            move_by_motor(pointed_thing.under, direction_index, user)
        end
    end
end
--[[
TODO: Try VoxelManip again
]]
local function rotate_construction(
        nodes,
        no_intersect_move,
        no_intersect_rotate,
        axis_index,
        origin,
        origin_param,
        owner
        )
    local param2 = origin_param % 32
    local source_rotate = iaflyingships.facedir_to_rotate(param2)
    local axis = minetest.wallmounted_to_dir(axis_index - 1)
    local destination_rotate = source_rotate:restricted_quaternion_multiply(
        quaternion.new(axis.x, axis.y, axis.z, 1)
    )
    local global_rotate = quaternion.new(source_rotate:rotate_no_scale(axis))
    global_rotate.w = 1
    local nodelist = {}

    -- Check for obstruction and protection
    for _, svpos in ipairs(no_intersect_rotate[axis_index]) do
        local dest_pos = vector.add(source_rotate:rotate_no_scale(svpos), origin)
        local available, msg = is_available(dest_pos, owner)
        if not available then
            return false, msg
        end
    end

    for _, svpos in ipairs(nodes) do
        local source_pos = vector.add(source_rotate:rotate_no_scale(svpos), origin)
        local unprotected, msg = is_unprotected(source_pos, owner)
        if not unprotected then
            return false, msg
        end
        local dest_pos = vector.add(destination_rotate:rotate_no_scale(svpos), origin)
        table.insert(nodelist, {
            pos = dest_pos,
            oldpos = source_pos
        })
    end

    -- Gather info about nodes and objects
    local remove_list = {}
    local objects = {}
    for index, move_node_entry in ipairs(nodelist) do
        local source_pos = move_node_entry.oldpos
        local node = minetest.get_node(source_pos)
        if node.name == "air" then
            table.insert(remove_list, index)
        else
            move_node_entry.node = node
            local nodedef = minetest.registered_nodes[node.name]
            if nodedef then
                if nodedef.paramtype2 == "facedir" or nodedef.paramtype2 == "colorfacedir" then
                    local md = node.param2 % 32
                    node.param2 = node.param2 - md + iaflyingships.rotate_facedir(global_rotate, md)
                end
                if nodedef.paramtype2 == "wallmounted" or
                    nodedef.paramtype2 == "colorwallmounted"
                then
                    local md = node.param2 % 8
                    node.param2 = node.param2 - md +
                        minetest.dir_to_wallmounted(
                            global_rotate:rotate_no_scale(minetest.wallmounted_to_dir(md))
                        )
                end
            end
            local timer = minetest.get_node_timer(source_pos)
            move_node_entry.meta = minetest.get_meta(source_pos):to_table()
            move_node_entry.node_timer = (
                timer:is_started() and { timer:get_timeout(), timer:get_elapsed() } or nil
            )
        end

        collect_entities(objects, source_pos)
    end

    collect_near_entities(objects, no_intersect_move, source_rotate, origin)

    for _,obj_data in ipairs(objects) do
        obj_data.new_pos = vector.add(
            global_rotate:rotate_no_scale(vector.subtract(
                obj_data.object:get_pos(),
                origin
            )),
            origin
        )

        obj_data.new_vel = obj_data.object:get_velocity()
        obj_data.new_vel = vector.subtract(
            global_rotate:rotate_no_scale(obj_data.new_vel),
            obj_data.new_vel
        )

        if obj_data.object:is_player() then
            local new_look
            if param2 < 4 then
                obj_data.new_look = obj_data.object:get_look_horizontal() - math.pi / 2
            elseif param2 >= 20 then
                obj_data.new_look = obj_data.object:get_look_horizontal() + math.pi / 2
            end
        end
    end

    for i = #remove_list, 1, -1 do
        local remove_index = remove_list[i]
        remove_list[i] = nodelist[remove_index].pos
        table.remove(nodelist, remove_index)
    end

    local oposite_axis_index = get_oposite_index(axis_index)
    for _,svpos in pairs(no_intersect_rotate[oposite_axis_index]) do
        table.insert(remove_list, vector.add(destination_rotate:rotate_no_scale(svpos), origin))
    end

    do_move(nodelist, remove_list, objects)

    return true
end

local function rotate_by_rotator(pos, axis_index)
    local node = minetest.get_node(pos)
    local meta = minetest.get_meta(pos)
    local owner = meta:get_string("owner")
    local saved_positions, baked_move_positions, baked_rotate_positions = load_meta(meta, pos, node.param2)
    if saved_positions == nil then
        return false, msg_not_configured
    end
    return rotate_construction(saved_positions, baked_move_positions, baked_rotate_positions, axis_index, pos, node.param2, owner, user)
end

iaflyingships.rotator_on = function(pointed_thing, user)
    if pointed_thing.type == "node" then
        local node = minetest.get_node(pointed_thing.under)
        if minetest.get_item_group(node.name, "flyingship_motor") > 0 then

	    -- TODO check fuel

            local result, msg = rotate_by_rotator(vector.new(pointed_thing.under), 1)
            if not result then
                iaflyingships.send_message(user, msg)
            end
        end
    end
end

iaflyingships.configure = function(pointed_thing, user)
    local pos = pointed_thing.under
    local meta = minetest.get_meta(pos)

    if meta:get_string("owner") ~= user:get_player_name() then
        minetest.chat_send_player(user:get_player_name(), "You are not owner of this ship")
        return itemstack
    end

    local node = minetest.get_node(pointed_thing.under)
    local ship_nodes, move_to_nodes, rotate_to_nodes = iaflyingships.bake_construction(pos, node.param2 % 32)

    local message = ""

    if ship_nodes == nil then
        message = msg_too_large
    else
meta:set_int("shipsize", #ship_nodes)
        message = string.format(msg_connected, #ship_nodes, minetest.pos_to_string(pos))
        store_meta(meta, ship_nodes, move_to_nodes, rotate_to_nodes)
    end

    minetest.chat_send_player(user:get_player_name(), message)
end

local function make_comparator(high_key, mid_key, low_key)
    return function(a, b)
        if a[high_key] == b[high_key] then
            if a[mid_key] == b[mid_key] then
                return a[low_key] < b[low_key]
            end
            return a[mid_key] < b[mid_key]
        end
        return a[high_key] < b[high_key]
    end
end

local function make_reverse_comparator(high_key, mid_key, low_key)
    return function(a, b)
        if a[high_key] == b[high_key] then
            if a[mid_key] == b[mid_key] then
                return a[low_key] > b[low_key]
            end
            return a[mid_key] > b[mid_key]
        end
        return a[high_key] > b[high_key]
    end
end

local comparators = {
    make_comparator("z", "x", "y"),
    make_reverse_comparator("z", "x", "y"),
    make_comparator("z", "y", "x"),
    make_reverse_comparator("z", "y", "x"),
    make_comparator("y", "x", "z"),
    make_reverse_comparator("y", "x", "z"),
}

iaflyingships.bake_construction = function(pos, param2, list)
    local construction_local_positions = list or iaflyingships.get_connected_nodes(pos, param2)
    if not construction_local_positions then
        return nil, nil, nil
    end
    local baked_move_positions = {}
    local baked_rotation_positions = {}
    for i = 1, 6 do
        local dir = minetest.wallmounted_to_dir(i - 1)
        local move_positions = {}
        baked_move_positions[i] = move_positions
        table.sort(construction_local_positions, comparators[i])
        for index, value in ipairs(construction_local_positions) do
            local dir_pos = vector.add(value, dir)
            local next_pos = construction_local_positions[index + 1]
            if next_pos == nil then
                local move_pos = {
                    x = dir_pos.x,
                    y = dir_pos.y,
                    z = dir_pos.z,
                }
                table.insert(move_positions, move_pos)
                break
            end
            local diff = vector.subtract(next_pos, dir_pos)
            if not vector.equals(diff, vector.zero()) then
                local move_pos = {
                    x = dir_pos.x,
                    y = dir_pos.y,
                    z = dir_pos.z,
                    freespace = vector.equals(
                        vector.multiply(diff, dir),
                        diff
                    ) and (diff.x + diff.y + diff.z)
                }
                table.insert(move_positions, move_pos)
            end
        end
    end
    for i = 1, 6 do
        local axis = minetest.wallmounted_to_dir(i - 1)
        local rotation = quaternion.new(axis.x, axis.y, axis.z, 1)
        local rotated_positions = {}
        baked_rotation_positions[i] = rotated_positions
        for index, value in ipairs(construction_local_positions) do
            local rotated_pos = rotation:rotate_no_scale(value)
            if not iaflyingships.pos_in_table(construction_local_positions, rotated_pos) then
                table.insert(rotated_positions, rotated_pos)
            end
        end
    end
    return construction_local_positions, baked_move_positions, baked_rotation_positions
end
