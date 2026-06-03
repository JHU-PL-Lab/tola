cmake_minimum_required(VERSION 3.10)
project(tiny C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

add_library(tiny SHARED src/tiny.c)
target_include_directories(tiny PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>)

# Symbol versioning (canary's c5 cmp_sym_version testbed). Exports
# every tiny_* under TINY_1.0; everything else local. nm shows
# `T tiny_sum@@TINY_1.0`. Consumers (cstubs, cext) record @@TINY_1.0
# in their NEEDED references; the e9 symbol_version_floor scenario
# bumps to TINY_2.0 to surface the mismatch.
target_link_options(tiny PRIVATE
    "-Wl,--version-script=${CMAKE_CURRENT_SOURCE_DIR}/tiny.map")
# Treat tiny.map as a link-time dependency so cmake re-links when the
# version script changes (e.g. the harness's symbol_version_floor
# patch flips TINY_1.0 → TINY_2.0). Without this, `cmake --build`
# would see source files unchanged and skip relinking.
set_target_properties(tiny PROPERTIES
    LINK_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/tiny.map")

# SONAME = libtiny.so.1, full = libtiny.so.1.0
set_target_properties(tiny PROPERTIES
    VERSION   1.0
    SOVERSION 1
    PUBLIC_HEADER include/tiny.h)

include(GNUInstallDirs)
install(TARGETS tiny
    LIBRARY       DESTINATION ${CMAKE_INSTALL_LIBDIR}
    PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
