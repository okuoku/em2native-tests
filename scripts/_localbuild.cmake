cmake_minimum_required(VERSION 3.12)
include(${CMAKE_CURRENT_LIST_DIR}/detect_android_sdk.cmake)
set(root0 ${CMAKE_CURRENT_LIST_DIR}/..)
get_filename_component(root "${root0}" ABSOLUTE)
set(buildroot ${root}/_build)
set(android_abis armeabi-v7a arm64-v8a x86 x86_64)
#set(android_abis x86_64)
# Extract https://github.com/KhronosGroup/MoltenVK/releases/download/v1.2.10-rc2/MoltenVK-all.tar
set(moltenvk_prefix "${CMAKE_CURRENT_LIST_DIR}/../_moltenvk/MoltenVK")

detect_android_sdk()

# FIXME: Hardcode
set(emcmake "/Volumes/stage/repos/emsdk/upstream/emscripten/emcmake")

if(DEFINED ENV{YUNIBUILD_IMAGE_TYPE})
    if("$ENV{YUNIBUILD_IMAGE_TYPE}" STREQUAL yuniandroid)
        set(SKIP_NATIVE ON)
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
    nccc:SDL2-ANGLE-DirectX11)

set(winuwp_variants
    ${apps_all}
    dep:ANGLE-DirectX11
    dep:SDL2
    pkgUWP:SDL2-ANGLE-DirectX11)

set(posix_variants
    ${apps_all}
    # Assume Mesa and it provides both GLES and Vulkan
    dep:ANGLE-Vulkan
    dep:SDL2
    dep:GLSLang
    dep:UV
    core:SDL2-PlatformGLES
    core:SDL2-CWGL-Vulkan
    core:SDL2-ANGLE-Vulkan
    nccc:SDL2-PlatformGLES)

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
            RESULT_VARIABLE rr
            )
        if(rr)
            message(FATAL_ERROR "Failed to build ${nam}")
        endif()
    endforeach()
endfunction()

function(buildandroidpkg nam)
    message(STATUS "Entering ${nam} (Android gradlew)")
    if(WIN32)
        set(ext .bat)
        set(pref)
    else()
        set(ext)
        set(pref ./)
    endif()
    execute_process(COMMAND
        ${pref}gradlew${ext} assemble
        RESULT_VARIABLE rr
        WORKING_DIRECTORY ${buildroot}/${nam}
        )
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
        set(gen "Visual Studio 17 2022")
    else()
        message(FATAL_ERROR "Unknown project (${proj})")
    endif()

    if(EXISTS ${moltenvk_prefix})
        set(moltenvk "-DYFRM_MOLTENVK_PREFIX=${moltenvk_prefix}")
    endif()

    set(binaryroot "-DYFRM_BINARY_ROOT=${buildroot}/${platform}@${abi}")

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
    elseif(${abi} MATCHES "^MSVCUWP")
        set(system_name -DCMAKE_SYSTEM_NAME=WindowsStore)
    else()
        # Native Windows, Mac, ...
    endif()

    if(${platform} STREQUAL Emscripten)
        set(emcmake_prefix ${emcmake})
    else()
        set(emcmake_prefix)
    endif()

    if(sysroot)
        message(STATUS "Configure ${nam} (${abi}, sysroot ${sysroot})")
    else()
        message(STATUS "Configure ${nam} (${abi})")
    endif()
    execute_process(COMMAND
        ${emcmake_prefix}
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
        RESULT_VARIABLE rr
        )
    if(rr)
        message(FATAL_ERROR "Failed to configure ${nam} (${rr})")
    endif()
endfunction()

# Check environment
if(DEFINED ENV{ANDROID_HOME})
    set(has_android_sdk ON)
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
if(has_android_sdk)
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
if(EXISTS ${emcmake})
    foreach(v ${emscripten_variants})
        list(APPEND variants Emscripten:Wasm32Web:${v})
    endforeach()
endif()

if(WIN32)
    foreach(v ${win_variants})
        list(APPEND variants Windows:MSVCx64:${v})
    endforeach()
    foreach(v ${winuwp_variants})
        list(APPEND variants Windows:MSVCUWPx64:${v})
    endforeach()
elseif(APPLE)
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
elseif(UNIX)
    if(NOT SKIP_NATIVE)
        foreach(v ${posix_variants})
            list(APPEND variants Posix:Native:${v})
        endforeach()
    endif()
else()
    # FIXME: Implement Generic variants here.
    message(FATAL_ERROR "Couldn't determine variants")
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
