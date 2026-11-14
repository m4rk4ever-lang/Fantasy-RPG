class_name HeroProportions
extends SkeletonModifier3D
## Heroic, stylized proportions on top of the imported body (owner reference, 14-11-2026):
## broader chest and shoulders, stronger arms and hands, sturdier legs. Runs after the animation.
## Scaling a bone scales its children, so the head is scaled back.

var scales: Dictionary = {
	"Chest": Vector3(1.16, 1.04, 1.12),
	"Neck": Vector3(0.9, 0.96, 0.9),
	"UpperArm.L": Vector3(1.12, 1.0, 1.12),
	"UpperArm.R": Vector3(1.12, 1.0, 1.12),
	"Wrist.L": Vector3(1.12, 1.12, 1.12),
	"Wrist.R": Vector3(1.12, 1.12, 1.12),
	"UpperLeg.L": Vector3(1.1, 1.0, 1.1),
	"UpperLeg.R": Vector3(1.1, 1.0, 1.1),
	"Abdomen": Vector3(0.94, 1.0, 0.94),
}


func _process_modification() -> void:
	var skel: Skeleton3D = get_skeleton()
	if skel == null:
		return
	for bone: String in scales:
		var i: int = skel.find_bone(bone)
		if i >= 0:
			skel.set_bone_pose_scale(i, scales[bone])
