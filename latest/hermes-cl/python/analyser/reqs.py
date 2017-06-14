import ast
import collections
import doctest
import fnmatch
import functools
import imp
import importlib
import os
import sys
import zipfile
import zipimport

# https://github.com/damnever/pigar/tree/master/pigar

try:
    from types import FileType  # py2
except ImportError:
    from io import IOBase as FileType  # py3

from .utils import parse_git_config
from .modules import ImportedModules
import json


def project_import_modules(project_path, ignores):
    """Get entire project all imported modules."""
    modules = ImportedModules()
    try_imports = set()
    local_mods = set()
    ignore_paths = collections.defaultdict(set)
    if not ignores:
        ignore_paths[project_path].add('.git')
    else:
        for path in ignores:
            parent_dir = os.path.dirname(path)
            ignore_paths[parent_dir].add(os.path.basename(path))

    for dirpath, dirnames, files in os.walk(project_path, followlinks=True):
        if dirpath in ignore_paths:
            dirnames[:] = [d for d in dirnames
                           if d not in ignore_paths[dirpath]]

        py_files = list()
        for fn in files:
            # C extension.
            if fn.endswith('.so'):
                local_mods.add(fn[:-3])
            # Normal Python file.
            if fn.endswith('.py'):
                local_mods.add(fn[:-3])
                py_files.append(fn)
        if '__init__.py' in files:
            local_mods.add(os.path.basename(dirpath))
        for file in py_files:
            fpath = os.path.join(dirpath, file)

            with open(fpath, 'rb') as f:
                fmodules, try_ipts = file_import_modules(fpath, f.read())
                modules |= fmodules
                try_imports |= try_ipts

    return modules, try_imports, list(local_mods)


def file_import_modules(fpath, fdata):
    """Get single file all imported modules."""
    modules = ImportedModules()
    str_codes = collections.deque([(fdata, 1)])
    try_imports = set()

    while str_codes:
        str_code, lineno = str_codes.popleft()
        ic = ImportChecker(fpath, lineno)
        try:
            parsed = ast.parse(str_code)
            ic.visit(parsed)
        # Ignore SyntaxError in Python code.
        except SyntaxError:
            pass
        modules |= ic.modules
        str_codes.extend(ic.str_codes)
        try_imports |= ic.try_imports
        del ic

    return modules, try_imports


class ImportChecker(object):

    def __init__(self, fpath, lineno):
        self._fpath = fpath
        self._lineno = lineno - 1
        self._modules = ImportedModules()
        self._str_codes = collections.deque()
        self._try_imports = set()

    def visit_Import(self, node, try_=False):
        """As we know: `import a [as b]`."""
        lineno = node.lineno + self._lineno

        for alias in node.names:
            module_name = extract_module_name(alias.name)
            if not is_stdlib(module_name):
                self._modules.add(module_name, self._fpath, lineno)
                if try_:
                    self._try_imports.add(module_name)

    def visit_ImportFrom(self, node, try_=False):
        """
        As we know: `from a import b [as c]`. If node.level is not 0,
        import statement like this `from .a import b`.
        """

        mod_name = node.module
        if mod_name is not None and not mod_name.startswith('.'):
            module_name = extract_module_name(mod_name)
            if not is_stdlib(module_name):
                self._modules.add(module_name, self._fpath, node.lineno + self._lineno)
                if try_:
                    self._try_imports.add(module_name)

    def visit_TryExcept(self, node):
        """
        If modules which imported by `try except` and not found,
        maybe them come from other Python version.
        """
        for ipt in node.body:
            if ipt.__class__.__name__.startswith('Import'):
                method = 'visit_' + ipt.__class__.__name__
                getattr(self, method)(ipt, True)
        for handler in node.handlers:
            for ipt in handler.body:
                if ipt.__class__.__name__.startswith('Import'):
                    method = 'visit_' + ipt.__class__.__name__
                    getattr(self, method)(ipt, True)

    # For Python 3.3+
    visit_Try = visit_TryExcept

    def visit_Exec(self, node):
        """
        Check `expression` of `exec(expression[, globals[, locals]])`.
        **Just available in python 2.**
        """
        if hasattr(node.body, 's'):
            self._str_codes.append((node.body.s, node.lineno + self._lineno))
        # PR#13: https://github.com/Damnever/pigar/pull/13
        # Sometimes exec statement may be called with tuple in Py2.7.6
        elif hasattr(node.body, 'elts') and len(node.body.elts) >= 1 and hasattr(node.body.elts[0], 's'):
            self._str_codes.append((node.body.elts[0].s, node.lineno + self._lineno))

    def visit_Expr(self, node):
        """
        Check `expression` of `eval(expression[, globals[, locals]])`.
        Check `expression` of `exec(expression[, globals[, locals]])`
        in python 3.
        Check `name` of `__import__(name[, globals[, locals[,
        fromlist[, level]]]])`.
        Check `name` or `package` of `importlib.import_module(name,
        package=None)`.
        """
        # Built-in functions
        value = node.value
        if isinstance(value, ast.Call):
            if hasattr(value.func, 'id'):
                if (value.func.id == 'eval' and
                        hasattr(node.value.args[0], 's')):
                    self._str_codes.append(
                        (node.value.args[0].s, node.lineno + self._lineno))
                # **`exec` function in Python 3.**
                elif (value.func.id == 'exec' and
                          hasattr(node.value.args[0], 's')):
                    self._str_codes.append(
                        (node.value.args[0].s, node.lineno + self._lineno))
                # `__import__` function.
                elif (value.func.id == '__import__' and
                              len(node.value.args) > 0 and
                          hasattr(node.value.args[0], 's')):

                    module_name = extract_module_name(node.value.args[0].s)
                    if not is_stdlib(module_name):
                        self._modules.add(module_name, self._fpath,
                                          node.lineno + self._lineno)
            # `import_module` function.
            elif getattr(value.func, 'attr', '') == 'import_module':
                module = getattr(value.func, 'value', None)
                if (module is not None and
                            getattr(module, 'id', '') == 'importlib'):
                    args = node.value.args
                    arg_len = len(args)
                    if arg_len > 0 and hasattr(args[0], 's'):
                        name = args[0].s
                        if not name.startswith('.'):
                            module_name = extract_module_name(name)
                            if not is_stdlib(module_name):
                                self._modules.add(name, self._fpath,
                                                  node.lineno + self._lineno)
                        elif arg_len == 2 and hasattr(args[1], 's'):
                            module_name = extract_module_name(args[1].s)
                            if not is_stdlib(module_name):
                                self._modules.add(args[1].s, self._fpath,
                                                  node.lineno + self._lineno)

    def visit_FunctionDef(self, node):
        """
        Check docstring of function, if docstring is used for doctest.
        """
        docstring = self._parse_docstring(node)
        if docstring:
            self._str_codes.append((docstring, node.lineno + self._lineno + 2))

    def visit_ClassDef(self, node):
        """
        Check docstring of class, if docstring is used for doctest.
        """
        docstring = self._parse_docstring(node)
        if docstring:
            self._str_codes.append((docstring, node.lineno + self._lineno + 2))

    def visit(self, node):
        """Visit a node, no recursively."""
        for node in ast.walk(node):
            method = 'visit_' + node.__class__.__name__
            getattr(self, method, lambda x: x)(node)

    @staticmethod
    def _parse_docstring(node):
        """Extract code from docstring."""
        docstring = ast.get_docstring(node)
        if docstring:
            parser = doctest.DocTestParser()
            try:
                dt = parser.get_doctest(docstring, {}, None, None, None)
            except ValueError:
                # >>> 'abc'
                pass
            else:
                examples = dt.examples
                return '\n'.join([example.source for example in examples])
        return None

    @property
    def modules(self):
        return self._modules

    @property
    def str_codes(self):
        return self._str_codes

    @property
    def try_imports(self):
        return set((name.split('.')[0] if name and '.' in name else name)
                   for name in self._try_imports)


def extract_module_name(name):
    if name.startswith('.'):
        return name.split(".")[1]
    else:
        return name.split(".")[0]


def _checked_cache(func):
    checked = dict()

    @functools.wraps(func)
    def _wrapper(name):
        if name not in checked:
            checked[name] = func(name)
        return checked[name]

    return _wrapper


@_checked_cache
def is_stdlib(name):
    """Check whether it is stdlib module."""
    exist = True
    module_info = ('', '', '')
    try:
        module_info = imp.find_module(name)
    except ImportError:

        if hasattr(importlib, 'find_loader'):
            loader = importlib.find_loader(name)
            if loader is not None:
                if not isinstance(loader, zipimport.zipimporter):
                    module_info = (loader.name, loader.path)
                    sys.modules.pop(name)
                else:
                    module_info = ('', loader.archive)
            else:
                exist = False

    # Testcase: ResourceWarning
    if isinstance(module_info[0], FileType):
        module_info[0].close()
    if exist and (module_info[1] is not None and
                      ('site-packages' in module_info[1] or
                               'dist-packages' in module_info[1])):
        exist = False
    return exist


def get_installed_pkgs_detail():
    """Get mapping for import top level name
    and install package name with version.
    """
    mapping = dict()

    for path in sys.path:
        if os.path.isdir(path) and path.rstrip('/').endswith(
                ('site-packages', 'dist-packages')):
            mapping.update(_search_path(path))

    return mapping


def _search_path(path):
    """
    Looks inside a directory for installed modules in order to get their pip name and their version

    :param path: where to look
    :return:
    """
    mapping = dict()

    for file in os.listdir(path):
        # Install from PYPI.
        if fnmatch.fnmatch(file, '*-info'):
            top_level = os.path.join(path, file, 'top_level.txt')
            if not os.path.isfile(top_level):
                continue
            pkg_name, version = file.split('-')[:2]

            pkg_info = os.path.join(path, file, 'PKG-INFO')
            if os.path.isfile(pkg_info):
                with open(pkg_info, 'r') as f:
                    for line in f:
                        parsed = line.strip().split(':')
                        if parsed[0] == "Name":
                            pkg_name = parsed[1].strip()
                            break

            metadata_json = os.path.join(path, file, 'metadata.json')
            if os.path.isfile(metadata_json):
                with open(metadata_json) as f:
                    metadata = json.load(f)
                    pkg_name = metadata['name']

            if version.endswith('dist'):
                version = version.rsplit('.', 1)[0]
            with open(top_level, 'r') as f:
                for line in f:
                    mapping[line.strip()] = (pkg_name, version)

        # Install from local and available in GitHub.
        elif fnmatch.fnmatch(file, '*-link'):
            link = os.path.join(path, file)
            if not os.path.isfile(link):
                continue
            # Link path.
            with open(link, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line != '.':
                        dev_dir = line
            if not dev_dir:
                continue
            # Egg info path.
            info_dir = [_file for _file in os.listdir(dev_dir)
                        if _file.endswith('egg-info')]
            if not info_dir:
                continue
            info_dir = info_dir[0]
            top_level = os.path.join(dev_dir, info_dir, 'top_level.txt')
            # Check whether it can be imported.
            if not os.path.isfile(top_level):
                continue

            # Check .git dir.
            git_path = os.path.join(dev_dir, '.git')
            if os.path.isdir(git_path):
                config = parse_git_config(git_path)
                url = config.get('remote "origin"', {}).get('url')
                if not url:
                    continue
                branch = 'branch "master"'
                if branch not in config:
                    for section in config:
                        if 'branch' in section:
                            branch = section
                            break
                if not branch:
                    continue
                branch = branch.split()[1][1:-1]

                pkg_name = info_dir.split('.egg')[0]
                git_url = 'git+{0}@{1}#egg={2}'.format(url, branch, pkg_name)
                with open(top_level, 'r') as f:
                    for line in f:
                        mapping[line.strip()] = ('-e', git_url)

        elif fnmatch.fnmatch(file, '*.egg'):
            file_path = os.path.join(path, file)

            if zipfile.is_zipfile(file_path):
                pkg_name, version = file.split('-')[:2]

                with zipfile.ZipFile(file_path, 'r') as egg:
                    inner_list = egg.namelist()
                    if 'EGG-INFO/PKG-INFO' in inner_list:
                        with egg.open('EGG-INFO/PKG-INFO', 'r') as f:
                            for line in f:
                                parsed = line.decode('utf8').strip().split(':')
                                if parsed[0] == "Name":
                                    pkg_name = parsed[1].strip()
                                    break

                    if version.endswith('dist'):
                        version = version.rsplit('.', 1)[0]
                    if 'EGG-INFO/top_level.txt' in inner_list:
                        with egg.open('EGG-INFO/top_level.txt', 'r') as f:
                            for line in f:
                                mapping[line.decode('utf8').strip()] = (pkg_name, version)

            elif os.path.isdir(file_path):
                pkg_name, version = file.split('-')[:2]

                egg_info = os.path.join(file_path, 'EGG-INFO')

                if os.path.isdir(egg_info):
                    pkg_info = os.path.join(egg_info, 'PKG-INFO')
                    if os.path.isfile(pkg_info):
                        with open(pkg_info, 'r') as f:
                            for line in f:
                                parsed = line.strip().split(':')
                                if parsed[0] == "Name":
                                    pkg_name = parsed[1].strip()
                                    break

                    if version.endswith('dist'):
                        version = version.rsplit('.', 1)[0]

                    top_level = os.path.join(egg_info, 'top_level.txt')
                    if os.path.isfile(top_level):
                        with open(top_level, 'r') as f:
                            for line in f:
                                mapping[line.strip()] = (pkg_name, version)

    return mapping
