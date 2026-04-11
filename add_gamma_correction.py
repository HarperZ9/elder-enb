import os
import re

overlay_dir = r"C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

# Files that have Gamma parameters (from grep results)
files_with_gamma = [
    "007. ENV - Linear Light 1.8.ini",
    "027. STYLE - 11.11.11 (LE).ini",
    "029. STYLE - Arrival of Autumn.ini",
    "032. STYLE - Desert Mirage.ini",
    "033. STYLE - Dramatic Contrast.ini",
    "035. STYLE - Ethqnm Edition.ini",
    "040. STYLE - High Key.ini",
    "041. STYLE - Jotunheimar.ini",
    "042. STYLE - Maritime Noir.ini",
    "044. STYLE - Monochrome Dramatic.ini",
    "049. STYLE - Noir.ini",
    "051. STYLE - Pastel Dream.ini",
    "053. STYLE - Rudy Inspired.ini",
    "055. STYLE - Somber Tones.ini",
    "060. STYLE - Wretched.ini",
]

print("Adding Gamma Correction parameters to match Gamma parameters...\n")

for filename in files_with_gamma:
    filepath = os.path.join(overlay_dir, filename)

    if not os.path.exists(filepath):
        print(f"  WARNING: {filename} not found!")
        continue

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find all Gamma parameters and their values
    gamma_pattern = r'\[OVERLAYPARAM(\d+)\]\s*\n\s*Category = ENBEFFECT\.FX\s*\n\s*Name = (CG\.HDR\.\|- [^-]+ - Gamma)\s*\n\s*Operation = "([^"]+)"'

    matches = list(re.finditer(gamma_pattern, content))

    if not matches:
        print(f"  {filename}: No Gamma parameters found")
        continue

    # For each Gamma parameter, we need to add a Gamma Correction parameter after it
    insertions = []
    for match in matches:
        gamma_name = match.group(2)  # e.g., "CG.HDR.|- Day - Gamma"
        operation = match.group(3)   # e.g., "+ 0.4"

        # Create the Gamma Correction name
        gamma_correction_name = gamma_name.replace(" - Gamma", " - Gamma Correction")

        # Position to insert after this parameter block
        insert_pos = match.end()

        # The new parameter block
        new_block = f"\n\n[OVERLAYPARAM_NEW]\nCategory = ENBEFFECT.FX\nName = {gamma_correction_name}\nOperation = \"{operation}\""

        insertions.append((insert_pos, new_block))

    # Apply insertions in reverse order to preserve positions
    new_content = content
    for pos, block in reversed(insertions):
        new_content = new_content[:pos] + block + new_content[pos:]

    # Now renumber all OVERLAYPARAM sections
    param_counter = [0]  # Use list to allow modification in nested function

    def renumber(match):
        param_counter[0] += 1
        return f"[OVERLAYPARAM{param_counter[0]}]"

    new_content = re.sub(r'\[OVERLAYPARAM\d*\]|\[OVERLAYPARAM_NEW\]', renumber, new_content)

    # Write the updated content
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print(f"  {filename}: Added {len(matches)} Gamma Correction parameters (total params: {param_counter[0]})")

print("\nDone!")
