# CardPaymentManager Autoload Setup Instructions

To set up the CardPaymentManager as an autoload in Godot:

1. Open Project Settings (Project > Project Settings)
2. Go to the "AutoLoad" tab
3. Click "Add" or use the "+" button
4. Set the following:
   - Path: res://Game/scripts/CardPaymentManager.gd
   - Node Name: CardPaymentManagerAL
   - Enable: ✓ (checked)
5. Click "Add"

The CardPaymentManager will now be available globally as `CardPaymentManagerAL` throughout the project.

## Usage in game.gd:

Replace these old function calls:
- `canPayCard(card)` → `CardPaymentManagerAL.canPayCard(card)`
- `tryPayCard(card)` → `CardPaymentManagerAL.tryPayCard(card)`
- `canPayAdditionalCosts(costs)` → `CardPaymentManagerAL.canPayAdditionalCosts(costs)`
- `_isCardCastable(card)` → `CardPaymentManagerAL.isCardCastable(card)`
- `_isCardDataCastable(card_data)` → `CardPaymentManagerAL.isCardDataCastable(card_data)`

Make sure to call `CardPaymentManagerAL.set_game_context(self)` in game._ready() to set up the context.

## Functions moved to CardPaymentManager:
- canPayCard()
- canPayCardData()
- tryPayCard()
- canPayAdditionalCosts()
- canPaySingleAdditionalCost()
- canSacrificePermanents()
- payAdditionalCosts()
- paySingleAdditionalCost()
- sacrificePermanents()
- getPlayerControlledCards()
- filterCardsByValidCard()
- isCardCastable() (replaces _isCardCastable)
- isCardDataCastable() (replaces _isCardDataCastable)
