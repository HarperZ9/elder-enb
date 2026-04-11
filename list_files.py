import os

overlay_dir = r"C:\Users\Zain\ENB\enbseries\enbpresetoverlays"
files = sorted(os.listdir(overlay_dir))

for f in files:
    if f.endswith('.ini'):
        print(f)
