extends PopupPanel
@onready var label: Label = %Label


func set_message(message:String):
	label.text = message

