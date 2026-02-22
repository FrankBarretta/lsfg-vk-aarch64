cmake_minimum_required(VERSION 3.10)
project(lsfg-vk LANGUAGES CXX)
include(GNUInstallDirs)

# === READ HERE FOR BUILD OPTIONS ===
option(LSFGVK_BUILD_VK_LAYER     "Build the Vulkan layer"            ON)
option(LSFGVK_BUILD_UI           "Build the user interface"         OFF)
option(LSFGVK_BUILD_CLI          "Build the command line interface"  ON)
option(LSFGVK_INSTALL_DEVELOP    "Install development libraries and headers"      OFF)
option(LSFGVK_INSTALL_XDG_FILES  "Install the application icon and desktop files" OFF)
set(_LSFGVK_DEFAULT_LAYER_LIBRARY_PATH
    "${CMAKE_INSTALL_FULL_LIBDIR}/${CMAKE_SHARED_LIBRARY_PREFIX}lsfg-vk-layer${CMAKE_SHARED_LIBRARY_SUFFIX}")
set(LSFGVK_LAYER_LIBRARY_PATH "${_LSFGVK_DEFAULT_LAYER_LIBRARY_PATH}" CACHE STRING "Change where Vulkan searches for the layer library")
option(LSFGVK_TESTING_RENDERDOC  "Enable RenderDoc integration for testing purposes" OFF)
option(LSFGVK_PORTABLE_ABI "Build with ABI portability flags for older runtime glibc/libstdc++" ON)
option(LSFGVK_STATIC_LIBSTDCXX "Statically link libstdc++ and libgcc for better portability" ON)
# === READ HERE FOR BUILD OPTIONS ===

if(CMAKE_SIZEOF_VOID_P LESS 8)
    message(FATAL_ERROR "lsfg-vk supports only 64-bit targets")
endif()

string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" LSFGVK_SYSTEM_PROCESSOR)
if(LSFGVK_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
    message(STATUS "Building lsfg-vk for AArch64")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_SKIP_RPATH ON)

if(LSFGVK_PORTABLE_ABI)
    message(STATUS "LSFGVK_PORTABLE_ABI enabled: forcing older-compatible libc symbol usage where possible")
    add_compile_definitions(__GLIBC_USE_C2X_STRTOL=0)
endif()

if(LSFGVK_STATIC_LIBSTDCXX)
    message(STATUS "LSFGVK_STATIC_LIBSTDCXX enabled: linking libstdc++/libgcc statically")
    add_link_options(-static-libstdc++ -static-libgcc)
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

    if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        message(STATUS "Building with clang-specific diagnostics")

        set(CMAKE_CXX_CLANG_TIDY clang-tidy) # See .clang-tidy files

        add_compile_options(
            # By default, enable all warnings
            -Weverything
            # Some warnings are incompatible with each other
            -Wno-pre-c++20-compat-pedantic
            -Wno-c++98-compat-pedantic
            -Wno-switch-default
            # Then there's code-style things I don't care about
            -Wno-missing-designated-field-initializers
            -Wno-shadow
            # And functional warning I don't care about either
            -Wno-cast-function-type-strict
            -Wno-padded
        )
    endif()
endif()

if(LSFGVK_TESTING_RENDERDOC)
    add_compile_definitions(LSFGVK_TESTING_RENDERDOC)
endif()

add_subdirectory(lsfg-vk-common)
add_subdirectory(lsfg-vk-backend)
if(LSFGVK_BUILD_VK_LAYER)
    add_subdirectory(lsfg-vk-layer)
endif()
if(LSFGVK_BUILD_UI)
    add_subdirectory(lsfg-vk-ui)
endif()
if(LSFGVK_BUILD_CLI)
    add_subdirectory(lsfg-vk-cli)
endif()
