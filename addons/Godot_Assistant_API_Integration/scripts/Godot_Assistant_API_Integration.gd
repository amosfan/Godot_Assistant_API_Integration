@tool
extends EditorPlugin
enum mode { Ask, Summary, Action, Help }
var current_mode: int

var openAICommunicator: Node
var textHandler: TextHandler

var is_API_Key_ready:=false
var is_Assistant_ID_ready:=false
var is_user_ready=false

var assistant_id:String
var assistant_id_leneEdit
var request1:Label
var request2:Label
var warning_label:Label

var chatDock: Control
var Ask_button: Button
var Summary_button: Button
var Action_button: Button
var Help_button: Button
var Clear_button: Button
var richTextLabel:RichTextLabel
var textEdit: TextEdit

var summary_prompt: String
var Action_prompt: String
var Help_prompt: String
var final_prompt: String

var popup: PackedScene
var popup_timeout := 1.4

var cursor_position: int


var addon_startup:PackedScene= preload("res://addons/Godot_Assistant_API_Integration/UI/addon_starup.tscn")
var addon_startup_instance
var DoneBtn:Button
var CancelBtn:Button

signal popup_finished
signal user_press_done


func _enter_tree() -> void:		
	_prepare_textHandler()
	_prepare_openAICommunicator()	
	_check_API_Key()
	_check_Assistant_ID()
	_show_addon_startup()	


func _ready() -> void:
	if not is_user_ready:
		await user_press_done
		if not is_user_ready:
			return		
	#print("--------------")
	#print("on ready")
	#print("is_API_Key_ready: "+str(is_API_Key_ready))
	#print("is_Assistant_ID_ready: "+str(is_Assistant_ID_ready))
	#print("is_user_ready: "+str(is_user_ready))
	#print("---------------")
	_add_ChatDock_to_editor()
	_prepare_UI()
	_connect_all_buttons()
	_prepare_prompts()	
	pass
	

func _check_API_Key():
	var openai_api_key = OS.get_environment("OPENAI_API_KEY")
	#print("openai_api_key: "+openai_api_key)		
	if openai_api_key != "" and textHandler.check_API_key_format(openai_api_key):
		openAICommunicator.set_API_KEY(openai_api_key)
		is_API_Key_ready=true	
	else:
		print("Environment Variable 'OPENAI_API_KEY' not set.")
		is_API_Key_ready=false
	
		
func _check_Assistant_ID():		
	var is_Assistant_ID_File_Exist = FileAccess.file_exists("res://addons/Godot_Assistant_API_Integration/Assistant_ID.txt")
	if is_Assistant_ID_File_Exist:
		var txtfile = FileAccess.open("res://addons/Godot_Assistant_API_Integration/Assistant_ID.txt", FileAccess.READ)	
		var content = txtfile.get_as_text()
		var check_result=textHandler.check_Assistant_ID_format(content)
		if check_result:
			is_Assistant_ID_ready=true
			openAICommunicator.set_assistant_id(content)
	#print(is_Assistant_ID_ready)	
	#print(assistant_id)	


func save_assistant_id(assistant_id:String):
	var file = FileAccess.open("res://addons/Godot_Assistant_API_Integration/Assistant_ID.txt", FileAccess.WRITE)
	file.store_string(assistant_id)


func _show_addon_startup():		
	if is_API_Key_ready==false or is_Assistant_ID_ready==false:
		is_user_ready=false
		addon_startup_instance=	addon_startup.instantiate()
		add_child(addon_startup_instance)
		_prepate_addon_startup_buttons()	
		_hide_passed_condition()		
	else:
		is_user_ready=true
		
	#print("is_API_Key_ready: "+str(is_API_Key_ready))
	#print("is_Assistant_ID_ready: "+str(is_Assistant_ID_ready))
	#print("is_user_ready: "+str(is_user_ready))
	#print("---------------")

func _prepate_addon_startup_buttons():
	#print("is_API_Key_ready:"+str(is_API_Key_ready))
	assistant_id_leneEdit=addon_startup_instance.get_node("MarginContainer/VBoxContainer/assistant_id")
	(assistant_id_leneEdit as LineEdit).text_changed.connect(_on_assistant_id_leneEdit_text_changed)
	request1=addon_startup_instance.get_node("MarginContainer/VBoxContainer/request1")
	request2=addon_startup_instance.get_node("MarginContainer/VBoxContainer/request2")		
	warning_label=addon_startup_instance.get_node("MarginContainer/VBoxContainer/warning_label")		
	DoneBtn=addon_startup_instance.get_node("MarginContainer/VBoxContainer/HBoxContainer/DoneBtn")
	DoneBtn.pressed.connect(_on_DoneBtn_pressed)	
	CancelBtn=addon_startup_instance.get_node("MarginContainer/VBoxContainer/HBoxContainer/CancelBtn")
	CancelBtn.pressed.connect(_on_CancelBtn_pressed)


func _hide_passed_condition():
	if is_API_Key_ready:
		request1.visible=false
	if is_Assistant_ID_ready:
		request2.visible=false
		assistant_id_leneEdit.visible=false

func _on_assistant_id_leneEdit_text_changed(new_text: String):
	var result=textHandler.check_Assistant_ID_format(new_text)
	if result==false:
		DoneBtn.disabled=true
		warning_label.visible=true
	else:
		DoneBtn.disabled=false
		warning_label.visible=false
		
		
func _on_DoneBtn_pressed():
	save_assistant_id(assistant_id_leneEdit.text)
	openAICommunicator.set_assistant_id(assistant_id_leneEdit.text)
	#print("openAICommunicator.get_assistant_id(): "+openAICommunicator.get_assistant_id())			
	is_Assistant_ID_ready=true
	if is_API_Key_ready and is_Assistant_ID_ready:
		is_user_ready=true
	user_press_done.emit()
	addon_startup_instance.queue_free()

func _on_CancelBtn_pressed():
	is_user_ready=false
	addon_startup_instance.queue_free()
	
func _prepare_prompts():
	summary_prompt = "Summarize GDScript function below within 25 words: \n"
	Action_prompt = "Write ONLY function(s) (GDScript version 4.2) for the requirement below (Code only,No explanation needed, in-line comments is fine): \n"
	Help_prompt = "Check if there are any issues with the following GDScript code: \n"


func _exit_tree() -> void:
	if is_instance_valid(chatDock):
		remove_control_from_docks(chatDock)	
		chatDock.queue_free()
	


func _prepare_UI() -> void:
	Ask_button = chatDock.get_node("VBox1/VBox2/HBox1/Ask") as Button
	Summary_button = chatDock.get_node("VBox1/VBox2/HBox2/Summary") as Button
	Action_button = chatDock.get_node("VBox1/VBox2/HBox2/Action") as Button
	Help_button = chatDock.get_node("VBox1/VBox2/HBox2/Help") as Button
	Clear_button = chatDock.get_node("VBox1/VBox2/HBox2/Clear") as Button
	
	richTextLabel=chatDock.get_node("VBox1/RichTextLabel") as RichTextLabel
	
	textEdit = chatDock.get_node("VBox1/VBox2/HBox1/TextEdit")
	popup = preload("res://addons/Godot_Assistant_API_Integration/UI/popup_panel.tscn")


func _prepare_textHandler():
	textHandler = TextHandler.new()


func _prepare_openAICommunicator():
	openAICommunicator = (
		preload("res://addons/Godot_Assistant_API_Integration/scripts/OpenAI_Communicator.gd").new()
	)
	add_child(openAICommunicator)
	openAICommunicator.answer_is_ready_on_local.connect(_on_answer_is_ready_on_local)


func _add_ChatDock_to_editor():
	chatDock = preload("res://addons/Godot_Assistant_API_Integration/UI/chat.tscn").instantiate()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UL, chatDock)


func _connect_all_buttons():
	Ask_button.pressed.connect(_on_Ask_pressed)
	Summary_button.pressed.connect(_on_Summary_pressed)
	Action_button.pressed.connect(_on_Action_pressed)
	Help_button.pressed.connect(_on_Help_pressed)
	Clear_button.pressed.connect(_on_Clear_pressed)
	popup_finished.connect(_on_popup_finished)


func _on_popup_finished():
	_free_all_buttons()


func _on_Ask_pressed():
	if not _is_textEdit_ready():
		return
	current_mode = mode.Ask

	_add_input_to_display()
	_disable_all_buttons()
	_clear_final_prompt()
	_add_to_final_prompt(textEdit.text)
#	_print_final_prompt()
	_clear_input()
	openAICommunicator.send_message(final_prompt)


func _add_input_to_display():
	_add_speaker_to_display("You", Color.DODGER_BLUE)
	_add_to_display(textEdit.text)


func _add_to_display(info: String):
	richTextLabel.append_text(info + "\n\n")


func _display_assistant_response_on_dock():
	var raw_answer = openAICommunicator.get_raw_answer()
	raw_answer = textHandler.remove_gdscript_string(raw_answer)
	raw_answer = textHandler.replace_code_blocks(raw_answer)
#	print("\nformated answer: "+raw_answer+"\n")
	_add_speaker_to_display("Assistant", Color.DARK_ORANGE)
	_add_to_display(raw_answer)
	_add_horizon_line_to_display()


func _add_horizon_line_to_display():
	richTextLabel.append_text("[center]--------------------[/center]\n")
	pass


func _add_speaker_to_display(speaker: String, color: Color):
	richTextLabel.push_color(color)
	richTextLabel.push_bold()
	richTextLabel.append_text(speaker + " :\n")
	richTextLabel.pop()
	richTextLabel.pop()


func _is_textEdit_ready() -> bool:
	if (not is_instance_valid(textEdit)) or textEdit.text.length()<10:
		return false
	return true


func _clear_input():
	textEdit.text = ""


func _clear_final_prompt():
	final_prompt = ""


func _add_to_final_prompt(text: String):
	final_prompt += text


func _on_Summary_pressed():	
	var selection = await _get_selection()
	
	if selection.length() <= 5:
		_show_popup()
		_disable_all_buttons()
		return
	current_mode = mode.Summary
	_disable_all_buttons()
	_get_cursor_position_for_Summary()
	_clear_final_prompt()
	_add_to_final_prompt(summary_prompt + selection)
	_add_speaker_to_display("You", Color.DODGER_BLUE)
	_add_to_display(final_prompt)
#	_print_final_prompt()
	openAICommunicator.send_message(final_prompt)


func _print_final_prompt():
	print("\n" + "final_prompt: \n" + final_prompt + "\n")


func _on_Action_pressed():
	_add_lines_at_last_line(10)	
	var selection = await _get_selection()
	if selection.length() <= 5:
		_show_popup()
		_disable_all_buttons()
		return	
	current_mode = mode.Action
	_disable_all_buttons()
	_get_cursor_position_for_Action()
	_clear_final_prompt()
	selection = textHandler.remove_hash_mark(selection)
	_add_to_final_prompt(Action_prompt + selection)
	_add_speaker_to_display("You", Color.DODGER_BLUE)
	_add_to_display(final_prompt)
#	_print_final_prompt()
	openAICommunicator.send_message(final_prompt)
	


func _disable_all_buttons():
	Ask_button.disabled = true
	Summary_button.disabled = true
	Action_button.disabled = true
	Help_button.disabled = true
	Clear_button.disabled = true


func _free_all_buttons():
	Ask_button.disabled = false
	Summary_button.disabled = false
	Action_button.disabled = false
	Help_button.disabled = false
	Clear_button.disabled = false


func _on_Help_pressed():
	var selection = await _get_selection()
	if selection.length() <= 5:
		_show_popup()
		_disable_all_buttons()
		return
	current_mode = mode.Help
	_disable_all_buttons()
#	_get_cursor_position_for_Summary()
	_clear_final_prompt()
	_add_to_final_prompt(Help_prompt + selection)
	_add_speaker_to_display("You", Color.DODGER_BLUE)
	_add_to_display(final_prompt)
#	_print_final_prompt()
	openAICommunicator.send_message(final_prompt)


func _get_selection() -> String:
	await get_tree().create_timer(0.2).timeout
	var currentScriptSelection = get_editor_interface().get_script_editor().get_current_editor()
	var codeEditor = currentScriptSelection.get_base_editor()
	var lines =codeEditor.get_line_count()	
	if not codeEditor.has_selection():
		return ""
	return codeEditor.get_selected_text()


func _get_cursor_position_for_Summary():
	var currentScriptSelection = get_editor_interface().get_script_editor().get_current_editor()
	var codeEditor = currentScriptSelection.get_base_editor()
	cursor_position = codeEditor.get_selection_from_line()
	_update_current_line_minus()
#	print("final cursor_position : " + str(cursor_position))


func _update_current_line_minus():
	var currentScriptSelection = get_editor_interface().get_script_editor().get_current_editor()
	var codeEditor = currentScriptSelection.get_base_editor()
	var checked_line_text: String = codeEditor.get_line(cursor_position)
	checked_line_text = checked_line_text.strip_edges()
	if not checked_line_text.is_empty():
		cursor_position -= 1
		_update_current_line_minus()
	else:
		cursor_position += 1


func _get_cursor_position_for_Action():
	var currentScriptSelection = get_editor_interface().get_script_editor().get_current_editor()
	var codeEditor = currentScriptSelection.get_base_editor()
	cursor_position = codeEditor.get_selection_to_line()
#	print("base cursor_position: " + str(cursor_position))
	_update_current_line_plus()
#	print("Action cursor_position: " + str(cursor_position))


func _update_current_line_plus():
	var currentScriptSelection = get_editor_interface().get_script_editor().get_current_editor()
	var codeEditor = currentScriptSelection.get_base_editor()
	var checked_line_text: String = codeEditor.get_line(cursor_position)
	checked_line_text = checked_line_text.strip_edges()
	if not checked_line_text.is_empty():
		cursor_position += 1
		_update_current_line_plus()
	else:
#		cursor_position += 1
		pass


func _on_Clear_pressed():
	richTextLabel.clear()
	richTextLabel.text=""
	textEdit.clear()
	openAICommunicator.clear()


func _on_answer_is_ready_on_local():
	_display_Assistant_answer()
	_free_all_buttons()


func _display_Assistant_answer():
#	print("current_mode: "+str(current_mode))
	match current_mode:
		mode.Ask:
			_display_assistant_response_on_dock()
		mode.Summary:
			_display_assistant_response_on_dock()			
			_display_assistant_summary_response_on_scriptEditor()
		mode.Action:
			_display_assistant_response_on_dock()
			_display_assistant_action_response_on_scriptEditor()
			_remove_trailing_empty_lines()	
		mode.Help:
			_display_assistant_response_on_dock()


func _display_assistant_summary_response_on_scriptEditor():
	var currentScriptSelection = get_editor_interface().get_script_editor().get_current_editor()
	var codeEditor = currentScriptSelection.get_base_editor()
	var assistant_response = openAICommunicator.get_raw_answer()
	assistant_response = textHandler.format_for_summary(assistant_response)
	codeEditor.insert_line_at(cursor_position, assistant_response)


func _display_assistant_action_response_on_scriptEditor():
	var currentScriptSelection = get_editor_interface().get_script_editor().get_current_editor()
	var codeEditor = currentScriptSelection.get_base_editor()
	var assistant_response = openAICommunicator.get_raw_answer()
	assistant_response = textHandler.format_for_action(assistant_response)
#	print("final cursor_position: " + str(cursor_position))
	codeEditor.insert_line_at(cursor_position, assistant_response)


func _show_popup():
	var popup_instance = popup.instantiate()
	add_child(popup_instance)
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = popup_timeout
	timer.one_shot = true
	var _on_popup_timeout=func ():
		popup_finished.emit()
		popup_instance.queue_free()
		timer.queue_free()
	timer.timeout.connect(_on_popup_timeout)
	timer.start()

func _add_lines_at_last_line(add_lines:int):
	var currentScriptSelection = get_editor_interface().get_script_editor().get_current_editor()
	var codeEditor = currentScriptSelection.get_base_editor()
	var last_line=codeEditor.get_line_count()-1
	
	for i in range(add_lines):    
		codeEditor.insert_line_at(last_line,"\n")
	
func _remove_trailing_empty_lines():
	var last_non_empty_line = _find_last_non_empty_line()
#	print("last_non_empty_line: "+str(last_non_empty_line))
	var currentScriptSelection = get_editor_interface().get_script_editor().get_current_editor()
	var codeEditor = currentScriptSelection.get_base_editor()
	if last_non_empty_line != -1 and last_non_empty_line != codeEditor.get_line_count() - 1:
		codeEditor.remove_text(last_non_empty_line + 1, 0, codeEditor.get_line_count()-1, 0)


func _find_last_non_empty_line() -> int:
	var currentScriptSelection = get_editor_interface().get_script_editor().get_current_editor()
	var codeEditor = currentScriptSelection.get_base_editor()
	var line_count = codeEditor.get_line_count()
	for line_number in range(line_count - 1, -1, -1):
		var line = codeEditor.get_line(line_number)
		if line.strip_edges() != "":
			return line_number
	return -1	


