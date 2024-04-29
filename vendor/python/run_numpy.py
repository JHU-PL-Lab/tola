import importlib.machinery
import sys

class TolaMetaPathFinder(importlib.machinery.PathFinder):
  @classmethod
  def find_spec(cls, fullname, path=None, target=None):
    # print(fullname)
    if fullname:
      print('find_spec:', fullname, path, target)
      tola_path = '/home/ex/code/tola/ventor/tola_pkgm'
      # spec = importlib.machinery.PathFinder.find_spec(fullname, path=tola_path, target=target)
      
      if path is None:
          path = sys.path
      spec = cls._get_spec(fullname, path, target)
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
        
      print(spec)
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

import tola_pkgm

if __name__ == "__main__":
  import numpy as np
  print (np.zeros(1,))
  