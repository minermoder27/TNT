local tnt_range = 2
local tnt_preserve_items = false
local tnt_drop_items = false
local tnt_seed = 15

local tnt_side = "default_tnt_side.png^tnt_shadows.png"

local function get_tnt_random(pos)
	return PseudoRandom(math.abs(pos.x+pos.y*3+pos.z*5)+tnt_seed)
end

local function drop_item(pos, nodename)
	local drop = minetest.get_node_drops(nodename, "")
	if tnt_drop_items then
		for _,item in ipairs(drop) do
			if type(item) == "string" then
				local obj = minetest.env:add_item(pos, item)
				if obj == nil then
					return
				end
				obj:get_luaentity().collect = true
				obj:setacceleration({x=0, y=-10, z=0})
				obj:setvelocity({x=pr:next(0,6)-3, y=10, z=pr:next(0,6)-3})
			else
				for i=1,item:get_count() do
					local obj = minetest.env:add_item(pos, item:get_name())
					if obj == nil then
						return
					end
					obj:get_luaentity().collect = true
					obj:setacceleration({x=0, y=-10, z=0})
					obj:setvelocity({x=pr:next(0,6)-3, y=10, z=pr:next(0,6)-3})
				end
			end
		end
	end
end

local destroy = function(pos)
	local nodename = minetest.env:get_node(pos).name
	local p_pos = area:index(pos.x, pos.y, pos.z)
	if nodes[p_pos] ~= tnt_c_air then
--		minetest.env:remove_node(pos)
--		nodeupdate(pos)
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
	drop_item(pos, nodename)
end

function boom(pos, time)
	minetest.after(time, function(pos)
		if minetest.env:get_node(pos).name ~= "tnt:tnt_burning" then
			return
		end

		local t1 = os.clock()
		pr = get_tnt_random(pos)
		minetest.sound_play("tnt_explode", {pos=pos, gain=1.5, max_hear_distance=tnt_range*64})

		local manip = minetest.get_voxel_manip()
		local width = tnt_range
		local emerged_pos1, emerged_pos2 = manip:read_from_map({x=pos.x-width, y=pos.y-width, z=pos.z-width},
			{x=pos.x+width, y=pos.y+width, z=pos.z+width})
		area = VoxelArea:new{MinEdge=emerged_pos1, MaxEdge=emerged_pos2}
		nodes = manip:get_data()

		local p_pos = area:index(pos.x, pos.y, pos.z)
		nodes[p_pos] = tnt_c_boom
		--minetest.env:set_node(pos, {name="tnt:boom"})
		
		local objects = minetest.env:get_objects_inside_radius(pos, 7)
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
					local node =  minetest.env:get_node(p)
					if d_p_node == tnt_c_tnt
					or d_p_node == tnt_c_tnt_burning then
						nodes[p_node] = tnt_c_tnt_burning
						boom({x=p.x, y=p.y, z=p.z}, 0)
					elseif not ( d_p_node == tnt_c_fire
					or string.find(node.name, "default:water_")
					or string.find(node.name, "default:lava_")
					or d_p_node == tnt_c_boom ) then
						if math.abs(dx)<tnt_range and math.abs(dy)<tnt_range and math.abs(dz)<tnt_range then
							destroy(p)
						else
							if pr:next(1,5) <= 4 then
								destroy(p)
							end
						end
					end
					
				end
			end
		end
		
		minetest.add_particlespawner(
			100, --amount
			0.1, --time
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
			false, --collisiondetection
			"tnt_smoke.png" --texture
		)
		manip:set_data(nodes)
		manip:write_to_map()
		print(string.format("[tnt] exploded in: %.2fs", os.clock() - t1))
		local t1 = os.clock()
		manip:update_map()
		print(string.format("[tnt] map updated after: %.2fs", os.clock() - t1))
		minetest.after(0.5, function(pos)
				minetest.env:remove_node(pos)
			end, {x=pos.x, y=pos.y, z=pos.z}
		)
	end, pos)
end

minetest.register_node("tnt:tnt", {
	description = "TNT",
	tiles = {"default_tnt_top.png", "default_tnt_bottom.png", tnt_side},
	groups = {dig_immediate=2, mesecon=2},
	sounds = default.node_sound_wood_defaults(),
	
	on_punch = function(pos, node, puncher)
		if puncher:get_wielded_item():get_name() == "default:torch" then
			minetest.sound_play("tnt_ignite", {pos=pos})
			minetest.env:set_node(pos, {name="tnt:tnt_burning"})
			boom(pos, 4)
		end
	end,
	
	mesecons = {
		effector = {
			action_on = function(pos, node)
				minetest.env:set_node(pos, {name="tnt:tnt_burning"})
				boom(pos, 0)
			end
		},
	},
})

local tnt_frame_count = 4
local tnt_frame_size = 16

local l = tnt_frame_count
local px = 0
local combine_textures = ":0,"..px.."=default_tnt_top.png"
while l ~= 0 do
	combine_textures = combine_textures..":0,"..px.."=default_tnt_top.png"
	px = px+tnt_frame_size
	l = l-1
end

local animated_tnt_texture = "tnt_top_burning_animated.png^[combine:16x64:"..combine_textures.."^tnt_top_burning_animated.png"

minetest.register_node("tnt:tnt_burning", {
	tiles = {{name=animated_tnt_texture, animation={type="vertical_frames", aspect_w=16, aspect_h=16, length=1}},
	"default_tnt_bottom.png", tnt_side},
	light_source = 5,
	drop = "",
	sounds = default.node_sound_wood_defaults(),
})

minetest.register_node("tnt:boom", {
	drawtype = "plantlike",
	tiles = {"tnt_boom.png"},
	light_source = LIGHT_MAX,
	walkable = false,
	drop = "",
	groups = {dig_immediate=3},
})

burn = function(pos)
	if minetest.env:get_node(pos).name == "tnt:tnt" then
		minetest.sound_play("tnt_ignite", {pos=pos})
		minetest.env:set_node(pos, {name="tnt:tnt_burning"})
		boom(pos, 1)
		return
	end
	if minetest.env:get_node(pos).name ~= "tnt:gunpowder" then
		return
	end
	minetest.sound_play("tnt_gunpowder_burning", {pos=pos, gain=2})
	minetest.env:set_node(pos, {name="tnt:gunpowder_burning"})
	
	minetest.after(1, function(pos)
		if minetest.env:get_node(pos).name ~= "tnt:gunpowder_burning" then
			return
		end
		minetest.after(0.5, function(pos)
			minetest.env:remove_node(pos)
		end, {x=pos.x, y=pos.y, z=pos.z})
		for dx=-1,1 do
			for dz=-1,1 do
				for dy=-1,1 do
					pos.x = pos.x+dx
					pos.y = pos.y+dy
					pos.z = pos.z+dz
					
					if not (math.abs(dx) == 1 and math.abs(dz) == 1) then
						if dy == 0 then
							burn({x=pos.x, y=pos.y, z=pos.z})
						else
							if math.abs(dx) == 1 or math.abs(dz) == 1 then
								burn({x=pos.x, y=pos.y, z=pos.z})
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

minetest.register_node("tnt:gunpowder", {
	description = "Gun Powder",
	drawtype = "raillike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	tiles = {"tnt_gunpowder.png",},
	inventory_image = "tnt_gunpowder_inventory.png",
	wield_image = "tnt_gunpowder_inventory.png",
	selection_box = {
		type = "fixed",
		fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
	},
	groups = {dig_immediate=2,attached_node=1},
	sounds = default.node_sound_leaves_defaults(),
	
	on_punch = function(pos, node, puncher)
		if puncher:get_wielded_item():get_name() == "default:torch" then
			burn(pos)
		end
	end,
})

minetest.register_node("tnt:gunpowder_burning", {
	drawtype = "raillike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	light_source = 5,
	tiles = {{name="tnt_gunpowder_burning_animated.png", animation={type="vertical_frames", aspect_w=16, aspect_h=16, length=1}}},
	selection_box = {
		type = "fixed",
		fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
	},
	drop = "",
	groups = {dig_immediate=2,attached_node=1},
	sounds = default.node_sound_leaves_defaults(),
})

tnt_c_boom = minetest.get_content_id("tnt:boom")
tnt_c_tnt = minetest.get_content_id("tnt:tnt")
tnt_c_tnt_burning = minetest.get_content_id("tnt:tnt_burning")
tnt_c_air = minetest.get_content_id("air")
tnt_c_fire = minetest.get_content_id("fire:basic_flame")


minetest.register_abm({
	nodenames = {"tnt:tnt", "tnt:gunpowder"},
	neighbors = {"fire:basic_flame"},
	interval = 2,
	chance = 10,
	action = function(pos, node)
		if node.name == "tnt:tnt" then
			minetest.env:set_node(pos, {name="tnt:tnt_burning"})
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

minetest.register_craft({
	output = "tnt:tnt",
	recipe = {
		{"", "group:wood", ""},
		{"group:wood", "tnt:gunpowder", "group:wood"},
		{"", "group:wood", ""}
	}
})

if minetest.setting_get("log_mods") then
	minetest.log("action", "tnt loaded")
end
