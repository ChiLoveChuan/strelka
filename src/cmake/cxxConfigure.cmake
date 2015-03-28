#
# Starka
# Copyright (c) 2009-2014 Illumina, Inc.
#
# This software is provided under the terms and conditions of the
# Illumina Open Source Software License 1.
#
# You should have received a copy of the Illumina Open Source
# Software License 1 along with this program. If not, see
# <https://github.com/sequencing/licenses/>
#

################################################################################
##
## CMake configuration file for c++ executables
##
## author Come Raczy
##
################################################################################


INCLUDE(CheckFunctionExists)

find_path(HAVE_INTTYPES_H  inttypes.h)
find_path(HAVE_MEMORY_H    memory.h)
find_path(HAVE_STDINT_H    stdint.h)
find_path(HAVE_STDLIB_H    stdlib.h)
find_path(HAVE_STRING_H    string.h)
find_path(HAVE_STRINGS_H   strings.h)
find_path(HAVE_UNISTD_H    unistd.h)

set (CMAKE_REQUIRED_LIBRARIES m)
check_function_exists(floorf HAVE_FLOORF)
check_function_exists(round  HAVE_ROUND)
check_function_exists(roundf HAVE_ROUNDF)
check_function_exists(powf HAVE_POWF)

include ("${THIS_MACROS_CMAKE}")

# Support for static linking
# Note that this implies that all libraries must be found with the
# exact file name (libXXX.a or libXXX.so)
#if    (THIS_FORCE_STATIC_LINK)
#    message(STATUS "All libraries will be statically linked")
#    set(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS "-static")
#    set(CMAKE_SHARED_LIBRARY_LINK_CXX_FLAGS "-static")
    # ensure that even if cmake decides to allow for dynamic libs resolution,
    # this gets overriden into static...
#    set(CMAKE_EXE_LINK_DYNAMIC_CXX_FLAGS ${CMAKE_EXE_LINK_STATIC_CXX_FLAGS})
#    set(THIS_LIBRARY_PREFIX ${CMAKE_STATIC_LIBRARY_PREFIX})
#    set(THIS_LIBRARY_SUFFIX ${CMAKE_STATIC_LIBRARY_SUFFIX})
    # set(CMAKE_EXE_LINKER_FLAGS "-static-libgcc -static-libstdc++")
#else  ()
#    set(THIS_LIBRARY_PREFIX "")
#    set(THIS_LIBRARY_SUFFIX "")
#endif ()

# required support for gzip compression
static_find_library(ZLIB zlib.h z)
if    (HAVE_ZLIB)
    set  (THIS_ADDITIONAL_LIB ${THIS_ADDITIONAL_LIB} z)
    message(STATUS "Gzip compression supported")
else  ()
    message(FATAL_ERROR "No support for gzip compression")
endif ()

# samtools 1.x forces pthreads in link:
find_package( Threads )

# setup ccache if found in path
find_program(CCACHE_PATH ccache)
set (IS_CCACHE TRUE)
if (CCACHE_PATH STREQUAL "CCACHE_PATH-NOTFOUND")
    set (IS_CCACHE FALSE)
endif()

if (${IS_CCACHE})
    message (STATUS "Found ccache: ${CCACHE_PATH}")
    SET_PROPERTY(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ${CCACHE_PATH})
    SET_PROPERTY(GLOBAL PROPERTY RULE_LAUNCH_LINK ${CCACHE_PATH})

    # special logic to get clang and ccache working together (suggestion from http://petereisentraut.blogspot.com/2011/09/ccache-and-clang-part-2.html):
    set(ENV{CCACHE_CPP2} "yes")
    if (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Qunused-arguments")
    endif()
    if (CMAKE_C_COMPILER_ID STREQUAL "Clang")
        set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Qunused-arguments")
    endif()

else()
    message (STATUS "No ccache found")
endif()


# Force static linking
set(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS "")

function(get_compiler_name_version compiler_name compiler_version)
    execute_process(COMMAND ${compiler_name} -dumpversion OUTPUT_VARIABLE this_version)
    STRING(REGEX REPLACE "(\r?\n)+$" "" this_version "${this_version}")
    set(${compiler_version} ${this_version} PARENT_SCOPE)
endfunction()

macro(get_compiler_version compiler_version)
    get_compiler_name_version(${CMAKE_CXX_COMPILER} compiler_version)
endmacro()

# clang doesn't make finding the version easy for us...
macro(get_clang_version compiler_version)
#    execute_process(COMMAND bash -c "${CMAKE_CXX_COMPILER} -v 2>&1 | awk '{printf $3; exit}'" OUTPUT_VARIABLE ${compiler_version})
    execute_process(COMMAND bash -c "echo | ${CMAKE_CXX_COMPILER} -dM -E - | awk '/__clang_version__/ {printf $3; exit}' | tr -d '\"'" OUTPUT_VARIABLE ${compiler_version})
endmacro()

macro(test_min_compiler compiler_version min_compiler_version compiler_label)
    if (${compiler_version} VERSION_LESS ${min_compiler_version})
        message (FATAL_ERROR "Unsupported version for ${compiler_label}: ${compiler_version}: "
                             "only versions >= ${min_compiler_version} are supported")
    endif ()
endmacro()


set(min_gxx_version "4.7")
set(min_clang_version "3.2")
set(min_intel_version "12.0") # guestimate based on intel support documentation

if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    get_compiler_version(compiler_version)
    test_min_compiler(${compiler_version} "${min_gxx_version}" "g++")
    message (STATUS "Using compiler: g++ version ${compiler_version}")

elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    get_clang_version(compiler_version)
    test_min_compiler(${compiler_version} "${min_clang_version}" "clang++")
    message (STATUS "Using compiler: clang++ version ${compiler_version}")

elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Intel")
    get_compiler_version(compiler_version)
    test_min_compiler(${compiler_version} "${min_intel_version}" "icpc")
    message (STATUS "Using compiler: Intel version ${compiler_version}")

    # for intel we also need to test the minimum version of g++ currently
    # in the path (because this is the stdc++ library that # intel will use):
    get_compiler_name_version("g++" gxx_compiler_version)
    test_min_compiler(${gxx_compiler_version} "${min_gxx_version}" "g++ libstdc++ (library used by icpc)")
    message (STATUS "Using libstdc++: gnu version ${gxx_compiler_version}")

else ()
    message (STATUS "Using compiler: ${CMAKE_CXX_COMPILER_ID}")
endif ()



#
# set compile flags
#


##
## set static linking of standard libraries for binary redistribution:
##
set (IS_STANDARD_STATIC FALSE)
if     (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    if (NOT (${compiler_version} VERSION_LESS "4.5"))
        set (IS_STANDARD_STATIC TRUE)
        set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static-libgcc -static-libstdc++")
    endif ()
elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Intel")
    set (IS_STANDARD_STATIC TRUE)
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static-libgcc -static-libstdc++")
endif ()

if (${IS_STANDARD_STATIC})
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static-libgcc -static-libstdc++")
endif ()


##
## set bug workarounds:
##
if     (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    if (((${compiler_version} VERSION_EQUAL "4.7") OR (${compiler_version} VERSION_EQUAL "4.7.3")) OR
        ((${compiler_version} VERSION_EQUAL "4.8") OR (${compiler_version} VERSION_EQUAL "4.8.2")))
        # workaround for: https://gcc.gnu.org/bugzilla/show_bug.cgi?id=58800
        add_definitions( -DBROKEN_NTH_ELEMENT )
    endif ()
endif ()


##
## set warning flags:
##
set (GNU_COMPAT_COMPILER ( (CMAKE_CXX_COMPILER_ID STREQUAL "GNU") OR (CMAKE_CXX_COMPILER_ID STREQUAL "Clang") OR (CMAKE_CXX_COMPILER_ID STREQUAL "Intel")))
if (GNU_COMPAT_COMPILER)
    set (CXX_WARN_FLAGS "-Wall -Wextra -Wshadow -Wunused -Wpointer-arith -Winit-self -pedantic -Wunused-parameter")
    set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wundef -Wdisabled-optimization -Wno-unknown-pragmas")
    set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wempty-body -Wdeprecated -Wno-missing-braces")
    if (NOT CMAKE_CXX_COMPILER_ID STREQUAL "Intel")
        set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wredundant-decls")
    endif ()

    if (NOT ${CMAKE_BUILD_TYPE} STREQUAL "Debug")
        set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wuninitialized")
    endif ()
endif ()

if     (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    if (NOT (${compiler_version} VERSION_LESS "4.2"))
        set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wlogical-op")
    endif ()

    if ((${compiler_version} VERSION_LESS "4.8") AND (NOT (${compiler_version} VERSION_LESS "4.7")))
        # switching off warning about unused function because otherwise compilation will fail with g++ 4.7.3 in Ubuntu,
        # don't know which patch levels are affected, so marking out all gcc 4.7.X
        set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wno-unused-function")
    endif ()
elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    set (IS_WARN_EVERYTHING FALSE)

    if (${IS_WARN_EVERYTHING})
        set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Weverything")
    endif ()

    set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wmissing-prototypes -Wunused-exception-parameter -Wbool-conversion")
    set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wimplicit-fallthrough -Wsizeof-array-argument -Wstring-conversion")
    set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wloop-analysis -Wextra-semi -Wmissing-variable-declarations")
    set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wheader-hygiene -Wmismatched-tags -Wunused-private-field")

    if (${IS_WARN_EVERYTHING})
        set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wno-sign-conversion -Wno-weak-vtables -Wno-conversion -Wno-cast-align -Wno-padded")
        set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wno-switch-enum -Wno-missing-noreturn -Wno-covered-switch-default")
        set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wno-unreachable-code -Wno-global-constructors -Wno-exit-time-destructors")
        set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wno-c++98-compat -Wno-old-style-cast -Wno-unused-member-function")
        set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wno-documentation -Wno-float-equal")
    endif ()

    if (NOT (${compiler_version} VERSION_LESS "3.3"))
        set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Woverloaded-shift-op-parentheses")

        if (${IS_WARN_EVERYTHING})
            set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wno-documentation-unknown-command")
        endif ()
    endif ()

    if (NOT (${compiler_version} VERSION_LESS "3.4"))
        set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wheader-guard -Wlogical-not-parentheses")
    endif ()

    if (NOT (${compiler_version} VERSION_LESS "3.6"))
        set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wunreachable-code-return -Wkeyword-macro -Winconsistent-missing-override")

        if (${IS_WARN_EVERYTHING})
            set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wno-reserved-id-macro")
        endif ()
    endif ()

elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Intel")
    # suppress errors in boost headers:
    set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -diag-disable 177,193,869,1599,3280")

    set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wunused-variable -Wpointer-arith")

    #set (CXX_WARN_FLAGS "${CXX_WARN_FLAGS} -Wmissing-prototypes -Wmissing-declarations -Wunused-variable -Wpointer-arith -Wuninitialized")
endif()


set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CXX_WARN_FLAGS}")


if (GNU_COMPAT_COMPILER)
    set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++0x")
    set (CMAKE_CXX_FLAGS_DEBUG "-O0 -g")

    # The NDEBUG macro is intentionally removed from release. One discussion on this is:
    # http://www.drdobbs.com/an-exception-or-a-bug/184401686
    set (CMAKE_CXX_FLAGS_RELEASE "-O3 -fomit-frame-pointer")
    set (CMAKE_CXX_FLAGS_RELWITHDEBINFO "-O2 -g")
    set (CMAKE_CXX_FLAGS_ASAN "-O1 -g -fsanitize=address -fno-omit-frame-pointer -fno-optimize-sibling-calls")
    #set (CMAKE_CXX_FLAGS_PROFILE "-O0 -g -pg -fprofile-arcs -ftest-coverage")

    # this doesn't seem to impact performance, taking out for now:
    #if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    #    set (CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -flto")
    #endif ()
endif()

# if ASan build type is requested, check that the compiler supports it:
if (CMAKE_BUILD_TYPE STREQUAL "ASan")
    set (IS_ASAN_SUPPORTED false)
    if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        if (NOT (${compiler_version} VERSION_LESS "4.8"))
            set (IS_ASAN_SUPPORTED true)
        endif ()
    elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        if (NOT (${compiler_version} VERSION_LESS "3.1"))
            set (IS_ASAN_SUPPORTED true)
        endif ()
    endif ()

    if (NOT ${IS_ASAN_SUPPORTED})
        message(FATAL_ERROR "Address sanitizer build type requested, but this is not supported by compiler.")
    endif ()
endif ()


if (GNU_COMPAT_COMPILER)

  if (${DEVELOPER_MODE})
    # some compiler versions will produce warnings with no reasonable workaround,
    # turn Werror off in this case
    #
    # a very common example are warnings from boost generated despite this library
    # being identified as a system header
    #
    set(IS_WERROR true)
    if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        if (${compiler_version} VERSION_LESS "4.2")
            set(IS_WERROR false)
        endif ()
    endif ()

    if(${IS_WERROR})
        message (STATUS "Building in developer mode: treating compiler warnings as errors")
        set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Werror")
    endif ()
  endif ()

  if (CMAKE_SYSTEM_PROCESSOR MATCHES "^i[67]86$")
    ##
    ## Use scalar floating point instructions from the SSE instruction set.
    ## Note: Pentium3 SSE supports only single precision arithmetics
    ##
    set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -msse -mfpmath=sse")
  elseif (CMAKE_SYSTEM_PROCESSOR MATCHES "^i[345]86$")
    ##
    ## Prevent using 80bit registers (more consistent rounding)
    ##
    set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -ffloat-store")
  endif ()

endif()

# cmake configure-time c++ configuration:
set(THIS_CXX_CONFIG_H_DIR ${CMAKE_CURRENT_BINARY_DIR}/lib)
set (CONFIG_DEST_FILE ${THIS_CXX_CONFIG_H_DIR}/common/config.h)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/lib/common/config.h.in ${CONFIG_DEST_FILE} @ONLY)

# build-time c++ configuration:
# note: (csaunders) tried to do this as add_custom_command every which way, can't get cmake to figure out
#       dependency chain in this case
set (CONFIG_VERSION_SOURCE_FILE ${CMAKE_CURRENT_SOURCE_DIR}/lib/common/configWorkflowVersion.h.in)
set (CONFIG_VERSION_DEST_FILE ${THIS_CXX_CONFIG_H_DIR}/common/configWorkflowVersion.h)
set (CONFIG_VERSION_TARGET "${THIS_PROJECT_NAME}_config_version")
add_custom_target(${CONFIG_VERSION_TARGET}
    DEPENDS ${THIS_VERSION_TARGET}
    COMMAND ${CMAKE_COMMAND}
    -D VERSION_FILE=${THIS_VERSION_FILE} 
    -D SOURCE_FILE=${CONFIG_VERSION_SOURCE_FILE}
    -D DEST_FILE=${CONFIG_VERSION_DEST_FILE}
    -P ${THIS_MODULE_DIR}/buildTimeConfigure.cmake)

#
# include dirs:
#
set (THIS_CXX_BEFORE_SYSTEM_INCLUDES "${Boost_INCLUDE_DIRS}" "${HTSLIB_DIR}" "${SAMTOOLS_DIR}" "${CODEMIN_DIR}")
set (THIS_CXX_ALL_INCLUDES "${CMAKE_SOURCE_DIR}/c++/lib")
