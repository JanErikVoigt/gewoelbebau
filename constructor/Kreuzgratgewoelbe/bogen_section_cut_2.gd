@tool
extends MultiMeshInstance3D

@export_node_path var arch : NodePath
@export_range(-20,20,0.01) var length_arch : float = 6
@export_range(-89,89,1, "radians") var angle_y_cutsurface : float = 0
#@export_node_path var cut_surface : NodePath

func _ready():
	multimesh.instance_count = 10000
	for i in range(10000):
		multimesh.set_instance_transform(i, Transform3D())
		multimesh.set_instance_custom_data(i, Color(1,1,1,1))
		multimesh.set_instance_color(i, Color("a5512f"))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if arch == null:# or cut_surface == null:
		multimesh.visible_instance_count = 0
		return
		
	var bogen = get_node(arch)
	var shape = Vector3(bogen.shape.x, bogen.shape.y, length_arch)
	
	#print("shape",shape)
	
	var arc_len_1 = bogen.arc_len()
	var brick_height = 0.08 + 0.01
	var brick_length = 0.3 + 0.01
	
	var brick_shape = Vector3(0.12, 0.08, 0.3)
	var fugen_thickness = 0.01
	
	#var cut_surface_transform_inv = get_node(cut_surface).transform.inverse()
	var bogen_t_inv = bogen.transform.inverse()
		
	$cutsurface.transform = bogen.transform.translated_local(Vector3.FORWARD * length_arch).rotated_local(Vector3.UP, angle_y_cutsurface)
	
	var i_brick = 0
	for i_arc in range(floor(arc_len_1 / brick_height)):
		var dist_from_bot = i_arc * brick_height
		#$"DoppelBogenBack".transform * $"DoppelBogenBack/Bogen2".transform * 
		var t_arc = bogen.pos_on_arc(dist_from_bot)
		
		
		## 1. calculate how long the row should be for each corner
		var corner_offsets = [
			Vector3.ZERO,
			Vector3.UP * brick_shape.y,
			Vector3.RIGHT * brick_shape.x,
			Vector3(brick_shape.x,brick_shape.y,0)
		]
		
		var corners = []
		for j in range(4):
			corners.push_back(
				length_arch + t_arc.translated_local(corner_offsets[j]).origin.x * tan(angle_y_cutsurface)
			)
			
		
		## 2. fill with bricks
		var brick_row_length = corners.max()
		var last_brick_min_length = corners.max() - corners.min()
		if length_arch < 0:
			brick_row_length = abs(corners.min())
			# last_brick_min_length has right sign, already!
			
		var brick_fill = fill_length_with_bricks(brick_row_length, last_brick_min_length, (i_arc%2) == 0,brick_shape.z, fugen_thickness)
		
		
		## 3. add bricks (not last one yet)
		
		for i in range(brick_fill.size()-1):
			var brick_z
			if length_arch >= 0:
				brick_z = brick_fill[i][0]
			else:
				brick_z = -brick_fill[i][0] - brick_fill[i][1] * brick_length
			var t = t_arc.translated(Vector3.FORWARD * brick_z)
			t = bogen.transform * t
			multimesh.set_instance_transform(i_brick, t)
			multimesh.set_instance_custom_data(i_brick, Color(brick_fill[i][1],0,0))
			i_brick += 1
		
		## 4. add last brick
		if length_arch >= 0:
			var last_brick_z = brick_fill[brick_fill.size()-1][0]
			
			var brick_cut_at_corners = []
			for j in range(4):
				brick_cut_at_corners.push_back(
					brick_shape.z - (corners[j] - last_brick_z)
				)
				
				
			var brick_shorten = (brick_shape.z-brick_cut_at_corners[0]) /brick_shape.z
			var brick_shorten_y = brick_cut_at_corners[1] - brick_cut_at_corners[0]
			var brick_shorten_x = brick_cut_at_corners[2] - brick_cut_at_corners[0]
			var brick_cut_custom_data = Color(brick_shorten,brick_shorten_x,brick_shorten_y,0)
			
			
			#if i_arc == 20:
				#var markers = [$marker1,$marker2,$marker3,$marker4]
				##print("corners ",corners, corners.max())
				##print("brick_cut_at_corners ",brick_cut_at_corners)
				#for j in range(4):
					#var t2 = t_arc.translated_local(Vector3.FORWARD *  corners[j])
					#t2 = t2.translated_local(corner_offsets[j])
					#t2 = bogen.transform * t2
					#markers[j].transform = t2
			
			var t = t_arc.translated_local(Vector3.FORWARD * last_brick_z)
			t = bogen.transform * t
			multimesh.set_instance_transform(i_brick, t)
			
			multimesh.set_instance_custom_data(i_brick, brick_cut_custom_data)
			i_brick += 1
		
		else:
			var last_brick_z = - brick_fill[brick_fill.size()-1][0]
			#if i_arc == 20:
				#print(corners[1],last_brick_z)
			var brick_cut_at_corners = []
			for j in range(4):
				brick_cut_at_corners.push_back(
					brick_shape.z - (-corners[j] + last_brick_z)
				)
			#if i_arc == 20:
		#		print(brick_cut_at_corners)
			#
				
			var brick_shorten = (brick_shape.z-brick_cut_at_corners[2]) /brick_shape.z
			var brick_shorten_y = brick_cut_at_corners[1] - brick_cut_at_corners[0]
			var brick_shorten_x = -brick_cut_at_corners[2] + brick_cut_at_corners[0]
			var brick_cut_custom_data = Color(brick_shorten,brick_shorten_x,brick_shorten_y,0)

			
			var t = t_arc.translated_local(Vector3.RIGHT* brick_shape.x).rotated_local(Vector3.UP, PI).translated_local(Vector3.FORWARD * (-last_brick_z))
			t = bogen.transform * t
			multimesh.set_instance_transform(i_brick, t)
			
			multimesh.set_instance_custom_data(i_brick, brick_cut_custom_data)
			i_brick += 1
			
		
	multimesh.visible_instance_count = i_brick


# TODO also take last row of bricks
func fill_length_with_bricks(
		length:float, 
		last_brick_min_length:float,
		end_short:bool, brick_length:float, fugen_thickness:float):
	
	var brick_fuge_len = (brick_length  + fugen_thickness)
	var last_brick_len = max( 0.5* brick_length, last_brick_min_length)
	
	
	if last_brick_min_length > brick_length:
		printerr("last brick too long")
	
	if length <= 2*brick_length + fugen_thickness:
		#print(length)
		if end_short:
			if length <= 1 * brick_length:
				return [[0,length/brick_length]]
			else:
				#print("1to2")
				var middle_bricklen = length - 2*fugen_thickness - 0.5*brick_length - last_brick_len
				return [
					[0,0.5], 
					[0.5*brick_length + fugen_thickness,middle_bricklen/brick_length],
					[length-last_brick_len,last_brick_len/brick_length]]
		else: #end long
			if length <= 1 * brick_length:
				return [[0,length/brick_length]]
			else:
				var remaining = length - fugen_thickness
				var bricklen_last = max(remaining/2, last_brick_min_length)
				var bricklen_first = remaining - bricklen_last
				return [[0,bricklen_first/brick_length],[bricklen_first + fugen_thickness, bricklen_last]]
	
	
		
	var result = []
	var remaining = length
	
	
	
	if not end_short:
		remaining = length
		remaining -= 2 * brick_length  + fugen_thickness # first and last and one fuge
	
		result = [[0,1]]
	else:
		remaining = length
		remaining -= 0.5* brick_length  + fugen_thickness + last_brick_len # first and last and one fuge
		
		result = [[0,0.5]]
		
		
	var bricks_middle = remaining / brick_fuge_len
	var whole_bricks = floor(bricks_middle) 
	#print("bricks_middle", bricks_middle)
	
	
	
	var half_brickfuge_if_short_row = 0.0
	if end_short:
		half_brickfuge_if_short_row = (0.5*brick_length + fugen_thickness) / brick_fuge_len
	#print("half_brickfuge_if_short_row ",half_brickfuge_if_short_row)
	
	for i in range(whole_bricks):
		if not end_short:
			result.push_back([brick_fuge_len * (i+1), 1])
		else:
			result.push_back([brick_fuge_len * (i+1) - 0.5*brick_length, 1])
		
	var brick_remainder = bricks_middle - whole_bricks
	brick_remainder -= fugen_thickness / brick_fuge_len
	if brick_remainder <= 0.01 / brick_fuge_len:
		# TODO: redistribute fuge to all fugen 
		var to_distribute = (bricks_middle - whole_bricks) * brick_fuge_len
		var per_fuge = to_distribute / (result.size())
		
		for j in range(1,result.size()):
			result[j][0] += per_fuge * j
		#print("brick_remainder ",brick_remainder, "to_distribute ",to_distribute," per_fuge ",per_fuge)
		#printerr("sec to last brick is too short! (<1cm)")
	else:
		## second to last brick
		if not end_short:
			result.push_back([brick_fuge_len * (whole_bricks+1), brick_remainder])
		else:
			var offset = 0.5 * brick_length
			result.push_back([brick_fuge_len * (whole_bricks+1) - offset, brick_remainder])
	
		
	## last brick
	if not end_short:
		result.push_back([length - brick_length, 1])
	else:
		result.push_back([length - last_brick_len, last_brick_len])

	return result
	

#func cut_bricks_using_surface():
	#pass
	##cut_surface
	#if cut_surface != null:
		#var cut_surface_transform_inv = get_node(cut_surface).transform.inverse()
		#
		#for i_brick in range(multimesh.instance_count):
			#var brick_t = multimesh.get_instance_transform(i_brick)
			#
			#var t_along_cutsurface = cut_surface_transform_inv * brick_t.origin
			#
			#if t_along_cutsurface.z > 0:
				##var last_t = multimesh.get_instance_transform(multimesh.visible_instance_count-1)
				#multimesh.set_instance_transform(i_brick, Transform3D())
				##multimesh.visible_instance_count -= 1
				##i_brick -= 1
			##print(t_along_cutsurface)
		##print(cut_surface_transform_inv)
