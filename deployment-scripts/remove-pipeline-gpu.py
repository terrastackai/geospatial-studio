# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import yaml
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("filename", help="The filename of the values.yaml from which to remove the GPU specification.", type=str)
parser.add_argument("--remove-affinity-only", action="store_true", help="Remove affinity")
args = parser.parse_args()
# print(args.filename)


with open(args.filename) as stream:
    try:
        data = yaml.safe_load(stream)
    except yaml.YAMLError as exc:
        print(exc)

try:
    for p in data['processors']:
        if 'resources' in p:
            if args.remove_affinity_only:
                p.pop('affinity', None)
            else:
                if 'limits' in p['resources']:
                    p['resources']['limits'].pop('nvidia.com/gpu', None)
                if 'requests' in p['resources']:
                    p['resources']['requests'].pop('nvidia.com/gpu', None)
                p.pop('affinity', None)
                p['resources']['shm'] = "true"

except yaml.YAMLError as exc:
    print(exc)

# with open(args.filename.replace('.yaml','-cpu.yaml'), 'w') as stream:
with open(args.filename, 'w') as stream:
    yaml.dump(data, stream)
