#pragma once
#include <elf_gnu_structure.h>
#include <filesystem/echfs.h> // to do add a global file system
#include <sys/types.h>
#include <utils/sys/programm_exec_info.h>
pid_t launch_programm(const char *path, file_system *file_sys, int argc, const char **argv);
pid_t launch_programm_usr(programm_exec_info *info);

pid_t launch_module(const char *path, file_system *file_sys, int argc, const char **argv);
