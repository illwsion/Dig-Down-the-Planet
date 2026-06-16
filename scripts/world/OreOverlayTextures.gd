class_name OreOverlayTextures

## 광물 오버레이 id별 타일 텍스처를 반환한다.
## WorldGenerator의 ore_overlay_id 값과 같은 id를 키로 사용한다.

const c_Textures: Dictionary = {
	&"copper": preload("res://assets/tiles/overlay_copper.png"),
	&"iron": preload("res://assets/tiles/overlay_iron.png"),
}


static func get_texture(_ore_overlay_id: StringName) -> Texture2D:
	return c_Textures.get(_ore_overlay_id, null)
