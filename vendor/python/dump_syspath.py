# should use `import sysconfig`
# https://docs.python.org/3/library/sysconfig.html#installation-paths
# https://stackoverflow.com/questions/122327/how-do-i-find-the-location-of-my-python-site-packages-directory

# these are all user scope

# python3 -c "import sysconfig; print(sysconfig.get_path('stdlib'))"
# /usr/lib/python3.10

# python3 -c "import sysconfig; print(sysconfig.get_path('platstdlib'))"
# /usr/lib/python3.10

# python3 -c "import sysconfig; print(sysconfig.get_path('platlib'))"
# /usr/local/lib/python3.10/dist-packages

# python3 -c "import sysconfig; print(sysconfig.get_path('purelib'))"
# /usr/local/lib/python3.10/dist-packages

# python3 -c "import sysconfig; print(sysconfig.get_path('include'))"
# /usr/include/python3.10

# python3 -c "import sysconfig; print(sysconfig.get_paths())"

# dist-packages not site-packages
# /home/ex/.local/lib/python3.10/site-packages

# python3 -m sysconfig | grep packages
# python3 -m site | grep packages
if __name__ == "__main__":
  import sys
  for p in sys.path:
    print(p)