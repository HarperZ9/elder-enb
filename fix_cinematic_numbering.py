import os

overlay_dir = r"C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

# CINEMATIC BORDERS need to be renumbered from 094-098 to 096-100
# Process in reverse order to avoid conflicts

cinematic_renames = [
    ("098. CINEMATIC BORDERS - Vintage Corners.ini", "100. CINEMATIC BORDERS - Vintage Corners.ini"),
    ("097. CINEMATIC BORDERS - Ultra Wide 2.76.ini", "099. CINEMATIC BORDERS - Ultra Wide 2.76.ini"),
    ("096. CINEMATIC BORDERS - Subtle Frame.ini", "098. CINEMATIC BORDERS - Subtle Frame.ini"),
    ("095. CINEMATIC BORDERS - IMAX 1.43.ini", "097. CINEMATIC BORDERS - IMAX 1.43.ini"),
    ("094. CINEMATIC BORDERS - Classic 2.35.ini", "096. CINEMATIC BORDERS - Classic 2.35.ini"),
]

print("Renumbering CINEMATIC BORDERS presets (094-098 -> 096-100)...\n")

for old_name, new_name in cinematic_renames:
    old_path = os.path.join(overlay_dir, old_name)
    new_path = os.path.join(overlay_dir, new_name)

    if os.path.exists(old_path):
        os.rename(old_path, new_path)
        print(f"  {old_name} -> {new_name}")
    else:
        print(f"  WARNING: {old_name} not found!")

print("\nDone!")
