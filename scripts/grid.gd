extends Node2D

#State machine
enum {wait, move}
var state;

# Grid variables
export (int) var width;
export (int) var height;
export (int) var x_start;
export (int) var y_start;
export (int) var offset;
export (int) var y_offset;

# Obstacle stuff
export (PoolVector2Array) var empty_spaces;
export (PoolVector2Array) var ice_spaces;
var locked_spaces = [];

# Obstacle signals
signal make_ice;
signal damage_ice;

# Piece array
var possible_pieces = [
	preload("res://Scenes/blue_piece.tscn"),
	preload("res://Scenes/green_piece.tscn"),
	preload("res://Scenes/orange_piece.tscn"),
	preload("res://Scenes/yellow_piece.tscn"),
	preload("res://Scenes/light_green_piece.tscn"),
	preload("res://Scenes/pink_piece.tscn"),
];

# Swap back variables
var piece1 = null;
var piece2 = null;
var last_place = Vector2(0, 0);
var last_direction = Vector2(0, 0);
var move_checked = false;

# In-memory representation of the board
var all_pieces = [];

#Touch variables
var first_touch = Vector2(0, 0);
var final_touch = Vector2(0, 0);
var controlling = false;

# Called when the node enters the scene tree for the first time.
func _ready():
	state = wait;
	randomize();
	all_pieces = make_2d_array();
	spawn_pieces();
	spawn_ice();
	state = move;

func restricted_fill(place):
	return is_in_array(empty_spaces, place);

func is_in_array(array, item):
	for i in array:
		if i == item:
			return true;
	return false;

func make_2d_array():
	var array = [];
	for i in width:
		array.append([]);
		for j in height:
			array[i].append(null);
	return array;

func spawn_pieces():
	for i in width:
		for j in height:
			if restricted_fill(Vector2(i, j)):
				continue;

			# Choose a random number and store it
			var rand = floor(rand_range(0, possible_pieces.size()));
			# Instance that piece from the array
			var piece = possible_pieces[rand].instance();

			var loops = 0;
			while match_at(i, j, piece.color) && loops < 100:
				rand = floor(rand_range(0, possible_pieces.size()));
				piece = possible_pieces[rand].instance();
				loops += 1;

			
			add_child(piece);
			piece.position = grid_to_pixel(i, j);
			all_pieces[i][j] = piece;

func spawn_ice():
	for ice_space in ice_spaces:
		emit_signal("make_ice", ice_space);
		locked_spaces.append(ice_space);

func match_at(i, j, color):
	if i > 1:
		if all_pieces[i - 1][j] != null \
				&& all_pieces[i-2][j] != null:
			if all_pieces[i-1][j].color == color \
					&& all_pieces[i-1][j].color == color:
				return true;
	if j > 1:
		if all_pieces[i][j-1] != null \
				&& all_pieces[i][j-2] != null:
			if all_pieces[i][j-1].color == color \
					&& all_pieces[i][j-2].color == color:
				return true;
	pass;

func grid_to_pixel(col, row):
	var new_x = x_start + (offset * col);
	var new_y = y_start + (-offset * row);
	return Vector2(new_x, new_y);

func pixel_to_grid(pixel_x, pixel_y):
	var new_x = round((pixel_x - x_start) / offset);
	var new_y = round((pixel_y - y_start) / -offset);
	return Vector2(new_x, new_y);

func is_in_grid(grid_pos):
	if grid_pos.x >= 0 && grid_pos.x < width:
		if grid_pos.y >= 0 && grid_pos.y < height:
			return true;
	return false;

func touch_input():
	# Swipe press
	if Input.is_action_just_pressed("ui_touch"):
		var gmp = get_global_mouse_position();
		if is_in_grid(pixel_to_grid(gmp.x, gmp.y)) \
				&& !is_in_array(locked_spaces, pixel_to_grid(gmp.x, gmp.y)):
			print();
			controlling = true;
			first_touch = gmp;

	# Swipe release
	if Input.is_action_just_released("ui_touch"):
		var gmp = get_global_mouse_position();
		if is_in_grid(pixel_to_grid(gmp.x, gmp.y)) \
				&& controlling \
				&& !is_in_array(locked_spaces, pixel_to_grid(gmp.x, gmp.y)):
			controlling = false;
			final_touch = gmp;
			var grid_pos = pixel_to_grid(final_touch.x, final_touch.y);
			touch_difference(pixel_to_grid(first_touch.x, first_touch.y), grid_pos);
	
	if Input.is_action_just_released("ui_longpress"):
		var gmp = get_global_mouse_position();
		var gmptg = pixel_to_grid(gmp.x, gmp.y);
		if is_in_grid(gmptg):
			emit_signal("damage_ice", gmptg);
			all_pieces[gmptg.x][gmptg.y].queue_free();
			all_pieces[gmptg.x][gmptg.y] = null;
			locked_spaces.erase(gmptg);
			get_parent().get_node("collapse_timer").start();

# swap_piece:
# Parameters:
#	-col (int):				column/x-coordinate of base piece to swap
#	-row (int):				row/y-coordinate of base piece to swap
#	-direction (Vector2):	direction that piece will be swapped
func swap_pieces(col, row, direction):
	print("swap_pieces")
	var first_piece = all_pieces[col][row];
	var other_piece = all_pieces[col+direction.x][row+direction.y];
	if first_piece != null && other_piece != null:
		store_info(first_piece, other_piece, Vector2(col, row), direction);
		state = wait;
		all_pieces[col][row] = other_piece;
		all_pieces[col+direction.x][row+direction.y] = first_piece;
		first_piece.move(grid_to_pixel(col+direction.x, row+direction.y));
		other_piece.move(grid_to_pixel(col, row));
		if !move_checked:
			find_matches();

func store_info(first_piece, other_piece, place, direction):
	piece1 = first_piece;
	piece2 = other_piece;
	last_place = place;
	last_direction = direction;

func swap_back():
	print("swap_back")
	# Move previously swapped pieces back
	if piece1 != null && piece2 != null:
		swap_pieces(last_place.x, last_place.y, last_direction);
	move_checked = false;
	state = move;

func touch_difference(grid1, grid2):
	var diff = grid2 - grid1;
	if abs(diff.x) > abs(diff.y):
		if diff.x > 0:
			swap_pieces(grid1.x, grid1.y, Vector2(1, 0));
		elif diff.x < 0:
			swap_pieces(grid1.x, grid1.y, Vector2(-1, 0));
	elif abs(diff.x) < abs(diff.y):
		if diff.y > 0:
			swap_pieces(grid1.x, grid1.y, Vector2(0, 1));
		if diff.y < 0:
			swap_pieces(grid1.x, grid1.y, Vector2(0, -1));

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if state == move:
		touch_input();

func find_matches():
	print("find_matches");
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				var curr_color = all_pieces[i][j].color;
				# Check horizontal matches
				if i > 0 && i < width - 1:
					if all_pieces[i-1][j] != null \
							&& all_pieces[i+1][j] != null:
						if all_pieces[i-1][j].color == curr_color \
								&& all_pieces[i+1][j].color == curr_color:
							all_pieces[i-1][j].matched = true;
							all_pieces[i-1][j].dim();
							all_pieces[i][j].matched = true;
							all_pieces[i][j].dim();
							all_pieces[i+1][j].matched = true;
							all_pieces[i+1][j].dim();
				# Check vertical matches
				if j > 0 && j < height - 1:
					if all_pieces[i][j-1] != null \
							&& all_pieces[i][j+1] != null:
						if all_pieces[i][j-1].color == curr_color \
								&& all_pieces[i][j+1].color == curr_color:
							all_pieces[i][j-1].matched = true;
							all_pieces[i][j-1].dim();
							all_pieces[i][j].matched = true;
							all_pieces[i][j].dim();
							all_pieces[i][j+1].matched = true;
							all_pieces[i][j+1].dim();
	get_parent().get_node("destroy_timer").start();

func destroy_matched():
	print("destroy_matched");
	var was_matched = false;
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				if all_pieces[i][j].matched:
					emit_signal("damage_ice", Vector2(i, j));
					locked_spaces.erase(Vector2(i, j));
					was_matched = true;
					all_pieces[i][j].queue_free();
					all_pieces[i][j] = null;
	move_checked = true;
	if was_matched:
		get_parent().get_node("collapse_timer").start();
		piece1 = null;
		piece2 = null;
	else:
		swap_back();

func collapse_columns():
	print("collapse_columns");
	for i in width:
		for j in height:
			if restricted_fill(Vector2(i, j)):
				continue;

			if is_in_array(locked_spaces, Vector2(i, j)):
				continue;

			if all_pieces[i][j] == null:
				for k in range(j + 1, height):
					if all_pieces[i][k] != null:
						if is_in_array(locked_spaces, Vector2(i, k)):
							continue;
						all_pieces[i][k].move(grid_to_pixel(i, j));
						all_pieces[i][j] = all_pieces[i][k];
						all_pieces[i][k] = null;
						break;
	get_parent().get_node("refill_timer").start();

func refill_columns():
	var need_to_skip;
	print("refill_timer");
	for i in width:
		for j in height:
			need_to_skip = false;
			if restricted_fill(Vector2(i, j)):
				continue;

			if all_pieces[i][j] == null:

				# Check if current space is below a locked piece
				for k in range(j+1, height):
					print(Vector2(i, k));
					if is_in_array(locked_spaces, Vector2(i, k)):
						print("Don't refill");
						need_to_skip = true;

				if need_to_skip:
					continue;

				print(Vector2(i, j));
				print("Refilling");
				# Choose a random number and store it
				var rand = floor(rand_range(0, possible_pieces.size()));
				# Instance that piece from the array
				var piece = possible_pieces[rand].instance();

				var loops = 0;
				while match_at(i, j, piece.color) && loops < 100:
					rand = floor(rand_range(0, possible_pieces.size()));
					piece = possible_pieces[rand].instance();
					loops += 1;

				add_child(piece);
				piece.position = grid_to_pixel(i, j + y_offset);
				piece.move(grid_to_pixel(i, j));
				all_pieces[i][j] = piece;
	after_refill();

func after_refill():
	print("after_refill");
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				if match_at(i, j, all_pieces[i][j].color):
					find_matches();
					return;
	move_checked = false;
	state = move

func _on_destroy_timer_timeout():
	destroy_matched();

func _on_collapse_timer_timeout():
	collapse_columns();

func _on_refill_timer_timeout():
	refill_columns();
