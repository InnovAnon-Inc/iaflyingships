--local MODNAME = minetest.get_current_modname()
local current_mod_name = minetest.get_current_modname()

iaflyingships = {}

iaflyingships.META_CONNECTED = "conn_node"
iaflyingships.META_BAKED_MOVE = "move_bake"
iaflyingships.META_BAKED_ROTATE = "rotate_bake"
iaflyingships.DIRS = {{x=0,y=1,z=0},{x=0,y=0,z=1},{x=0,y=0,z=-1},{x=1,y=0,z=0},{x=-1,y=0,z=0},{x=0,y=-1,z=0}}

iaflyingships.MAX_BLOCKS_PER_SHIP = minetest.setting_get("iaflyingships.max_blocks_per_ship")
if iaflyingships.MAX_BLOCKS_PER_SHIP == nil then
    iaflyingships.MAX_BLOCKS_PER_SHIP = 4000
    --iaflyingships.MAX_BLOCKS_PER_SHIP = 32000
end

iaflyingships.CONFIGURATOR_NODE = core.settings:get("iaflyingships.configurator")
if iaflyingships.CONFIGURATOR_NODE == nil then
    iaflyingships.CONFIGURATOR_NODE = "default:mese_crystal_fragment"
end



dofile(minetest.get_modpath(current_mod_name) .. "/math.lua")
dofile(minetest.get_modpath(current_mod_name) .. "/util.lua")
dofile(minetest.get_modpath(current_mod_name) .. "/functions.lua")
dofile(minetest.get_modpath(current_mod_name) .. "/refinery.lua")
dofile(minetest.get_modpath(current_mod_name) .. "/craft.lua")
