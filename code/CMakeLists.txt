set(EXTENSION gzip)

############## find zlib #################

find_package(ZLIB REQUIRED)

message("zlib: ${ZLIB_INCLUDE_DIRS}")

include_directories(${ZLIB_INCLUDE_DIRS})

############## find postgres #################

find_package(PostgreSQL REQUIRED)

message("postgres: ${PostgreSQL_INCLUDE_DIRS}")

include_directories(${PostgreSQL_INCLUDE_DIRS})

if(WIN32)
  include_directories(${PostgreSQL_INCLUDE_DIR}/server/port/win32)
  if(MSVC)
    include_directories(${PostgreSQL_INCLUDE_DIR}/server/port/win32_msvc)
  endif(MSVC)
endif(WIN32)

if(NOT DEFINED PostgreSQL_ROOT)
  if(DEFINED ENV{PostgreSQL_ROOT})
    set(PostgreSQL_ROOT "$ENV{PostgreSQL_ROOT}")
  endif(DEFINED ENV{PostgreSQL_ROOT})
endif(NOT DEFINED PostgreSQL_ROOT)

if(NOT DEFINED PostgreSQL_ROOT)
  set(PostgreSQL_ROOT "${PostgreSQL_LIBRARY_DIRS}/..")
endif(NOT DEFINED PostgreSQL_ROOT)

if(NOT DEFINED PostgreSQL_CONFIG_DIR)
  set(PostgreSQL_CONFIG_DIR "${PostgreSQL_ROOT}/bin")
endif(NOT DEFINED PostgreSQL_CONFIG_DIR)

if(NOT DEFINED PostgreSQL_CONFIG)
  set(PostgreSQL_CONFIG "${PostgreSQL_CONFIG_DIR}/pg_config")
endif(NOT DEFINED PostgreSQL_CONFIG)

macro (run_pg_config arg var)
  execute_process(COMMAND ${PostgreSQL_CONFIG} ${arg}
                  RESULT_VARIABLE pgsql_config_result
                  OUTPUT_VARIABLE ${var}
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT ${pgsql_config_result} EQUAL 0 OR NOT ${var})
    message(FATAL_ERROR "${PostgreSQL_CONFIG} ${arg} failed")
  endif()
endmacro ()

run_pg_config (--bindir PG_BINDIR)
run_pg_config (--sharedir PG_SHAREDIR)
run_pg_config (--pkglibdir PG_PKGLIBDIR)

set(PG_PKGLIBDIR "${PG_PKGLIBDIR}/")
set(PG_EXTENSIONDIR "${PG_SHAREDIR}/extension")

if(MSVC)
  add_definitions(-DWIN32 -DBUILDING_MODULE -DNOMINMAX)
  if(NOT (MSVC_VERSION LESS 1700))
    add_definitions(-DHAVE_RINT)
  endif()
endif(MSVC)

link_directories(${PostgreSQL_LIBRARY_DIRS})

############## define library #################

add_library(${EXTENSION} SHARED pg_gzip.c)

target_link_libraries(${EXTENSION} ${ZLIB_LIBRARIES})

target_link_libraries(${EXTENSION} ${PostgreSQL_LIBRARIES})

if(WIN32)
	target_link_libraries(${EXTENSION} postgres)
endif(WIN32)

############## find pg_regress #######################

if(WIN32 AND NOT UNIX)
  set(PGREGRESS_BINARY "${PG_BINDIR}\\pg_regress.exe")
  string(REGEX REPLACE "/" "\\\\" PG_EXTENSIONDIR ${PG_EXTENSIONDIR})
  string(REGEX REPLACE "/" "\\\\" PGREGRESS_BINARY ${PGREGRESS_BINARY})
else(WIN32 AND NOT UNIX)
  run_pg_config (--pgxs PG_MAKEFILE)
  get_filename_component(PG_MAKEFILESDIR ${PG_MAKEFILE} PATH)
  set(PGREGRESS_BINARY "${PG_MAKEFILESDIR}/../test/regress/pg_regress")
endif(WIN32 AND NOT UNIX)

if(NOT EXISTS ${PGREGRESS_BINARY})
  message(FATAL_ERROR "${PGREGRESS_BINARY} does not exist")
endif()

macro (run_pgregress arg var)
  execute_process(COMMAND ${PGREGRESS_BINARY} ${arg}
                  OUTPUT_VARIABLE ${var}
                  ERROR_VARIABLE ${var}
                  OUTPUT_STRIP_TRAILING_WHITESPACE
                  ERROR_STRIP_TRAILING_WHITESPACE)
endmacro ()

############## get bindir switch #######################

set(PGREGRESS_BINDIR_SWITCH "")

foreach(opt "bindir" "psqldir")
  run_pgregress("--${opt}" err)
  if (${err} MATCHES "option requires an argument")
    set(PGREGRESS_BINDIR_SWITCH ${opt})
    break()
  endif()
endforeach()

if (NOT ${PGREGRESS_BINDIR_SWITCH} STREQUAL "")
  set(PGREGRESS_BINDIR_SWITCH "--${PGREGRESS_BINDIR_SWITCH}=\"${PG_BINDIR}\"")
endif()

############## generate installation and test command parts #######################

set(testPgSQLName "${CMAKE_CURRENT_BINARY_DIR}/pgsql_regress")
set(installPgSQLName "${CMAKE_CURRENT_BINARY_DIR}/pgsql_install")
set(PG_CURRENT_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/")
set(PG_CURRENT_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/")

if(WIN32 AND NOT UNIX)
  set(testPgSQLCommand "")
  set(testPgSQLName "${testPgSQLName}.bat")
  set(installPgSQLName "${installPgSQLName}.bat")
  set(installCopyCommand "copy /Y")
  set(installPgSQLBody "")
  set(PG_GZIP_LIB_SRC "${EXTENSION}.dll")
  set(PG_GZIP_LIB_DEST "${EXTENSION}.dll")
  string(REGEX REPLACE "/" "\\\\" PG_CURRENT_SOURCE_DIR ${PG_CURRENT_SOURCE_DIR})
  string(REGEX REPLACE "/" "\\\\" PG_CURRENT_BINARY_DIR ${PG_CURRENT_BINARY_DIR})
  string(REGEX REPLACE "/" "\\\\" PG_PKGLIBDIR ${PG_PKGLIBDIR})
else(WIN32 AND NOT UNIX)
  set (EXTENSION_PREFIX "lib")
  set(testPgSQLCommand "sh")
  set(testPgSQLName "${testPgSQLName}.sh")
  set(installPgSQLName "${installPgSQLName}.sh")
  set(installCopyCommand "cp")
  set(installPgSQLBody "set -x\n")
  set(PG_GZIP_LIB_SRC "${EXTENSION_PREFIX}${EXTENSION}.so")
  set(PG_GZIP_LIB_DEST "${EXTENSION}.so")
endif(WIN32 AND NOT UNIX)

set(testPgSQLBody "cd \"${PG_CURRENT_BINARY_DIR}\"\n"
    "\"${PGREGRESS_BINARY}\" --inputdir=sql "
    "${PGREGRESS_BINDIR_SWITCH} gzip\n")

############## get control file and generate sql file #######################

file(STRINGS ${PG_CURRENT_SOURCE_DIR}${EXTENSION}.control
    PG_EXTVERSION LIMIT_COUNT 1 REGEX default_version)

string(REPLACE " " ";" tokList ${PG_EXTVERSION})

list(GET tokList -1 PG_EXTVERSION)

string(REGEX REPLACE "'" "" PG_EXTVERSION ${PG_EXTVERSION})

if(MSVC)
  if(${CMAKE_GENERATOR} STREQUAL "NMake Makefiles")
    set(PG_GZIP_LIB_SRC "${PG_GZIP_LIB_SRC}")
  else(${CMAKE_GENERATOR} STREQUAL "NMake Makefiles")
    set(PG_GZIP_LIB_SRC "${CMAKE_BUILD_TYPE}\\${PG_GZIP_LIB_SRC}")
  endif(${CMAKE_GENERATOR} STREQUAL "NMake Makefiles")
endif(MSVC)

configure_file("${PG_CURRENT_SOURCE_DIR}${EXTENSION}.sql.in"
               "${PG_CURRENT_BINARY_DIR}${EXTENSION}--${PG_EXTVERSION}.sql")

############## generate install and test bat/sh files #######################

set(installPgSQLBody "${installPgSQLBody}"
    "${installCopyCommand} \"${PG_CURRENT_BINARY_DIR}${EXTENSION}--${PG_EXTVERSION}.sql\" \"${PG_EXTENSIONDIR}\"\n"
    "${installCopyCommand} \"${PG_CURRENT_SOURCE_DIR}${EXTENSION}.control\" \"${PG_EXTENSIONDIR}\"\n"
    "${installCopyCommand} \"${PG_CURRENT_BINARY_DIR}${PG_GZIP_LIB_SRC}\" \"${PG_PKGLIBDIR}${PG_GZIP_LIB_DEST}\"\n")

file(WRITE ${testPgSQLName} ${testPgSQLBody})

file(WRITE ${installPgSQLName} ${installPgSQLBody})

############## copy testing prerequisites #######################

foreach(testDir sql expected)
  add_custom_command(TARGET ${EXTENSION} PRE_BUILD
      COMMAND "${CMAKE_COMMAND}" -E copy_directory
      "${PG_CURRENT_SOURCE_DIR}${testDir}" "${PG_CURRENT_BINARY_DIR}${testDir}")
endforeach()

############## print installation message #######################

message("\n"
    "=====================================================================\n"
    "After building, check\n"
    "${installPgSQLName}\n"
    "for correctness of installation paths. If everything is OK, gain \n"
    "administrator privileges, stop the PostgreSQL service, run\n"
    "${installPgSQLName}\n"
    "to install the PostgreSQL RDKit cartridge, then start again\n"
    "the PostgreSQL service\n"
    "=====================================================================\n")

############## add test target #######################

add_test(testPgSQL ${testPgSQLCommand} ${testPgSQLName})
