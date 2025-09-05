import importlib.machinery
import sys

# hack; it's a hacky code to one line to run on python3.10
is_python3_12 = sys.version_info.major == 3 and sys.version_info.minor == 12
             
class TolaMetaPathFinder(importlib.machinery.PathFinder):
  def make_tola_path():
    if sys.platform == 'darwin':
      return '/Users/ex/code/tola/tola/vendor/tola_pkgm'
    else:
      return '/home/ex/code/tola/vendor/tola_pkgm'
  tola_path = make_tola_path()

  def make_ignored_modules():
    set1 = {'backports_abc', '_winapi', 'nt', 'pickle5', '_wmi'}
    set2 = {'org', 'msvcrt', 'cStringIO', 'cPickle'}
    return set.union(set1, set2)
      
  ignored_modules = make_ignored_modules()

  @classmethod
  def find_spec(cls, fullname, path=None, target=None):
    if fullname in TolaMetaPathFinder.ignored_modules:
       return None

    if fullname:
      print('find_spec:', fullname, path, target)
      # if path is None:
      #   path = sys.path
      path = [TolaMetaPathFinder.tola_path] + sys.path

      # spec = importlib.machinery.PathFinder.find_spec(fullname, path=tola_path, target=target)
      spec = cls._get_spec(fullname, path, target)
      print('spec:', spec)
      if spec is None:
          return None
      elif spec.loader is None:
          namespace_path = spec.submodule_search_locations
          if namespace_path:
              # We found at least one namespace path.  Return a spec which
              # can create the namespace package.
              spec.origin = None

              # spec.submodule_search_locations = importlib.machinery._NamespacePath(fullname, namespace_path, cls._get_spec)              
              _NamespacePath = importlib.machinery._NamespacePathif if is_python3_12 else importlib._bootstrap_external._NamespacePath
              spec.submodule_search_locations = _NamespacePath(fullname, namespace_path, cls._get_spec)
              return spec
          else:
              return None
      else:
          return spec

# For illustrative purposes only.
# TolaMetaPathFinder = importlib.machinery.PathFinder
SpamPathEntryFinder = importlib.machinery.FileFinder
loader_details = (importlib.machinery.SourceFileLoader,
                  importlib.machinery.SOURCE_SUFFIXES)

# Setting up a meta path finder.
# Make sure to put the finder in the proper location in the list in terms of
# priority.
sys.meta_path.append(TolaMetaPathFinder)

# Setting up a path entry finder.
# Make sure to put the path hook in the proper location in the list in terms
# of priority.
sys.path_hooks.append(SpamPathEntryFinder.path_hook(loader_details))

# import numpy
import importlib

t = importlib.import_module("numpy")

print(t)

import tola_cool

# import tola_cool.foo 
print(tola_cool)
print(tola_cool.u)
print(tola_cool.foo)
print(tola_cool.foo.bar)
print(tola_cool.foo2)
print(tola_cool.bar2)
print(tola_cool.foo2.bar2)

if __name__ == "__main__":
  import numpy as np
  print (np.zeros(1,))
  