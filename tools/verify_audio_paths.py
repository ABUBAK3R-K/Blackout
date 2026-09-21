import os
import re

with open('assets/audio/audio_registry.gd', 'r') as f:
    content = f.read()

paths = re.findall(r'"path":\s*"res://([^"]+)"', content)
print(f"Total paths in AudioRegistry: {len(paths)}")

missing = []
for p in paths:
    if not os.path.exists(p):
        missing.append(p)

if missing:
    print(f"ERROR: {len(missing)} missing files:")
    for m in missing:
        print(" -", m)
else:
    print("SUCCESS: 100% of AudioRegistry paths resolve to real files on disk!")
