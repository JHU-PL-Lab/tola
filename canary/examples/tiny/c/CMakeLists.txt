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
#
# ELF ONLY (2026-08-26). Mach-O has no symbol versioning at all, and
# ld64 rejects the flag outright rather than ignoring it:
#
#   ld: unknown options: --version-script=.../tiny.map
#
# so with this unguarded the tiny lib does not LINK on macOS and every
# scenario built on it is unreachable, versioned or not. Guarding it
# means c5 has no referent there — that is a fact about the object
# format, not a gap in the witness. The nearest Mach-O analogue is a
# load-time version FLOOR at library rather than symbol granularity
# (LC_ID_DYLIB's compatibility_version, which dyld refuses to satisfy
# downward); wiring it is a new contract, not a port of this one. See
# doc/canary/project/issues.md.
if(NOT APPLE)
    target_link_options(tiny PRIVATE
        "-Wl,--version-script=${CMAKE_CURRENT_SOURCE_DIR}/tiny.map")
    # Treat tiny.map as a link-time dependency so cmake re-links when the
    # version script changes (e.g. the harness's symbol_version_floor
    # patch flips TINY_1.0 → TINY_2.0). Without this, `cmake --build`
    # would see source files unchanged and skip relinking.
    set_target_properties(tiny PROPERTIES
        LINK_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/tiny.map")
endif()

# SONAME = libtiny.so.1, full = libtiny.so.1.0
set_target_properties(tiny PROPERTIES
    VERSION   1.0
    SOVERSION 1
    PUBLIC_HEADER include/tiny.h)

include(GNUInstallDirs)
install(TARGETS tiny
    LIBRARY       DESTINATION ${CMAKE_INSTALL_LIBDIR}
    PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
