cmake_minimum_required(VERSION 3.7)

project (RDKit)

IF(NOT CMAKE_BUILD_TYPE)
  SET(CMAKE_BUILD_TYPE Release CACHE STRING
      "Choose the type of build, options are: None Debug Release RelWithDebInfo MinSizeRel."
      FORCE)
ENDIF(NOT CMAKE_BUILD_TYPE)

# Enable CTest
include(CTest)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# At build time put runtime binaries in the bin subdirectory
set(RDK_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/bin")
set(RDK_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lib")
set(RDK_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lib")

set(RDKit_LibDir "lib${LIB_SUFFIX}")
set(RDKit_ShareDir "share/RDKit")

if(CMAKE_SIZEOF_VOID_P EQUAL 4)
  target_compile_definitions(rdkit_base INTERFACE "-DRDK_32BIT_BUILD")
else()
  target_compile_definitions(rdkit_base INTERFACE "-DRDK_64BIT_BUILD")
endif()

# disable some warnings that we don't care about
if(MSVC)
  # These should occasionally be enabled to check what's going on
  # 4267 conversion with possible loss of data.
  # 4305 truncation from 'double' to 'const float'
  # 4244 conversion from 'uint64_t' to 'unsigned int', possible loss of data
  target_compile_options(rdkit_base INTERFACE "/wd4267" "/wd4305" "/wd4244")
  target_compile_definitions(rdkit_base INTERFACE "_CRT_SECURE_NO_WARNINGS")
endif(MSVC)

# Detect clang, which masquerades as gcc.  CMake 2.6 doesn't know how to
# detect it.
string(REGEX MATCH "clang" CMAKE_COMPILER_IS_CLANG "${CMAKE_C_COMPILER}")

find_package(PostgreSQL REQUIRED)

# setup our compiler flags:

if(CMAKE_COMPILER_IS_GNUCXX)
  SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-deprecated -Wno-unused-function -fno-strict-aliasing")
  SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-deprecated -Wno-unused-function -fno-strict-aliasing -Wall -Wextra")
  if (NOT CYGWIN)
    SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fPIC")
    SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC")
  endif()
endif()

if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
  SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-array-bounds -fPIC -Wno-parentheses -Wno-logical-op-parentheses -Wno-format")
  SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -Wno-deprecated -Wno-unused-function -fno-strict-aliasing -Wno-format -Wno-logical-op-parentheses -fPIC")
endif()

install(FILES README license.txt
        DESTINATION ${RDKit_ShareDir}
        COMPONENT base
        )

if (MSVC)
  # disable warnings:
  #  - 4267: conversion from 'size_t' to 'unsigned int', possible loss of data
  add_definitions( "/wd4267" )
endif(MSVC)

add_subdirectory(Code)

# Memory testing setup
FIND_PROGRAM(MEMORYCHECK_COMMAND valgrind)
CONFIGURE_FILE(CTestCustom.ctest.in ${RDKit_BINARY_DIR}/CTestCustom.ctest)
