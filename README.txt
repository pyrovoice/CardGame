Design philosophy and goals:
In-Game:
- Players build boards over multiple turns. Each archetype uses this differently, creating varied and interesting effects that develop over time.
- Archetypes should be unique but not completely parasitic. Most archetypes should work with some cards outside their theme. Limitations should be general characteristics rather than archetype-specific (e.g., "If this card has X trait" instead of "If this card is Archetype A").
- Game length should support various playstyles (aggro, midrange, combo, control). Aggro pressures opponents quickly, while control must still interact early to prevent opponents from gaining too much advantage.
- Combat is pivotal to any strategy, offering interesting and varied tactical options.
- Players must interact with the AI every turn through combat, resource management, or other mechanics.
- Comeback mechanics: Players should know when to retreat from a location to gain resources and when to commit resources to prevent opponents from gaining too much for too little. Opponents are expected to capture locations, but this shouldn't be too costly for players.
- Not every location should be captured each turn, but units should make progress every turn.
- Randomness and adaptability are key factors. Players need options, and gained resources should force adaptation.
- Players should be able to interact with opponent resources: reveal cards for combat preparation, reduce danger, temporarily remove specific cards from their pool...
- The opponent's archetype should give potential answers to the player and be closer to a puzzle to solve rather than a wall to break.

During a run
- Improve cards during the run with small buffs
- Add new cards to the deck and be able to deckbuild
- Have a sideboard that the player can use when they lose a game/accessible during the game with the extra deck

Between runs
- the player should feel progression between each run, either by unlocking new stuff or improving other stuff
- The player should have deckbuilding options and be able to customize their deck
- The player should have limited deckbuilding options and be forced to select one or two archetype starting a run


Card idea:
	
- High power, but silence everything else you own at that location
- Stone giant: harmless, high defense, raise limit to conquer OR block additional creatures if it can survive

Archetypes:
- master of the wild Hunt: Boss monster followed by Wolves. Generates wolves, send them to attack creatures, stay alive while it has wolves
- Rabbits: generate tokens, boost all tokens
- Fishes: Effects to sacrifice your small fishes to summon random bigger fishes
- Faction with Negative effects on their monsters and a bunch of silence/Effect cancel
- Dwarf faction mining for gold and getting stronger the more gold they have
- Geomancer that vastly modify battlefields
- Circus act: alternate between balls, diabolo and something else. have a number of item set or flying, with cards setting or using flying items for effects depending on the type of Act, and cards to switch between acts. act difficulty?
- Pokemon: Capture opponent monsters and play them somehow
- Boss maker: Turn regular monster into Boss cards that go in the extra deck

Game rules:

- Gold: Gained each turn, starts at 3/turn, can grind up ?
Cards: Gained each turn, starts at 2/turn, can grind up? Can be traded for gold?
- Charges: Get charges on common game event (everytime a non-token creature dies?)
- Archetype/elemental charges: Gained by common game event of the specific type
- Fight: Each location has 6 slots for creatures on 3 lanes. Creatures always fill lanes from left to right and fight in their own lane. Each lane has a front row and a back row, with creatures attacking the front row first if possible.
- Player needs to places creatures on filled row before they can player creatures on free rows. Any row unprotected will have the creature attack the location directly. Dealing enough damage at a location will either damage it or capture it. Damaging grant a small reward and lower the requirement to capture, capturing grants a point and/or a special resource?
- Scoring: When the player scores, the opponent becomes stronger. When the opponent scores, the player lose a life (they start with low amount of life, but are giving shields every match) and gain some resources.
- Boss Deck: Contains Boss creatures that serve either as Boss and have strict requirements, or as Sideboard cards and have less strict requirements but cost more resources
- Locations: Up to three, they have a capture threshold, an effect and a reward. lose to many and lose the game, win by capture enough/resisting waves for a number of turn
- Hero power: Each hero has several shared power + an archetype power
- Have a target Corruption/Purity that gets higher for the corresponding player whenever they win at a location? Auto-balance the game, makes locations adapt to stronger sides organically
- Deck management: Players have a deck list and the deck is filled with 2 copies of each cards. Then, any time the deck's halfpoint is reached, a copy of all card is added. Possibility to play with probabilities by adding and removing cards to the decks, and also give a gold to the opponent when shuffling to open mill strategies?
- Hidden plays. Some cards played by the opponent are played hidden, and an effect in the game is the ability to reveal card played or cards in hand to prepare better for the fight with the opponent.

Other stuff:
- Find a way to have a Sphere mask transition: https://www.reddit.com/r/unrealengine/comments/lrd086/landscape_transition_effect_using_sphere_masks/ or https://www.reddit.com/r/godot/comments/1nidl3l/worldmerging_shader/ or https://github.com/lukky-nl/Stencil-Buffer-Holographic-Display
- Make each location resolved on player choice, with possibility to play in-between each fight? Offers more startegy to the player, less confusion, gameplay possibility of repeating a battle...
- Link Danger to actual game stuff: Card in graveyard, playerlife... makes things that usually would have no effect on the play be useful and open counterplay for the player
- Make battlefield resolve separately