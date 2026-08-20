extends RefCounted
class_name SelectionRequest

## Fluent builder + global singleton for the currently-active player-selection request.
##
## Only one selection runs at a time, so a single shared instance is safe.
##
## Usage pattern for direct callers:
##   SelectionRequest.reset().with_pool(cards).with_count(1).with_context("my_spell")
##   var result = await game_context.start_card_selection()   ← reads SelectionRequest.current
##
## Effect.declare_selections() builds and returns SelectionRequest objects normally;
## Effect.run() assigns each one to SelectionRequest.current before calling start_card_selection().
##
## Injected result (when fulfilled by Effect.run()):
##   null   → player pressed Cancel / skipped
##   []     → player confirmed with no card selected  (binary "yes")
##   [...]  → player selected specific cards

# ── Global singleton ──────────────────────────────────────────────────────────
## The currently-active request.  Set by reset() or by Effect.run() before each call.
static var current: SelectionRequest = null

## Clear all fields, assign self as current, and return self for chaining.
static func reset() -> SelectionRequest:
	current = SelectionRequest.new()
	return current

# ── Selection pool ────────────────────────────────────────────────────────────
var pool: Array[CardData] = []       ## Cards the player may pick from (empty = binary confirm/cancel)

# ── Count constraints ─────────────────────────────────────────────────────────
var count: int = 1                   ## Required number of cards (used as min and max when no override)
var min_count: int = -1              ## Minimum cards; -1 = use count
var max_count: int = -1              ## Maximum cards; -1 = use count
var is_optional: bool = false        ## If true, 0 selections still counts as complete

# ── UI labels ─────────────────────────────────────────────────────────────────
var confirm_text: String = ""        ## Custom label for the Confirm button (empty = auto-generated)
var description: String = ""         ## Human-readable label shown in the selection description text

# ── Routing / injection ───────────────────────────────────────────────────────
var result_key: String = "PlayerSelection"  ## Key injected into effect parameters on completion
var context: String = ""                    ## Debug / selection_type label passed to SelectionManager

# ── Game / animation side ─────────────────────────────────────────────────────
var casting_card: CardData = null    ## Card being cast — drives casting animation (may be null)
var preselected: Array[CardData] = [] ## Pre-selected cards that bypass the UI entirely

# ── Builder methods ───────────────────────────────────────────────────────────

func with_pool(p: Array[CardData]) -> SelectionRequest:
	pool = p; return self

func with_count(n: int) -> SelectionRequest:
	count = n; return self

func with_min_count(n: int) -> SelectionRequest:
	min_count = n; return self

func with_max_count(n: int) -> SelectionRequest:
	max_count = n; return self

## Mark the selection as optional: 0 selections is still a valid (completed) state.
func optional() -> SelectionRequest:
	is_optional = true; return self

func with_confirm_text(t: String) -> SelectionRequest:
	confirm_text = t; return self

func with_description(d: String) -> SelectionRequest:
	description = d; return self

func with_result_key(k: String) -> SelectionRequest:
	result_key = k; return self

func with_context(c: String) -> SelectionRequest:
	context = c; return self

func with_casting_card(c: CardData) -> SelectionRequest:
	casting_card = c; return self

func with_preselected(p: Array[CardData]) -> SelectionRequest:
	preselected = p; return self

# ── Resolved constraints (used by PlayerSelection) ───────────────────────────

func effective_min() -> int:
	return min_count if min_count >= 0 else count

func effective_max() -> int:
	return max_count if max_count >= 0 else count



