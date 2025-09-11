extends RefCounted
class_name AdditionalCostTest

# Test additional cost parsing
static func test_goblin_boss_additional_cost():
	print("=== Testing Goblin Boss Additional Cost Parsing ===")
	
	# Load the goblin boss card
	var goblin_boss = CardLoader.load_card_by_name("Goblin Boss")
	
	if not goblin_boss:
		print("❌ Failed to load Goblin Boss card")
		return
	
	print("✅ Loaded Goblin Boss: ", goblin_boss.cardName)
	print("   Gold Cost: ", goblin_boss.goldCost)
	print("   Has Additional Costs: ", goblin_boss.hasAdditionalCosts())
	
	if goblin_boss.hasAdditionalCosts():
		print("   Additional Costs: ", goblin_boss.additionalCosts)
		print("   Cost Description: ", goblin_boss.getAdditionalCostDescription())
		
		for cost in goblin_boss.additionalCosts:
			print("   Cost Details: ", cost)
	else:
		print("❌ No additional costs found!")
	
	print("   Full Description: ", goblin_boss.describe())
	print("===")

# Test function to be called from game
static func run_tests():
	# Ensure cards are loaded
	CardLoader.load_all_cards()
	test_goblin_boss_additional_cost()
