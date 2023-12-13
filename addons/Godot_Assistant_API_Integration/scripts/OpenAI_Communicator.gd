extends Node
var API_KEY: String
var assistant_id: String
var http_Request: HTTPRequest
var model = "gpt-4-1106-preview"

var max_tokens: int = 1024
var temperature: float = 0

var thread_base_url: String = "https://api.openai.com/v1/threads"
var thread_id: String
var thread_url: String
var run_id: String
var run_url: String
var run_check_url:String

var http_request: HTTPRequest
var headers: Array[String]

var processing_status: String
var raw_answer:String

var checking_in_progress:int=0

signal request_thread_completed
signal add_message_to_thread_completed
signal run_the_assistant_completed
signal answer_is_ready_on_openai
signal answer_is_ready_on_local


func _ready() -> void:
	_get_API_key()
	_set_headers()


func _get_API_key():
	var openai_api_key = OS.get_environment("OPENAI_API_KEY")
	if openai_api_key != null:
		API_KEY = openai_api_key
	else:
		print("Environment Variable 'OPENAI_API_KEY' not set.")

func set_API_KEY(new_API_KEY:String):
	API_KEY=new_API_KEY

func set_assistant_id(new_assistant_id: String):
	assistant_id=new_assistant_id

func get_assistant_id():
	return assistant_id
	
func _set_headers():
	headers = [		
		"Authorization: Bearer " + API_KEY,
		"OpenAI-Beta: assistants=v1",
		"Content-Type: application/json"
	]

func clear():
	thread_id=""
	thread_url="" 
	run_id=""
	run_url=""
	run_check_url=""	

	
func send_message(final_prompt:String):
	if thread_id.is_empty() or thread_url.is_empty():
#		print("New thread! (new session)")
		_request_thread()
		await request_thread_completed
	_add_message_to_thread(final_prompt)
	await add_message_to_thread_completed
	_run_the_assistant()
	await run_the_assistant_completed
	_repeate_check_run_status()
	
	await answer_is_ready_on_openai
	_get_response()


func _request_thread():
#	print("--------------------")
#	print("request_thread()")
	http_request = HTTPRequest.new()
	http_request.request_completed.connect(_on_thread_request_completed)
	
	add_child(http_request)
	var error = http_request.request(thread_base_url, headers, HTTPClient.METHOD_POST)
	if error != OK:
		print("_request_thread request failed! error:" + str(error))


func _on_thread_request_completed(result, response_code, headers, body):
	if response_code==401:
		print("Your API Key stored in environment variable is incorrect or you run out of tokens...")
		print("After changing your API key in environment variable, remember to reboot your windows.")
		return
	if response_code != 200 :
		print("_on_thread_request_completed failed on server! response_code: "+ str(response_code))
		return

	var body_string = body.get_string_from_utf8()

	var json = JSON.new()
	var error = json.parse(body_string)
	if error != OK:
		print("_on_thread_request_completed JSON parsing failed... error: ", error)
		return	
	var response = json.get_data()
	if response and response.has("id"):
		thread_id = response["id"]
#		print("Thread ID: " + thread_id)
		_set_thread_URL()
		_set_run_URL()
	else:
		print("_on_thread_request_completed failed to parse response!")
	http_request.queue_free()
	request_thread_completed.emit()


func _set_thread_URL():
	thread_url = thread_base_url + "/" + thread_id + "/messages"
#	print("thread_url: " + thread_url) 


func _set_run_URL():
	run_url = thread_base_url + "/" + thread_id + "/runs"
#	print("run_url: " + run_url)


func _set_run_check_URL():
	run_check_url = run_url + "/" + run_id
#	print("run_check_url: " + run_check_url)


func _add_message_to_thread(message: String):
#	print("--------------------")
#	print("_add_message_to_thread()")
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_add_message_to_thread_completed)
	var body = JSON.new().stringify({"role": "user", "content": message})
	var error = http_request.request(thread_url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("_add_message_to_thread request failed")

func _on_add_message_to_thread_completed(result, response_code, headers, body):
	if response_code != 200:
		print("_on_add_message_to_thread_completed failed on server! response_code: "+str(response_code))

	var body_string = body.get_string_from_utf8()

	var json = JSON.new()
	var error = json.parse(body_string)
	if error != OK:
		print("_on_add_message_to_thread_completed JSON parsing failed: ", error)
		return

	var response = json.get_data()
	if response and response.has("id"):
		var MsgID = response["id"]
#		print("Message ID: " + MsgID)
	else:
		print("_on_add_message_to_thread_completed failed to parse response!")
	http_request.queue_free()
	add_message_to_thread_completed.emit()


func _run_the_assistant():
#	print("--------------------")
#	print("_run_the_assistant()")
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_run_the_assistant_completed)
	var body = JSON.new().stringify({"assistant_id": assistant_id})
	var error = http_request.request(run_url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("_run_the_assistant request failed...error: "+str(error))

func _on_run_the_assistant_completed(result, response_code, headers, body):
	if response_code != 200 and response_code!=404:
		print("_on_run_the_assistant_completed failled on server! response_code: "+str(response_code))	
	if response_code==404:
		print("Assistant ID is incorrect, please reactivate the addon and enter the right one.")
		clear_assistant_id_text()
		return		
		
	var body_string = body.get_string_from_utf8()
	var json = JSON.new()
	var error = json.parse(body_string)
	if error != OK:
		print("_on_run_the_assistant_completed JSON parsing failed : ", error)
		return

	var response = json.get_data()
	if response and response.has("id") and response.has("status"):
		run_id = response["id"]
		processing_status = response["status"]		
#		print("run ID : " + run_id)
		_set_run_check_URL()
	else:
		print("_on_run_the_assistant_completed failed to parse response!")
	http_request.queue_free()
	checking_in_progress=0
	run_the_assistant_completed.emit()	


func _repeate_check_run_status():	
#	print("--------------------")
#	print("_repeate_check_run_status()")
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.8
	timer.one_shot = true
	timer.timeout.connect(func():
		_check_run_status()
		timer.queue_free())	
	timer.start()


func _check_run_status():	
#	print("--------------------")
#	print("_check_run_status()")
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_check_run_status)	
	var error = http_request.request(run_check_url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		print("_check_run_status request failed! error: "+str(error))
	

func _on_check_run_status(result, response_code, headers, body):
	if response_code != 200 and response_code!=31:
		print("_on_check_run_status failed on server! "+str(response_code))
	if response_code==31:
		#print("Assistant ID is incorrect...")
		pass
	
	var body_string = body.get_string_from_utf8()
	var json = JSON.new()
	var error = json.parse(body_string)
	if error != OK:
		print("_on_check_run_status JSON parsing failed : ", error)
		return
	var response = json.get_data()
	if response and response.has("status"):		
		processing_status = response["status"]				
		if processing_status=="in_progress":
			checking_in_progress+=1#		
		if checking_in_progress==1:
			print("Processing status : " + processing_status)		
		if processing_status!="completed":
			_repeate_check_run_status()
		else :
#			print("answer_is_ready")
			checking_in_progress=0
			answer_is_ready_on_openai.emit()
	else:
		print("_on_check_run_status failed to parsing response!")	
	http_request.queue_free()


func _get_response():
	print("Processing status : completed")
#	print("_get_response()")
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_get_response)	
#	print("thread_url: "+thread_url)
#	print(headers)
	var error = http_request.request(thread_url, headers, HTTPClient.METHOD_GET)	
	if error != OK:
		print("_get_response request failed! error: "+str(error))


func _on_get_response(result, response_code, headers, body):
#	print("--------------------")
#	print("_on_get_response()")
	if response_code != 200:
		print("_on_get_response request failed on server!"+ str(response_code))

	var body_string = body.get_string_from_utf8()
	var json = JSON.new()
	var error = json.parse(body_string)
	if error != OK:
		print("_on_get_response JSON parsing failed: ", error)
		return	
	var full_response = json.get_data()	
	if full_response and full_response.has("data"):
		var data = full_response["data"]			
		raw_answer= data[0]["content"][0]["text"]["value"]
#		print("raw_answer: \n"+raw_answer+"\n\n")			
		answer_is_ready_on_local.emit()
	else:
		print("_on_get_response failed to parsing response!")
	if http_request !=null:
		http_request.queue_free()


func get_raw_answer()->String:
	return raw_answer


func clear_assistant_id_text():
	var file = FileAccess.open("res://addons/Godot_Assistant_API_Integration/Assistant_ID.txt", FileAccess.WRITE)
	file.store_string("")
	


