# Tentative
cmake_minimum_required(VERSION 3.12)
project(yuniframe-tests NONE)

# Setup

set(YFRM_SDL2_PREFIX ${CMAKE_CURRENT_BINARY_DIR}/sdl2header)

set(YFRM_CWGL_USE_ANGLE ON)
set(YFRM_CWGL_USE_VULKAN OFF)
set(YFRM_CWGL_USE_DX11 ON)
set(YFRM_CWGL_EXPERIMENTAL_TRACKER OFF)
set(YFRM_CWGL_USE_METAL OFF)
set(YFRM_FS_USE_CXX17 ON)

set(CWGL_KHRONOS_HEADER_DIR 
    ${CMAKE_CURRENT_LIST_DIR}/integ/ext/cwgl/angle/include)
set(YFRM_CWGL_PREFIX
    ${CMAKE_CURRENT_LIST_DIR}/integ/cwgl)

# External libs
add_subdirectory(integ/proj/glslang glslang)
add_subdirectory(integ/proj/angle angle) # Angle (sometimes) depends glslang
add_subdirectory(integ/proj/sdl2 sdl2)

# Libs
add_subdirectory(integ/cwgl cwgl)
add_subdirectory(integ/yuniframe yfrm)

# App
add_subdirectory(native/imgui test-imgui)
