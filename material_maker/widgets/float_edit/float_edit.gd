extends LineEdit

export var value : float = 0.5 setget set_value
export var min_value : float = 0.0 setget set_min_value
export var max_value : float = 1.0 setget set_max_value
export var step : float = 0.0 setget set_step
export var float_only : bool = false

var sliding : bool = false
var start_position : float
var last_position : float
var start_value : float
var modifiers : int
var from_lower_bound : bool = false
var from_upper_bound : bool = false

onready var slider = $Slider
onready var cursor = $Slider/Cursor

signal value_changed(value)
signal value_changed_undo(value, merge_undo)

func _ready() -> void:
	do_update()

func get_value() -> String:
	return text
	
func set_value(v, notify = false) -> void:
	if v is int:
		v = float(v)
	if v is float:
		value = v
		text = str(v)
		do_update()
		$Slider.visible = true
		if notify:
			emit_signal("value_changed", value)
			emit_signal("value_changed_undo", value, false)
	elif v is String and !float_only:
		text = v
		$Slider.visible = false
		if notify:
			emit_signal("value_changed", v)
			emit_signal("value_changed_undo", v, false)

func set_value_from_expression_editor(v : String):
	if v.is_valid_float():
		set_value(float(v), true)
	else:
		set_value(v, true)

func set_min_value(v : float) -> void:
	min_value = v
	do_update()

func set_max_value(v : float) -> void:
	max_value = v
	do_update()

func set_step(v : float) -> void:
	step = v
	do_update()

func do_update(update_text : bool = true) -> void:
	if update_text and $Slider.visible:
		text = str(value)
		if cursor != null:
			if max_value != min_value:
				cursor.rect_position.x = (clamp(value, min_value, max_value)-min_value)*(slider.rect_size.x-cursor.rect_size.x)/(max_value-min_value)
			else:
				cursor.rect_position.x = 0

func get_modifiers(event):
	var new_modifiers = 0
	if event.shift:
		new_modifiers |= 1
	if event.control:
		new_modifiers |= 2
	if event.alt:
		new_modifiers |= 4
	return new_modifiers

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT and event.is_pressed() and !float_only:
		var expression_editor : WindowDialog = load("res://material_maker/widgets/float_edit/expression_editor.tscn").instance()
		add_child(expression_editor)
		expression_editor.edit_parameter("Expression editor - "+name, text, self, "set_value_from_expression_editor")
		accept_event()
	if !slider.visible or !sliding and !editable:
		return
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.is_pressed():
			if event.doubleclick:
				yield(get_tree(), "idle_frame")
				select_all()
			else:
				last_position = event.position.x
				start_position = last_position
				start_value = value
				sliding = true
				from_lower_bound = value <= min_value
				from_upper_bound = value >= max_value
				modifiers = get_modifiers(event)
				emit_signal("value_changed_undo", value, false)
				editable = false
				selecting_enabled = false
		else:
			sliding = false
			editable = true
			selecting_enabled = true
	elif sliding and event is InputEventMouseMotion and event.button_mask == BUTTON_MASK_LEFT:
		var new_modifiers = get_modifiers(event)
		if new_modifiers != modifiers:
			start_position = last_position
			start_value = value
			modifiers = new_modifiers
		else:
			last_position = event.position.x
			var delta : float = last_position-start_position
			var current_step = step
			if event.control:
				delta *= 0.2
			elif event.shift:
				delta *= 5.0
			if event.alt:
				current_step *= 0.01
			var v : float = start_value+sign(delta)*pow(abs(delta)*0.005, 2)*abs(max_value - min_value)
			if current_step != 0:
				v = min_value+floor((v - min_value)/current_step)*current_step
			if !from_lower_bound and v < min_value:
				v = min_value
			if !from_upper_bound and v > max_value:
				v = max_value
			set_value(v)
			emit_signal("value_changed", value)
			emit_signal("value_changed_undo", value, true)
		accept_event()
	elif event is InputEventKey and !event.echo:
		match event.scancode:
			KEY_SHIFT, KEY_CONTROL, KEY_ALT:
				start_position = last_position
				start_value = value
				modifiers = get_modifiers(event)

func _on_LineEdit_text_changed(_new_text : String) -> void:
	pass

func _on_LineEdit_text_entered(new_text : String, release = true) -> void:
	if new_text.is_valid_float():
		var new_value : float = new_text.to_float()
		if abs(value-new_value) > 0.00001:
			value = new_value
			do_update()
			emit_signal("value_changed", value)
			emit_signal("value_changed_undo", value, false)
			$Slider.visible = true
	elif float_only or new_text == "":
		do_update()
		emit_signal("value_changed", value)
		emit_signal("value_changed_undo", value, false)
		$Slider.visible = true
	else:
		emit_signal("value_changed", new_text)
		emit_signal("value_changed_undo", new_text, false)
		$Slider.visible = false
	if release:
		release_focus()

func _on_FloatEdit_focus_entered():
	select_all()

func _on_LineEdit_focus_exited() -> void:
	select(0, 0)
	_on_LineEdit_text_entered(text, false)
	select(0, 0)
