# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import os
import re
import argparse
from typing import List, Dict, Tuple

parser = argparse.ArgumentParser(
    description="Validate environment variables."
)
parser.add_argument("--env-file", help="Path to the .env file", type=str)
parser.add_argument("--env-variables", help="List of .env variables to validate", type=str)
parser.add_argument("--env-sh-file", help="Path to the env.sh file", type=str)
parser.add_argument("--env-sh-variables", help="List of env.sh variables to validate", type=str)
args = parser.parse_args()

validation_values = [
    {
        "file": args.env_file,
        "variables": args.env_variables.split(",") if args.env_variables else [],
    },
    {
        "file": args.env_sh_file,
        "variables": args.env_sh_variables.split(",") if args.env_sh_variables else [],
    }
]

def check_config_file(filepath: str, required_vars: List[str]) -> Tuple[bool, Dict[str, str]]:
    """
    Check if a configuration file contains all required variables.

    This function reads a configuration file and verifies if it contains all the required variables.
    It returns a tuple where the first element is a boolean indicating if all required variables are present,
    and the second element is a dictionary mapping each variable to its status (success, warning, or error).

    Args:
        filepath (str): The path to the configuration file.
        required_vars (List[str]): A list of required variable names.

    Returns:
        Tuple[bool, Dict[str, str]]: A tuple containing a boolean indicating overall validity and a dictionary
            with variable status messages.
    """
    VAR_REGEX = re.compile(
        r'^\s*' 
        r'(?:export\s+)?' 
        r'([A-Z_][A-Z0-9_]*)' 
        r'\s*=\s*' 
        r'(' 
            r'(?:".*?"|\'.*?\'|[^#\n]*)?'
        r')'
        r'\s*(?:#.*)?$', 
        re.IGNORECASE | re.MULTILINE
    )
    
    file_vars: Dict[str, str] = {}
    
    if not os.path.exists(filepath):
        print(f"❌ ERROR: Env file not found: {filepath}")
        return False, {var: "NOT FOUND (File missing)" for var in required_vars}

    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()

            if not line or line.startswith('#'):
                continue
            
            match = VAR_REGEX.match(line)
            if match:
                var_name = match.group(1)
                raw_value = match.group(2).strip()

                if raw_value.startswith(('"', "'")) and raw_value.endswith(('"', "'")):
                    value = raw_value[1:-1]
                else:
                    value = raw_value
                    
                file_vars[var_name] = value.strip()


    all_valid = True
    status_map: Dict[str, str] = {}
    
    for var in required_vars:
        if var not in file_vars:
            status_map[var] = f"❌ ERROR: **{var}** is NOT found."
            all_valid = False
        elif not file_vars[var]:
            status_map[var] = f"⚠️ WARNING: **{var}** is defined but EMPTY."
            all_valid = False
        else:
            status_map[var] = f"✅ Success: **{var}** is set."

    return all_valid, status_map

global_status = True
for entry in validation_values:
    is_valid, status_map = check_config_file(entry["file"], entry["variables"])
    
    for var, status in status_map.items():
        print(status)
        
    if not is_valid:
        global_status = False

if global_status:
    print("All required variables were found and set across all configuration files.")
else:
    print("One or more required variables are missing or empty. Check the logs above.")
    exit(1)