local MODNAME = minetest.get_current_modname()
minetest.register_craft({
    output = "iaflyingships:frame_motor",
    recipe = {
        {"mesecons:mesecon", "mesecons_materials:glue", "mesecons:mesecon"},
        {"mesecons:mesecon", "default:copperblock", "mesecons:mesecon"},
        {"mesecons:mesecon", "mesecons_materials:glue", "mesecons:mesecon"}
    }
})

minetest.register_craft({
    output = "iaflyingships:frame_motor_directed",
    recipe = {
        {"mesecons:mesecon", "mesecons_materials:glue", "mesecons:mesecon"},
        {"mesecons:mesecon", "default:goldblock", "mesecons:mesecon"},
        {"mesecons:mesecon", "mesecons_materials:glue", "mesecons:mesecon"}
    }
})

minetest.register_craft({
    output = "iaflyingships:frame_rotator",
    recipe = {
        {"mesecons:mesecon", "mesecons:mesecon", "mesecons:mesecon"},
        {"mesecons_materials:glue", "default:goldblock", "mesecons_materials:glue"},
        {"mesecons:mesecon", "mesecons:mesecon", "mesecons:mesecon"}
    }
})
