# Builds abi_check.c against the FreeType and HarfBuzz headers in upstream/, with the options header the libraries are built with.
# Run by tools/abi/check.sh, on every platform.
cmake_minimum_required(VERSION 3.21)
project(abi_check LANGUAGES C)

get_filename_component(ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)
add_executable(abi_check abi_check.c)
target_include_directories(abi_check PRIVATE
    "${ROOT}/upstream/config" "${ROOT}/upstream/freetype/include" "${ROOT}/upstream/harfbuzz/src"
)
target_compile_definitions(abi_check PRIVATE
    _CRT_SECURE_NO_WARNINGS
    "FT_CONFIG_OPTIONS_H=\"fontlibs_ftoption.h\""
    "FT_CONFIG_MODULES_H=\"fontlibs_ftmodule.h\""
)
