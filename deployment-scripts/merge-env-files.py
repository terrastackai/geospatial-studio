# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import re
import os
import argparse
from typing import Dict, List, Tuple

parser = argparse.ArgumentParser(
    description="Merge environment variables from old files into new files, preserving defined values in new files but overwriting empty ones."
)
parser.add_argument("--old-env-file", help="Path to the old .env file", type=str)
parser.add_argument("--new-env-file", help="Path to the new .env file", type=str)
parser.add_argument("--old-env-sh-file", help="Path to the old env.sh file", type=str)
parser.add_argument("--new-env-sh-file", help="Path to the new env.sh file", type=str)
args = parser.parse_args()

ENV_FILE_PAIRS = [
    (args.old_env_file, args.new_env_file, False),
    (args.old_env_sh_file, args.new_env_sh_file, True)
]

def parse_line(line: str, is_export: bool) -> Tuple[str, str, str, bool]:
    """
    Parses a configuration line and returns the key, value, and modified line.

    Args:
        line (str): The configuration line to parse.
        is_export (bool): Indicates if the line is an export statement.

    Returns:
        Tuple[str, str, str, bool]: A tuple containing the key, value, modified line, and a boolean indicating if the line was processed.
    """
    line = line.strip()
    
    if not line or line.startswith('#'):
        return "", "", line, False

    prefix = 'export ' if is_export and line.startswith('export ') else ''
    content = line[len(prefix):].strip()

    match = re.match(r'([a-zA-Z_][a-zA-Z0-9_]*)=(.*)', content)

    if match:
        key = match.group(1)
        value_raw = match.group(2).strip()
        
        if value_raw.startswith('"') and value_raw.endswith('"'):
            value = value_raw[1:-1]
        elif value_raw.startswith("'") and value_raw.endswith("'"):
            value = value_raw[1:-1]
        else:
            value = value_raw
            
        new_line = f"{prefix}{key}={value_raw}"
        
        return key, value, new_line, True
    
    return "", "", line, False

def merge_environment_files(old_path: str, new_path: str, is_export: bool):
    """
    Parses a single line from an environment file into its components.

    This function splits a line from an environment file into a key, value, and determines if it's an EXPORT variable.

    Args:
        line (str): The line to parse.
        is_export (bool): A flag indicating whether to consider EXPORT variables.

    Returns:
        Tuple[str, str, str, bool]: A tuple containing the key, value, new line (if modified), and a boolean indicating if it's an EXPORT variable.
    """
    if not os.path.exists(old_path):
        return

    new_content: List[str] = []
    new_vars_info: Dict[str, Tuple[int, bool]] = {} 

    if os.path.exists(new_path):
        with open(new_path, 'r') as f:
            for line in f:
                original_line = line.rstrip()
                key, value, _, is_var = parse_line(original_line, is_export)
                
                new_content.append(original_line)
                
                if is_var:
                    is_defined = bool(value)
                    new_vars_info[key] = (len(new_content) - 1, is_defined) 

    added_new_vars: List[str] = []
    
    with open(old_path, 'r') as f:
        for line in f:
            original_line = line.rstrip()
            key, value_stripped, new_line, is_var = parse_line(original_line, is_export)
            
            if is_var and value_stripped: 
                
                if key in new_vars_info:
                    line_index, is_defined_in_new = new_vars_info[key]

                    if not is_defined_in_new:
                        new_content[line_index] = new_line
                else:
                    added_new_vars.append(original_line)
                    new_vars_info[key] = (-1, True) 

    if added_new_vars:
        if new_content and new_content[-1] != "":
             new_content.append("") 
        
        new_content.append(f"# --- Variables Added from {old_path} ---")
        new_content.extend(added_new_vars)

    with open(new_path, 'w') as f:
        for line in new_content:
            f.write(line + '\n')


for old_file, new_file, is_export in ENV_FILE_PAIRS:
    if old_file and new_file:
        merge_environment_files(old_file, new_file, is_export)