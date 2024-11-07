#
# INPUTs:
#   BUILD_NCCC_MODULE: Build NCCC module
#

if(NOT TESTSLOT)
    message(FATAL_ERROR "Could not determine TESTSLOT")
endif()

# Guess binary root for Android Studio
if(DEFINED YFRM_BINARY_ROOT_GUESS)
    if(ANDROID_ABI)
        set(YFRM_BINARY_ROOT "${YFRM_BINARY_ROOT_GUESS}/Android@${ANDROID_ABI}")
        message(STATUS "Root guessed: ${YFRM_BINARY_ROOT}")
    else()
        message(FATAL_ERROR "We cannot guess binary root with this platform.")
    endif()
endif()

if(APPLE AND NOT CMAKE_TOOLCHAIN_FILE)
    # We might link against .xcframeworks
    cmake_minimum_required(VERSION 3.28)
else()
    cmake_minimum_required(VERSION 3.12)
endif()
project(yuniframe-tests NONE)

enable_testing()

# Toolchain ABI setup
if(EMSCRIPTEN)
    add_compile_options(-pthread)
endif()

# Setup
if(NOT YFRM_BINARY_ROOT)
    set(YFRM_SDL2_PREFIX ${CMAKE_CURRENT_BINARY_DIR}/_yfrm_headers)
else()
    set(YFRM_SDL2_PREFIX ${YFRM_BINARY_ROOT}/_yfrm_headers)
endif()

# Options
set(YFRM_USE_SDL2 OFF)
set(YFRM_CWGL_USE_ANGLE OFF)
set(YFRM_CWGL_USE_VULKAN OFF)
set(YFRM_CWGL_USE_DX11 OFF)
set(YFRM_CWGL_USE_METAL OFF)
set(YFRM_CWGL_USE_PLATFORMGLES OFF)
set(YFRM_CWGL_EXPERIMENTAL_TRACKER OFF)

if(TESTSLOT STREQUAL "SDL2-ANGLE-DirectX11")
    set(YFRM_USE_SDL2 ON)
    set(YFRM_CWGL_USE_ANGLE ON)
    set(YFRM_CWGL_USE_DX11 ON)
elseif(TESTSLOT STREQUAL "SDL2-ANGLE-Vulkan")
    set(YFRM_USE_SDL2 ON)
    set(YFRM_CWGL_USE_ANGLE ON)
    set(YFRM_CWGL_USE_VULKAN ON)
elseif(TESTSLOT STREQUAL "SDL2-ANGLE-Metal")
    set(YFRM_USE_SDL2 ON)
    set(YFRM_CWGL_USE_ANGLE ON)
    set(YFRM_CWGL_USE_METAL ON)
elseif(TESTSLOT STREQUAL "SDL2-CWGL-Vulkan")
    set(YFRM_USE_SDL2 ON)
    set(YFRM_CWGL_USE_VULKAN ON)
    set(YFRM_CWGL_EXPERIMENTAL_TRACKER ON)
elseif(TESTSLOT STREQUAL "SDL2-CWGL-GLES")
    set(YFRM_USE_SDL2 ON)
    set(YFRM_CWGL_USE_VULKAN OFF)
    set(YFRM_CWGL_EXPERIMENTAL_TRACKER ON)
elseif(TESTSLOT STREQUAL "SDL2-PlatformGLES")
    set(YFRM_USE_SDL2 ON)
    set(YFRM_CWGL_USE_PLATFORMGLES ON)
    if(WIN32)
        link_directories(${CMAKE_CURRENT_LIST_DIR}/blobs/mesa-dist-win/lib/x64)
    endif()
elseif(TESTSLOT STREQUAL "Native-PlatformGLES")
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

if("${CMAKE_SYSTEM_NAME}" STREQUAL WindowsStore OR EMSCRIPTEN)
    # FIXME: miniio backend 
else()
    add_subdirectory(proj/uv uv)
    set(UV_ROOT ${CMAKE_CURRENT_LIST_DIR}/ext/platform/libuv)
endif()

# Libs
if(BUILD_NCCC_MODULE)
    set(YFRM_BUILD_MODULE ON)
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)
endif()
set(NCCC_ROOT ${CMAKE_CURRENT_LIST_DIR}/integ/nccc)
set(CWGL_ROOT ${CMAKE_CURRENT_LIST_DIR}/integ/cwgl)
set(VOLK_ROOT ${CMAKE_CURRENT_LIST_DIR}/integ/ext/cwgl/volk)
set(SPIRV_TOOLS_ROOT ${CMAKE_CURRENT_LIST_DIR}/integ/ext/cwgl/SPIRV-Tools)
set(SPIRV_CROSS_ROOT ${CMAKE_CURRENT_LIST_DIR}/integ/ext/cwgl/SPIRV-Cross)
set(GLSLANG_ROOT ${CMAKE_CURRENT_LIST_DIR}/integ/ext/cwgl/glslang)
set(VULKAN_HEADERS_ROOT ${CMAKE_CURRENT_LIST_DIR}/integ/ext/cwgl/Vulkan-Headers)

# NCCC Modules
add_subdirectory(integ/cwgl cwgl)
add_subdirectory(integ/yuniframe yfrm)
add_subdirectory(miniio/nccc miniio)
add_subdirectory(integ/nccc/stubsupport nccc-stubsupport)
add_subdirectory(integ/nccc/tests nccc-tests)

# NCCC module targets
set(mods
    nccc_yfrm
    nccc_miniio
    nccc_tests_nccc
    nccc_nccc_corelib)

if(BUILD_NCCC_MODULE)
    # Deploy nccc modules to ${CMAKE_CURRENT_BINARY_DIR}/nccc
    set(debugloc ${CMAKE_CURRENT_BINARY_DIR}/nccc) # Prefer debug build now
    set(releaseloc ${CMAKE_CURRENT_BINARY_DIR}/nccc/release)
    set(dest "$<IF:$<CONFIG:Debug>,${debugloc},${releaseloc}>")
    file(MAKE_DIRECTORY ${debugloc})
    file(MAKE_DIRECTORY ${releaseloc})
    foreach(tgt ${mods})
        add_custom_target(deploymod-${tgt} ALL
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
            $<TARGET_FILE:${tgt}> ${dest}/
            DEPENDS ${tgt}
            )
    endforeach()
    if(EXISTS /opt/yunibase)
        set(YUNI_WITH_YUNIBASE /opt/yunibase)
    elseif(EXISTS c:/yunibase)
        set(YUNI_WITH_YUNIBASE c:/yunibase)
    endif()
    # FIXME: Support single-config generator
    set(YUNI_INPLACE_NCCC_MODULES_PREFIX "${debugloc}")
    # Build yuni only for now
    add_subdirectory(ribbon-integ/yuni yuni)
else()
    # Build ribbon (Unused for now)
    if(NOT TESTPKG)
        set(YUNI_SKIP_TESTS ON)
        set(RIBBON_SKIP_TESTS ON)
        set(USE_RIBBON_PREBOOT ON)
        add_subdirectory(ribbon-integ)
    endif()
    # Build test dummy
    #add_subdirectory(native/imgui test-imgui)
    add_subdirectory(native/nanovg test-nanovg)
endif()

message(STATUS "TESTSLOT: ${TESTSLOT}")
