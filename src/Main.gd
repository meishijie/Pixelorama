extends Control

var opensprite_file_selected := false
var file_menu : PopupMenu
var view_menu : PopupMenu
var redone := false
var unsaved_canvas_state := 0
var is_quitting_on_save := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	# Set a minimum window size to prevent UI elements from collapsing on each other.
	# This property is only available in 3.2alpha or later, so use `set()` to fail gracefully if it doesn't exist.
	OS.set("min_window_size", Vector2(1024, 576))
	Global.loaded_locales = TranslationServer.get_loaded_locales()

	# Make sure locales are always sorted, in the same order
	Global.loaded_locales.sort()

	# Restore the window position/size if values are present in the configuration cache
	if Global.config_cache.has_section_key("window", "screen"):
		OS.current_screen = Global.config_cache.get_value("window", "screen")
	if Global.config_cache.has_section_key("window", "maximized"):
		OS.window_maximized = Global.config_cache.get_value("window", "maximized")

	if !OS.window_maximized:
		if Global.config_cache.has_section_key("window", "position"):
			OS.window_position = Global.config_cache.get_value("window", "position")
		if Global.config_cache.has_section_key("window", "size"):
			OS.window_size = Global.config_cache.get_value("window", "size")

	var file_menu_items := {
		"New..." : InputMap.get_action_list("new_file")[0].get_scancode_with_modifiers(),
		"Open..." : InputMap.get_action_list("open_file")[0].get_scancode_with_modifiers(),
		'Open last project...' : 0,
		"Save..." : InputMap.get_action_list("save_file")[0].get_scancode_with_modifiers(),
		"Save as..." : InputMap.get_action_list("save_file_as")[0].get_scancode_with_modifiers(),
		"Import..." : InputMap.get_action_list("import_file")[0].get_scancode_with_modifiers(),
		"Export..." : InputMap.get_action_list("export_file")[0].get_scancode_with_modifiers(),
		"Export as..." : InputMap.get_action_list("export_file_as")[0].get_scancode_with_modifiers(),
		"Quit" : InputMap.get_action_list("quit")[0].get_scancode_with_modifiers(),
		}
	var edit_menu_items := {
		"Undo" : InputMap.get_action_list("undo")[0].get_scancode_with_modifiers(),
		"Redo" : InputMap.get_action_list("redo")[0].get_scancode_with_modifiers(),
		"Clear Selection" : 0,
		"Preferences" : 0
		}
	var view_menu_items := {
		"Tile Mode" : InputMap.get_action_list("tile_mode")[0].get_scancode_with_modifiers(),
		"Show Grid" : InputMap.get_action_list("show_grid")[0].get_scancode_with_modifiers(),
		"Show Rulers" : InputMap.get_action_list("show_rulers")[0].get_scancode_with_modifiers(),
		"Show Guides" : InputMap.get_action_list("show_guides")[0].get_scancode_with_modifiers(),
		"Show Animation Timeline" : 0
		}
	var image_menu_items := {
		"Scale Image" : 0,
		"Crop Image" : 0,
		"Flip Horizontal" : InputMap.get_action_list("image_flip_horizontal")[0].get_scancode_with_modifiers(),
		"Flip Vertical" : InputMap.get_action_list("image_flip_vertical")[0].get_scancode_with_modifiers(),
		"Rotate Image" : 0,
		"Invert colors" : 0,
		"Desaturation" : 0,
		"Outline" : 0,
		"Adjust Hue/Saturation/Value" : 0
		}
	var help_menu_items := {
		"View Splash Screen" : 0,
		"Online Docs" : 0,
		"Issue Tracker" : 0,
		"Changelog" : 0,
		"About Pixelorama" : 0
		}

	# Load language
	if Global.config_cache.has_section_key("preferences", "locale"):
		var saved_locale : String = Global.config_cache.get_value("preferences", "locale")
		TranslationServer.set_locale(saved_locale)

		# Set the language option menu's default selected option to the loaded locale
		var locale_index: int = Global.loaded_locales.find(saved_locale)
		$PreferencesDialog.languages.get_child(0).pressed = false # Unset System Language option in preferences
		$PreferencesDialog.languages.get_child(locale_index + 1).pressed = true
	else: # If the user doesn't have a language preference, set it to their OS' locale
		TranslationServer.set_locale(OS.get_locale())

	if "zh" in TranslationServer.get_locale():
		theme.default_font = preload("res://assets/fonts/CJK/NotoSansCJKtc-Regular.tres")
	else:
		theme.default_font = preload("res://assets/fonts/Roboto-Regular.tres")


	file_menu = Global.file_menu.get_popup()
	var edit_menu : PopupMenu = Global.edit_menu.get_popup()
	view_menu = Global.view_menu.get_popup()
	var image_menu : PopupMenu = Global.image_menu.get_popup()
	var help_menu : PopupMenu = Global.help_menu.get_popup()

	var i = 0
	for item in file_menu_items.keys():
		file_menu.add_item(item, i, file_menu_items[item])
		i += 1
	i = 0
	for item in edit_menu_items.keys():
		edit_menu.add_item(item, i, edit_menu_items[item])
		i += 1
	i = 0
	for item in view_menu_items.keys():
		view_menu.add_check_item(item, i, view_menu_items[item])
		i += 1
	view_menu.set_item_checked(2, true) # Show Rulers
	view_menu.set_item_checked(3, true) # Show Guides
	view_menu.set_item_checked(4, true) # Show Animation Timeline
	view_menu.hide_on_checkable_item_selection = false
	i = 0
	for item in image_menu_items.keys():
		image_menu.add_item(item, i, image_menu_items[item])
		if i == 4:
			image_menu.add_separator()
		i += 1
	i = 0
	for item in help_menu_items.keys():
		help_menu.add_item(item, i, help_menu_items[item])
		i += 1

	file_menu.connect("id_pressed", self, "file_menu_id_pressed")
	edit_menu.connect("id_pressed", self, "edit_menu_id_pressed")
	view_menu.connect("id_pressed", self, "view_menu_id_pressed")
	image_menu.connect("id_pressed", self, "image_menu_id_pressed")
	help_menu.connect("id_pressed", self, "help_menu_id_pressed")

	# Checks to see if it's 3.1.x
	if Engine.get_version_info().major == 3 and Engine.get_version_info().minor < 2:
		Global.left_color_picker.get_picker().move_child(Global.left_color_picker.get_picker().get_child(0), 1)
		Global.right_color_picker.get_picker().move_child(Global.right_color_picker.get_picker().get_child(0), 1)

	Global.window_title = "(" + tr("untitled") + ") - Pixelorama " + Global.current_version

	Global.layers[0][0] = tr("Layer") + " 0"
	Global.layers_container.get_child(0).label.text = Global.layers[0][0]
	Global.layers_container.get_child(0).line_edit.text = Global.layers[0][0]

	Import.import_brushes(Global.directory_module.get_brushes_search_path_in_order())
	Import.import_patterns(Global.directory_module.get_patterns_search_path_in_order())

	Global.left_color_picker.get_picker().presets_visible = false
	Global.right_color_picker.get_picker().presets_visible = false
	$QuitAndSaveDialog.add_button("Save & Exit", false, "Save")
	$QuitAndSaveDialog.get_ok().text = "Exit without saving"

	if not Global.config_cache.has_section_key("preferences", "startup"):
		Global.config_cache.set_value("preferences", "startup", true)

	# Wait for the window to adjust itself, so the popup is correctly centered
	yield(get_tree().create_timer(0.01), "timeout")
	if Global.config_cache.get_value("preferences", "startup"):
		$SplashDialog.popup_centered() # Splash screen
		modulate = Color(0.5, 0.5, 0.5)
	else:
		Global.can_draw = true

	# If backup file exists then Pixelorama was not closed properly (probably crashed) - reopen backup
	$BackupConfirmation.get_cancel().text = tr("Delete")
	if Global.config_cache.has_section("backups"):
		var project_paths = Global.config_cache.get_section_keys("backups")
		if project_paths.size() > 0:
			# Get backup path
			var backup_path = Global.config_cache.get_value("backups", project_paths[0])
			# Temporatily stop autosave until user confirms backup
			OpenSave.autosave_timer.stop()
			# For it's only possible to reload the first found backup
			$BackupConfirmation.dialog_text = tr($BackupConfirmation.dialog_text) % project_paths[0]
			$BackupConfirmation.connect("confirmed", self, "_on_BackupConfirmation_confirmed", [project_paths[0], backup_path])
			$BackupConfirmation.get_cancel().connect("pressed", self, "_on_BackupConfirmation_delete", [project_paths[0], backup_path])
			$BackupConfirmation.popup_centered()
			Global.can_draw = false
			modulate = Color(0.5, 0.5, 0.5)
		else:
			if Global.open_last_project:
				load_last_project()
	else:
		if Global.open_last_project:
			load_last_project()

	if OS.get_cmdline_args():
		for arg in OS.get_cmdline_args():
			if arg.get_extension().to_lower() == "pxo":
				_on_OpenSprite_file_selected(arg)
			else:
				if arg == OS.get_cmdline_args()[0]:
					$ImportSprites.new_frame = false
				$ImportSprites._on_ImportSprites_files_selected([arg])
				$ImportSprites.new_frame = true


func _input(event : InputEvent) -> void:
	Global.left_cursor.position = get_global_mouse_position() + Vector2(-32, 32)
	Global.left_cursor.texture = Global.left_cursor_tool_texture
	Global.right_cursor.position = get_global_mouse_position() + Vector2(32, 32)
	Global.right_cursor.texture = Global.right_cursor_tool_texture

	if event is InputEventKey and (event.scancode == KEY_ENTER or event.scancode == KEY_KP_ENTER):
		if get_focus_owner() is LineEdit:
			get_focus_owner().release_focus()

	if event.is_action_pressed("toggle_fullscreen"):
		OS.window_fullscreen = !OS.window_fullscreen

	if event.is_action_pressed("redo_secondary"): # Shift + Ctrl + Z
		redone = true
		Global.undo_redo.redo()
		redone = false


func _notification(what : int) -> void:
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST: # Handle exit
		show_quit_dialog()


func file_menu_id_pressed(id : int) -> void:
	match id:
		0: # New
			if Global.project_has_changed:
				unsaved_canvas_state = id
				$UnsavedCanvasDialog.popup_centered()
			else:
				$CreateNewImage.popup_centered()
			Global.dialog_open(true)
		1: # Open
			$OpenSprite.popup_centered()
			Global.dialog_open(true)
			opensprite_file_selected = false
		2: # Open last project
			# Check if last project path is set and if yes then open
			if Global.config_cache.has_section_key("preferences", "last_project_path"):
				if Global.project_has_changed:
					unsaved_canvas_state = id
					$UnsavedCanvasDialog.popup_centered()
					Global.dialog_open(true)
				else:
					load_last_project()
			else: # if not then warn user that he didn't edit any project yet
				Global.error_dialog.set_text("You haven't saved or opened any project in Pixelorama yet!")
				Global.error_dialog.popup_centered()
				Global.dialog_open(true)
		3: # Save
			is_quitting_on_save = false
			if OpenSave.current_save_path == "":
				$SaveSprite.popup_centered()
				Global.dialog_open(true)
			else:
				_on_SaveSprite_file_selected(OpenSave.current_save_path)
		4: # Save as
			is_quitting_on_save = false
			$SaveSprite.popup_centered()
			Global.dialog_open(true)
		5: # Import
			$ImportSprites.popup_centered()
			Global.dialog_open(true)
			opensprite_file_selected = false
		6: # Export
			if $ExportDialog.was_exported == false:
				$ExportDialog.popup_centered()
				Global.dialog_open(true)
			else:
				$ExportDialog.external_export()
		7: # Export as
			$ExportDialog.popup_centered()
			Global.dialog_open(true)
		8: # Quit
			show_quit_dialog()


func edit_menu_id_pressed(id : int) -> void:
	match id:
		0: # Undo
			Global.undo_redo.undo()
		1: # Redo
			redone = true
			Global.undo_redo.redo()
			redone = false
		2: # Clear selection
			Global.canvas.handle_undo("Rectangle Select")
			Global.selection_rectangle.polygon[0] = Vector2.ZERO
			Global.selection_rectangle.polygon[1] = Vector2.ZERO
			Global.selection_rectangle.polygon[2] = Vector2.ZERO
			Global.selection_rectangle.polygon[3] = Vector2.ZERO
			Global.selected_pixels.clear()
			Global.canvas.handle_redo("Rectangle Select")
		3: # Preferences
			$PreferencesDialog.popup_centered(Vector2(400, 280))
			Global.dialog_open(true)


func view_menu_id_pressed(id : int) -> void:
	match id:
		0: # Tile mode
			Global.tile_mode = !Global.tile_mode
			view_menu.set_item_checked(0, Global.tile_mode)
		1: # Show grid
			Global.draw_grid = !Global.draw_grid
			view_menu.set_item_checked(1, Global.draw_grid)
		2: # Show rulers
			Global.show_rulers = !Global.show_rulers
			view_menu.set_item_checked(2, Global.show_rulers)
			Global.horizontal_ruler.visible = Global.show_rulers
			Global.vertical_ruler.visible = Global.show_rulers
		3: # Show guides
			Global.show_guides = !Global.show_guides
			view_menu.set_item_checked(3, Global.show_guides)
			for canvas in Global.canvases:
				for guide in canvas.get_children():
					if guide is Guide:
						guide.visible = Global.show_guides
		4: # Show animation timeline
			Global.show_animation_timeline = !Global.show_animation_timeline
			view_menu.set_item_checked(4, Global.show_animation_timeline)
			Global.animation_timeline.visible = Global.show_animation_timeline

	Global.canvas.update()


func image_menu_id_pressed(id : int) -> void:
	if Global.layers[Global.current_layer][2]: # No changes if the layer is locked
		return
	match id:
		0: # Scale Image
			$ScaleImage.popup_centered()
			Global.dialog_open(true)

		1: # Crop Image
			# Use first cel as a starting rectangle
			var used_rect : Rect2 = Global.canvases[0].layers[0][0].get_used_rect()

			for c in Global.canvases:
				# However, if first cel is empty, loop through all cels until we find one that isn't
				for layer in c.layers:
					if used_rect != Rect2(0, 0, 0, 0):
						break
					else:
						if layer[0].get_used_rect() != Rect2(0, 0, 0, 0):
							used_rect = layer[0].get_used_rect()

				# Merge all layers with content
				for layer in c.layers:
						if layer[0].get_used_rect() != Rect2(0, 0, 0, 0):
							used_rect = used_rect.merge(layer[0].get_used_rect())

			# If no layer has any content, just return
			if used_rect == Rect2(0, 0, 0, 0):
				return

			var width := used_rect.size.x
			var height := used_rect.size.y
			Global.undos += 1
			Global.undo_redo.create_action("Scale")
			for c in Global.canvases:
				Global.undo_redo.add_do_property(c, "size", Vector2(width, height).floor())
				# Loop through all the layers to crop them
				for j in range(Global.canvas.layers.size() - 1, -1, -1):
					var sprite : Image = c.layers[j][0].get_rect(used_rect)
					Global.undo_redo.add_do_property(c.layers[j][0], "data", sprite.data)
					Global.undo_redo.add_undo_property(c.layers[j][0], "data", c.layers[j][0].data)

				Global.undo_redo.add_undo_property(c, "size", c.size)
			Global.undo_redo.add_undo_method(Global, "undo", Global.canvases)
			Global.undo_redo.add_do_method(Global, "redo", Global.canvases)
			Global.undo_redo.commit_action()

		2: # Flip Horizontal
			var canvas : Canvas = Global.canvas
			canvas.handle_undo("Draw")
			canvas.layers[Global.current_layer][0].unlock()
			canvas.layers[Global.current_layer][0].flip_x()
			canvas.layers[Global.current_layer][0].lock()
			canvas.handle_redo("Draw")

		3: # Flip Vertical
			var canvas : Canvas = Global.canvas
			canvas.handle_undo("Draw")
			canvas.layers[Global.current_layer][0].unlock()
			canvas.layers[Global.current_layer][0].flip_y()
			canvas.layers[Global.current_layer][0].lock()
			canvas.handle_redo("Draw")

		4: # Rotate
			var image : Image = Global.canvas.layers[Global.current_layer][0]
			$RotateImage.set_sprite(image)
			$RotateImage.popup_centered()
			Global.dialog_open(true)

		5: # Invert Colors
			var image : Image = Global.canvas.layers[Global.current_layer][0]
			Global.canvas.handle_undo("Draw")
			for xx in image.get_size().x:
				for yy in image.get_size().y:
					var px_color = image.get_pixel(xx, yy).inverted()
					if px_color.a == 0:
						continue
					image.set_pixel(xx, yy, px_color)
			Global.canvas.handle_redo("Draw")

		6: # Desaturation
			var image : Image = Global.canvas.layers[Global.current_layer][0]
			Global.canvas.handle_undo("Draw")
			for xx in image.get_size().x:
				for yy in image.get_size().y:
					var px_color = image.get_pixel(xx, yy)
					if px_color.a == 0:
						continue
					var gray = image.get_pixel(xx, yy).v
					px_color = Color(gray, gray, gray, px_color.a)
					image.set_pixel(xx, yy, px_color)
			Global.canvas.handle_redo("Draw")

		7: # Outline
			$OutlineDialog.popup_centered()
			Global.dialog_open(true)

		8: # HSV
			$HSVDialog.popup_centered()
			Global.dialog_open(true)


func help_menu_id_pressed(id : int) -> void:
	match id:
		0: # Splash Screen
			$SplashDialog.popup_centered()
			Global.dialog_open(true)
		1: # Online Docs
			OS.shell_open("https://orama-interactive.github.io/Pixelorama-Docs/")
		2: # Issue Tracker
			OS.shell_open("https://github.com/Orama-Interactive/Pixelorama/issues")
		3: # Changelog
			OS.shell_open("https://github.com/Orama-Interactive/Pixelorama/blob/master/CHANGELOG.md#v07---2020-05-16")
		4: # About Pixelorama
			$AboutDialog.popup_centered()
			Global.dialog_open(true)


func load_last_project() -> void:
	# Check if any project was saved or opened last time
	if Global.config_cache.has_section_key("preferences", "last_project_path"):
		# Check if file still exists on disk
		var file_path = Global.config_cache.get_value("preferences", "last_project_path")
		var file_check := File.new()
		if file_check.file_exists(file_path): # If yes then load the file
			_on_OpenSprite_file_selected(file_path)
		else:
			# If file doesn't exist on disk then warn user about this
			Global.error_dialog.set_text("Cannot find last project file.")
			Global.error_dialog.popup_centered()
			Global.dialog_open(true)


func _on_UnsavedCanvasDialog_confirmed() -> void:
	if unsaved_canvas_state == 0: # New image
		$CreateNewImage.popup_centered()
		Global.dialog_open(true)
	elif unsaved_canvas_state == 2: # Open last project
		load_last_project()


func _on_OpenSprite_file_selected(path : String) -> void:
	OpenSave.open_pxo_file(path)

	$SaveSprite.current_path = path
	# Set last opened project path and save
	Global.config_cache.set_value("preferences", "last_project_path", path)
	Global.config_cache.save("user://cache.ini")
	$ExportDialog.file_name = path.get_file().trim_suffix(".pxo")
	$ExportDialog.directory_path = path.get_base_dir()
	$ExportDialog.was_exported = false
	file_menu.set_item_text(3, tr("Save") + " %s" % path.get_file())
	file_menu.set_item_text(6, tr("Export"))


func _on_SaveSprite_file_selected(path : String) -> void:
	OpenSave.save_pxo_file(path, false)

	# Set last opened project path and save
	Global.config_cache.set_value("preferences", "last_project_path", path)
	Global.config_cache.save("user://cache.ini")
	$ExportDialog.file_name = path.get_file().trim_suffix(".pxo")
	$ExportDialog.directory_path = path.get_base_dir()
	$ExportDialog.was_exported = false
	file_menu.set_item_text(3, tr("Save") + " %s" % path.get_file())

	if is_quitting_on_save:
		_on_QuitDialog_confirmed()


func _on_ImportSprites_popup_hide() -> void:
	if !opensprite_file_selected:
		_can_draw_true()


func _can_draw_true() -> void:
	Global.dialog_open(false)


func show_quit_dialog() -> void:
	if !$QuitDialog.visible:
		if !Global.project_has_changed:
			$QuitDialog.call_deferred("popup_centered")
		else:
			$QuitAndSaveDialog.call_deferred("popup_centered")

	Global.dialog_open(true)


func _on_QuitAndSaveDialog_custom_action(action : String) -> void:
	if action == "Save":
		is_quitting_on_save = true
		$SaveSprite.popup_centered()
		$QuitDialog.hide()
		Global.dialog_open(true)
		OpenSave.remove_backup()


func _on_QuitDialog_confirmed() -> void:
	# Darken the UI to denote that the application is currently exiting
	# (it won't respond to user input in this state).
	modulate = Color(0.5, 0.5, 0.5)
	OpenSave.remove_backup()
	get_tree().quit()


func _on_BackupConfirmation_confirmed(project_path : String, backup_path : String) -> void:
	OpenSave.reload_backup_file(project_path, backup_path)
	OpenSave.autosave_timer.start()
	$ExportDialog.file_name = OpenSave.current_save_path.get_file().trim_suffix(".pxo")
	$ExportDialog.directory_path = OpenSave.current_save_path.get_base_dir()
	$ExportDialog.was_exported = false
	file_menu.set_item_text(3, tr("Save") + " %s" % OpenSave.current_save_path.get_file())
	file_menu.set_item_text(6, tr("Export"))


func _on_BackupConfirmation_delete(project_path : String, backup_path : String) -> void:
	OpenSave.remove_backup_by_path(project_path, backup_path)
	OpenSave.autosave_timer.start()
	# Reopen last project
	if Global.open_last_project:
		load_last_project()
