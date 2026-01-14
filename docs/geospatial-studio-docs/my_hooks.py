from pathlib import Path
import os
import subprocess


def on_pre_build(config):
    source_dir = Path("../../populate-studio/payloads")
    dest_dir = Path("docs/payloads")

    if not os.path.exists(dest_dir):
        subprocess.run(["mkdir", "-p", dest_dir], text=True, check=True)

    if os.path.exists(source_dir):
        subprocess.run(f"cp -r {source_dir}/* {dest_dir}/", text=True, check=True, shell=True)
    else:
        print(f"Warning: Source directory {source_dir} does not exist")

