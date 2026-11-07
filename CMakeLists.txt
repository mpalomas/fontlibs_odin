# Builds FreeType and HarfBuzz from upstream/ on Windows, with MSVC (cl or clang-cl): freetype.lib and harfbuzz.lib (static),
# named as the bindings import them. Run by tools/build_fontlibs.ps1, which installs them in lib/windows-<arch>/.
# Linux and macOS use tools/build_fontlibs.sh, which builds the same sources the same way.
#
# FreeType is built with upstream/config/owin_ftoption.h and owin_ftmodule.h (TrueType and CFF fonts, the auto-hinter, the smooth
# rasterizer; no zlib, PNG or other formats). HarfBuzz is built from upstream/config/owin_harfbuzz.cc: the shaper and the raster
# library, without the platform shapers, and with no libpng. No exceptions, RTTI or thread-safe statics, and the static C runtime
# (/MT), which Odin programs link (libcmt): HarfBuzz needs no C++ runtime (its mutex is a Win32 critical section).
cmake_minimum_required(VERSION 3.21)
project(fontlibs LANGUAGES C CXX)

if(NOT MSVC)
    message(FATAL_ERROR "CMakeLists.txt builds with MSVC only: on Linux and macOS, run tools/build_fontlibs.sh")
endif()

set(UP "${CMAKE_CURRENT_SOURCE_DIR}/upstream")
set(FT "${UP}/freetype")
set(HB "${UP}/harfbuzz/src")
if(NOT EXISTS "${FT}/src/base/ftbase.c" OR NOT EXISTS "${HB}/hb-ot-shape.cc")
    message(FATAL_ERROR "no sources in upstream/: run tools/import_sources.sh")
endif()

set(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreaded)
# Replaced by /EHs-c- and /GR- below.
string(REGEX REPLACE "/EH[a-z]+|/GR" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")

# /Gy and /Gw let the programs' linker drop the unused functions and data (/OPT:REF, which Odin passes). /Zl leaves out the default
# library directives: the program chooses the C runtime. /MP compiles the files in parallel.
set(COMMON_OPTIONS /O2 /Gy /Gw /Zl /utf-8 /W3 /MP)

# FREETYPE: the files of tools/build_fontlibs.sh. The options and modules headers are named by quotes: they're found in
# upstream/config, without angle brackets that a shell could take for redirections.
set(FT_SOURCES
    "${FT}/src/base/ftsystem.c" "${FT}/src/base/ftinit.c" "${FT}/src/base/ftdebug.c" "${FT}/src/base/ftbase.c"
    "${FT}/src/base/ftbbox.c" "${FT}/src/base/ftglyph.c" "${FT}/src/base/ftbitmap.c" "${FT}/src/base/ftmm.c"
    "${FT}/src/base/ftstroke.c" "${FT}/src/base/ftsynth.c" "${FT}/src/base/ftfstype.c" "${FT}/src/base/ftgasp.c"
    "${FT}/src/truetype/truetype.c" "${FT}/src/cff/cff.c" "${FT}/src/sfnt/sfnt.c" "${FT}/src/psaux/psaux.c"
    "${FT}/src/psnames/psnames.c" "${FT}/src/pshinter/pshinter.c" "${FT}/src/smooth/smooth.c"
    "${FT}/src/autofit/autofit.c"
)
add_library(freetype STATIC ${FT_SOURCES})
target_include_directories(freetype PRIVATE "${UP}/config" "${FT}/include" "${FT}/src")
target_compile_definitions(freetype PRIVATE
    FT2_BUILD_LIBRARY
    _CRT_SECURE_NO_WARNINGS
    "FT_CONFIG_OPTIONS_H=\"owin_ftoption.h\""
    "FT_CONFIG_MODULES_H=\"owin_ftmodule.h\""
)
target_compile_options(freetype PRIVATE ${COMMON_OPTIONS})
install(TARGETS freetype ARCHIVE DESTINATION .)

# HARFBUZZ: one translation unit, which MSVC needs /bigobj for.
add_library(harfbuzz STATIC "${UP}/config/owin_harfbuzz.cc")
target_include_directories(harfbuzz PRIVATE "${HB}" "${UP}/config")
target_compile_definitions(harfbuzz PRIVATE _CRT_SECURE_NO_WARNINGS _HAS_EXCEPTIONS=0)
target_compile_options(harfbuzz PRIVATE ${COMMON_OPTIONS} /std:c++17 /Zc:__cplusplus /GR- /EHs-c- /Zc:threadSafeInit- /bigobj)
install(TARGETS harfbuzz ARCHIVE DESTINATION .)
