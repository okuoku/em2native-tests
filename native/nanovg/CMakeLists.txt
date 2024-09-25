cmake_minimum_required(VERSION 3.12)
project(test-nanovg C CXX) # CXX because we must link C++ runtime for ANGLE

# FIXME: Copy pasted 

# Toolchain ABI setup
if(EMSCRIPTEN)
    add_compile_options(-pthread)
endif()

if(CMAKE_SYSTEM_NAME STREQUAL WindowsStore)
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)
endif()

include_directories(nanovg/src nanovg/example)

# => backendlibs
include(${CMAKE_CURRENT_LIST_DIR}/../../integ/yuniframe/calclinkdeps.cmake)

add_library(test-nanovg OBJECT
    nanovg/src/nanovg.c
    demo.c
    example.c)

target_link_libraries(test-nanovg
    PUBLIC yfrm cwgl)

if(ANDROID)
    add_library(test-nanovg-app SHARED
        dummy.cpp)
elseif(EMSCRIPTEN)
    set(CMAKE_EXECUTABLE_SUFFIX ".html")
    
    add_executable(test-nanovg-app dummy.cpp)
    set_target_properties(test-nanovg-app
        PROPERTIES
        LINK_OPTIONS "-pthread;-sPROXY_TO_PTHREAD")
else()
    add_executable(test-nanovg-app WIN32
        dummy.cpp)
endif()

# FIXME: Why do we need yfrm cwgl here?
target_link_libraries(test-nanovg-app PRIVATE
    ${backendlibs}
    test-nanovg yfrm yfrm_main cwgl)

if("${CMAKE_SYSTEM_NAME}" STREQUAL WindowsStore)
    set(rtmain
        ../../integ/yuniframe/src-sdl2/winrt/SDL2_winrt_main_NonXAML.cpp)
    target_sources(test-nanovg-app PRIVATE ${rtmain})
    set_source_files_properties(${rtmain}
        PROPERTIES COMPILE_FLAGS "/ZW")
    target_link_libraries(test-nanovg-app LINK_PRIVATE
        -nodefaultlib:vccorlib$<$<CONFIG:Debug>:d>
        -nodefaultlib:msvcrt$<$<CONFIG:Debug>:d>
        vccorlib$<$<CONFIG:Debug>:d>.lib
        msvcrt$<$<CONFIG:Debug>:d>.lib)
endif()

if(TESTPKG)
    if(${TESTPKG} STREQUAL Xcode)
        set_target_properties(test-nanovg-app
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


