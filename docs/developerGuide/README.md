Strelka Developer Guide
=======================

## Table of Contents
[] (BEGIN automated TOC section, any edits will be overwritten on next source refresh)
* [Scope](#scope)
  * [Developer Build Notes](#developer-build-notes)
    * [Building from source repository vs. versioned code distribution:](#building-from-source-repository-vs-versioned-code-distribution)
    * [Source auto-documentation](#source-auto-documentation)
    * [Improving build time](#improving-build-time)
    * [General Debugging: Address Sanitizer](#general-debugging-address-sanitizer)
    * [General Debugging: Inspecting temporary files](#general-debugging-inspecting-temporary-files)
    * [Windows development support](#windows-development-support)
    * [Automating Portable Binary Builds for Linux](#automating-portable-binary-builds-for-linux)
  * [Coding Guidelines](#coding-guidelines)
    * [Source formatting](#source-formatting)
    * [Error handling](#error-handling)
    * [Unit tests](#unit-tests)
[] (END automated TOC section, any edits will be overwritten on next source refresh)

# Scope

This guide provides:
* protocols for contributing new or modified methods
* methods to debug stability or runtime issues
* methods to debug suspected false or missing variant calls
* high-level architectural documentation

Information is added as pertinent questions/discussions come up in the contributor community,
so this guide is not intended to provide complete coverage of the above topics.

For end user documentation describing how to run an analysis and interpret its output,
please see the [User Guide](../userGuide/README.md).

## Developer Build Notes

The following section provides a supplement to the standard build
instructions including additional details of interest to methods
developers.

### Building from source repository vs. versioned code distribution:

When the source repository is cloned from github, it is configured for development
rather than user distribution. In this configuration all builds are strict
such that:
* all warnings are treated as errors
* if cppcheck is found any detected cppcheck issue is converted to a build error

Note that all unit tests are always run and required to pass for the build
procedure to complete.

### Source auto-documentation

If doxygen is found in the path (and optionally dot as well) during
build configuration, then c++ documentation is available as an
additional "doc" target for the makefile:

    make doc

There is no installation for the documentation outside of the build
directory, the root doxygen page after completing this target will be:

    ${STRELKA_BUILD_PATH}/c++/doxygen/html/index.html

### Improving build time

#### ccache

The build system is configured to use ccache whenever this is
found in the path

#### Bundled dependencies

Note that during the configuration step, the following dependencies will be
built from source if they are not found:

* cmake 2.8.5+
* boost 1.53.0+

To avoid the extra time associated with this step, ensure that (1)
cmake 2.8.5+ is in your PATH and (2) BOOST\_ROOT is defined to point
to boost 1.53.0 or newer.

### General Debugging: Address Sanitizer

The build system offers first-class support for google address sanitizer
when a supporting compiler is detected. To use this mode, start a fresh
installation process with the additional configure option `--build-type=ASan`,
for example:

    ../configure --jobs=4 --prefix=/path/to/install --build-type=ASan

### General Debugging: Inspecting temporary files

All Strelka workflow configuration steps include an extended option to keep all temporary
files which would normally be deleted by the workflow as it runs. Keeping these
files may be helpful in various debugging scenarios. To turn on this option, add
`--retainTempFiles` as a configuration argument:

    configureStrelkaWorkflow.py [other_options...] --retainTempFiles

### Windows development support

Strelka does not link or run on windows. However, the build system does
facilitate Visual Studio (VS) developers. When cmake configuration is run
on windows, all linking is disabled and most third party libraries are
unpacked for header include access, but are not compiled. Cmake VS
solutions allow the c++ code to be browsed, analyzed and compiled to
the library level.  Note that unit test codes are compiled to
libraries but not linked or run.

C++11 features in use require at least VS2013. Windows
installations of cmake and zlib are also required to configure and compile.
Note that the minimum cmake version is 3.1.0 for Windows. Windows zlib is provided by the [gnuwin32 package] [gnuwin32] among others.

[gnuwin32]:http://gnuwin32.sourceforge.net/packages/zlib.htm

### Automating Portable Binary Builds for Linux

A script is provided to enable a dockerized build process which
issues Centos5+ or Centos6+ binary tarballs. To use this script, ensure you
have permission to `docker run` on the current system and execute the
following script:

```
${STRELKA_ROOT_PATH}/scratch/docker/deployment/dockerBuildBinaryTarball.bash ${STRELKA_ROOT_PATH2} ${BINARY_BUILD_PREFIX}
```

The term `${STRELKA_ROOT_PATH2}` can point to the current git repo (ie. `${STRELKA_ROOT_PATH}`),
or to an extracted Strelka source tarball previously created using the script:

```
${STRELKA_ROOT_PATH}/scratch/make_release_tarball.bash
```

The choice of virtualized build environment is hard-coded in the deploy script for the time being,
specified by `builderImage`.

## Coding Guidelines

### Source formatting

* Basic formatting restrictions on c++ code:
  * spaces instead of tabs
  * 4-space indents
  * "ANSI" bracket style
* Note the above restrictions are enforced by an astyle script which is occasionally run on the master branch (see [run_cxx_formatter.bash](../../scratch/source_check_and_format/run_cxx_formatter.bash))
* Otherwise, follow local code conventions

### Error handling

#### General Policies
* Exceptions with informative contextual details are encouraged whenever possible.
* To quickly express invariants it is acceptable to add `assert()`'s first, and transition to exceptions as code stabilizes.
* Note that the build process will never define `NDEBUG` to compile out assert statements, even in release code.
* Exceptions are never thrown with the intent to recover -- this is not a web browser. The goal is to:
  * Fail at the first sign of trouble.
  * Provide as much helpful contextual information as possible, including context from multiple layers of the stack.
* Warnings are discouraged. If considering a warning you should probably just fail per the above policy.

#### Exception Details
* Preferred exception pattern is to use an internal class derived from `boost::exception`:

```c++

#include "common/Exceptions.hh"

#include <sstream>

void
foo(const char* name)
{
    using namespace illumina::common;

    std::ostringstream oss;
    oss << "ERROR: unrecognized variant scoring model name: '" << name << "'\n";
    BOOST_THROW_EXCEPTION(LogicException(oss.str()));
}
```

* Context at the original throw site is often supplemented by a 'catch and release' block to add
information at a few critical points on the stack. Typically this is information which
is unavailable at the throw site. Example code is:

```c++
try
{
    realign_and_score_read(_opt,_dopt,sif.sample_opt,_ref,realign_buffer_range,rseg,sif.indel_sync());
}
catch (...)
{
    log_os << "ERROR: Exception caught in align_pos() while realigning segment: "
	   << static_cast<int>(r.second) << " of read: " << (*r.first) << "\n";
    throw;
}
```

#### Logging

* At the workflow (python) layer, please write all logging messages through pyflow's logging interface as follows:
```python
self.flowLog("Initiating Starling workflow version: %s" % (__version__)
```

* At the binary (c++) layer, there is no logger at present. Direct all error messaging to `std::cerr`.

### Unit tests
* Unit tests are enabled for a subset of the c++ code
* All tests use the boost unit test framework
* All unit tests are required to run and pass as part of every build (including end-user builds)
* Unit tests are already enabled for every library "test" subdirectory, additional tests in these directories will be automatically detected
  * Example [blt_util unit tests directory](../../src/c++/lib/blt_util/test)

