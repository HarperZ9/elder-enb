import os
import re

overlay_dir = r"C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

# Update UIOrdering inside each BLOOM file
bloom_files = [
    ("081. BLOOM - Candlelight.ini", 81),
    ("082. BLOOM - Cool Atmosphere.ini", 82),
    ("083. BLOOM - Crisp Minimal.ini", 83),
    ("084. BLOOM - Dramatic.ini", 84),
    ("085. BLOOM - Ethereal.ini", 85),
    ("086. BLOOM - Film Stock.ini", 86),
    ("087. BLOOM - Foggy Atmosphere.ini", 87),
    ("088. BLOOM - HDR Punch.ini", 88),
    ("089. BLOOM - High Key.ini", 89),
    ("090. BLOOM - Interior Mood.ini", 90),
    ("091. BLOOM - Neon Nights.ini", 91),
    ("092. BLOOM - Night Enhanced.ini", 92),
    ("093. BLOOM - Subtle Clean.ini", 93),
    ("094. BLOOM - Sunset Blaze.ini", 94),
    ("095. BLOOM - Warm Glow.ini", 95),
]

print("Updating UIOrdering values inside BLOOM files...\n")

for filename, new_ordering in bloom_files:
    filepath = os.path.join(overlay_dir, filename)

    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        # Update UIOrdering
        old_match = re.search(r'UIOrdering = (\d+)', content)
        if old_match:
            old_value = old_match.group(1)
            content = re.sub(r'UIOrdering = \d+', f'UIOrdering = {new_ordering}', content)

            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)

            print(f"  {filename}: UIOrdering {old_value} -> {new_ordering}")
        else:
            print(f"  WARNING: {filename} has no UIOrdering!")
    else:
        print(f"  WARNING: {filename} not found!")

print("\nDone!")
