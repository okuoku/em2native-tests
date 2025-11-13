cmake_minimum_required(VERSION 3.12)
include(${CMAKE_CURRENT_LIST_DIR}/detect_android_sdk.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/detect_msvc.cmake)

find_program(CYGPATH cygpath)

set(root0 ${CMAKE_CURRENT_LIST_DIR}/..)
if(CYGPATH)
    execute_process(COMMAND ${CYGPATH} -u 
        ${root0}
        OUTPUT_VARIABLE root
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    message(STATUS "root path convert: ${root0} => ${root}")
else()
    set(root "${root0}")
endif()
set(buildroot ${root}/_build)
message(STATUS "buildroot: ${buildroot}")
set(android_abis armeabi-v7a arm64-v8a x86 x86_64)
set(vs_gen "Visual Studio 17 2022")
# Extract https://github.com/KhronosGroup/MoltenVK/releases/download/v1.2.10-rc2/MoltenVK-all.tar
set(moltenvk_prefix "${CMAKE_CURRENT_LIST_DIR}/../_moltenvk/MoltenVK")


if(CYGPATH)
    message(STATUS "Skipping Local build because I'm Cygwin")
    set(SKIP_LOCAL ON)
endif()

if(DEFINED ENV{YUNIBUILD_IMAGE_TYPE})
    # Inside Docker, etc.
    set(SKIP_LOCAL ON)
    if("$ENV{YUNIBUILD_IMAGE_TYPE}" STREQUAL yuniandroid)
        detect_android_sdk()
        set(HAVE_ANDROID_SDK ON)
    endif()
    if("$ENV{YUNIBUILD_IMAGE_TYPE}" STREQUAL yunimingw-x64)
        set(TOOLCHAIN_MINGW_x64_C x86_64-w64-mingw32-gcc)
        set(TOOLCHAIN_MINGW_x64_CXX x86_64-w64-mingw32-g++)
        set(HAVE_MINGW_x64 ON)
    endif()
    if("$ENV{YUNIBUILD_IMAGE_TYPE}" STREQUAL yuniemscripten)
        set(emcmake emcmake)
        set(HAVE_EMSCRIPTEN_SDK ON)
    endif()
    if("$ENV{YUNIBUILD_IMAGE_TYPE}" STREQUAL yunimsvc17-amd64)
        set(HAVE_MSVC17 ON)
        detect_msvc17()
    endif()
    if("$ENV{YUNIBUILD_IMAGE_TYPE}" STREQUAL yunimingw-x64-ucrt-msys2)
        set(TOOLCHAIN_MINGW_x64_C c:/msys64/ucrt64/bin/x86_64-w64-mingw32-gcc.exe)
        set(TOOLCHAIN_MINGW_x64_CXX c:/msys64/ucrt64/bin/x86_64-w64-mingw32-g++.exe)
        set(HAVE_MINGW_x64 ON)
    endif()
    if("$ENV{YUNIBUILD_IMAGE_TYPE}" STREQUAL yunimingw-i686-msys2)
        set(TOOLCHAIN_MINGW_i686_C c:/msys64/mingw32/bin/i686-w64-mingw32-gcc.exe)
        set(TOOLCHAIN_MINGW_i686_CXX c:/msys64/mingw32/bin/i686-w64-mingw32-g++.exe)
        set(HAVE_MINGW_i686 ON)
    endif()
elseif(DEFINED ENV{YUNIBUILD_LOCAL_TYPE})
    # Inside Docker or others for POSIXy builds
    set(SKIP_LOCAL OFF)
    # FIXME: Bake these into images
    set(find_alternative_toolchain_Alpine ON)
    set(find_alternative_toolchain_Ubuntu ON)
    set(find_alternative_toolchain_Fedora ON)
    if("$ENV{YUNIBUILD_LOCAL_TYPE}" STREQUAL Linux)
        set(LOCAL_VARIANT "$ENV{YUNIBUILD_LOCAL_VARIANT}")
        if(find_alternative_toolchain_${LOCAL_VARIANT})
            set(LOCAL_VARIANT_HAS_ALTERNATIVE_TOOLCHAIN ON)
            find_program(CHECK_GCC g++)
            find_program(CHECK_CLANG clang++)
            if(CHECK_GCC)
                set(LOCAL_VARIANT_GCC ON)
            endif()
            if(CHECK_CLANG)
                set(LOCAL_VARIANT_CLANG ON)
            endif()
        endif()
    endif()
else()
    # Local build
    detect_android_sdk()
    if(android_sdkmanager)
        set(HAVE_ANDROID_SDK ON)
    endif()
    if(WIN32 OR CYGPATH)
        detect_msvc17()
        if(msvc17_vcvars64)
            # Intentionally exclude Cygwin
            set(HAVE_MSVC17 ON)
        endif()
    endif()
endif()

if(NOT PHASE)
    set(PHASE generate)
endif()

set(buildtypes Debug RelWithDebInfo)

set(apps_webgl2
    app:WebGL2:nanovg)
set(apps_webgl1
    app:WebGL1:nanovg
    app:WebGL1:imgui)
set(apps_all
    ${apps_webgl1}
    ${apps_webgl2})

set(backend_gpulevels_PlatformGLES
    WebGL1 WebGL2)
set(backend_gpulevels_CWGL-Vulkan
    WebGL1)
set(backend_gpulevels_CWGL-GLES
    WebGL1 WebGL2)
set(backend_gpulevels_ANGLE-Vulkan
    WebGL1 WebGL2)
set(backend_gpulevels_ANGLE-DirectX11
    WebGL1 WebGL2)
set(backend_gpulevels_ANGLE-Metal
    WebGL1 WebGL2)

set(android_variants
    ${apps_all}
    dep:ANGLE-Vulkan
    dep:SDL2
    dep:GLSLang
    # dep:UV # FIXME: It does not build on recent NDK
    pkgAndroid:SDL2-PlatformGLES
    pkgAndroid:SDL2-CWGL-Vulkan
    pkgAndroid:SDL2-CWGL-GLES
    pkgAndroid:SDL2-ANGLE-Vulkan)

set(win_variants
    ${apps_all}
    dep:ANGLE-DirectX11
    dep:ANGLE-Vulkan
    dep:SDL2
    dep:GLSLang
    dep:UV
    core:SDL2-PlatformGLES
    core:SDL2-ANGLE-DirectX11
    core:SDL2-ANGLE-Vulkan
    core:SDL2-CWGL-Vulkan
)
set(winmsvc_variants
    nccc:SDL2-ANGLE-DirectX11
)

set(winuwp_variants
    ${apps_all}
    dep:ANGLE-DirectX11
    dep:SDL2
    pkgUWP:SDL2-ANGLE-DirectX11)

set(posix_variants
    dep:SDL2
    dep:UV
    core:SDL2-PlatformGLES
    nccc:SDL2-PlatformGLES)

set(linux_variants
    ${apps_all}
    ${posix_variants}
    dep:GLSLang
    # Assume Mesa and it provides both GLES and Vulkan
    dep:ANGLE-Vulkan
    core:SDL2-CWGL-Vulkan
    core:SDL2-ANGLE-Vulkan
)

set(apple_variants
    ${apps_all}
    dep:ANGLE-Metal
    dep:SDL2
    dep:GLSLang
    dep:UV
    core:SDL2-ANGLE-Metal
    core:SDL2-CWGL-Vulkan
    pkgXcode:SDL2-ANGLE-Metal
    pkgXcode:SDL2-CWGL-Vulkan
    nccc:SDL2-ANGLE-Metal)

set(apple_mobile_variants
    ${apps_all}
    dep:ANGLE-Metal
    dep:SDL2
    dep:GLSLang
    dep:UV
    pkgXcode:SDL2-ANGLE-Metal
    pkgXcode:SDL2-CWGL-Vulkan
    pkgXcode:SDL2-PlatformGLES)

set(apple_tv_variants # ANGLE does not support tvOS 
    ${apps_all}
    dep:SDL2
    dep:GLSLang
    dep:UV
    pkgXcode:SDL2-CWGL-Vulkan
    pkgXcode:SDL2-PlatformGLES)

set(emscripten_variants
    ${apps_all}
    dep:SDL2
    core:Native-PlatformGLES
    core:SDL2-PlatformGLES)

function(build nam)
    foreach(cfg ${buildtypes})
        message(STATUS "Entering ${nam} (${cfg})")
        execute_process(COMMAND
            ${CMAKE_COMMAND} --build ${buildroot}/${nam}
            --config ${cfg}
            --parallel
            RESULT_VARIABLE rr
            )
        if(rr)
            message(FATAL_ERROR "Failed to build ${nam}")
        endif()
    endforeach()
endfunction()

function(buildandroidpkg nam)
    if(WIN32)
        set(ext .bat)
        set(pref)
    else()
        set(ext)
        set(pref ./)
    endif()

    if(DEFINED ENV{GRADLE_HOME})
        message(STATUS "Entering ${nam} (System Gradle)")
        execute_process(COMMAND
            $ENV{GRADLE_HOME}/bin/gradle${ext} assemble
            RESULT_VARIABLE rr
            WORKING_DIRECTORY ${buildroot}/${nam}
        )
    else()
        message(STATUS "Entering ${nam} (Android gradlew)")
        execute_process(COMMAND
            ${pref}gradlew${ext} assemble
            RESULT_VARIABLE rr
            WORKING_DIRECTORY ${buildroot}/${nam}
        )
    endif()

    if(rr)
        message(FATAL_ERROR "Failed to build ${nam} (${rr})")
    endif()
endfunction()

function(genandroidpkg nam slot gpulevel appsym)
    set(gradle-files
        gradlew
        gradlew.bat
        gradle.properties
        gradle/wrapper/gradle-wrapper.jar
        gradle/wrapper/gradle-wrapper.properties)

    set(template-files
        app/build.gradle
        build.gradle
        settings.gradle)

    set(resources-files
        res/values/strings.xml
        res/xml/backup_rules.xml
        res/xml/data_extraction_rules.xml
        res/drawable/ic_launcher_background.xml
        res/drawable-v24/ic_launcher_foreground.xml
        res/mipmap-mdpi/ic_launcher.webp
        res/mipmap-mdpi/ic_launcher_round.webp
        res/mipmap-hdpi/ic_launcher.webp
        res/mipmap-hdpi/ic_launcher_round.webp
        res/mipmap-xhdpi/ic_launcher.webp
        res/mipmap-xhdpi/ic_launcher_round.webp
        res/mipmap-xxhdpi/ic_launcher.webp
        res/mipmap-xxhdpi/ic_launcher_round.webp
        res/mipmap-xxxhdpi/ic_launcher.webp
        res/mipmap-xxxhdpi/ic_launcher_round.webp
        res/mipmap-anydpi-v26/ic_launcher.xml
        res/mipmap-anydpi-v26/ic_launcher_round.xml)

    set(sdl2-files
        AndroidManifest.xml # XXX: Require GLES3 for WebGL2 gpulevel?
        java/org/cltn/yfrm/user_common/SDL2ActivityWrapper_test1.java
        )

    set(manifest ${root}/templates/android-sdl2/AndroidManifest.xml)
    set(gradle-root ${root}/templates/android-gradle)
    set(template-root ${root}/templates/android-project)
    set(resources-root ${root}/templates/android-resources)
    set(sdl2-root ${root}/templates/android-sdl2)

    set(pkgroot ${buildroot}/${nam})

    # Replacements
    string(TOLOWER ${slot} pkgname0)
    string(REPLACE - _ pkgname ${pkgname0})
    set(YFRM_PKGID org.okotama.yuniframe.test.${pkgname})
    set(YFRM_SLOT ${slot})
    set(YFRM_PFJAVADIR "\"../../../integ/ext/platform/SDL2/android-project/app/src/main/java\"")
    set(YFRM_BINARY_ROOT_GUESS "${buildroot}")
    set(YFRM_GPULEVEL "${gpulevel}")
    set(YFRM_APPSYM "${appsym}")
    set(YFRM_NDKVERSION "${android_ndkversion}")
    set(YFRM_PLATFORMVERSION "${android_platformversion}")
    set(YFRM_CMAKEVERSION "${android_cmakeversion}")
    set(abifilter)
    foreach(abi IN LISTS android_abis)
        if(NOT abifilter)
            set(abifilter "'${abi}'")
        else()
            set(abifilter "${abifilter},'${abi}'")
        endif()
    endforeach()
    set(YFRM_NDKABIFILTERS "${abifilter}")

    foreach(r gradle template resources sdl2)
        foreach(e ${${r}-files})
            set(file ${${r}-root}/${e})
            if(EXISTS ${file}.in)
                configure_file(${file}.in ${pkgroot}/${e} @ONLY)
            else()
                configure_file(${file} ${pkgroot}/${e} COPYONLY)
            endif()
        endforeach()
    endforeach()
endfunction()

function(gencmake nam proj platform abi slot gpulevel appsym)
    set(sysroot)
    set(system_name)
    set(architectures)
    set(toolchain_file)
    set(buildtarget)
    set(deftype)

    # Package ID (Reversed DNS name)
    set(pkgid org.okotama.yuniframe.test.${slot})

    set(appopts "-DTESTSLOT=${slot}" 
        "-DYFRM_WITH_PREBUILT_LIBS=1"
        "-DYFRM_GPULEVEL=${gpulevel}" "-DYFRM_APPSYM=${appsym}")

    if(${proj} STREQUAL core)
        set(cmakeroot ${root})
        set(buildtarget ${appopts})
        set(deftype -DCMAKE_DEFAULT_BUILD_TYPE=Debug)
        set(gen "Ninja Multi-Config")
    elseif(${proj} STREQUAL nccc)
        set(cmakeroot ${root})
        set(buildtarget "-DTESTSLOT=${slot}" "-DYFRM_WITH_PREBUILT_LIBS=1"
            "-DBUILD_NCCC_MODULE=1")
        set(deftype -DCMAKE_DEFAULT_BUILD_TYPE=Debug)
        set(gen "Ninja Multi-Config")
    elseif(${proj} STREQUAL dep)
        set(cmakeroot ${root}/deps)
        set(buildtarget "-DTGT=${slot}")
        set(deftype -DCMAKE_DEFAULT_BUILD_TYPE=Debug)
        set(gen "Ninja Multi-Config")
    elseif(${proj} STREQUAL pkgXcode)
        set(cmakeroot ${root})
        set(buildtarget "-DTESTPKGID=${pkgid}" "-DTESTPKG=Xcode" ${appopts})
        set(gen "Xcode")
    elseif(${proj} STREQUAL pkgUWP)
        # NB: Changing system version requires complete clean build
        set(cmakeroot ${root})
        set(buildtarget 
            -DCMAKE_GENERATOR_PLATFORM=x64
            # 19041: Windows10 2004
            -DCMAKE_SYSTEM_VERSION=10.0.19041.0
            "-DTESTPKGID=${pkgid}"
            "-DTESTPKG=UWP" ${appopts})
        set(gen "${vs_gen}")
    else()
        message(FATAL_ERROR "Unknown project (${proj})")
    endif()

    if(EXISTS ${moltenvk_prefix})
        set(moltenvk "-DYFRM_MOLTENVK_PREFIX=${moltenvk_prefix}")
    endif()

    set(binaryroot "-DYFRM_BINARY_ROOT=${buildroot}/${platform}@${abi}")

    message(STATUS "abi: ${abi}")
    if(${platform} STREQUAL iOSsim)
        set(architectures "-DCMAKE_OSX_ARCHITECTURES=${abi}")
        set(sysroot "-DCMAKE_OSX_SYSROOT=${xcode_prefix}/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk")
        set(system_name "-DCMAKE_SYSTEM_NAME=iOS")
    elseif(${platform} STREQUAL iOS)
        set(architectures "-DCMAKE_OSX_ARCHITECTURES=${abi}")
        set(sysroot "-DCMAKE_OSX_SYSROOT=${xcode_prefix}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk")
        set(system_name "-DCMAKE_SYSTEM_NAME=iOS")
    elseif(${platform} STREQUAL tvOSsim)
        set(architectures "-DCMAKE_OSX_ARCHITECTURES=${abi}")
        set(sysroot "-DCMAKE_OSX_SYSROOT=${xcode_prefix}/Platforms/AppleTVSimulator.platform/Developer/SDKs/AppleTVSimulator.sdk")
        set(system_name "-DCMAKE_SYSTEM_NAME=tvOS")
    elseif(${platform} STREQUAL tvOS)
        set(architectures "-DCMAKE_OSX_ARCHITECTURES=${abi}")
        set(sysroot "-DCMAKE_OSX_SYSROOT=${xcode_prefix}/Platforms/AppleTVOS.platform/Developer/SDKs/AppleTVOS.sdk")
        set(system_name "-DCMAKE_SYSTEM_NAME=tvOS")
    elseif(${platform} STREQUAL Android)
        # Using NDK toolchain file
        # https://developer.android.com/ndk/guides/cmake
        set(system_name "-DCMAKE_SYSTEM_NAME=Android")
        set(toolchain_file "-DCMAKE_TOOLCHAIN_FILE=${android_home}/ndk/${android_ndkversion}/build/cmake/android.toolchain.cmake")
        set(architectures -DANDROID_ABI=${abi} -DANDROID_ARM_NEON=ON)
    elseif(${abi} MATCHES "^MSVC17UWP")
        set(system_name -DCMAKE_SYSTEM_NAME=WindowsStore
            -DCMAKE_SYSTEM_VERSION=10.0.19041.0)
        # Override generator
        set(gen "${vs_gen}")
        set(deftype)
    elseif(${abi} MATCHES "^MSVC")
        # Override generator
        set(gen "${vs_gen}")
        set(deftype)
    elseif(${abi} MATCHES "^Mingw(.*)")
        set(abiarch ${CMAKE_MATCH_1})
        set(compilers
            -DCMAKE_SYSTEM_NAME=Windows
            -DCMAKE_C_COMPILER=${TOOLCHAIN_MINGW_${abiarch}_C}
            -DCMAKE_CXX_COMPILER=${TOOLCHAIN_MINGW_${abiarch}_CXX})
    elseif(${platform} STREQUAL "Linux")
        if(${abi} MATCHES "Gcc")
            set(compilers
                -DCMAKE_SYSTEM_NAME=Linux
                -DCMAKE_C_COMPILER=gcc
                -DCMAKE_CXX_COMPILER=g++)
        elseif(${abi} MATCHES "Clang")
            set(compilers
                -DCMAKE_SYSTEM_NAME=Linux
                -DCMAKE_C_COMPILER=clang
                -DCMAKE_CXX_COMPILER=clang++)
        endif()
    else()
        # Native Windows, Mac, ...
    endif()

    if(${platform} STREQUAL Emscripten)
        set(envprefix ${emcmake})
    else()
        set(envprefix)
    endif()

    if(sysroot)
        message(STATUS "Configure ${nam} (${abi}, sysroot ${sysroot})")
    else()
        message(STATUS "Configure ${nam} (${abi})")
    endif()

    message(STATUS "root: ${cmakeroot}")

    execute_process(COMMAND
        ${envprefix}
        ${CMAKE_COMMAND} -G "${gen}"
        -S ${cmakeroot}
        -B ${buildroot}/${nam}
        "-DCMAKE_CONFIGURATION_TYPES=${buildtypes}"
        -DCMAKE_INSTALL_PREFIX=${buildroot}/install/${nam}
        ${deftype}
        ${moltenvk}
        ${sysroot}
        ${system_name}
        ${architectures}
        ${toolchain_file}
        ${buildtarget}
        ${binaryroot}
        ${compilers}
        RESULT_VARIABLE rr
        )
    if(rr)
        message(FATAL_ERROR "Failed to configure ${nam} (${rr})")
    endif()
endfunction()

# Check environment
if(DEFINED ENV{ANDROID_HOME})
    file(TO_CMAKE_PATH "$ENV{ANDROID_HOME}" android_home)
    message(STATUS "android home = ${android_home}")
endif()

if(NOT PHASE STREQUAL build)
    if(APPLE)
        # Detect Xcode prefix
        execute_process(COMMAND xcode-select -p
            OUTPUT_VARIABLE xcode_prefix
            RESULT_VARIABLE rr)
        if(rr)
            message(FATAL_ERROR "Could not detect Xcode prefix (${rr})")
        endif()
        string(STRIP "${xcode_prefix}" xcode_prefix)
        message(STATUS "Xcode prefix = ${xcode_prefix}")
    endif()
endif()

# Host dispatch
set(variants)

# Add Android projects
if(HAVE_ANDROID_SDK)
    foreach(v ${android_variants})
        if(${v} MATCHES "^pkgAndroid")
            list(APPEND variants Android:any:${v})
        else()
            foreach(abi IN LISTS android_abis)
                list(APPEND variants Android:${abi}:${v})
            endforeach()
        endif()
    endforeach()
endif()

# Add Emscripten projects
if(HAVE_EMSCRIPTEN_SDK)
    foreach(v ${emscripten_variants})
        list(APPEND variants Emscripten:Wasm32Web:${v})
    endforeach()
endif()

# Add Mingw Win32/Win64 projects
foreach(arch x64 i686)
    if(HAVE_MINGW_${arch})
        foreach(v ${win_variants})
            list(APPEND variants Windows:Mingw${arch}:${v})
        endforeach()
    endif()
endforeach()

# Windows MSVC
if(HAVE_MSVC17)
    foreach(v ${win_variants} ${winmsvc_variants})
        list(APPEND variants Windows:MSVC17x64:${v})
    endforeach()
    foreach(v ${winuwp_variants})
        list(APPEND variants Windows:MSVC17UWPx64:${v})
    endforeach()
endif()

# Local(not-in-containers) builds
if(NOT SKIP_LOCAL)
    # Apple platforms are local-only
    if(APPLE)
        foreach(v ${apple_variants})
            list(APPEND variants Mac:Native:${v})
        endforeach()
        foreach(m iOS:arm64 iOSsim:x86_64)
            foreach(v ${apple_mobile_variants})
                list(APPEND variants ${m}:${v})
            endforeach()
        endforeach()
        foreach(m tvOS:arm64 tvOSsim:x86_64)
            foreach(v ${apple_tv_variants})
                list(APPEND variants ${m}:${v})
            endforeach()
        endforeach()
    elseif(LINUX)
        foreach(v ${linux_variants})
            # Musl or Glibc or other libc
            if(NOT LOCAL_VARIANT)
                list(APPEND variants Linux:Local:${v})
            elseif(NOT LOCAL_VARIANT_HAS_ALTERNATIVE_TOOLCHAIN)
                list(APPEND variants Linux:${LOCAL_VARIANT}:${v})
            else()
                if(LOCAL_VARIANT_GCC)
                    list(APPEND variants Linux:${LOCAL_VARIANT}Gcc:${v})
                endif()
                if(LOCAL_VARIANT_CLANG)
                    list(APPEND variants Linux:${LOCAL_VARIANT}Clang:${v})
                endif()
            endif()
        endforeach()
    elseif(UNIX)
        foreach(v ${posix_variants})
            list(APPEND variants Posix:Local:${v})
        endforeach()
    endif()
endif()

# Pass1: Collect apps for platform
set(build_variants)
foreach(v ${variants})
    if(${v} MATCHES "([^:]*):([^:]*):([^:]*):(.*)")
        set(platform ${CMAKE_MATCH_1})
        set(abi ${CMAKE_MATCH_2})
        set(proj ${CMAKE_MATCH_3})
        set(slot ${CMAKE_MATCH_4})
        if(${proj} STREQUAL "app")
            if(${slot} MATCHES "([^:]*):(.*)")
                set(gpulevel ${CMAKE_MATCH_1})
                set(appsym ${CMAKE_MATCH_2})
                list(APPEND apps_${platform}_${gpulevel} ${appsym})
            else()
                message(FATAL_ERROR "Invalid line: ${v}")
            endif()
        else()
            list(APPEND build_variants ${v})
        endif()
    endif()
endforeach()

# Pass2: Run build
function(buildlib nam)
    build(${nam})
endfunction()
function(genlib skippable nam proj platform abi slot)
    set(generated OFF)
    if(EXISTS ${buildroot}/${nam}/CMakeCache.txt)
        set(generated ON)
    endif()
    if(${skippable} AND ${generated})
        message(STATUS "Skip generation: ${nam}")
    else()
        message(STATUS "Genlib: ${nam}/${proj}/${platform}/${abi}/${slot}")
        gencmake(${nam} ${proj} ${platform} ${abi} ${slot} NONE NONE)
    endif()
endfunction()

function(buildapp nambase proj platform slot)
    if("${slot}" MATCHES "([^-]*)-(.*)")
        set(disp ${CMAKE_MATCH_1})
        set(gpu ${CMAKE_MATCH_2})
        foreach(gpulevel ${backend_gpulevels_${gpu}})
            foreach(appsym ${apps_${platform}_${gpulevel}})
                set(nam ${nambase}_${appsym}_${gpulevel})
                set(genandroid OFF)
                if(${proj} MATCHES "^pkgAndroid")
                    set(genandroid ON)
                endif()
                if(genandroid)
                    buildandroidpkg(${nam})
                else()
                    build(${nam})
                endif()
            endforeach()
        endforeach()
    else()
        message(FATAL_ERROR "Unrecognized platform: ${slot}")
    endif()
endfunction()

function(genapp skippable nambase proj platform abi slot)
    if("${slot}" MATCHES "([^-]*)-(.*)")
        set(disp ${CMAKE_MATCH_1})
        set(gpu ${CMAKE_MATCH_2})
        foreach(gpulevel ${backend_gpulevels_${gpu}})
            foreach(appsym ${apps_${platform}_${gpulevel}})
                set(nam ${nambase}_${appsym}_${gpulevel})
                set(generated OFF)
                set(genandroid OFF)
                if(${proj} MATCHES "^pkgAndroid")
                    set(genandroid ON)
                    if(EXISTS ${buildroot}/${nam}/build.gradle)
                        set(generated ON)
                    endif()
                else()
                    if(EXISTS ${buildroot}/${nam}/CMakeCache.txt)
                        set(generated ON)
                    endif()
                endif()
                if(${skippable} AND ${generated})
                    message(STATUS "Skip generation: ${nam}")
                else()
                    if(genandroid)
                        genandroidpkg(${nam} ${slot} ${gpulevel} ${appsym})
                    else()
                        gencmake(${nam} ${proj} ${platform} ${abi} ${slot}
                            ${gpulevel} ${appsym})
                    endif()
                endif()
            endforeach()
        endforeach()
    else()
        message(FATAL_ERROR "Unrecognized platform: ${slot}")
    endif()
endfunction()

foreach(v ${build_variants})
    message(STATUS "v: ${v}")
    if(${v} MATCHES "([^:]*):([^:]*):([^:]*):(.*)")
        set(platform ${CMAKE_MATCH_1})
        set(abi ${CMAKE_MATCH_2})
        set(proj ${CMAKE_MATCH_3})
        set(slot ${CMAKE_MATCH_4})

        set(build_app OFF)
        set(skippable ON)
        if(${proj} MATCHES "^pkgAndroid")
            set(nam pkg-${platform}@${slot})
            set(build_app ON)
        elseif(${proj} MATCHES "^pkgXcode")
            set(nam pkg-${platform}${abi}@${slot})
            set(build_app ON)
            # Xcode CMake generator does not handle regeneration
            set(skippable OFF) 
        elseif(${proj} MATCHES "^pkg")
            set(nam pkg-${platform}${abi}@${slot})
            set(build_app ON)
        elseif(${proj} STREQUAL "core")
            set(nam ${platform}${abi}@${slot})
            set(build_app ON)
        elseif(${proj} STREQUAL "nccc")
            set(nam nccc-${platform}${abi}@${slot})
        else()
            set(nam ${platform}${abi}@${slot})
        endif()

        if(PHASE STREQUAL generate)
            if(build_app)
                genapp(OFF ${nam} ${proj} ${platform} ${abi} ${slot})
            else()
                genlib(OFF ${nam} ${proj} ${platform} ${abi} ${slot})
            endif()
        elseif(PHASE STREQUAL build)
            if(build_app)
                buildapp(${nam} ${proj} ${platform} ${slot})
            else()
                buildlib(${nam})
            endif()
        elseif(PHASE STREQUAL cycle)
            if(build_app)
                genapp(${skippable} ${nam} ${proj} ${platform} ${abi} ${slot})
                buildapp(${nam} ${proj} ${platform} ${slot})
            else()
                genlib(${skippable} ${nam} ${proj} ${platform} ${abi} ${slot})
                buildlib(${nam})
            endif()
        else()
            message(FATAL_ERROR "Unknown command: ${PHASE}")
        endif()
    else()
        message(FATAL_ERROR "???: ${v}")
    endif()
endforeach()
