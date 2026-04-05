# conf-* Package Reverse Dependencies (classified)

Sorted by reverse dependency count (non-conf packages depending on it).
See [conf_package_analysis.md](../conf_package_analysis.md) for full
category descriptions and eliminability analysis.

### Category key

| Category | Build section does | Example |
|----------|-------------------|---------|
| pkgconfig | Runs `pkg-config <libname>` to check C library | conf-sqlite3, conf-zlib |
| version_check | Runs `<tool> --version` or `-V` to verify tool exists | conf-npm, conf-perl |
| compile_test | Compiles a `test.c` against headers/libs | conf-bluetooth, conf-pam |
| no_build | Empty build — just depexts declaration | (passive packages) |
| which_check | Runs `which <tool>` or `command -v` | conf-which, conf-wget |
| custom_script | Custom `configure.sh`/`build.sh` with project-specific logic | conf-llvm, conf-cmake |
| other | Mixed/unclassified (many are version_check or compile_test missed by grep) | conf-autoconf, conf-python-3 |
| unclassified | In revdeps but not in classification output (newer packages) | — |

| RevDeps | Category      | Package                              |
| ------- | ------------- | ------------------------------------ |
| 492     | pkgconfig     | conf-pkg-config                      |
| 175     | pkgconfig     | conf-ffmpeg                          |
| 133     | other         | conf-autoconf                        |
| 129     | pkgconfig     | conf-gmp                             |
| 119     | other         | conf-python-3                        |
| 102     | custom_script | conf-cmake                           |
| 96      | version_check | conf-npm                             |
| 92      | version_check | conf-perl                            |
| 88      | which_check   | conf-which                           |
| 69      | custom_script | conf-libev                           |
| 66      | version_check | conf-gcc                             |
| 65      | other         | conf-findutils                       |
| 63      | version_check | conf-gnuplot                         |
| 61      | version_check | conf-g++                             |
| 59      | other         | conf-m4                              |
| 58      | version_check | conf-c++                             |
| 56      | pkgconfig     | conf-zlib                            |
| 55      | pkgconfig     | conf-gtksourceview                   |
| 49      | pkgconfig     | conf-mpfr                            |
| 47      | which_check   | conf-time                            |
| 47      | other         | conf-graphviz                        |
| 46      | version_check | conf-git                             |
| 46      | compile_test  | conf-rdkit                           |
| 44      | pkgconfig     | conf-gtksourceview3                  |
| 40      | other         | conf-diffutils                       |
| 37      | other         | conf-python-3-dev                    |
| 36      | pkgconfig     | conf-ncurses                         |
| 34      | pkgconfig     | conf-libpcre                         |
| 31      | other         | conf-openssl                         |
| 30      | pkgconfig     | conf-sqlite3                         |
| 30      | pkgconfig     | conf-adwaita-icon-theme              |
| 30      | compile_test  | conf-ppl                             |
| 28      | version_check | conf-mingw-w64-gcc-x86_64            |
| 28      | version_check | conf-mingw-w64-gcc-i686              |
| 28      | other         | conf-python-2-7                      |
| 26      | pkgconfig     | conf-libssl                          |
| 26      | custom_script | conf-llvm                            |
| 25      | other         | conf-r                               |
| 23      | version_check | conf-rust-2021                       |
| 23      | version_check | conf-jq                              |
| 23      | pkgconfig     | conf-cairo                           |
| 23      | compile_test  | conf-lapack                          |
| 22      | pkgconfig     | conf-gnomecanvas                     |
| 22      | other         | conf-libcurl                         |
| 22      | compile_test  | conf-blas                            |
| 21      | version_check | conf-rust                            |
| 21      | no_build      | conf-boost                           |
| 20      | pkgconfig     | conf-tcl                             |
| 20      | other         | conf-tk                              |
| 18      | other         | conf-bmake                           |
| 18      | compile_test  | conf-linux-libc-dev                  |
| 17      | version_check | conf-clang                           |
| 17      | version_check | conf-bash                            |
| 17      | pkgconfig     | conf-openblas                        |
| 17      | pkgconfig     | conf-gtk3                            |
| 17      | custom_script | conf-libclang                        |
| 16      | other         | conf-binutils                        |
| 15      | version_check | conf-capnproto                       |
| 15      | other         | conf-automake                        |
| 14      | which_check   | conf-liblinear-tools                 |
| 14      | version_check | conf-swi-prolog                      |
| 14      | version_check | conf-protoc                          |
| 14      | other         | conf-msvc64                          |
| 14      | other         | conf-msvc32                          |
| 14      | compile_test  | conf-sundials                        |
| 13      | pkgconfig     | conf-zstd                            |
| 13      | pkgconfig     | conf-postgresql                      |
| 13      | pkgconfig     | conf-mesa                            |
| 13      | pkgconfig     | conf-libxrandr                       |
| 13      | pkgconfig     | conf-libxinerama                     |
| 13      | pkgconfig     | conf-libxi                           |
| 13      | pkgconfig     | conf-libxcursor                      |
| 13      | pkgconfig     | conf-gsl                             |
| 13      | pkgconfig     | conf-gmp-powm-sec                    |
| 13      | pkgconfig     | conf-glfw3                           |
| 12      | pkgconfig     | conf-libnl3                          |
| 11      | version_check | conf-ruby                            |
| 11      | version_check | conf-perl-string-shellquote          |
| 11      | pkgconfig     | conf-zmq                             |
| 11      | other         | conf-mysql                           |
| 10      | version_check | conf-perl-ipc-system-simple          |
| 10      | version_check | conf-emacs                           |
| 10      | pkgconfig     | conf-freetype                        |
| 9       | version_check | conf-aclocal                         |
| 9       | pkgconfig     | conf-secp256k1                       |
| 9       | pkgconfig     | conf-sdl2                            |
| 9       | pkgconfig     | conf-openbabel                       |
| 9       | pkgconfig     | conf-libseccomp                      |
| 9       | pkgconfig     | conf-hidapi                          |
| 9       | other         | conf-rocksdb                         |
| 8       | version_check | conf-gfortran                        |
| 8       | version_check | conf-bison                           |
| 8       | version_check | conf-age                             |
| 8       | pkgconfig     | conf-sdl2-ttf                        |
| 8       | pkgconfig     | conf-r-mathlib                       |
| 8       | pkgconfig     | conf-efl                             |
| 8       | compile_test  | conf-fts                             |
| 7       | version_check | conf-ninja                           |
| 7       | pkgconfig     | conf-sdl2-image                      |
| 7       | pkgconfig     | conf-libmaxminddb                    |
| 7       | pkgconfig     | conf-libgl                           |
| 7       | pkgconfig     | conf-gtk2                            |
| 7       | pkgconfig     | conf-glade                           |
| 7       | other         | conf-neko                            |
| 6       | version_check | conf-flex                            |
| 6       | pkgconfig     | conf-mingw-w64-zstd-x86_64           |
| 6       | pkgconfig     | conf-mingw-w64-zstd-i686             |
| 6       | pkgconfig     | conf-mariadb                         |
| 6       | pkgconfig     | conf-libpcre2-8                      |
| 6       | pkgconfig     | conf-libglu                          |
| 6       | pkgconfig     | conf-libffi                          |
| 6       | pkgconfig     | conf-gssapi                          |
| 6       | pkgconfig     | conf-gnutls                          |
| 6       | pkgconfig     | conf-glew                            |
| 6       | pkgconfig     | conf-gles2                           |
| 6       | other         | conf-texlive                         |
| 6       | other         | conf-pandoc                          |
| 6       | other         | conf-pam                             |
| 6       | other         | conf-ida                             |
| 6       | compile_test  | conf-netsnmp                         |
| 6       | compile_test  | conf-glpk                            |
| 6       | compile_test  | conf-fswatch                         |
| 5       | version_check | conf-rust-2018                       |
| 5       | version_check | conf-libtool                         |
| 5       | pkgconfig     | conf-xkbcommon                       |
| 5       | pkgconfig     | conf-sfml2                           |
| 5       | pkgconfig     | conf-sdl2-mixer                      |
| 5       | pkgconfig     | conf-openimageio                     |
| 5       | pkgconfig     | conf-freeglut                        |
| 5       | other         | conf-radare2                         |
| 5       | other         | conf-openjdk                         |
| 5       | other         | conf-env-travis                      |
| 5       | other         | conf-bap-llvm                        |
| 5       | custom_script | conf-qt                              |
| 5       | compile_test  | conf-cuda                            |
| 4       | which_check   | conf-wget                            |
| 4       | which_check   | conf-sdpa                            |
| 4       | which_check   | conf-libsvm-tools                    |
| 4       | version_check | conf-x86_64-linux-gnu-gcc            |
| 4       | version_check | conf-aarch64-linux-gnu-gcc           |
| 4       | pkgconfig     | conf-xxhash                          |
| 4       | pkgconfig     | conf-wayland-protocols               |
| 4       | pkgconfig     | conf-unwind                          |
| 4       | pkgconfig     | conf-taglib                          |
| 4       | pkgconfig     | conf-libwayland                      |
| 4       | pkgconfig     | conf-libogg                          |
| 4       | pkgconfig     | conf-libevent                        |
| 4       | pkgconfig     | conf-libX11                          |
| 4       | pkgconfig     | conf-goocanvas2                      |
| 4       | pkgconfig     | conf-glib-2                          |
| 4       | pkgconfig     | conf-fftw3                           |
| 4       | other         | conf-lz4                             |
| 4       | other         | conf-libobjc2                        |
| 4       | other         | conf-gnustep-gui                     |
| 4       | other         | conf-gnustep-base                    |
| 4       | custom_script | conf-llvm-static                     |
| 4       | compile_test  | conf-flint                           |
| 3       | which_check   | conf-timeout                         |
| 3       | which_check   | conf-csdp                            |
| 3       | version_check | conf-hg                              |
| 3       | version_check | conf-ghostscript                     |
| 3       | version_check | conf-asciidoc                        |
| 3       | pkgconfig     | conf-sdl-ttf                         |
| 3       | pkgconfig     | conf-sdl-image                       |
| 3       | pkgconfig     | conf-portaudio                       |
| 3       | pkgconfig     | conf-plplot                          |
| 3       | pkgconfig     | conf-pango                           |
| 3       | pkgconfig     | conf-oniguruma                       |
| 3       | pkgconfig     | conf-nlopt                           |
| 3       | pkgconfig     | conf-mad                             |
| 3       | pkgconfig     | conf-libmpg123                       |
| 3       | pkgconfig     | conf-libmd                           |
| 3       | pkgconfig     | conf-liblz4                          |
| 3       | pkgconfig     | conf-libjpeg                         |
| 3       | pkgconfig     | conf-libblake3                       |
| 3       | pkgconfig     | conf-ao                              |
| 3       | pkgconfig     | conf-alsa                            |
| 3       | other         | conf-tzdata                          |
| 3       | other         | conf-python3-tomli                   |
| 3       | other         | conf-python3-pyparsing               |
| 3       | no_build      | conf-lame                            |
| 3       | no_build      | conf-ladspa                          |
| 3       | no_build      | conf-dssi                            |
| 3       | compile_test  | conf-libbz2                          |
| 2       | version_check | conf-qemu-img                        |
| 2       | version_check | conf-mingw-w64-g++-x86_64            |
| 2       | version_check | conf-mingw-w64-g++-i686              |
| 2       | version_check | conf-dpkg                            |
| 2       | version_check | conf-cpio                            |
| 2       | pkgconfig     | conf-srt                             |
| 2       | pkgconfig     | conf-shine                           |
| 2       | pkgconfig     | conf-sdl-mixer                       |
| 2       | pkgconfig     | conf-samplerate                      |
| 2       | pkgconfig     | conf-pulseaudio                      |
| 2       | pkgconfig     | conf-libsodium                       |
| 2       | pkgconfig     | conf-librsvg2                        |
| 2       | pkgconfig     | conf-libpng                          |
| 2       | pkgconfig     | conf-libmosquitto                    |
| 2       | pkgconfig     | conf-libcorosync                     |
| 2       | pkgconfig     | conf-gd                              |
| 2       | pkgconfig     | conf-allegro5                        |
| 2       | other         | conf-python3-yaml                    |
| 2       | other         | conf-libportmidi                     |
| 2       | other         | conf-bluetooth                       |
| 2       | no_build      | conf-protoc-dev                      |
| 2       | no_build      | conf-libgif                          |
| 2       | no_build      | conf-bpftool                         |
| 2       | custom_script | conf-llvm-shared                     |
| 2       | custom_script | conf-dkml-cross-toolchain            |
| 2       | compile_test  | conf-xen                             |
| 2       | compile_test  | conf-tidy                            |
| 2       | compile_test  | conf-snappy                          |
| 2       | compile_test  | conf-mbedtls                         |
| 2       | compile_test  | conf-leveldb                         |
| 2       | compile_test  | conf-calcium                         |
| 2       | compile_test  | conf-arb                             |
| 2       | compile_test  | conf-antic                           |
| 1       | pkgconfig     | conf-vips                            |
| 1       | pkgconfig     | conf-trexio                          |
| 1       | pkgconfig     | conf-taglib_c                        |
| 1       | pkgconfig     | conf-soundtouch                      |
| 1       | pkgconfig     | conf-sdl-gfx                         |
| 1       | pkgconfig     | conf-mpi                             |
| 1       | pkgconfig     | conf-libxcb-xkb                      |
| 1       | pkgconfig     | conf-libxcb-shm                      |
| 1       | pkgconfig     | conf-libxcb-keysyms                  |
| 1       | pkgconfig     | conf-libxcb-image                    |
| 1       | pkgconfig     | conf-libxcb                          |
| 1       | pkgconfig     | conf-libvorbis                       |
| 1       | pkgconfig     | conf-libudev                         |
| 1       | pkgconfig     | conf-libtheora                       |
| 1       | pkgconfig     | conf-libspeex                        |
| 1       | pkgconfig     | conf-libopus                         |
| 1       | pkgconfig     | conf-liblzma                         |
| 1       | pkgconfig     | conf-libfuse                         |
| 1       | pkgconfig     | conf-libfontconfig                   |
| 1       | pkgconfig     | conf-libflac                         |
| 1       | pkgconfig     | conf-libdw                           |
| 1       | pkgconfig     | conf-libdrm                          |
| 1       | pkgconfig     | conf-libXft                          |
| 1       | pkgconfig     | conf-jack                            |
| 1       | pkgconfig     | conf-guile                           |
| 1       | pkgconfig     | conf-gstreamer                       |
| 1       | pkgconfig     | conf-gpiod                           |
| 1       | pkgconfig     | conf-gobject-introspection           |
| 1       | pkgconfig     | conf-frei0r                          |
| 1       | pkgconfig     | conf-fdkaac                          |
| 1       | pkgconfig     | conf-faad                            |
| 1       | pkgconfig     | conf-expat                           |
| 1       | pkgconfig     | conf-brotli                          |
| 1       | other         | conf-wxwidgets                       |
| 1       | other         | conf-scdoc                           |
| 1       | other         | conf-pic-switch                      |
| 1       | other         | conf-mpfr-paths                      |
| 1       | other         | conf-gmp-paths                       |
| 1       | other         | conf-dbm                             |
| 1       | other         | conf-cosmopolitan                    |
| 1       | no_build      | conf-sysinfo                         |
| 1       | no_build      | conf-readline                        |
| 1       | no_build      | conf-numa                            |
| 1       | no_build      | conf-lilv                            |
| 1       | no_build      | conf-liburing                        |
| 1       | no_build      | conf-libmagic                        |
| 1       | no_build      | conf-liblo                           |
| 1       | no_build      | conf-libbpf                          |
| 1       | no_build      | conf-libargon2                       |
| 1       | custom_script | conf-python-3-7                      |
| 1       | compile_test  | conf-opencc1_1                       |
| 1       | compile_test  | conf-opencc1                         |
| 1       | compile_test  | conf-opencc0                         |
| 1       | compile_test  | conf-mecab                           |
| 1       | compile_test  | conf-libgccjit                       |
| 0       | which_check   | conf-rust-llvm                       |
| 0       | version_check | conf-vim                             |
| 0       | version_check | conf-tree-sitter                     |
| 0       | version_check | conf-rust-2024                       |
| 0       | version_check | conf-povray                          |
| 0       | version_check | conf-nmap                            |
| 0       | version_check | conf-clang-format                    |
| 0       | version_check | conf-binaryen                        |
| 0       | pkgconfig     | conf-srt-openssl                     |
| 0       | pkgconfig     | conf-srt-gnutls                      |
| 0       | pkgconfig     | conf-sndfile                         |
| 0       | pkgconfig     | conf-sdl2-net                        |
| 0       | pkgconfig     | conf-sdl-net                         |
| 0       | pkgconfig     | conf-rubberband                      |
| 0       | pkgconfig     | conf-openblas-macOS-env              |
| 0       | pkgconfig     | conf-ode                             |
| 0       | pkgconfig     | conf-nauty                           |
| 0       | pkgconfig     | conf-nanomsg                         |
| 0       | pkgconfig     | conf-mingw-w64-zlib-x86_64           |
| 0       | pkgconfig     | conf-mingw-w64-zlib-i686             |
| 0       | pkgconfig     | conf-mingw-w64-sqlite3-x86_64        |
| 0       | pkgconfig     | conf-mingw-w64-sqlite3-i686          |
| 0       | pkgconfig     | conf-mingw-w64-sdl2-x86_64           |
| 0       | pkgconfig     | conf-mingw-w64-sdl2-ttf-x86_64       |
| 0       | pkgconfig     | conf-mingw-w64-sdl2-ttf-i686         |
| 0       | pkgconfig     | conf-mingw-w64-sdl2-net-x86_64       |
| 0       | pkgconfig     | conf-mingw-w64-sdl2-net-i686         |
| 0       | pkgconfig     | conf-mingw-w64-sdl2-mixer-x86_64     |
| 0       | pkgconfig     | conf-mingw-w64-sdl2-mixer-i686       |
| 0       | pkgconfig     | conf-mingw-w64-sdl2-image-x86_64     |
| 0       | pkgconfig     | conf-mingw-w64-sdl2-image-i686       |
| 0       | pkgconfig     | conf-mingw-w64-sdl2-i686             |
| 0       | pkgconfig     | conf-mingw-w64-postgresql-x86_64     |
| 0       | pkgconfig     | conf-mingw-w64-postgresql-i686       |
| 0       | pkgconfig     | conf-mingw-w64-pkgconf-x86_64        |
| 0       | pkgconfig     | conf-mingw-w64-pkgconf-i686          |
| 0       | pkgconfig     | conf-mingw-w64-pcre2-x86_64          |
| 0       | pkgconfig     | conf-mingw-w64-pcre2-i686            |
| 0       | pkgconfig     | conf-mingw-w64-pcre-x86_64           |
| 0       | pkgconfig     | conf-mingw-w64-pcre-i686             |
| 0       | pkgconfig     | conf-mingw-w64-openssl-x86_64        |
| 0       | pkgconfig     | conf-mingw-w64-openssl-i686          |
| 0       | pkgconfig     | conf-mingw-w64-nettle-x86_64         |
| 0       | pkgconfig     | conf-mingw-w64-nettle-i686           |
| 0       | pkgconfig     | conf-mingw-w64-ncurses-x86_64        |
| 0       | pkgconfig     | conf-mingw-w64-ncurses-i686          |
| 0       | pkgconfig     | conf-mingw-w64-mbedtls-x86_64        |
| 0       | pkgconfig     | conf-mingw-w64-liblz4-x86_64         |
| 0       | pkgconfig     | conf-mingw-w64-liblz4-i686           |
| 0       | pkgconfig     | conf-mingw-w64-libffi-x86_64         |
| 0       | pkgconfig     | conf-mingw-w64-libffi-i686           |
| 0       | pkgconfig     | conf-mingw-w64-libevent-x86_64       |
| 0       | pkgconfig     | conf-mingw-w64-libevent-i686         |
| 0       | pkgconfig     | conf-mingw-w64-gtksourceview3-x86_64 |
| 0       | pkgconfig     | conf-mingw-w64-gtksourceview3-i686   |
| 0       | pkgconfig     | conf-mingw-w64-gtk3-x86_64           |
| 0       | pkgconfig     | conf-mingw-w64-gtk3-i686             |
| 0       | pkgconfig     | conf-mingw-w64-gtk2-x86_64           |
| 0       | pkgconfig     | conf-mingw-w64-gtk2-i686             |
| 0       | pkgconfig     | conf-mingw-w64-gnutls-x86_64         |
| 0       | pkgconfig     | conf-mingw-w64-gnutls-i686           |
| 0       | pkgconfig     | conf-mingw-w64-gnomecanvas-x86_64    |
| 0       | pkgconfig     | conf-mingw-w64-gnomecanvas-i686      |
| 0       | pkgconfig     | conf-mingw-w64-gmp-x86_64            |
| 0       | pkgconfig     | conf-mingw-w64-gmp-i686              |
| 0       | pkgconfig     | conf-mingw-w64-glade-x86_64          |
| 0       | pkgconfig     | conf-mingw-w64-glade-i686            |
| 0       | pkgconfig     | conf-mingw-w64-freetype-x86_64       |
| 0       | pkgconfig     | conf-mingw-w64-freetype-i686         |
| 0       | pkgconfig     | conf-mingw-w64-freeglut-x86_64       |
| 0       | pkgconfig     | conf-mingw-w64-freeglut-i686         |
| 0       | pkgconfig     | conf-mingw-w64-curl-x86_64           |
| 0       | pkgconfig     | conf-mingw-w64-curl-i686             |
| 0       | pkgconfig     | conf-mingw-w64-cairo-x86_64          |
| 0       | pkgconfig     | conf-mingw-w64-cairo-i686            |
| 0       | pkgconfig     | conf-mingw-w64-ao-x86_64             |
| 0       | pkgconfig     | conf-mingw-w64-ao-i686               |
| 0       | pkgconfig     | conf-mingw-w64-allegro5-x86_64       |
| 0       | pkgconfig     | conf-mingw-w64-allegro5-i686         |
| 0       | pkgconfig     | conf-lua                             |
| 0       | pkgconfig     | conf-libuv                           |
| 0       | pkgconfig     | conf-libgsasl                        |
| 0       | pkgconfig     | conf-libelf                          |
| 0       | pkgconfig     | conf-libMagickCore                   |
| 0       | pkgconfig     | conf-gnome-icon-theme3               |
| 0       | pkgconfig     | conf-gegl                            |
| 0       | pkgconfig     | conf-ftgl                            |
| 0       | other         | conf-zig                             |
| 0       | other         | conf-rust-wasm                       |
| 0       | other         | conf-pixz                            |
| 0       | other         | conf-lldb                            |
| 0       | other         | conf-lld                             |
| 0       | other         | conf-cuda-config                     |
| 0       | other         | conf-assimp                          |
| 0       | no_build      | conf-libsamplerate                   |
| 0       | no_build      | conf-haveged                         |
| 0       | compile_test  | conf-python-2-7-dev                  |
| 0       | compile_test  | conf-libsvm                          |

## Distribution summary

| RevDeps range | Count | %   |
| ------------- | ----- | --- |
| 0             | 98    | 26% |
| 1             | 55    | 14% |
| 2-5           | 95    | 25% |
| 6-20          | 75    | 20% |
| 21-100        | 41    | 11% |
| 101+          | 6     | 1%  |

Median: 2, Mean: 10.9

## By category

| Category      | Count | Mean RevDeps | Median RevDeps |
| ------------- | ----- | ------------ | -------------- |
| pkgconfig     | 208   | 8.4          | 1              |
| version_check | 46    | 17.5         | 8              |
| compile_test  | 28    | 7.6          | 2              |
| no_build      | 18    | 2.5          | 1              |
| which_check   | 9     | 18.6         | 4              |
| custom_script | 9     | 25.3         | 5              |
| other         | 52    | 15.6         | 5              |

**Observations:**

- **custom_script has the highest mean (25.3)** — the most complex
  conf packages are also the most depended-upon (conf-cmake at 102,
  conf-llvm family). These are the ones that can't be eliminated and
  where version resolution bugs have the widest impact.
- **pkgconfig has median 1** — most pkg-config conf packages serve a
  single binding. These are the strongest candidates for elimination
  (one-to-one conf→binding pairs could inline the check).
- **version_check and which_check have high medians (8, 4)** — these
  are build tool confs (cmake, perl, npm, which) shared across many
  packages. Important infrastructure, but trivially simple logic.
- **no_build has the lowest mean (2.5)** — pure depexts declarations
  with no verification. Least useful as separate packages.
