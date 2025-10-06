Design philosophy and goals:
	In game:
- The player should build a board over turns and become stronger and stronger
- Each archetype should do unique things but not be completely parasitic
- Game length should support various gameplay style (aggro, midrange, combo, control) but every step of the game should matter
- Combat should be important and a pivotal point in any strategy while offering options to the player
- The player should be expected to answer the AI every turn or lose something
- Comeback mechanics, the player should know when not to fight and get things if they lose a location, or know when to commit resources so the opponent doesn't get too much for too little
- Not every location should be captured every turn, but progress should be made every turn by units there
- Randomness and adaptability should be important factors for the player. They must have options, and resources gained should be forcing adaptability
- The player should be able to interact with the opponent's ressource. Reveal played cards for combat 2, reduce danger, remove specific card from their pool temporarely...

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

Gold: Gained each turn, starts at 3/turn, can grind up ?
Cards: Gained each turn, starts at 2/turn, can grind up? Can be traded for gold?
Charges: Get charges on common game event (everytime a non-token creature dies?)
Archetype/elemental charges: Gained by common game event of the specific type
Fight: Each location has 6 slots for creatures on 3 lanes. Creatures always fill lanes from left to right and fight in their own lane. Each lane has a front row and a back row, with creatures attacking the front row first if possible.
Player needs to places creatures on filled row before they can player creatures on free rows. Any row unprotected will have the creature attack the location directly. Dealing enough damage at a location will either damage it or capture it. Damaging grant a small reward and lower the requirement to capture, capturing grants a point and/or a special resource?
Scoring: When the player scores, the opponent becomes stronger. When the opponent scores, the player lose a life (they start with low amount of life, but are giving shields every match) and gain some resources.
Boss Deck: Contains Boss creatures that serve either as Boss and have strict requirements, or as Sideboard cards and have less strict requirements but cost more resources
Locations: Up to three, they have a capture threshold, an effect and a reward. lose to many and lose the game, win by capture enough/resisting waves for a number of turn
Hero power: Each hero has several shared power + an archetype power
Have a target Corruption/Purity that gets higher for the corresponding player whenever they win at a location? Auto-balance the game, makes locations adapt to stronger sides organically
Deck management: Players have a deck list and the deck is filled with 2 copies of each cards. Then, any time the deck's halfpoint is reached, a copy of all card is added. Possibility to play with probabilities by adding and removing cards to the decks, and also give a gold to the opponent when shuffling to open mill strategies?

Combat:
	- Creatures are set left to right and front to back. All creatures accumulate their might, and damage is assigned to creatures in order to kill them.
	- Any spillover might is dealt to the location as purification or corruption. 
	- Each player has a Conquest target value. When they accumulate enough at a location, that location becomes captured with the benefits that implies
	- Capturing for each player should mean getting closer to victory, but making the opponent stronger (catchup mechanism)
	- Capturing in early game should be hard and take several turns, while becoming faster and easier with combat
	- Each capture increases the needed score to capture a location by that much
Ideas to justify pull and push: 
- Locations have a crystal that can be corrupted or fred, the player adds "good" resource while the opponent add "corruption" to it. Possible ressource: Vitality, to restore the crystal. Purification. 
- Add stuff to the opponent's deck or hand ("Fool, 2c 1p with no effect", here to waste opponent's ressource)
Questions:
- How much can a player prepare before starting scoring? What are ways to prevent the player from just farming resources before winning in one swoop?
- How is the opponent's cards decided? First draft: Start turn by drawing up to its danger level, then play revealed stuff and keep other hidden, then player can interact with played or stuff in hand, then combat phase where opponent plays the rest, then resolve and end turn

Other stuff:
Find a way to have a Sphere mask transition: https://www.reddit.com/r/unrealengine/comments/lrd086/landscape_transition_effect_using_sphere_masks/ or https://www.reddit.com/r/godot/comments/1nidl3l/worldmerging_shader/ or https://github.com/lukky-nl/Stencil-Buffer-Holographic-Display
Make each location resolved on player choice, with possibility to play in-between each fight? Offers more startegy to the player, less confusion, gameplay possibility of repeating a battle...

- How to manage flying units? Evasive
