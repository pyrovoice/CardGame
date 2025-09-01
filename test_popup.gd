extends Node
# Simple test script to verify popup functionality

func _ready():
	print("Testing card popup functionality...")
	
	# Test CardPopupManager loading
	var popup_scene = preload("res://Shared/scenes/CardPopupManager.tscn")
	if popup_scene:
		print("✓ CardPopupManager scene loads successfully")
		var popup_manager = popup_scene.instantiate()
		if popup_manager:
			print("✓ CardPopupManager instantiates successfully")
			popup_manager.queue_free()
	else:
		print("✗ Failed to load CardPopupManager scene")
	
	# Test CardLoader
	if CardLoader:
		print("✓ CardLoader is available")
		CardLoader.load_all_cards()
		if CardLoader.cardData.size() > 0:
			print("✓ CardLoader loaded ", CardLoader.cardData.size(), " cards")
		else:
			print("✗ CardLoader has no cards")
	else:
		print("✗ CardLoader not available")
	
	print("Test completed")
