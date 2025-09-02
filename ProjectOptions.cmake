include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(arksamplecmake_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(arksamplecmake_setup_options)
  option(arksamplecmake_ENABLE_HARDENING "Enable hardening" ON)
  option(arksamplecmake_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    arksamplecmake_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    arksamplecmake_ENABLE_HARDENING
    OFF)

  arksamplecmake_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR arksamplecmake_PACKAGING_MAINTAINER_MODE)
    option(arksamplecmake_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(arksamplecmake_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(arksamplecmake_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(arksamplecmake_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(arksamplecmake_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(arksamplecmake_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(arksamplecmake_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(arksamplecmake_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(arksamplecmake_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(arksamplecmake_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(arksamplecmake_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(arksamplecmake_ENABLE_PCH "Enable precompiled headers" OFF)
    option(arksamplecmake_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(arksamplecmake_ENABLE_IPO "Enable IPO/LTO" ON)
    option(arksamplecmake_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(arksamplecmake_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(arksamplecmake_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(arksamplecmake_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(arksamplecmake_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(arksamplecmake_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(arksamplecmake_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(arksamplecmake_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(arksamplecmake_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(arksamplecmake_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(arksamplecmake_ENABLE_PCH "Enable precompiled headers" OFF)
    option(arksamplecmake_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      arksamplecmake_ENABLE_IPO
      arksamplecmake_WARNINGS_AS_ERRORS
      arksamplecmake_ENABLE_USER_LINKER
      arksamplecmake_ENABLE_SANITIZER_ADDRESS
      arksamplecmake_ENABLE_SANITIZER_LEAK
      arksamplecmake_ENABLE_SANITIZER_UNDEFINED
      arksamplecmake_ENABLE_SANITIZER_THREAD
      arksamplecmake_ENABLE_SANITIZER_MEMORY
      arksamplecmake_ENABLE_UNITY_BUILD
      arksamplecmake_ENABLE_CLANG_TIDY
      arksamplecmake_ENABLE_CPPCHECK
      arksamplecmake_ENABLE_COVERAGE
      arksamplecmake_ENABLE_PCH
      arksamplecmake_ENABLE_CACHE)
  endif()

  arksamplecmake_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (arksamplecmake_ENABLE_SANITIZER_ADDRESS OR arksamplecmake_ENABLE_SANITIZER_THREAD OR arksamplecmake_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(arksamplecmake_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(arksamplecmake_global_options)
  if(arksamplecmake_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    arksamplecmake_enable_ipo()
  endif()

  arksamplecmake_supports_sanitizers()

  if(arksamplecmake_ENABLE_HARDENING AND arksamplecmake_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR arksamplecmake_ENABLE_SANITIZER_UNDEFINED
       OR arksamplecmake_ENABLE_SANITIZER_ADDRESS
       OR arksamplecmake_ENABLE_SANITIZER_THREAD
       OR arksamplecmake_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${arksamplecmake_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${arksamplecmake_ENABLE_SANITIZER_UNDEFINED}")
    arksamplecmake_enable_hardening(arksamplecmake_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(arksamplecmake_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(arksamplecmake_warnings INTERFACE)
  add_library(arksamplecmake_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  arksamplecmake_set_project_warnings(
    arksamplecmake_warnings
    ${arksamplecmake_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(arksamplecmake_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    arksamplecmake_configure_linker(arksamplecmake_options)
  endif()

  include(cmake/Sanitizers.cmake)
  arksamplecmake_enable_sanitizers(
    arksamplecmake_options
    ${arksamplecmake_ENABLE_SANITIZER_ADDRESS}
    ${arksamplecmake_ENABLE_SANITIZER_LEAK}
    ${arksamplecmake_ENABLE_SANITIZER_UNDEFINED}
    ${arksamplecmake_ENABLE_SANITIZER_THREAD}
    ${arksamplecmake_ENABLE_SANITIZER_MEMORY})

  set_target_properties(arksamplecmake_options PROPERTIES UNITY_BUILD ${arksamplecmake_ENABLE_UNITY_BUILD})

  if(arksamplecmake_ENABLE_PCH)
    target_precompile_headers(
      arksamplecmake_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(arksamplecmake_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    arksamplecmake_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(arksamplecmake_ENABLE_CLANG_TIDY)
    arksamplecmake_enable_clang_tidy(arksamplecmake_options ${arksamplecmake_WARNINGS_AS_ERRORS})
  endif()

  if(arksamplecmake_ENABLE_CPPCHECK)
    arksamplecmake_enable_cppcheck(${arksamplecmake_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(arksamplecmake_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    arksamplecmake_enable_coverage(arksamplecmake_options)
  endif()

  if(arksamplecmake_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(arksamplecmake_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(arksamplecmake_ENABLE_HARDENING AND NOT arksamplecmake_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR arksamplecmake_ENABLE_SANITIZER_UNDEFINED
       OR arksamplecmake_ENABLE_SANITIZER_ADDRESS
       OR arksamplecmake_ENABLE_SANITIZER_THREAD
       OR arksamplecmake_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    arksamplecmake_enable_hardening(arksamplecmake_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
