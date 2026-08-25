cmake_minimum_required(VERSION 3.16)
project(msgpackc LANGUAGES C)

list(INSERT CMAKE_MODULE_PATH 0 "$ENV{SWIPL_HOME_DIR}/cmake")
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "$ENV{SWIPL_HOME_DIR}/lib/cmake/swipl")
include(swipl)
include(SWIPLTargets)

add_library(msgpackc MODULE c/msgpackc.c)
target_link_swipl(msgpackc)
install(TARGETS msgpackc DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/${swipl_module_dir})

enable_testing()
swipl_add_test(msgpackc)
