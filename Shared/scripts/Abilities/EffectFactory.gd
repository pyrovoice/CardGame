extends RefCounted
class_name EffectFactory

## Factory class to create Effect instances based on EffectType

static func create_effect(effect_type: EffectType.Type) -> Effect:
	"""Create an Effect instance based on the effect type enum"""
	match effect_type:
		EffectType.Type.DEAL_DAMAGE:
			return DealDamageEffect.new()
		
		EffectType.Type.PUMP:
			return PumpEffect.new()
		
		EffectType.Type.ADD_KEYWORD:
			return AddKeywordEffect.new()
		
		EffectType.Type.CREATE_TOKEN:
			return CreateTokenEffect.new()
		
		EffectType.Type.CREATE_CARD:
			return CreateCardEffect.new()
		
		EffectType.Type.CAST:
			return CastEffect.new()
		
		EffectType.Type.CREATE_DELAYED_EFFECT:
			return CreateDelayedEffectEffect.new()
		
		EffectType.Type.DRAW:
			return DrawCardEffect.new()
		
		EffectType.Type.ADD_TYPE:
			return AddTypeEffect.new()
		
		EffectType.Type.MOVE_CARD:
			return MoveCardEffect.new()
		
		EffectType.Type.SWITCH_POSITIONS:
			return SwitchPositionsEffect.new()
		
		EffectType.Type.SACRIFICE:
			return SacrificeEffect.new()
		
		EffectType.Type.REMOVE_CARD_FROM_PLAY:
			return RemoveCardFromPlayEffect.new()
	
		EffectType.Type.ADD_GOLD:
			return AddGoldEffect.new()
		
		EffectType.Type.DRAFT:
			return DraftEffect.new()
		
		EffectType.Type.RECYCLE:
			return RecycleEffect.new()
		
		EffectType.Type.REDUCE_COST:
			return ReduceCostEffect.new()
		
		EffectType.Type.RELIC_DURABILITY_TICK:
			return RelicDurabilityEffect.new()
		
		_:
			push_error("Unknown effect type: " + str(effect_type))
			return null

static func execute_effect(effect_type: EffectType.Type, parameters: Dictionary, source_card_data: CardData, game_context: Game):
	"""Convenience method to create and run an effect in one call"""
	var effect = create_effect(effect_type)
	if effect:
		if not effect.validate_parameters(parameters):
			push_error("Invalid parameters for effect type: " + EffectType.type_to_string(effect_type))
			return
		await effect.resolve(parameters, source_card_data, game_context)
	else:
		push_error("Failed to create effect for type: " + EffectType.type_to_string(effect_type))
