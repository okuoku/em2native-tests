cmake_minimum_required(VERSION 3.12)
project(test-imgui CXX)

# Toolchain ABI setup
if(EMSCRIPTEN)
    add_compile_options(-pthread)
endif()

include_directories(imgui)

# => backendlibs
include(${CMAKE_CURRENT_LIST_DIR}/../../integ/yuniframe/calclinkdeps.cmake)

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
    set(apptgt app-imgui)
    add_library(${apptgt} SHARED
        dummy.cpp)
elseif(EMSCRIPTEN)
    set(apptgt test-imgui-so)
    set(CMAKE_EXECUTABLE_SUFFIX ".html")
    
    add_executable(${apptgt} dummy.cpp)
    set_target_properties(${apptgt}
        PROPERTIES
        LINK_OPTIONS "-pthread;-sPROXY_TO_PTHREAD")
else()
    set(apptgt test-imgui-app)
    add_executable(${apptgt} WIN32
        dummy.cpp)
endif()

# FIXME: Why do we need yfrm cwgl here?
target_link_libraries(${apptgt} PRIVATE 
    ${backendlibs}
    test-imgui yfrm yfrm_main cwgl)

if("${CMAKE_SYSTEM_NAME}" STREQUAL WindowsStore)
    set(rtmain 
        ../../integ/yuniframe/src-sdl2/winrt/SDL2_winrt_main_NonXAML.cpp)
    target_sources(${apptgt} PRIVATE ${rtmain})
    set_source_files_properties(${rtmain}
        PROPERTIES COMPILE_FLAGS "/ZW")
    target_link_libraries(${apptgt} LINK_PRIVATE
        -nodefaultlib:vccorlib$<$<CONFIG:Debug>:d>
        -nodefaultlib:msvcrt$<$<CONFIG:Debug>:d>
        vccorlib$<$<CONFIG:Debug>:d>.lib
        msvcrt$<$<CONFIG:Debug>:d>.lib)
endif()

if(TESTPKG)
    if(${TESTPKG} STREQUAL Xcode)
        set_target_properties(${apptgt}
            PROPERTIES
            # https://cmake.org/cmake/help/latest/prop_tgt/MACOSX_BUNDLE_INFO_PLIST.html
            MACOSX_BUNDLE TRUE
            MACOSX_BUNDLE_BUNDLE_NAME "em2app"
            MACOSX_BUNDLE_GUI_IDENTIFIER "${TESTPKGID}"
            MACOSX_BUNDLE_BUNDLE_VERSION 1.0
            MACOSX_BUNDLE_SHORT_VERSION_STRING 1.0
            MACOSX_BUNDLE_LONG_VERSION_STRING 1.0
            # Workaround for bundle identifier
            # https://zenn.dev/link/comments/abea557dc83ec9
            XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
            XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
            )
    elseif(${TESTPKG} STREQUAL UWP)
        # Implement resource files here
    else()
        message(FATAL_ERROR "Unknown pkg mode (${TESTPKG})")
    endif()
endif()
