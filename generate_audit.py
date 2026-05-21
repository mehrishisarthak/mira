import os
from pathlib import Path

output_file = "FULL_CODEBASE_SOURCE_AUDIT.txt"
target_dirs = ["lib", "test"]

with open(output_file, "w", encoding="utf-8") as out:
    # Do pubspec.yaml
    pubspec = Path("pubspec.yaml")
    if pubspec.exists():
        out.write("================================================================================\n")
        out.write(f"FILE: {pubspec.name}\n")
        out.write("================================================================================\n")
        out.write(pubspec.read_text(encoding="utf-8"))
        out.write("\n\n")

    for d in target_dirs:
        d_path = Path(d)
        if not d_path.exists():
            continue
        for root, dirs, files in os.walk(d_path):
            for file in files:
                if file.endswith(".dart"):
                    file_path = Path(root) / file
                    out.write("================================================================================\n")
                    out.write(f"FILE: {file_path.as_posix()}\n")
                    out.write("================================================================================\n")
                    try:
                        out.write(file_path.read_text(encoding="utf-8"))
                    except Exception as e:
                        out.write(f"Error reading file: {e}\n")
                    out.write("\n\n")
