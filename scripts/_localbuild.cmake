cmake_minimum_required(VERSION 3.12)
set(root0 ${CMAKE_CURRENT_LIST_DIR}/..)
get_filename_component(root "${root0}" ABSOLUTE)
set(buildroot ${root}/_build)
set(ndkversion 27.0.12077973)
# Extract https://github.com/KhronosGroup/MoltenVK/releases/download/v1.2.10-rc2/MoltenVK-all.tar
set(moltenvk_prefix "${CMAKE_CURRENT_LIST_DIR}/../_moltenvk/MoltenVK")

if(NOT PHASE)
    set(PHASE generate)
endif()

set(buildtypes Debug RelWithDebInfo)

set(android_variants
    dep:ANGLE-Vulkan
    dep:SDL2
    dep:GLSLang
    dep:UV
    core:SDL2-PlatformGLES
    core:SDL2-CWGL-Vulkan
    core:SDL2-ANGLE-Vulkan
    pkgAndroid:SDL2-PlatformGLES
    pkgAndroid:SDL2-CWGL-Vulkan
    pkgAndroid:SDL2-ANGLE-Vulkan)

set(win_variants
    dep:ANGLE-DirectX11
    dep:ANGLE-Vulkan
    dep:SDL2
    dep:GLSLang
    dep:UV
    core:SDL2-PlatformGLES
    core:SDL2-ANGLE-DirectX11
    core:SDL2-ANGLE-Vulkan
    core:SDL2-CWGL-Vulkan)

set(winuwp_variants
    dep:ANGLE-DirectX11
    dep:SDL2
    # dep:GLSLang
    core:SDL2-ANGLE-DirectX11
    pkgUWP:SDL2-ANGLE-DirectX11)

set(posix_variants
    # Assume Mesa and it provides both GLES and Vulkan
    #dep:ANGLE-Vulkan ## FIXME: Needs patch..?
    dep:SDL2
    dep:GLSLang
    dep:UV
    core:SDL2-PlatformGLES
    core:SDL2-CWGL-Vulkan
    #core:SDL2-ANGLE-Vulkan
    )

set(apple_variants
    dep:ANGLE-Metal
    dep:SDL2
    dep:GLSLang
    dep:UV
    core:SDL2-ANGLE-Metal
    core:SDL2-CWGL-Vulkan
    pkgXcode:SDL2-ANGLE-Metal
    pkgXcode:SDL2-CWGL-Vulkan)

set(apple_mobile_variants
    dep:ANGLE-Metal
    dep:SDL2
    dep:GLSLang
    dep:UV
    core:SDL2-ANGLE-Metal
    #core:SDL2-CWGL-Vulkan
    core:SDL2-PlatformGLES
    pkgXcode:SDL2-ANGLE-Metal
    pkgXcode:SDL2-PlatformGLES)

set(apple_tv_variants # ANGLE does not support tvOS 
    dep:SDL2
    dep:GLSLang
    dep:UV
    #core:SDL2-CWGL-Vulkan
    core:SDL2-PlatformGLES
    pkgXcode:SDL2-PlatformGLES)

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

function(genandroidpkg nam slot)
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
        AndroidManifest.xml
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

function(gencmake nam proj platform abi slot)
    set(sysroot)
    set(system_name)
    set(architectures)
    set(toolchain_file)
    set(buildtarget)
    set(deftype)

    # Package ID (Reversed DNS name)
    set(pkgid org.okotama.yuniframe.test.${slot})

    if(${proj} STREQUAL core)
        set(cmakeroot ${root})
        set(buildtarget "-DTESTSLOT=${slot}" "-DYFRM_WITH_PREBUILT_LIBS=1")
        set(deftype -DCMAKE_DEFAULT_BUILD_TYPE=Debug)
        set(gen "Ninja Multi-Config")
    elseif(${proj} STREQUAL dep)
        set(cmakeroot ${root}/deps)
        set(buildtarget "-DTGT=${slot}")
        set(deftype -DCMAKE_DEFAULT_BUILD_TYPE=Debug)
        set(gen "Ninja Multi-Config")
    elseif(${proj} STREQUAL pkgXcode)
        set(cmakeroot ${root})
        set(buildtarget 
            "-DTESTPKGID=${pkgid}"
            "-DTESTPKG=Xcode"
            "-DTESTSLOT=${slot}" "-DYFRM_WITH_PREBUILT_LIBS=1")
        set(gen "Xcode")
    elseif(${proj} STREQUAL pkgUWP)
        # NB: Changing system version requires complete clean build
        set(cmakeroot ${root})
        set(buildtarget 
            -DCMAKE_GENERATOR_PLATFORM=x64
            # 19041: Windows10 2004
            -DCMAKE_SYSTEM_VERSION=10.0.19041.0
            "-DTESTPKGID=${pkgid}"
            "-DTESTPKG=UWP"
            "-DTESTSLOT=${slot}" "-DYFRM_WITH_PREBUILT_LIBS=1")
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
        set(toolchain_file "-DCMAKE_TOOLCHAIN_FILE=${android_home}/ndk/${ndkversion}/build/cmake/android.toolchain.cmake")
        set(architectures -DANDROID_ABI=${abi} -DANDROID_ARM_NEON=ON)
    elseif(${abi} MATCHES "^MSVCUWP")
        set(system_name -DCMAKE_SYSTEM_NAME=WindowsStore)
    else()
        # Native Windows, Mac, ...
    endif()

    if(sysroot)
        message(STATUS "Configure ${nam} (${abi}, sysroot ${sysroot})")
    else()
        message(STATUS "Configure ${nam} (${abi})")
    endif()
    execute_process(COMMAND
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
if(has_android_sdk)
    foreach(v ${android_variants})
        if(${v} MATCHES "^pkgAndroid")
            list(APPEND variants Android:any:${v})
        else()
            foreach(abi armeabi-v7a arm64-v8a x86 x86_64)
                list(APPEND variants Android:${abi}:${v})
            endforeach()
        endif()
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
    foreach(v ${posix_variants})
        list(APPEND variants Posix:Native:${v})
    endforeach()
else()
    # FIXME: Implement Generic variants here.
    message(FATAL_ERROR "Couldn't determine variants")
endif()

foreach(v ${variants})
    if(${v} MATCHES "([^:]*):([^:]*):([^:]*):(.*)")
        set(platform ${CMAKE_MATCH_1})
        set(abi ${CMAKE_MATCH_2})
        set(proj ${CMAKE_MATCH_3})
        set(slot ${CMAKE_MATCH_4})

        set(is_cmake ON)
        if(${proj} MATCHES "^pkgAndroid")
            set(nam pkg-${platform}@${slot})
            set(is_cmake OFF)
        elseif(${proj} MATCHES "^pkg")
            set(nam pkg-${platform}${abi}@${slot})
        else()
            set(nam ${platform}${abi}@${slot})
        endif()

        if(PHASE STREQUAL generate)
            if(is_cmake)
                gencmake(${nam} ${proj} ${platform} ${abi} ${slot})
            elseif(${proj} MATCHES "^pkgAndroid")
                genandroidpkg(${nam} ${slot})
            endif()
        elseif(PHASE STREQUAL build)
            if(${proj} MATCHES "^pkgAndroid")
                buildandroidpkg(${nam})
            else()
                build(${nam})
            endif()
        elseif(PHASE STREQUAL cycle)
            if(is_cmake)
                if(NOT EXISTS ${buildroot}/${nam}/CMakeCache.txt)
                    gencmake(${nam} ${proj} ${platform} ${abi} ${slot})
                endif()
                build(${nam})
            elseif(${proj} MATCHES "^pkgAndroid")
                if(NOT EXISTS ${buildroot}/${nam}/build.gradle)
                    genandroidpkg(${nam} ${slot})
                endif()
                buildandroidpkg(${nam})
            endif()
        else()
            message(FATAL_ERROR "Unknown command: ${PHASE}")
        endif()
    else()
        message(FATAL_ERROR "???: ${v}")
    endif()
endforeach()
