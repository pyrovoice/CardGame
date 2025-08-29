extends Control
class_name CardAlbum

@onready var card_grid: GridContainer = $VBoxContainer/CardContainer/CardGrid
@onready var back_button: Button = $VBoxContainer/BackButton
@onready var page_label: Label = $"page_label"
@onready var prev_button: Button = $"prev_button"
@onready var next_button: Button = $"next_button"

# Card popup manager - will be added to the scene
var card_popup_manager: Control

# Grid configuration
const CARDS_PER_PAGE = 10
const GRID_COLUMNS = 5

var all_cards: Array[CardData] = []
var current_page: int = 0
var total_pages: int = 0
var card_instances: Array[Card2D] = []

signal page_changed(page: int)

func _ready():
	# Load the shared popup manager
	var popup_scene = preload("res://Shared/scenes/CardPopupManager.tscn")
	card_popup_manager = popup_scene.instantiate()
	add_child(card_popup_manager)
	
	load_all_cards()
	setup_ui()
	display_current_page()

func load_all_cards():
	# Load all cards using the CardLoader
	CardLoader.load_all_cards()
	all_cards = CardLoader.cardData.duplicate()
	
	if all_cards.size() == 0:
		push_error("No cards found!")
		return
	
	while all_cards.size() < 30:
		all_cards.append_array(all_cards.duplicate())
	# Calculate total pages
	total_pages = ceili(float(all_cards.size()) / float(CARDS_PER_PAGE))
	print("Loaded ", all_cards.size(), " cards across ", total_pages, " pages")

func setup_ui():
	# Set up grid container
	if card_grid:
		card_grid.columns = GRID_COLUMNS
	
	# Connect button signals
	if prev_button:
		prev_button.pressed.connect(_on_prev_button_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_button_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	
	update_ui()

func display_current_page():
	clear_current_cards()
	
	var start_index = current_page * CARDS_PER_PAGE
	var end_index = min(start_index + CARDS_PER_PAGE, all_cards.size())
	
	for i in range(start_index, end_index):
		create_card_ui(all_cards[i])

func create_card_ui(card_data: CardData):
	var card_scene = preload("res://Shared/scenes/Card2D.tscn")
	var card_instance = card_scene.instantiate() as Card2D
	
	card_grid.add_child(card_instance)
	card_instance.set_card_data(card_data)
	card_instance.card_clicked.connect(_on_card_clicked)
	card_instance.card_right_clicked.connect(_on_card_right_clicked)
	
	card_instances.append(card_instance)

func clear_current_cards():
	for card in card_instances:
		if is_instance_valid(card):
			card.get_parent().remove_child(card)
			card.queue_free()
	card_instances.clear()

func _on_prev_button_pressed():
	if current_page > 0:
		current_page -= 1
		display_current_page()
		update_ui()
		page_changed.emit(current_page)

func _on_next_button_pressed():
	if current_page < total_pages - 1:
		current_page += 1
		display_current_page()
		update_ui()
		page_changed.emit(current_page)

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://MainMenu/scenes/MainMenu.tscn")

func _on_card_clicked(card: Card2D):
	print("Card clicked: ", card.card_data.cardName)

func _on_card_right_clicked(card_data: CardData):
	if card_popup_manager and card_popup_manager.has_method("show_card_popup"):
		card_popup_manager.show_card_popup(card_data)

func update_ui():
	if page_label:
		page_label.text = "Page " + str(current_page + 1) + " / " + str(total_pages)
	
	if prev_button:
		prev_button.disabled = (current_page == 0)
	
	if next_button:
		next_button.disabled = (current_page >= total_pages - 1)

func go_to_page(page: int):
	if page >= 0 and page < total_pages:
		current_page = page
		display_current_page()
		update_ui()
		page_changed.emit(current_page)

func _input(event):
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_page_up"):
		_on_prev_button_pressed()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_page_down"):
		_on_next_button_pressed()
