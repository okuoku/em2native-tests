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

add_executable(test-imgui-win32 WIN32
    dummy.cpp)


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
        SPIRV-Tools
        )
endif()

# FIXME: Why do we need yfrm cwgl here?
target_link_libraries(test-imgui-win32 PRIVATE 
    angle_static
    ${backendlibs}
    test-imgui yfrm cwgl)


