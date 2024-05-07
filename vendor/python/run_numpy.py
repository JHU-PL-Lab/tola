import importlib.machinery
import sys


class TolaMetaPathFinder(importlib.machinery.PathFinder):
  def make_tola_path():
    if sys.platform == 'darwin':
      return '/Users/ex/code/tola/tola/vendor/tola_pkgm'
    else:
      return '/home/ex/code/tola/vendor/tola_pkgm'
  tola_path = make_tola_path()

  def make_ignored_modules():
     return {'backports_abc', '_winapi', 'nt', 'pickle5', '_wmi'}
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
              spec.submodule_search_locations = importlib.machinery.PathFinder._NamespacePath(fullname, namespace_path, cls._get_spec)
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

print(tola_cool.foo.bar)

if __name__ == "__main__":
  import numpy as np
  print (np.zeros(1,))
  