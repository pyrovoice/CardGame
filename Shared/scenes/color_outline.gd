extends Node3D
class_name ColorOutline

@onready var stencil_viewport: SubViewport = $SubViewport
@onready var stencil_camera: Camera3D = $SubViewport/Camera3D
@export var mainCamera: Camera3D

func _ready() -> void:

	if mainCamera:
		stencil_camera.fov = mainCamera.fov
		stencil_camera.global_transform = mainCamera.global_transform
