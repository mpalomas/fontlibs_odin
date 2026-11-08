# Builds FreeType and HarfBuzz from upstream/ on Windows, with MSVC (cl or clang-cl): freetype.lib and harfbuzz.lib (static), and
# fontlibs.dll with its import library fontlibs.dll.lib (shared: one DLL with the API of both), named as the bindings import them.
# Run by tools/build_fontlibs.ps1, which installs them in lib/windows-<arch>/.
# Linux and macOS use tools/build_fontlibs.sh, which builds the same sources the same way.
#
# FreeType is built with upstream/config/fontlibs_ftoption.h and fontlibs_ftmodule.h (TrueType and CFF fonts, the auto-hinter, the smooth
# rasterizer; no zlib, PNG or other formats). HarfBuzz is built from upstream/config/fontlibs_harfbuzz.cc: the shaper and the raster
# library, without the platform shapers, and with no libpng. No exceptions, RTTI or thread-safe statics, and the static C runtime
# (/MT), which Odin programs link (libcmt): HarfBuzz needs no C++ runtime (its mutex is a Win32 critical section), and the DLL needs
# no Visual C++ redistributable. Built for size (/O1, NDEBUG), as the Unix script is (-Os).
#
# Options: FONTLIBS_STATIC, FONTLIBS_SHARED (both ON).
cmake_minimum_required(VERSION 3.21)
project(fontlibs LANGUAGES C CXX)

option(FONTLIBS_STATIC "Build the static libraries, freetype.lib and harfbuzz.lib" ON)
option(FONTLIBS_SHARED "Build the shared library, fontlibs.dll" ON)

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
# Size, not speed: /O1 (which includes /Gy, a section per function), where CMake's default is /O2.
set(CMAKE_C_FLAGS_RELEASE "/O1 /DNDEBUG")
set(CMAKE_CXX_FLAGS_RELEASE "/O1 /DNDEBUG")
# Replaced by /EHs-c- and /GR- below.
string(REGEX REPLACE "/EH[a-z]+|/GR" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")

# /Gy and /Gw let the programs' linker drop the unused functions and data (/OPT:REF, which Odin passes). /MP compiles the files in
# parallel. The static libraries also get /Zl, which leaves out the default library directives: the program chooses the C runtime.
set(COMMON_OPTIONS /Gy /Gw /utf-8 /W3 /MP)
set(HB_OPTIONS /std:c++17 /Zc:__cplusplus /GR- /EHs-c- /Zc:threadSafeInit- /bigobj)

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
set(FT_DEFINITIONS
    FT2_BUILD_LIBRARY
    _CRT_SECURE_NO_WARNINGS
    "FT_CONFIG_OPTIONS_H=\"fontlibs_ftoption.h\""
    "FT_CONFIG_MODULES_H=\"fontlibs_ftmodule.h\""
)
set(HB_DEFINITIONS _CRT_SECURE_NO_WARNINGS _HAS_EXCEPTIONS=0)
# HarfBuzz is one translation unit, which MSVC needs /bigobj for.
set(HB_SOURCE "${UP}/config/fontlibs_harfbuzz.cc")

# STATIC
if(FONTLIBS_STATIC)
    add_library(freetype STATIC ${FT_SOURCES})
    target_include_directories(freetype PRIVATE "${UP}/config" "${FT}/include" "${FT}/src")
    target_compile_definitions(freetype PRIVATE ${FT_DEFINITIONS})
    target_compile_options(freetype PRIVATE ${COMMON_OPTIONS} /Zl)
    install(TARGETS freetype ARCHIVE DESTINATION .)

    add_library(harfbuzz STATIC "${HB_SOURCE}")
    target_include_directories(harfbuzz PRIVATE "${HB}" "${UP}/config")
    target_compile_definitions(harfbuzz PRIVATE ${HB_DEFINITIONS})
    target_compile_options(harfbuzz PRIVATE ${COMMON_OPTIONS} ${HB_OPTIONS} /Zl)
    install(TARGETS harfbuzz ARCHIVE DESTINATION .)
endif()

# SHARED: one DLL with both APIs. The sources are compiled again, with the macros that export the API (DLL_EXPORT for FreeType,
# HB_EXTERN for HarfBuzz). No /Zl: the DLL links the static C runtime itself.
if(FONTLIBS_SHARED)
    add_library(freetype_objects OBJECT ${FT_SOURCES})
    target_include_directories(freetype_objects PRIVATE "${UP}/config" "${FT}/include" "${FT}/src")
    target_compile_definitions(freetype_objects PRIVATE ${FT_DEFINITIONS} DLL_EXPORT)
    target_compile_options(freetype_objects PRIVATE ${COMMON_OPTIONS})

    add_library(harfbuzz_objects OBJECT "${HB_SOURCE}")
    target_include_directories(harfbuzz_objects PRIVATE "${HB}" "${UP}/config")
    target_compile_definitions(harfbuzz_objects PRIVATE ${HB_DEFINITIONS} "HB_EXTERN=__declspec(dllexport)")
    target_compile_options(harfbuzz_objects PRIVATE ${COMMON_OPTIONS} ${HB_OPTIONS})

    add_library(fontlibs_shared SHARED $<TARGET_OBJECTS:freetype_objects> $<TARGET_OBJECTS:harfbuzz_objects>)
    # fontlibs.dll.lib, as the bindings name the import library, so that it can't be taken for a static library.
    set_target_properties(fontlibs_shared PROPERTIES OUTPUT_NAME fontlibs ARCHIVE_OUTPUT_NAME fontlibs.dll)
    target_link_options(fontlibs_shared PRIVATE /OPT:REF /OPT:ICF)
    install(TARGETS fontlibs_shared RUNTIME DESTINATION . ARCHIVE DESTINATION .)
endif()
