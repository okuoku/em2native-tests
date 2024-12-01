cmake_minimum_required(VERSION 3.12)
project(test-nanovg C CXX) # CXX because we must link C++ runtime for ANGLE
set(demoroot ${CMAKE_CURRENT_BINARY_DIR}/assets/)

if(EMSCRIPTEN)
    add_definitions(-DDEMOROOT=\"/assets/\")
else()
    add_definitions(-DDEMOROOT=\"${demoroot}\")
endif()

# Assets
set(assetsrc ${CMAKE_CURRENT_LIST_DIR}/nanovg/example)
set(assets
    NotoEmoji-Regular.ttf Roboto-Light.ttf      entypo.ttf
    Roboto-Bold.ttf       Roboto-Regular.ttf
    images/image1.jpg images/image2.jpg images/image3.jpg
    images/image4.jpg images/image5.jpg images/image6.jpg
    images/image7.jpg images/image8.jpg images/image9.jpg
    images/image10.jpg images/image11.jpg images/image12.jpg)

# Generate asset dir
set(asset_out)
foreach(f ${assets})
    set(tgt ${demoroot}example/${f})
    set(src ${assetsrc}/${f})
    add_custom_command(
        COMMAND ${CMAKE_COMMAND} -E copy_if_different ${src} ${tgt}
        DEPENDS ${src}
        OUTPUT ${tgt})
    list(APPEND asset_out ${tgt})
endforeach()
add_custom_target(test-nanovg-assets DEPENDS ${asset_out})


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
    add_library(app-nanovg SHARED
        dummy.cpp)
elseif(EMSCRIPTEN)
    set(CMAKE_EXECUTABLE_SUFFIX ".html")
    
    add_executable(app-nanovg dummy.cpp)
    if(${YFRM_GPULEVEL} STREQUAL WebGL2)
        set(webgl_opt -sMAX_WEBGL_VERSION=2 -sMIN_WEBGL_VERSION=2)
    else()
        set(webgl_opt)
    endif()
    # NB: --preload-file will not work with absolute paths
    set(abs_assets ${CMAKE_CURRENT_BINARY_DIR}/assets)
    cmake_path(RELATIVE_PATH 
        abs_assets BASE_DIRECTORY ${CMAKE_BINARY_DIR}
        OUTPUT_VARIABLE rel_assets)
    set(asset_opt --preload-file ${rel_assets}@/assets)
    set_target_properties(app-nanovg
        PROPERTIES
        LINK_OPTIONS "-pthread;${webgl_opt};${asset_opt}")
else()
    add_executable(app-nanovg WIN32
        dummy.cpp)
endif()

# FIXME: Why do we need yfrm cwgl here?
target_link_libraries(app-nanovg PRIVATE
    ${backendlibs}
    test-nanovg yfrm yfrm_main cwgl)

add_dependencies(app-nanovg test-nanovg-assets)

if("${CMAKE_SYSTEM_NAME}" STREQUAL WindowsStore)
    set(rtmain
        ../../integ/yuniframe/src-sdl2/winrt/SDL2_winrt_main_NonXAML.cpp)
    target_sources(app-nanovg PRIVATE ${rtmain})
    set_source_files_properties(${rtmain}
        PROPERTIES COMPILE_FLAGS "/ZW")
    target_link_libraries(app-nanovg LINK_PRIVATE
        -nodefaultlib:vccorlib$<$<CONFIG:Debug>:d>
        -nodefaultlib:msvcrt$<$<CONFIG:Debug>:d>
        vccorlib$<$<CONFIG:Debug>:d>.lib
        msvcrt$<$<CONFIG:Debug>:d>.lib)
endif()

if(TESTPKG)
    if(${TESTPKG} STREQUAL Xcode)
        set_target_properties(app-nanovg
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


