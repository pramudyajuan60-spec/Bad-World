class_name FormationUtils
extends RefCounted
## Pure, headlessly-testable formation math (Prompt Dasar: "Unit harus
## menggunakan formation spacing ... dan tidak menumpuk di titik yang
## sama"). Given N units and a target point, returns N distinct grid
## positions around that point so units never stack exactly on top of
## each other at the destination.

static func compute_positions(center: Vector2, count: int, spacing: float = 48.0) -> Array:
	var positions: Array = []
	if count <= 0:
		return positions
	if count == 1:
		positions.append(center)
		return positions
	var columns := int(ceil(sqrt(float(count))))
	var rows := int(ceil(float(count) / float(columns)))
	var start_x := -float(columns - 1) * spacing * 0.5
	var start_y := -float(rows - 1) * spacing * 0.5
	var i := 0
	for row in range(rows):
		for col in range(columns):
			if i >= count:
				break
			positions.append(center + Vector2(start_x + col * spacing, start_y + row * spacing))
			i += 1
	return positions
