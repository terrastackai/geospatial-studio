"""
MkDocs hooks for Geospatial Studio Workshop
This file contains custom hooks to extend MkDocs functionality
"""

import os
import shutil
from pathlib import Path


def on_post_build(config, **kwargs):
    """
    Hook that runs after the site is built.
    Copies notebook files from the notebooks/ directory to the site output.
    This maintains a single source of truth for notebooks.
    """
    # Get the site directory and project root
    site_dir = Path(config['site_dir'])
    docs_dir = Path(config['docs_dir'])
    project_root = docs_dir.parent
    
    # Source and destination for notebooks
    notebooks_src = docs_dir / 'notebooks'
    notebooks_dest = site_dir / 'notebooks'
    
    # Create destination directory if it doesn't exist
    notebooks_dest.mkdir(parents=True, exist_ok=True)
    
    # Copy all .ipynb and .json files
    if notebooks_src.exists():
        # Copy notebook files
        for notebook_file in notebooks_src.glob('*.ipynb'):
            dest_file = notebooks_dest / notebook_file.name
            shutil.copy2(notebook_file, dest_file)
            print(f"✓ Copied notebook: {notebook_file.name}")
        
        # Copy JSON configuration files (needed by notebooks)
        for json_file in notebooks_src.glob('*.json'):
            dest_file = notebooks_dest / json_file.name
            shutil.copy2(json_file, dest_file)
            print(f"✓ Copied JSON config: {json_file.name}")
    else:
        print(f"⚠️  Warning: notebooks directory not found at {notebooks_src}")
    
    # Also copy README if it exists
    readme_src = notebooks_src / 'README.md'
    if readme_src.exists():
        shutil.copy2(readme_src, notebooks_dest / 'README.md')
        print(f"✓ Copied README.md")
    
    print(f"✓ Notebook files copied to {notebooks_dest}")
