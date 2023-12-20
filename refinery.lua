local MODNAME = minetest.get_current_modname()
--File name: init.lua
--Project name: Biofuel, a Mod for Minetest
--License: General Public License, version 3 or later
--Original Work Copyright (C) 2016 cd2 (cdqwertz) <cdqwertz@gmail.com>
--Modified Work Copyright (C) 2017 Vitalie Ciubotaru <vitalie at ciubotaru dot tk>
--Modified Work Copyright (C) 2018 - 2023 Lokrates
--Modified Work Copyright (C) 2018 naturefreshmilk
--Modified Work Copyright (C) 2019 OgelGames
--Modified Work Copyright (C) 2020 6r1d
--Modified Work Copyright (C) 2021 nixnoxus


-- Load support for MT game translation.
local S = minetest.get_translator("iaflyingships")
--local plants_input = tonumber(minetest.settings:get("biomass_input")) or 1		-- The number of biomass required for fuel production (settingtypes.txt)

-- hopper compat
if minetest.get_modpath("hopper") then
	hopper:add_container({
		--{"top", "iaflyingships:frame_motor_directed", "dst"},
		{"bottom", "iaflyingships:frame_motor_directed", "src"},
		{"side", "iaflyingships:frame_motor_directed", "src"},
		--{"top", "iaflyingships:frame_rotator", "dst"},
		{"bottom", "iaflyingships:frame_rotator", "src"},
		{"side", "iaflyingships:frame_rotator", "src"},
	})
end


-- pipeworks compat
local has_pipeworks = minetest.get_modpath("pipeworks")
local tube_entry = ""

if has_pipeworks then
	tube_entry = "^pipeworks_tube_connection_metallic.png"
end


local function formspec(pos)
	local spos = pos.x..','..pos.y..','..pos.z
	local formspec =
		'size[8,8.5]'..
		default.gui_bg..
		default.gui_bg_img..
		default.gui_slots..
		'list[nodemeta:'..spos..';src;0.5,0.5;3,3;]'..
		--'list[nodemeta:'..spos..';dst;5,1;2,2;]'..
		'list[current_player;main;0,4.25;8,1;]'..
		'list[current_player;main;0,5.5;8,3;8]'..
		--'listring[nodemeta:'..spos ..';dst]'..
		'listring[current_player;main]'..
		'listring[nodemeta:'..spos ..';src]'..
		'listring[current_player;main]'..
		default.get_hotbar_bg(0, 4.25)
	return formspec
end


local function swap_node(pos, name)
	local node = minetest.get_node(pos)
	if node.name == name then
		return
	end
	node.name = name
	minetest.swap_node(pos, node)
end

local function count_input(pos)
	local q = 0
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local stacks = inv:get_list('src')
	for k in pairs(stacks) do
		q = q + inv:get_stack('src', k):get_count()
	end
	return q
end

--local function count_output(pos)
--	local q = 0
--	local meta = minetest.get_meta(pos)
--	local inv = meta:get_inventory()
--	local stacks = inv:get_list('dst')
--	for k in pairs(stacks) do
--		q = q + inv:get_stack('dst', k):get_count()
--	end
--	return q
--end

local function is_empty(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local stacks = inv:get_list('src')
	for k in pairs(stacks) do
		if not inv:get_stack('src', k):is_empty() then
			return false
		end
	end
	--stacks = inv:get_list('dst')
	--for k in pairs(stacks) do
	--	if not inv:get_stack('dst', k):is_empty() then
	--		return false
	--	end
	--end
	return true
end

--local function update_nodebox(pos)
--	if is_empty(pos) then
--		swap_node(pos, "iaflyingships:frame_motor_directed")
--	else
--		swap_node(pos, "iaflyingships:frame_rotator")
--	end
--end


--local refinery_time = minetest.settings:get("fuel_consumption_time") or 10 		-- Timebase (settingtypes.txt)
local refinery_time = minetest.settings:get("fuel_consumption_time") or 1 		-- Timebase (settingtypes.txt)
--local refinery_factor = minetest.settings:get("fuel_consumption_factor") or 5 		-- Timebase (settingtypes.txt)
local refinery_factor = minetest.settings:get("fuel_consumption_factor") or 1 		-- Timebase (settingtypes.txt)
local function update_timer(pos)
	local timer = minetest.get_node_timer(pos)
	local meta = minetest.get_meta(pos)
	--local has_output_space = (4 * 99) > count_output(pos)
	--if not has_output_space then
	--	if timer:is_started() then
	--		timer:stop()
	--		meta:set_string('infotext', S("Output is full "))
	--		meta:set_int('progress', 0)
	--	end
	--	return
	--end
	local count = count_input(pos)
	local plants_input = meta:get_int("shipsize")
	if not timer:is_started() and count >= plants_input then        	  			-- Input
		timer:start((refinery_time)/refinery_factor)   											-- Timebase
		--timer:start(refinery_time)   											-- Timebase
		meta:set_int('progress', 0)
		meta:set_string('infotext', S("progress: @1%", "0"))
		return
	end
	if timer:is_started() and count < plants_input then     		        		-- Input
		timer:stop()
		meta:set_string('infotext', S("To start locomotion add fuel"))
		meta:set_int('progress', 0)
	end
end

local function create_biofuel(pos)
	--local dirt_count = count_output(pos)
	local meta = minetest.get_meta(pos)
	local plants_input = meta:get_int("shipsize")
	local q = plants_input															-- Input
	local inv = meta:get_inventory()
	local stacks = inv:get_list('src')
	for k in pairs(stacks) do
		local stack = inv:get_stack('src', k)
		if not stack:is_empty() then
			local count = stack:get_count()
			if count <= q then
				inv:set_stack('src', k, '')
				q = q - count
			else
				inv:set_stack('src', k, stack:get_name() .. ' ' .. (count - q))
				q = 0
				break
			end
		end
	end
	--stacks = inv:get_list('dst')
	--for k in pairs(stacks) do
	--	local stack = inv:get_stack('dst', k)
	--	local count = stack:get_count()
	--	if 99 > count then
	--		if bottle_output then
	--			inv:set_stack('dst', k, 'biofuel:bottle_fuel ' .. (count + 1))
	--		else
	--			inv:set_stack('dst', k, 'biofuel:phial_fuel ' .. (count + 1))
	--		end
	--		break
	--	end
	--end
	-- TODO fly
	local pointed_thing = {type="node", under=pos, above=pos}
        local clicker       = meta:get_string("owner")
	local node          = minetest.get_node(pos)
	local name          = node.name
	if     name == 'iaflyingships:frame_motor_directed'   then
		iaflyingships.motor_on(pointed_thing, clicker, false)
	elseif name == 'iaflyingships:frame_rotator' then
		iaflyingships.rotator_on(pointed_thing, clicker)
	else assert(false) end
end

--local refinery_time = minetest.settings:get("fuel_production_time") or 10 		-- Timebase (settingtypes.txt)
local function on_timer(pos)
	--print('on timer')
	local timer = minetest.get_node_timer(pos)
	local meta = minetest.get_meta(pos)
	local plants_input = meta:get_int("shipsize")

	local flag = count_input(pos) -->= plants_input*2

	local progress = meta:get_int('progress') + (100/refinery_factor)  							--Progresss in %
	--local progress = meta:get_int('progress') + 100 							--Progresss in %
	if progress >= 100 then
		progress = progress - 100
		if flag >= plants_input*2 then
			--assert(progress > 0)
			meta:set_string('infotext', S("progress: @1%", progress))
			meta:set_int('progress', progress)
			minetest.get_node_timer(pos):start((refinery_time)/refinery_factor)
			--minetest.get_node_timer(pos):start(refinery_time)
		else
			meta:set_string('infotext', S("To start locomotion add fuel"))
			meta:set_int('progress', 0)
		end

		create_biofuel(pos)

		timer:stop()
		return false
	else
		meta:set_int('progress', progress)
	end
	--if (4 * 99) <= count_output(pos) then
	--	timer:stop()
	--	meta:set_string('infotext', S("Output is full "))
	--	meta:set_int('progress', 0)
	--	return false
	--end
	--local plants_input = meta:get_int("shipsize")
	if flag >= plants_input then									--Input
		meta:set_string('infotext', S("progress: @1%", progress))
		return true
	else
		timer:stop()
		meta:set_string('infotext', S("To start locomotion add fuel"))
		meta:set_int('progress', 0)
		return false
	end
end

local function on_construct(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	inv:set_size('src', 9)                                     					-- Input Fields
	--inv:set_size('dst', 4)                                     					-- Output Fields
	meta:set_string('infotext', S("To start locomotion add fuel "))
	meta:set_int('progress', 0)
end

local function on_rightclick(pos, node, clicker, itemstack)
	minetest.show_formspec(
		clicker:get_player_name(),
		-- TODO
		'iaflyingships:motor',
		formspec(pos)
	)
end
local function flying_rightclick(pos, node, clicker, itemstack, pointed_thing)
    if itemstack:get_name() == iaflyingships.CONFIGURATOR_NODE then
    	iaflyingships.configure(pointed_thing, clicker)
	return itemstack
    end
    on_rightclick(pos, node, clicker, itemstack)
    return itemstack
end

local function can_dig(pos,player)

	if player and player:is_player() and minetest.is_protected(pos, player:get_player_name()) then
		-- protected
		return false
	end

	local meta = minetest.get_meta(pos)
	local inv  = meta:get_inventory()
	if inv:is_empty('src') --and inv:is_empty('dst')
		then
		return true
	else
		return false
	end
end

local function is_convertible(item_name)
	--local fuel_item = inv:remove_item("fuel", fuel_item)
	local burn = minetest.get_craft_result({method="fuel",width=1,items={item_name}})
	--fuel_time = fuel_time + burn.time
	return burn ~= nil and burn.time >= 99
	--if minetest.get_item_group(item_name, "biofuel") > 0 then
	--	return true
	--end
	--return false
end

local tube = {
	insert_object = function(pos, node, stack, direction)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		local convertible = is_convertible(stack:get_name())
		if not convertible then
			return stack
		end

		local result = inv:add_item("src", stack)
		update_timer(pos)
		--update_nodebox(pos)
		return result
	end,
	can_insert = function(pos, node, stack, direction)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		stack = stack:peek_item(1)

		return is_convertible(stack:get_name()) and inv:room_for_item("src", stack)
	end,
	--input_inventory = "dst",
	connect_sides = {left = 1, right = 1, back = 1, front = 1, bottom = 1, top = 1}
}


local function allow_metadata_inventory_take(pos, listname, index, stack, player)
	if player and player:is_player() and minetest.is_protected(pos, player:get_player_name()) then
		-- protected
		return 0
	end

	return stack:get_count()
end

local function allow_metadata_inventory_put(pos, listname, index, stack, player)

	if player and player:is_player() and minetest.is_protected(pos, player:get_player_name()) then
		-- protected
		return 0
	end

	if listname == 'src' and is_convertible(stack:get_name()) then
		return stack:get_count()
	else
		return 0
	end
end

local function on_metadata_inventory_put(pos, listname, index, stack, player)
	update_timer(pos)
	--update_nodebox(pos)
	minetest.log('action', player:get_player_name() .. " moves stuff to motor at " .. minetest.pos_to_string(pos))
	return
end

local function on_metadata_inventory_take(pos, listname, index, stack, player)
	update_timer(pos)
	--update_nodebox(pos)
	minetest.log('action', player:get_player_name() .. " takes stuff from motor at " .. minetest.pos_to_string(pos))
	return
end

local function allow_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)

	if player and player:is_player() and minetest.is_protected(pos, player:get_player_name()) then
		-- protected
		return 0
	end

	local inv = minetest.get_meta(pos):get_inventory()
	if from_list == to_list then
		return inv:get_stack(from_list, from_index):get_count()
	else
		return 0
	end
end



minetest.register_node("iaflyingships:frame_motor_directed", {
    description = "Flying Ship directed motor",
    tiles = {"flyingships_arrow.png^[transformR90", "flyingships_gear.png", "flyingships_gear.png",
             "flyingships_gear.png", "flyingships_gear.png", "flyingships_gear.png"},
    groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2,mesecon=2,flyingship_motor=1},
    paramtype2 = "facedir",
    mesecons={effector={action_on=iaflyingships.directed_motor_on, action_off=iaflyingships.directed_motor_off}},

    after_place_node = function(pos, placer, itemstack)
        local meta = minetest.get_meta(pos)
        meta:set_string("owner", placer:get_player_name())
    end,

--on_timer = function(pos)
--	local pointed_thing = {type="node", under=pos, above=pos}
--	local meta          = minetest.get_meta(pos)
 --       local clicker       = meta:get_string("owner")
--	minetest.get_node_timer(pos):start(5)
--	--if math.random() < 0.1 then
 --       --	iaflyingships.rotator_on(pointed_thing, clicker)
--	--else
--		iaflyingships.motor_on(pointed_thing, clicker, false)
--	--end
--end,
	
	on_timer = on_timer,
	on_construct = on_construct,
	on_rightclick = flying_rightclick,
	can_dig = can_dig,
	tube = tube,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take,
	on_metadata_inventory_put = on_metadata_inventory_put,
	on_metadata_inventory_take = on_metadata_inventory_take,
})

minetest.register_node("iaflyingships:frame_rotator", {
    description = "Flying Ship Rotator",
    tiles = {"flyingships_gear.png", "flyingships_gear.png", "flyingships_arrow.png^[transformFX",
             "flyingships_arrow.png^[transformFX", "flyingships_arrow.png^[transformFX",
             "flyingships_arrow.png^[transformFX"},
    groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2,mesecon=2,flyingship_motor=1},
    paramtype2 = "facedir",

    after_place_node = function(pos, placer, itemstack)
        local meta = minetest.get_meta(pos)
        meta:set_string("owner", placer:get_player_name())
    end,

	on_timer = on_timer,
	on_construct = on_construct,
	on_rightclick = flying_rightclick,
	can_dig = can_dig,
	tube = tube,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take,
	on_metadata_inventory_put = on_metadata_inventory_put,
	on_metadata_inventory_take = on_metadata_inventory_take,
})
