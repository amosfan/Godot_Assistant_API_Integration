extends Node
class_name TextHandler

var raw_text:String


func format_for_summary(raw_text: String,line_Length_limit:int=30) -> String:
	var prepared_text = raw_text.strip_edges().replace("\n", "")
	var summary = "# "	
	var words = prepared_text.split(" ")
	var current_line_length=0
	
	for word in words:
		if current_line_length > line_Length_limit:
			summary += "\n# "			
			current_line_length=0
		summary += word + " "	
		current_line_length+=word.length()
	return summary.strip_edges(false, true)


func format_for_action(original: String) -> String:
	var result = original.replace("```", "")  
	result = result.replace("gdscript", "GDScript")  
	result = _remove_first_line(result)	
	result = result.replace("    ", "\t")
	return result


func _remove_first_line(text: String) -> String:
	var newline_index = text.find("\n")
	if newline_index != -1:
		return text.substr(newline_index + 1)
	return text  


func remove_hash_mark(original: String) -> String:
	return original.replace("#", "")


func remove_gdscript_string(original: String) -> String:
	return original.replace("gdscript", "")
	

func replace_code_blocks(text: String) -> String:
	var regex = RegEx.new()
	var error = regex.compile("(?s)```(.*?)```")
	if error != OK:
		print("replace_code_blocks RegEx compile error")
		return text
	
	var result = regex.sub(text, "[code]$1[/code]", true)
#	print("replaced code: \n" + result)
	return result

func check_Assistant_ID_format(checked_string: String) -> bool:
	var regex = RegEx.new()
	regex.compile("^asst_[a-zA-Z0-9]{24}$")
	var result = regex.search(checked_string)
	return result != null	

func check_API_key_format(checked_string)->bool:
	var regex = RegEx.new()
	regex.compile("^sk-[a-zA-Z0-9]{48}$")
	var result = regex.search(checked_string)
	return result != null
		
