# Choose some default

if(NOT TESTSLOT)
    if(WIN32)
        set(TESTSLOT SDL2-ANGLE-DirectX11)
    elseif(APPLE)
        set(TESTSLOT SDL2-ANGLE-Metal)
    else()
        message(FATAL_ERROR "Could not determine TESTSLOT")
    endif()
endif()

# Tentative
cmake_minimum_required(VERSION 3.12)
project(yuniframe-tests NONE)

# Setup

set(YFRM_SDL2_PREFIX ${CMAKE_CURRENT_BINARY_DIR}/sdl2header)

if(TESTSLOT STREQUAL "SDL2-ANGLE-DirectX11")
    set(YFRM_CWGL_USE_ANGLE ON)
    set(YFRM_CWGL_USE_VULKAN OFF)
    set(YFRM_CWGL_USE_DX11 ON)
    set(YFRM_CWGL_USE_METAL OFF)
    set(YFRM_CWGL_EXPERIMENTAL_TRACKER OFF)
elseif(TESTSLOT STREQUAL "SDL2-ANGLE-Vulkan")
    set(YFRM_CWGL_USE_ANGLE ON)
    set(YFRM_CWGL_USE_VULKAN ON)
    set(YFRM_CWGL_USE_DX11 OFF)
    set(YFRM_CWGL_USE_METAL OFF)
    set(YFRM_CWGL_EXPERIMENTAL_TRACKER OFF)
else()
    message(FATAL_ERROR "Unknown TESTSLOT(${TESTSLOT})")
endif()


set(YFRM_FS_USE_CXX17 ON)

set(CWGL_KHRONOS_HEADER_DIR 
    ${CMAKE_CURRENT_LIST_DIR}/integ/ext/cwgl/angle/include)
set(YFRM_CWGL_PREFIX
    ${CMAKE_CURRENT_LIST_DIR}/integ/cwgl)

# External libs
if(YFRM_CWGL_USE_VULKAN OR YFRM_CWGL_USE_METAL)
    add_subdirectory(integ/proj/glslang glslang)
endif()
if(YFRM_CWGL_USE_ANGLE)
    add_subdirectory(integ/proj/angle angle) # Angle (sometimes) depends glslang
endif()
add_subdirectory(integ/proj/sdl2 sdl2)

# Libs
set(NCCC_ROOT ${CMAKE_CURRENT_LIST_DIR}/integ/nccc)
set(CWGL_ROOT ${CMAKE_CURRENT_LIST_DIR}/integ/cwgl)
add_subdirectory(integ/cwgl cwgl)
add_subdirectory(integ/yuniframe yfrm) # Module

# App
add_subdirectory(native/imgui test-imgui)

message(STATUS "TESTSLOT: ${TESTSLOT}")
