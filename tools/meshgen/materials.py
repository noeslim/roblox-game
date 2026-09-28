"""Material keys used by the meshes. Each key maps to a Roblox material + color (applied in game by
ModelFactory) and to a Blender preview material. build.py writes the Roblox half into
src/shared/Config/MeshLibrary.luau, so this file is the single source of truth."""

MATERIALS = {
    # key:            (Roblox material,  color,     roughness, metallic, emission, transparency)
    "wood_dark": ("Wood", "#3B2616", 0.7, 0.0, 0, 0),
    "wood_mid": ("WoodPlanks", "#6B4A2E", 0.75, 0.0, 0, 0),
    "wood_crate": ("WoodPlanks", "#8A6238", 0.85, 0.0, 0, 0),
    "wood_worn": ("Wood", "#5A4632", 0.9, 0.0, 0, 0),
    "metal_dark": ("Metal", "#2B2D33", 0.45, 1.0, 0, 0),
    "metal_steel": ("Metal", "#8C9099", 0.3, 1.0, 0, 0),
    "metal_brushed": ("Foil", "#A8ADB6", 0.35, 1.0, 0, 0),
    "metal_black": ("Metal", "#16171B", 0.5, 0.9, 0, 0),
    "metal_rust": ("CorrodedMetal", "#6A4030", 0.9, 0.6, 0, 0),
    "metal_gun": ("Metal", "#24262B", 0.4, 1.0, 0, 0),
    "metal_gold": ("Metal", "#C9A23A", 0.25, 1.0, 0, 0),
    "metal_brass": ("Metal", "#A9853F", 0.35, 1.0, 0, 0),
    "diamond_plate": ("DiamondPlate", "#5A5E66", 0.4, 1.0, 0, 0),
    "paint_green": ("Metal", "#2F4F3A", 0.6, 0.4, 0, 0),
    "paint_red": ("Metal", "#7A1F1F", 0.55, 0.3, 0, 0),
    "plastic_black": ("SmoothPlastic", "#141418", 0.5, 0.0, 0, 0),
    "plastic_grey": ("SmoothPlastic", "#55575E", 0.55, 0.0, 0, 0),
    "polymer": ("Plastic", "#1C1D21", 0.75, 0.0, 0, 0),
    "polymer_tan": ("Plastic", "#8B7B5E", 0.8, 0.0, 0, 0),
    "rubber": ("Rubber", "#101012", 0.95, 0.0, 0, 0),
    "tape": ("Fabric", "#3A3A3A", 0.95, 0.0, 0, 0),
    "fabric_purple": ("Fabric", "#3D2570", 0.95, 0.0, 0, 0),
    "fabric_dark": ("Fabric", "#23222A", 0.95, 0.0, 0, 0),
    "leather": ("Leather", "#3A2418", 0.6, 0.0, 0, 0),
    "glass": ("Glass", "#BFE9FF", 0.05, 0.0, 0, 0.7),
    "glass_dark": ("Glass", "#1A2A33", 0.05, 0.0, 0, 0.4),
    "screen": ("Glass", "#0F2A22", 0.1, 0.0, 0.6, 0),
    "leaf": ("Grass", "#2E6B30", 0.8, 0.0, 0, 0),
    "soil": ("Ground", "#2A1C12", 1.0, 0.0, 0, 0),
    "ceramic": ("Slate", "#4A3A34", 0.6, 0.0, 0, 0),
    "paper": ("Fabric", "#D8D2C0", 0.9, 0.0, 0, 0),
    "cash": ("Fabric", "#2E6B45", 0.9, 0.0, 0, 0),
    "neon_pink": ("Neon", "#FF3FA4", 0.5, 0.0, 4, 0),
    "neon_blue": ("Neon", "#3FA9F5", 0.5, 0.0, 4, 0),
    "neon_green": ("Neon", "#39FF88", 0.5, 0.0, 4, 0),
    "neon_orange": ("Neon", "#FFB020", 0.5, 0.0, 4, 0),
    "neon_purple": ("Neon", "#B45CFF", 0.5, 0.0, 4, 0),
    "neon_red": ("Neon", "#FF3B3B", 0.5, 0.0, 4, 0),
    # city
    "window_glass": ("Glass", "#1E2A36", 0.08, 0.3, 0, 0),
    "window_lit": ("Glass", "#2A2A30", 0.1, 0.0, 2, 0),  # switched to warm Neon at night (NightGlow)
    "trim_light": ("Concrete", "#BDB6A8", 0.8, 0.0, 0, 0),
    "trim_dark": ("Metal", "#2A2A2E", 0.5, 0.6, 0, 0),
    "lamp_lens": ("Glass", "#FFE2B0", 0.2, 0.0, 3, 0),  # NightGlow + light
    "car_paint": ("SmoothPlastic", "#7A1F1F", 0.25, 0.4, 0, 0),  # recolored per car
    "container_paint": ("CorrodedMetal", "#8A3A2A", 0.7, 0.4, 0, 0),  # recolored per container
    "awning": ("Fabric", "#7A1E2A", 0.9, 0.0, 0, 0),  # recolored per shop
    "roof_green": ("Slate", "#2E5A45", 0.6, 0.0, 0, 0),
    "brick_red": ("Brick", "#6E3A2E", 0.9, 0.0, 0, 0),
    "concrete": ("Concrete", "#7A7A7E", 0.9, 0.0, 0, 0),
    "siding": ("WoodPlanks", "#6E7F86", 0.8, 0.0, 0, 0),
    "water": ("Glass", "#2E6A8A", 0.05, 0.0, 0, 0.3),
    "plaster_white": ("Plaster", "#E8E2D6", 0.9, 0.0, 0, 0),
    "chrome": ("Metal", "#C8CCD2", 0.15, 1.0, 0, 0),
    "bark": ("Wood", "#4A3626", 0.9, 0.0, 0, 0),
    "headlight": ("Neon", "#FFF3D6", 0.2, 0.0, 3, 0),
    # building door leaves: their own meshes so the game can swap them for doors that open
    "door_wood": ("Wood", "#3B2616", 0.7, 0.0, 0, 0),
    "door_glass": ("Glass", "#1E2A36", 0.08, 0.3, 0, 0),
    "door_metal": ("Metal", "#2B2D33", 0.45, 1.0, 0, 0),
    "signal_red": ("Glass", "#3A1212", 0.2, 0.0, 0, 0),  # lit by MapBuilder (TrafficSignal tag)
    "signal_amber": ("Glass", "#3A2A10", 0.2, 0.0, 0, 0),
    "signal_green": ("Glass", "#103A22", 0.2, 0.0, 0, 0),
    "billboard_face": ("SmoothPlastic", "#E8E2D6", 0.7, 0.0, 0, 0),  # covered by the ad (SurfaceGui)
    "wood_pole": ("Wood", "#4A3A2C", 0.95, 0.0, 0, 0),
    "court_paint": ("SmoothPlastic", "#E8E8E8", 0.6, 0.0, 0, 0),
    # Quaternius Downtown City MegaKit (tools/meshgen/kit.py): textured from the kit's own maps
    "kit_brick": ("Brick", "#8A4A3A", 0.85, 0.0, 0, 0),
    "kit_brick_pale": ("Brick", "#B08878", 0.85, 0.0, 0, 0),
    "kit_trim": ("Concrete", "#C8C0A8", 0.8, 0.0, 0, 0),
    "kit_trim_dark": ("Concrete", "#3A3A40", 0.7, 0.0, 0, 0),
    "kit_trim_green": ("Concrete", "#3C6A52", 0.7, 0.0, 0, 0),
    "kit_metal": ("Metal", "#5A5E64", 0.5, 0.6, 0, 0),
    "kit_ornaments": ("Metal", "#6A6A6E", 0.6, 0.4, 0, 0),
    "kit_slate": ("Slate", "#3A3E44", 0.8, 0.0, 0, 0),
    "kit_concrete": ("Concrete", "#8A8A8C", 0.9, 0.0, 0, 0),
    "kit_glass": ("Glass", "#1A1F24", 0.05, 0.0, 0, 0.35),
    "kit_interior": ("SmoothPlastic", "#16171C", 0.8, 0.0, 0, 0),  # dark room behind a window
}
