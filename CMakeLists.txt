# Choose some default

if(NOT TESTSLOT)
    if(WIN32)
        set(TESTSLOT SDL2-ANGLE-DirectX11)
    elseif(APPLE)
        if(NOT YFRM_VULKANSDK_PREFIX)
            set(TESTSLOT SDL2-ANGLE-Metal)
        else()
            set(TESTSLOT SDL2-ANGLE-Vulkan)
        endif()
    else()
        message(FATAL_ERROR "Could not determine TESTSLOT")
    endif()
endif()

# Guess binary root for Android Studio
if(DEFINED YFRM_BINARY_ROOT_GUESS)
    if("${YFRM_BINARY_ROOT_GUESS}" STREQUAL guess_android)
        set(YFRM_BINARY_ROOT "${CMAKE_CURRENT_LIST_DIR}/_build/Android@${ANDROID_ABI}")
        message(STATUS "Root guessed: ${YFRM_BINARY_ROOT}")
    endif()
endif()

# Tentative
cmake_minimum_required(VERSION 3.12)
project(yuniframe-tests NONE)

enable_testing()

# Setup

set(YFRM_SDL2_PREFIX ${CMAKE_CURRENT_BINARY_DIR}/sdl2header)
# Options
set(YFRM_CWGL_USE_ANGLE OFF)
set(YFRM_CWGL_USE_VULKAN OFF)
set(YFRM_CWGL_USE_DX11 OFF)
set(YFRM_CWGL_USE_METAL OFF)
set(YFRM_CWGL_USE_PLATFORMGLES OFF)
set(YFRM_CWGL_EXPERIMENTAL_TRACKER OFF)

if(TESTSLOT STREQUAL "SDL2-ANGLE-DirectX11")
    set(YFRM_CWGL_USE_ANGLE ON)
    set(YFRM_CWGL_USE_DX11 ON)
elseif(TESTSLOT STREQUAL "SDL2-ANGLE-Vulkan")
    set(YFRM_CWGL_USE_ANGLE ON)
    set(YFRM_CWGL_USE_VULKAN ON)
elseif(TESTSLOT STREQUAL "SDL2-ANGLE-Metal")
    set(YFRM_CWGL_USE_ANGLE ON)
    set(YFRM_CWGL_USE_METAL ON)
elseif(TESTSLOT STREQUAL "SDL2-CWGL-Vulkan")
    set(YFRM_CWGL_USE_VULKAN ON)
    set(YFRM_CWGL_EXPERIMENTAL_TRACKER ON)
elseif(TESTSLOT STREQUAL "SDL2-PlatformGLES")
    set(YFRM_CWGL_USE_PLATFORMGLES ON)
    if(WIN32)
        link_directories(${CMAKE_CURRENT_LIST_DIR}/blobs/mesa-dist-win/lib/x64)
    endif()
else()
    message(FATAL_ERROR "Unknown TESTSLOT(${TESTSLOT})")
endif()


set(YFRM_FS_USE_CXX17 ON)

set(CWGL_KHRONOS_HEADER_DIR 
    ${CMAKE_CURRENT_LIST_DIR}/integ/ext/cwgl/angle/include)
set(YFRM_CWGL_PREFIX
    ${CMAKE_CURRENT_LIST_DIR}/integ/cwgl)

# External libs(proj)
include(${CMAKE_CURRENT_LIST_DIR}/integ/proj/projwrap.cmake)

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
set(VOLK_ROOT ${CMAKE_CURRENT_LIST_DIR}/integ/ext/cwgl/volk)
set(SPIRV_TOOLS_ROOT ${CMAKE_CURRENT_LIST_DIR}/integ/ext/cwgl/SPIRV-Tools)
set(SPIRV_CROSS_ROOT ${CMAKE_CURRENT_LIST_DIR}/integ/ext/cwgl/SPIRV-Cross)
set(GLSLANG_ROOT ${CMAKE_CURRENT_LIST_DIR}/integ/ext/cwgl/glslang)
set(VULKAN_HEADERS_ROOT ${CMAKE_CURRENT_LIST_DIR}/integ/ext/cwgl/Vulkan-Headers)
add_subdirectory(integ/cwgl cwgl)
add_subdirectory(integ/yuniframe yfrm) # Module

# Ribbon
set(YUNI_SKIP_TESTS ON)
set(RIBBON_SKIP_TESTS ON)
add_subdirectory(ribbon-integ)

# Apps
add_subdirectory(native/imgui test-imgui)

message(STATUS "TESTSLOT: ${TESTSLOT}")
