local tnt_tables = {["bettertnt:tnt1"] = {r=1},
					["bettertnt:tnt2"] = {r=2},
					["bettertnt:tnt3"] = {r=4},
					["bettertnt:tnt4"] = {r=6},
					["bettertnt:tnt5"] = {r=8},
					["bettertnt:tnt6"] = {r=10},
					["bettertnt:tnt7"] = {r=12},
					["bettertnt:tnt8"] = {r=14},
					["bettertnt:tnt9"] = {r=16},
					["bettertnt:tnt10"] = {r=18},}


local function drop_item(pos, nodename, player)
        local drop = minetest.get_node_drops(nodename)

        for _,item in ipairs(drop) do
                    if type(item) == "string" then
                            local obj = minetest.env:add_item(pos, item)
                            if obj == nil then
                                    return
                            end
                            obj:get_luaentity().collect = true
                            obj:setacceleration({x=0, y=-10, z=0})
                            obj:setvelocity({x=math.random(0,6)-3, y=10, z=math.random(0,6)-3})
                    else
                            for i=1,item:get_count() do
                                    local obj = minetest.env:add_item(pos, item:get_name())
                                    if obj == nil then
                                            return
                                    end
                                    obj:get_luaentity().collect = true
                                    obj:setacceleration({x=0, y=-10, z=0})
                                    obj:setvelocity({x=math.random(0,6)-3, y=10, z=math.random(0,6)-3})
                            end
                    end
            end
end

local function destroy(pos, player)
        local nodename = minetest.get_node(pos).name
        local p_pos = area:index(pos.x, pos.y, pos.z)
        if nodes[p_pos] ~= tnt_c_air then
                if minetest.registered_nodes[nodename].groups.flammable ~= nil then
                        nodes[p_pos] = tnt_c_fire
                        return
                end
                nodes[p_pos] = tnt_c_air
                if pr:next(1,3) == 3
                or not tnt_preserve_items then
                        return
                end
        end
        drop_item(pos, nodename, player)
end

local function is_tnt(id)
	for i=1, #tnt_c_tnt do
		if tnt_c_tnt[i]==id then
			return true
		end
	end
	return false
end

local function combine_texture(texture_size, frame_count, texture, ani_texture)
        local l = frame_count
        local px = 0
        local combine_textures = ":0,"..px.."="..texture
        while l ~= 0 do
                combine_textures = combine_textures..":0,"..px.."="..texture
                px = px+texture_size
                l = l-1
        end
        return ani_texture.."^[combine:"..texture_size.."x"..texture_size*frame_count..":"..combine_textures.."^"..ani_texture
end

local animated_tnt_texture = combine_texture(16, 4, "default_tnt_top.png", "bettertnt_top_burning_animated.png")
	
tnt_c_tnt = {}
tnt_c_tnt_burning = {}
tnt_types_int = {}

for name,data in pairs(tnt_tables) do
	
	tnt_types_int[#tnt_types_int] = name

	minetest.register_node(name, {
		description = "TNT ("..name..")",
		tiles = {"default_tnt_top.png", "default_tnt_bottom.png", "default_tnt_side.png"},
		groups = {dig_immediate=2, mesecon=2},
		sounds = default.node_sound_wood_defaults(),
		
		on_punch = function(pos, node, puncher)
			if puncher:get_wielded_item():get_name() == "default:torch" then
				minetest.sound_play("bettertnt_ignite", {pos=pos})
				boom(pos, 4, puncher)
				minetest.set_node(pos, {name=name.."_burning"})
			end
		end,
		
		mesecons = {
			effector = {
				action_on = function(pos, node)
					boom(pos, 0)
				end
			},
		},
	})
	
	minetest.register_node(name.."_burning", {
	        tiles = {{name=animated_tnt_texture, animation={type="vertical_frames", aspect_w=16, aspect_h=16, length=1}},
	        "default_tnt_bottom.png", "default_tnt_side.png"},
	        light_source = 5,
	        drop = "",
	        sounds = default.node_sound_wood_defaults(),
	})
	
	local prev = "bettertnt:tnt"..tonumber(strs:rem_from_start(name, "bettertnt:tnt"))-1
	if prev=="bettertnt:tnt0" then prev="" end
	--print(name .. " is made from " .. prev)
	
	minetest.register_craft({
		output = name,
		recipe = {
			{"",					"bettertnt:gunpowder",			""						},
			{"bettertnt:gunpowder",	prev,							"bettertnt:gunpowder"	},
			{"",					"bettertnt:gunpowder",			""						}
		}
	})
	
	tnt_c_tnt[#tnt_c_tnt] = minetest.get_content_id(name)
	tnt_c_tnt_burning[#tnt_c_tnt_burning] = minetest.get_content_id(name.."_burning")

end


local function get_tnt_random(pos)
        return PseudoRandom(math.abs(pos.x+pos.y*3+pos.z*5)+15)
end





function boom(pos, time, player)
	local id = minetest.get_node(pos).name
	boom_id(pos, time, player, id)
end

function boom_id(pos, time, player, id)
	minetest.after(time, function(pos)
		
		local tnt_range = tnt_tables[id].r
	
		local t1 = os.clock()
		pr = get_tnt_random(pos)
		minetest.sound_play("bettertnt_explode", {pos=pos, gain=1.5, max_hear_distance=tnt_range*64})
		
		local manip = minetest.get_voxel_manip()
		local width = tnt_range
		local emerged_pos1, emerged_pos2 = manip:read_from_map({x=pos.x-width, y=pos.y-width, z=pos.z-width},
		{x=pos.x+width, y=pos.y+width, z=pos.z+width})
		area = VoxelArea:new{MinEdge=emerged_pos1, MaxEdge=emerged_pos2}
		nodes = manip:get_data()
		
		local p_pos = area:index(pos.x, pos.y, pos.z)
		nodes[p_pos] = tnt_c_air
		minetest.add_particle(pos, {x=0,y=0,z=0}, {x=0,y=0,z=0}, 0.5, 16, false, "bettertnt_boom.png")
		--minetest.set_node(pos, {name="tnt:boom"})
		
		local objects = minetest.get_objects_inside_radius(pos, 7)
		for _,obj in ipairs(objects) do
			if obj:is_player() or (obj:get_luaentity() and obj:get_luaentity().name ~= "__builtin:item") then
				local obj_p = obj:getpos()
				local vec = {x=obj_p.x-pos.x, y=obj_p.y-pos.y, z=obj_p.z-pos.z}
				local dist = (vec.x^2+vec.y^2+vec.z^2)^0.5
				local damage = (80*0.5^dist)*2
				obj:punch(obj, 1.0, {
					full_punch_interval=1.0,
					damage_groups={fleshy=damage},
				}, vec)
			end
		end
		
		for dx=-tnt_range,tnt_range do
			for dz=-tnt_range,tnt_range do
				for dy=tnt_range,-tnt_range,-1 do
					local p = {x=pos.x+dx, y=pos.y+dy, z=pos.z+dz}
					
					local p_node = area:index(p.x, p.y, p.z)
					local d_p_node = nodes[p_node]
					local node = minetest.get_node(p)
--					if d_p_node == tnt_c_tnt
--							or d_p_node == tnt_c_tnt_burning then
					if is_tnt(d_p_node)==true then
						--nodes[p_node] = tnt_c_tnt
						boom({x=p.x, y=p.y, z=p.z}, 0, player)
					elseif not ( d_p_node == tnt_c_fire
							or string.find(node.name, "default:water_")
							or string.find(node.name, "default:lava_")) then
						if math.abs(dx)<tnt_range and math.abs(dy)<tnt_range and math.abs(dz)<tnt_range then
							destroy(p, player)
						elseif pr:next(1,5) <= 4 then
								destroy(p, player)
						end
					end
					
				end
			end
			
		end
		
		minetest.add_particlespawner(
			3000, --amount
			4, --time
			{x=pos.x-3, y=pos.y-3, z=pos.z-3}, --minpos
			{x=pos.x+3, y=pos.y+3, z=pos.z+3}, --maxpos
			{x=-0, y=-0, z=-0}, --minvel
			{x=0, y=0, z=0}, --maxvel
			{x=-0.5,y=5,z=-0.5}, --minacc
			{x=0.5,y=5,z=0.5}, --maxacc
			0.1, --minexptime
			1, --maxexptime
			8, --minsize
			15, --maxsize
			true, --collisiondetection
			"bettertnt_smoke.png" --texture
		)
		manip:set_data(nodes)
		manip:write_to_map()
		print(string.format("[tnt] exploded in: %.2fs", os.clock() - t1))
		local t1 = os.clock()
		manip:update_map()
		print(string.format("[tnt] map updated after: %.2fs", os.clock() - t1))
	end, pos)
end



---------------------  GUNPOWDER  -------------------


function burn(pos, player)
        local nodename = minetest.get_node(pos).name
        if  strs:starts(nodename, "bettertnt:tnt") then
                minetest.sound_play("bettertnt_ignite", {pos=pos})
                boom(pos, 1, player)
                minetest.set_node(pos, {name=minetest.get_node(pos).name.."_burning"})
                return
        end
        if nodename ~= "bettertnt:gunpowder" then
                return
        end
        minetest.sound_play("bettertnt_gunpowder_burning", {pos=pos, gain=2})
        minetest.set_node(pos, {name="bettertnt:gunpowder_burning"})
        
        minetest.after(1, function(pos)
                if minetest.get_node(pos).name ~= "bettertnt:gunpowder_burning" then
                        return
                end
                minetest.after(0.5, function(pos)
                        minetest.remove_node(pos)
                end, {x=pos.x, y=pos.y, z=pos.z})
                for dx=-1,1 do
                        for dz=-1,1 do
                                for dy=-1,1 do
                                        pos.x = pos.x+dx
                                        pos.y = pos.y+dy
                                        pos.z = pos.z+dz
                                        
                                        if not (math.abs(dx) == 1 and math.abs(dz) == 1) then
                                                if dy == 0 then
                                                        burn({x=pos.x, y=pos.y, z=pos.z}, player)
                                                else
                                                        if math.abs(dx) == 1 or math.abs(dz) == 1 then
                                                                burn({x=pos.x, y=pos.y, z=pos.z}, player)
                                                        end
                                                end
                                        end
                                        
                                        pos.x = pos.x-dx
                                        pos.y = pos.y-dy
                                        pos.z = pos.z-dz
                                end
                        end
                end
        end, pos)
end


minetest.register_node("bettertnt:gunpowder", {
        description = "Gun Powder",
        drawtype = "raillike",
        paramtype = "light",
        sunlight_propagates = true,
        walkable = false,
        tiles = {"bettertnt_gunpowder.png",},
        inventory_image = "bettertnt_gunpowder_inventory.png",
        wield_image = "bettertnt_gunpowder_inventory.png",
        selection_box = {
                type = "fixed",
                fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
        },
        groups = {dig_immediate=2,attached_node=1},
        sounds = default.node_sound_leaves_defaults(),
        
        on_punch = function(pos, node, puncher)
                if puncher:get_wielded_item():get_name() == "default:torch" then
                        burn(pos, puncher)
                end
        end,
})

minetest.register_node("bettertnt:gunpowder_burning", {
        drawtype = "raillike",
        paramtype = "light",
        sunlight_propagates = true,
        walkable = false,
        light_source = 5,
        tiles = {{name="bettertnt_gunpowder_burning_animated.png", animation={type="vertical_frames", aspect_w=16, aspect_h=16, length=1}}},
        selection_box = {
                type = "fixed",
                fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
        },
        drop = "",
        groups = {dig_immediate=2,attached_node=1},
        sounds = default.node_sound_leaves_defaults(),
})

local tnt_plus_gunpowder = {"bettertnt:gunpowder"}
for name,data in pairs(tnt_tables) do
	tnt_plus_gunpowder[#tnt_plus_gunpowder+1] = name
end


minetest.register_abm({
        nodenames = tnt_plus_gunpowder,
        neighbors = {"fire:basic_flame"},
        interval = 2,
        chance = 10,
        action = function(pos, node)
                if node.name == "tnt:tnt1" then
                        boom({x=pos.x, y=pos.y, z=pos.z}, 0)
                else
                        burn(pos)
                end
        end
})

minetest.register_craft({
        output = "tnt:gunpowder",
        type = "shapeless",
        recipe = {"default:coal_lump", "default:gravel"}
})


tnt_c_air = minetest.get_content_id("air")
tnt_c_fire = minetest.get_content_id("fire:basic_flame")