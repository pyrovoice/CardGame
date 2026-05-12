class_name CastableEntry extends RefCounted

## Represents a single card the player can cast.
## Owned and managed by CastableRegistry.
##
## For HAND / EXTRA_DECK entries: proxy_card == source_card (card is its own proxy).
## For PREPARED_SPELL entries:   proxy_card is a duplicate; source_card is the creature.
## For FROM_GRAVEYARD / FROM_DECK entries: proxy_card == source_card (card casts itself).

enum Reason {
	HAND,           ## Normal hand card
	EXTRA_DECK,     ## Extra deck card
	PREPARED_SPELL, ## Prepared spell proxy (source = creature, proxy = spell duplicate)
	FROM_GRAVEYARD, ## Card castable from graveyard (future)
	FROM_DECK,      ## Card castable from deck (future)
}

## The CardData shown to the player and passed to tryPlayCard
var proxy_card: CardData
## The card that enabled this entry.  null when proxy is its own source (HAND / EXTRA_DECK).
var source_card: CardData
## Why this entry exists
var reason: Reason
## Called by Game after the cast resolves successfully
var on_cast_success: Callable
## Called by Game if the player cancels during the cast
var on_cast_cancel: Callable

func _init(p_proxy: CardData, p_source: CardData, p_reason: Reason) -> void:
	proxy_card = p_proxy
	source_card = p_source
	reason = p_reason
