import os

overlay_dir = r"C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

# BLOOM presets need to be renumbered from 079-093 to 081-095
# Process in reverse order to avoid conflicts

bloom_renames = [
    ("093. BLOOM - Warm Glow.ini", "095. BLOOM - Warm Glow.ini"),
    ("092. BLOOM - Sunset Blaze.ini", "094. BLOOM - Sunset Blaze.ini"),
    ("091. BLOOM - Subtle Clean.ini", "093. BLOOM - Subtle Clean.ini"),
    ("090. BLOOM - Night Enhanced.ini", "092. BLOOM - Night Enhanced.ini"),
    ("089. BLOOM - Neon Nights.ini", "091. BLOOM - Neon Nights.ini"),
    ("088. BLOOM - Interior Mood.ini", "090. BLOOM - Interior Mood.ini"),
    ("087. BLOOM - High Key.ini", "089. BLOOM - High Key.ini"),
    ("086. BLOOM - HDR Punch.ini", "088. BLOOM - HDR Punch.ini"),
    ("085. BLOOM - Foggy Atmosphere.ini", "087. BLOOM - Foggy Atmosphere.ini"),
    ("084. BLOOM - Film Stock.ini", "086. BLOOM - Film Stock.ini"),
    ("083. BLOOM - Ethereal.ini", "085. BLOOM - Ethereal.ini"),
    ("082. BLOOM - Dramatic.ini", "084. BLOOM - Dramatic.ini"),
    ("081. BLOOM - Crisp Minimal.ini", "083. BLOOM - Crisp Minimal.ini"),
    ("080. BLOOM - Cool Atmosphere.ini", "082. BLOOM - Cool Atmosphere.ini"),
    ("079. BLOOM - Candlelight.ini", "081. BLOOM - Candlelight.ini"),
]

print("Renumbering BLOOM presets (079-093 -> 081-095)...\n")

for old_name, new_name in bloom_renames:
    old_path = os.path.join(overlay_dir, old_name)
    new_path = os.path.join(overlay_dir, new_name)

    if os.path.exists(old_path):
        os.rename(old_path, new_path)
        print(f"  {old_name} -> {new_name}")
    else:
        print(f"  WARNING: {old_name} not found!")

print("\nDone!")
