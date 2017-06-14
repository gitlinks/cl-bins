import os


def parse_git_config(path):
    """Parse git config file."""
    config = dict()
    section = None

    with open(os.path.join(path, 'config'), 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('['):
                section = line[1: -1].strip()
                config[section] = dict()
            elif section:
                key, value = line.replace(' ', '').split('=')
                config[section][key] = value
    return config
