cmake_minimum_required(VERSION 3.12)
project(test-imgui CXX)

include_directories(imgui)

add_library(test-imgui OBJECT
    imgui/imgui.cpp
    imgui/imgui_demo.cpp
    imgui/imgui_draw.cpp
    imgui/imgui_tables.cpp
    imgui/imgui_widgets.cpp
    imgui_impl_cwgl.cpp
    imgui_impl_yfrm.cpp
    testimgui.cpp
    )


target_link_libraries(test-imgui
    PUBLIC yfrm cwgl)

if(ANDROID)
    set(apptgt test-imgui-so)
    add_library(${apptgt} SHARED
        dummy.cpp)
else()
    set(apptgt test-imgui-win32)
    add_executable(${apptgt} WIN32
        dummy.cpp)
endif()

set(backendlibs)
if(YFRM_CWGL_USE_DX11)
    list(APPEND backendlibs 
        # angle (Yuniframe)
        dxgi
        dxguid
        # yuniframe
        d3d11
        )
endif()
if(YFRM_CWGL_USE_VULKAN OR YFRM_CWGL_USE_METAL)
    list(APPEND backendlibs
        SPIRV-Tools-static
        )
endif()
if(YFRM_CWGL_USE_ANGLE)
    list(APPEND backendlibs
        angle_static)
endif()
if(YFRM_CWGL_EXPERIMENTAL_TRACKER)
    # FIXME: Move this to shxm dependency
    list(APPEND backendlibs
        glslang
        my-glslang-default-resource-limits
        SPIRV
        SPIRV-Tools-opt
        spirv-cross-c
        )
endif()

if(YFRM_CWGL_USE_PLATFORMGLES)
    if(APPLE)
        list(APPEND backendlibs
            "-framework OpenGLES")
    else()
        # FIXME: Use IMPORT library instead...
        if(WIN32)
            set(libprefix lib)
        else()
            set(libprefix)
        endif()
        list(APPEND backendlibs
            ${libprefix}EGL
            ${libprefix}GLESv2)
    endif()
endif()

if(APPLE)
    if(YFRM_CWGL_USE_VULKAN)
        # FIXME: Use CMake native feature later
        #        https://github.com/okuoku/yuniframe/issues/4
        if("${CMAKE_SYSTEM_NAME}" STREQUAL iOS)
            set(prefix ios)
        elseif("${CMAKE_SYSTEM_NAME}" STREQUAL tvOS)
            set(prefix tvos)
        else()
            set(prefix macos)
        endif()
        if(${prefix} STREQUAL macos)
            set(platform arm64_x86_64)
        else()
            set(platform arm64_x86_64-simulator)
        endif()
        list(APPEND backendlibs
            ${YFRM_VULKANSDK_PREFIX}/MoltenVK/MoltenVK.xcframework/${prefix}-${platform}/libMoltenVK.a)
    endif()
    # FIXME: Why do we need it actually?
    list(APPEND backendlibs
        "-framework IOSurface"
        )
endif()

# FIXME: Why do we need yfrm cwgl here?
target_link_libraries(${apptgt} PRIVATE 
    ${backendlibs}
    test-imgui yfrm yfrm_main cwgl)


