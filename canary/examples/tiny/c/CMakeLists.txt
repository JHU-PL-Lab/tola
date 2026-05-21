cmake_minimum_required(VERSION 3.10)
project(tiny C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

add_library(tiny SHARED src/tiny.c)
target_include_directories(tiny PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>)

# SONAME = libtiny.so.1, full = libtiny.so.1.0
set_target_properties(tiny PROPERTIES
    VERSION   1.0
    SOVERSION 1
    PUBLIC_HEADER include/tiny.h)

include(GNUInstallDirs)
install(TARGETS tiny
    LIBRARY       DESTINATION ${CMAKE_INSTALL_LIBDIR}
    PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
