import os
import re

overlay_dir = r"C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

# Update UIOrdering inside each CINEMATIC BORDERS file
cinematic_files = [
    ("096. CINEMATIC BORDERS - Classic 2.35.ini", 96),
    ("097. CINEMATIC BORDERS - IMAX 1.43.ini", 97),
    ("098. CINEMATIC BORDERS - Subtle Frame.ini", 98),
    ("099. CINEMATIC BORDERS - Ultra Wide 2.76.ini", 99),
    ("100. CINEMATIC BORDERS - Vintage Corners.ini", 100),
]

print("Updating UIOrdering values inside CINEMATIC BORDERS files...\n")

for filename, new_ordering in cinematic_files:
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
