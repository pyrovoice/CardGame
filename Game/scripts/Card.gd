extends Node3D
class_name Card

@onready var card_representation: Node3D = $CardRepresentation
@onready var background: MeshInstance3D = $CardRepresentation/background
@onready var card_art: MeshInstance3D = $CardRepresentation/CardArt

@onready var name_label: Label3D = $CardRepresentation/NameLabel
@onready var cost_label: Label3D = $CardRepresentation/CostLabel
@onready var type_label: Label3D = $CardRepresentation/TypeLabel
@onready var power_label: Label3D = $CardRepresentation/PowerLabel
@onready var text_label: Label3D = $CardRepresentation/TextLabel
@onready var damage_label: Label3D = $CardRepresentation/damageLabel

const namePositionBig = Vector3(-0.3, 0.005, -0.4)
const namePositionSmall = Vector3(-0.3, 0.005, -0.24)
const powerpositionBig = Vector3(0.1, 0.005, 0.35)
const powerpositionSmall = Vector3(0.1, 0.005, 0.228)
const cardArtPositionBig = Vector3(0, 0.005, -0.163)
const cardArtPositionSmall = Vector3(0, 0.005, -0.019)
const damageLabelPositionSmall = Vector3(0.2, 0.005, 0.228)
const damageLabelPositionBig = Vector3(0.17, 0.005, 0.272)

enum CardControlState{
	FREE,
	MOVED_BY_PLAYER,
	MOVED_BY_GAME
}
var cardData:CardData
var objectID
var cardControlState:CardControlState = CardControlState.FREE
var angleInHand: Vector3 = Vector3.ZERO
var damage = 0
const popUpVal = 1.0

static var objectUUID = -1
static func getNextID():
	objectUUID += 1
	return objectUUID

func _process(delta):
	if cardControlState == CardControlState.FREE:
		card_representation.position = card_representation.position.lerp(Vector3.ZERO, 0.2)
		card_representation.rotation_degrees.x = lerp(card_representation.rotation_degrees.x, angleInHand.x, 0.2)
	
	if cardControlState == CardControlState.MOVED_BY_PLAYER:
		cardControlState = CardControlState.FREE
	
func setData(_cardData):
	if !_cardData:
		push_error("Wtf")
		return
	cardData = _cardData
	objectID = getNextID()
	updateDisplay()
	
func updateDisplay():
	name_label.text = cardData.cardName
	name = cardData.cardName + str(objectID)
	cost_label.text = str(cardData.cost)
	type_label.text = cardData.getFullTypeString()  # Now includes subtypes
	power_label.text = str(cardData.power)
	text_label.text = cardData.text_box
	if getDamage() > 0:
		damage_label.show()
		damage_label.text = str(getDamage())

func popUp():
	if cardControlState == CardControlState.MOVED_BY_GAME:
		return
	var pos := card_representation.position
	pos.y = lerp(pos.y, popUpVal + (position.y*2), 0.4)
	pos.z = lerp(pos.z, 0.2 + (position.z), 0.4)
	card_representation.position = pos
	card_representation.rotation_degrees.x = 90

func dragged(pos: Vector3):
	if cardControlState == CardControlState.MOVED_BY_GAME:
		return
	cardControlState = CardControlState.MOVED_BY_PLAYER
	card_representation.global_position = card_representation.global_position.lerp(pos, 0.4)
	card_representation.position.z = 0.1

func animatePlayedTo(targetPos: Vector3):
	cardControlState = CardControlState.MOVED_BY_GAME
	var cardRepresentationPosBefore = card_representation.global_position
	global_position = targetPos
	card_representation.global_position = cardRepresentationPosBefore
	makeSmall()
	while card_representation.position.distance_to(Vector3.ZERO) > 0.1:
		await move_to_position(Vector3.ZERO, 10)
	card_representation.rotation_degrees.x = 90
	return true
	
func move_to_position(target: Vector3, speed: float) -> void:
	var posBefore = card_representation.global_position
	card_representation.position = card_representation.position.lerp(target, speed * get_process_delta_time())
	var posafter = card_representation.global_position
	await get_tree().process_frame
	
func describe() -> String:
	return objectID + cardData.describe()

func setRotation(angle_deg: Vector3, rotationValue):
		card_representation.rotation_degrees = angle_deg
		card_representation.rotate_z(rotationValue)
		angleInHand = card_representation.rotation_degrees

func makeSmall():
	cost_label.hide()
	type_label.hide()
	text_label.hide()
	(background.mesh as BoxMesh).size.z = 0.55
	card_art.position = cardArtPositionSmall
	power_label.position = powerpositionSmall
	name_label.position = namePositionSmall
	damage_label.position = damageLabelPositionSmall


func makeBig():
	cost_label.show()
	type_label.show()
	text_label.show()
	(background.mesh as BoxMesh).size.z = 0.89
	card_art.position = cardArtPositionBig
	power_label.position = powerpositionBig
	name_label.position = namePositionBig
	damage_label.position = damageLabelPositionBig

func getPower():
	return cardData.power

func getDamage():
	return damage
	
func receiveDamage(v: int):
	damage += v
	updateDisplay()
