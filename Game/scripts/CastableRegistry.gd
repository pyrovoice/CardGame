class_name CastableRegistry extends RefCounted

## Maintains the definitive list of cards the player can potentially cast.
## Registration is push-based (reactive) — no polling of all cards.
##
## View consumers: connect castable_list_changed and call get_all() to refresh.
## Cast consumers:  call get_entry_for_proxy(card_data) from tryPlayCard to obtain
##                  the success/cancel callbacks.
##
## Affordability (gold / conditions) is NOT tracked here.
## Use CardPaymentManagerAL.isCardCastable(entry.proxy_card) per entry for that.

## Emitted whenever an entry is added or removed.
signal castable_list_changed

## O(1) lookup by proxy card — used in the cast flow.
var _by_proxy: Dictionary = {}   # CardData -> CastableEntry

## O(1) lookup by source card — used when the source card leaves play.
## Key is source_card when present, otherwise proxy_card.
var _by_source: Dictionary = {}  # CardData -> Array[CastableEntry]

# ─── Registration ──────────────────────────────────────────────────────────

func register(entry: CastableEntry) -> void:
	if _by_proxy.has(entry.proxy_card):
		return  # already registered — idempotent
	_by_proxy[entry.proxy_card] = entry
	var key = _source_key(entry)
	if not _by_source.has(key):
		_by_source[key] = []
	(_by_source[key] as Array).append(entry)
	castable_list_changed.emit()

## Remove the entry whose proxy_card matches.  Safe to call when not registered.
func unregister_by_proxy(proxy: CardData) -> void:
	if not _by_proxy.has(proxy):
		return
	var entry: CastableEntry = _by_proxy[proxy]
	_by_proxy.erase(proxy)
	var key = _source_key(entry)
	if _by_source.has(key):
		(_by_source[key] as Array).erase(entry)
		if (_by_source[key] as Array).is_empty():
			_by_source.erase(key)
	castable_list_changed.emit()

## Remove all entries whose source_card matches (e.g., creature leaving battlefield).
## Safe to call when no entries exist for that source.
func unregister_by_source(source: CardData) -> void:
	if not _by_source.has(source):
		return
	var entries: Array = (_by_source[source] as Array).duplicate()
	_by_source.erase(source)
	for entry in entries:
		_by_proxy.erase((entry as CastableEntry).proxy_card)
	if not entries.is_empty():
		castable_list_changed.emit()

# ─── Queries ───────────────────────────────────────────────────────────────

## Returns the CastableEntry for a given proxy card, or null if not registered.
func get_entry_for_proxy(proxy: CardData) -> CastableEntry:
	return _by_proxy.get(proxy, null)

## True if this proxy card has a registered entry.
func has_proxy(proxy: CardData) -> bool:
	return _by_proxy.has(proxy)

## All registered entries in insertion order (no affordability filtering).
func get_all() -> Array[CastableEntry]:
	var result: Array[CastableEntry] = []
	for entry in _by_proxy.values():
		result.append(entry as CastableEntry)
	return result

## Clears all entries (e.g., on game reset).
func clear() -> void:
	var had_entries = not _by_proxy.is_empty()
	_by_proxy.clear()
	_by_source.clear()
	if had_entries:
		castable_list_changed.emit()

# ─── Internal helpers ──────────────────────────────────────────────────────

func _source_key(entry: CastableEntry) -> CardData:
	return entry.source_card if entry.source_card else entry.proxy_card
