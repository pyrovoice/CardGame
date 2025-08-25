@tool
extends RefCounted
class_name CardLoaderTest

# Simple executable unit test for card loading system
# Run this script directly in Godot's script editor or from command line

# Test data as text variables instead of files
const GOBLIN_PAIR_TEXT = """Name:Goblin pair
ManaCost:1
Types:Creature Goblin
Power:1
T:Mode$ ChangesZone | Origin$ Any | Destination$ Battlefield | ValidCard$ Card.Self | Execute$ TrigToken | TriggerDescription$ When CARDNAME enters, create a 1 power Goblin creature token at the same location.
SVar:TrigToken:DB$ Token | TokenScript$ goblin
CardText:When CARDNAME enters, create a 1 power Goblin creature token at the same location."""

const GOBLIN_WARCHIEF_TEXT = """Name:Goblin Warchief
ManaCost:3
Types:Creature Goblin
Power:2
S:Mode$ Continuous | Affected$ Creature.Goblin+Other+YouCtrl | AddPower$ 1 | AddToughness$ 1 | AddKeyword$ Haste | Description$ Other Goblin creatures you control get +1/+1 and have haste.
SVar:PlayMain1:TRUE
SVar:BuffedBy:Goblin
CardText:Haste (This creature can attack and {T} as soon as it comes under your control.)\\nOther Goblin creatures you control get +1/+1 and have haste."""

const MULTI_SUBTYPE_TEXT = """Name:Fire Goblin Warrior
ManaCost:2
Types:Creature Goblin Warrior Fire
Power:2
CardText:This creature has three subtypes to test the subtype system."""

static func run_tests():
	print("=== Card Loader Unit Tests ===")
	print("Running card loading tests...")
	
	# Test 1: Load all cards from files
	test_load_all_cards()
	
	# Test 2: Test parsing from text variables
	test_parse_from_text()
	
	# Test 3: Test data parsing
	test_data_parsing()
	
	# Test 4: Test subtype parsing
	test_subtype_parsing()
	
	print("=== Tests Complete ===")

static func test_load_all_cards():
	print("\n--- Test: Load All Cards from Files ---")
	var cards = CardLoader.load_all_cards()
	
	print("Loaded ", cards.size(), " cards:")
	for card_data in cards:
		print("- ", card_data.describe())
	
	assert(cards.size() > 0, "Should load at least one card")
	print("✓ Load all cards test passed")

static func test_parse_from_text():
	print("\n--- Test: Parse Cards from Text Variables ---")
	
	# Test Goblin Pair from text variable
	var goblin_pair = CardLoader.parse_card_data(GOBLIN_PAIR_TEXT)
	if goblin_pair:
		print("✓ Parsed Goblin Pair: ", goblin_pair.describe())
		assert(goblin_pair.cardName == "Goblin pair", "Card name should be 'Goblin pair'")
		assert(goblin_pair.cost == 1, "Mana cost should be 1")
		assert(goblin_pair.power == 1, "Power should be 1")
		assert(goblin_pair.type == CardData.CardType.CREATURE, "Should be a creature")
		assert(goblin_pair.subtypes.size() == 1, "Should have 1 subtype")
		assert("Goblin" in goblin_pair.subtypes, "Should have Goblin subtype")
	else:
		print("✗ Failed to parse Goblin Pair")
		return
	
	# Test Goblin Warchief from text variable
	var goblin_warchief = CardLoader.parse_card_data(GOBLIN_WARCHIEF_TEXT)
	if goblin_warchief:
		print("✓ Parsed Goblin Warchief: ", goblin_warchief.describe())
		assert(goblin_warchief.cardName == "Goblin Warchief", "Card name should be 'Goblin Warchief'")
		assert(goblin_warchief.cost == 3, "Mana cost should be 3")
		assert(goblin_warchief.power == 2, "Power should be 2")
		assert(goblin_warchief.type == CardData.CardType.CREATURE, "Should be a creature")
		assert(goblin_warchief.subtypes.size() == 1, "Should have 1 subtype")
		assert("Goblin" in goblin_warchief.subtypes, "Should have Goblin subtype")
	else:
		print("✗ Failed to parse Goblin Warchief")
		return
	
	# Test multi-subtype card from text variable
	var multi_card = CardLoader.parse_card_data(MULTI_SUBTYPE_TEXT)
	if multi_card:
		print("✓ Parsed Multi-subtype Card: ", multi_card.describe())
		assert(multi_card.cardName == "Fire Goblin Warrior", "Card name should be 'Fire Goblin Warrior'")
		assert(multi_card.cost == 2, "Mana cost should be 2")
		assert(multi_card.power == 2, "Power should be 2")
		assert(multi_card.type == CardData.CardType.CREATURE, "Should be a creature")
		assert(multi_card.subtypes.size() == 3, "Should have 3 subtypes")
		assert("Goblin" in multi_card.subtypes, "Should have Goblin subtype")
		assert("Warrior" in multi_card.subtypes, "Should have Warrior subtype")
		assert("Fire" in multi_card.subtypes, "Should have Fire subtype")
	else:
		print("✗ Failed to parse Multi-subtype Card")
		return
	
	print("✓ Parse from text test passed")

static func test_data_parsing():
	print("\n--- Test: Data Parsing ---")
	
	# Test string to int conversion
	var test_int_1 = int("1")
	var test_int_3 = int("3")
	var test_int_0 = int("0")
	
	assert(test_int_1 == 1, "String '1' should convert to int 1")
	assert(test_int_3 == 3, "String '3' should convert to int 3")
	assert(test_int_0 == 0, "String '0' should convert to int 0")
	
	print("✓ String to int conversion works correctly")
	print("  - '1' -> ", test_int_1)
	print("  - '3' -> ", test_int_3)
	print("  - '0' -> ", test_int_0)
	
	print("✓ Data parsing test passed")

static func test_subtype_parsing():
	print("\n--- Test: Subtype Parsing ---")
	
	# Test parsing "Creature Goblin" format
	var test_types = "Creature Goblin"
	var type_parts = test_types.split(" ")
	
	assert(type_parts.size() == 2, "Should have 2 parts: main type and subtype")
	assert(type_parts[0] == "Creature", "First part should be 'Creature'")
	assert(type_parts[1] == "Goblin", "Second part should be 'Goblin'")
	
	print("✓ Basic type parsing works correctly")
	print("  - 'Creature Goblin' -> Type: ", type_parts[0], ", Subtype: ", type_parts[1])
	
	# Test multiple subtypes using our text variable
	var multi_types = "Creature Goblin Warrior Fire"
	var multi_parts = multi_types.split(" ")
	var subtypes = []
	
	for i in range(1, min(multi_parts.size(), 4)):  # Skip first, max 3 subtypes
		subtypes.append(multi_parts[i])
	
	assert(subtypes.size() == 3, "Should have 3 subtypes")
	assert("Goblin" in subtypes, "Should contain 'Goblin'")
	assert("Warrior" in subtypes, "Should contain 'Warrior'")
	assert("Fire" in subtypes, "Should contain 'Fire'")
	
	print("✓ Multiple subtypes parsing works correctly")
	print("  - Subtypes: ", subtypes)
	
	# Test actual card subtype extraction from text variable
	var goblin_pair = CardLoader.parse_card_data(GOBLIN_PAIR_TEXT)
	if goblin_pair:
		print("✓ Goblin Pair subtypes from text: ", goblin_pair.subtypes)
		assert(goblin_pair.subtypes.size() > 0, "Should have at least one subtype")
		assert("Goblin" in goblin_pair.subtypes, "Should have Goblin subtype")
	
	# Test multi-subtype card
	var multi_card = CardLoader.parse_card_data(MULTI_SUBTYPE_TEXT)
	if multi_card:
		print("✓ Multi-subtype card subtypes: ", multi_card.subtypes)
		assert(multi_card.subtypes.size() == 3, "Should have 3 subtypes")
	
	print("✓ Subtype parsing test passed")

# Auto-run when script is executed
static func _static_init():
	if Engine.is_editor_hint():
		print("CardLoaderTest script loaded. Call CardLoaderTest.run_tests() to execute tests.")

# Entry point for manual execution
func _init():
	run_tests()
