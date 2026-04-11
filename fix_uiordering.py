import os
import re

overlay_dir = r"C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

# Files with UIOrdering mismatches
files_to_fix = [
    ("061. STYLE - Elder Originals.ini", 61),
    ("062. STYLE - Neutral.ini", 62),
    ("063. DOF - Artistic Swirl.ini", 63),
    ("064. DOF - Bubble Bokeh.ini", 64),
    ("065. DOF - Cat Eye.ini", 65),
    ("066. DOF - Cinematic Anamorphic.ini", 66),
    ("067. DOF - Dreamy Haze.ini", 67),
    ("068. DOF - Fast Fifty.ini", 68),
    ("069. DOF - Gentle Glow.ini", 69),
    ("070. DOF - Landscape.ini", 70),
    ("071. DOF - Macro Detail.ini", 71),
    ("072. DOF - Modern Clean.ini", 72),
    ("073. DOF - Night Hexagon.ini", 73),
    ("074. DOF - Ring Bokeh.ini", 74),
    ("075. DOF - Sharp Documentary.ini", 75),
    ("076. DOF - Soft Portrait.ini", 76),
    ("077. DOF - Star Diffraction.ini", 77),
    ("078. DOF - Telephoto.ini", 78),
    ("079. DOF - Tilt Shift.ini", 79),
    ("080. DOF - Vintage Film.ini", 80),
]

print("Fixing UIOrdering mismatches...\n")

for filename, correct_ordering in files_to_fix:
    filepath = os.path.join(overlay_dir, filename)

    if not os.path.exists(filepath):
        print(f"  WARNING: {filename} not found!")
        continue

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find current UIOrdering
    match = re.search(r'UIOrdering\s*=\s*(\d+)', content)
    if match:
        old_value = match.group(1)
        content = re.sub(r'UIOrdering\s*=\s*\d+', f'UIOrdering = {correct_ordering}', content)

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

        print(f"  {filename}: UIOrdering {old_value} -> {correct_ordering}")
    else:
        print(f"  WARNING: {filename} has no UIOrdering!")

print("\nDone!")
