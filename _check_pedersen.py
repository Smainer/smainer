#!/usr/bin/env python3
"""Quick check for pedersen_hash import."""
import sys

# Check various import paths
paths_tried = []

try:
    from starknet_py.hash.utils import pedersen_hash
    paths_tried.append(("starknet_py.hash.utils.pedersen_hash", "OK"))
except Exception as e:
    paths_tried.append(("starknet_py.hash.utils.pedersen_hash", str(e)))

try:
    from starknet_py.hash.hash_method import pedersen_hash as ph2
    paths_tried.append(("starknet_py.hash.hash_method.pedersen_hash", "OK"))
except Exception as e:
    paths_tried.append(("starknet_py.hash.hash_method.pedersen_hash", str(e)))

try:
    from starknet_py.cairo.felt import pedersen_hash as ph3
    paths_tried.append(("starknet_py.cairo.felt.pedersen_hash", "OK"))
except Exception as e:
    paths_tried.append(("starknet_py.cairo.felt.pedersen_hash", str(e)))

try:
    from starknet_py.hash.selector import pedersen_hash as ph4
    paths_tried.append(("starknet_py.hash.selector.pedersen_hash", "OK"))
except Exception as e:
    paths_tried.append(("starknet_py.hash.selector.pedersen_hash", str(e)))

try:
    import starknet_py
    paths_tried.append(("starknet_py version", starknet_py.__version__))
except Exception as e:
    paths_tried.append(("starknet_py version", str(e)))

try:
    import starknet_py.hash.utils as u
    paths_tried.append(("hash.utils dir", str([x for x in dir(u) if not x.startswith('_')])))
except Exception as e:
    paths_tried.append(("hash.utils dir", str(e)))

with open("/home/smainer/Smainer/_ped_results.txt", "w") as f:
    for path, result in paths_tried:
        line = f"{path}: {result}"
        f.write(line + "\n")
        print(line)
