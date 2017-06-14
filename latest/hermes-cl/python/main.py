import argparse
import json

from analyser.reqs import project_import_modules, file_import_modules, get_installed_pkgs_detail

parser = argparse.ArgumentParser(description='Get the used modules')
parser.add_argument('--folder')
parser.add_argument('--file')

args = parser.parse_args()

installed_packages = get_installed_pkgs_detail()

if args.folder is not None:
    modules, try_imports, local_mods = project_import_modules(args.folder, False)

    meta = {}
    for module in modules.keys():
        if module in installed_packages:
            meta[module] = {}
            meta[module]["version"] = installed_packages[module][1]
            meta[module]["library_name"] = installed_packages[module][0]

    print(json.dumps({
        "modules": modules,
        "meta": meta,
        "try_imports": list(try_imports),
        "local_mods": local_mods
    }))


elif args.file is not None:
    with open(args.file, 'rb') as f:
        modules, try_imports = file_import_modules(args.file, f.read())

        meta = {}
        for module in modules.keys():
            if module in installed_packages:
                meta[module] = {}
                meta[module]["version"] = installed_packages[module][1]
                meta[module]["library_name"] = installed_packages[module][0]

        print(json.dumps({
            "modules": modules,
            "meta": meta,
            "try_imports": list(try_imports)
        }))

