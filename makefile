DIRECTORY_GUARD=mkdir -p $(@D)

ARCH := x86_64
END_PATH := ./kernel/generic ./kernel/arch/$(ARCH) ./libs/libc ./libs/utils ./libs/module

BUILD_OUT := ./build
# kernel files
HFILES    := $(shell find $(END_PATH) -type f -name '*.h')
DPEND_FILES := $(patsubst %.h,$(BUILD_OUT)/%.d,$(HFILES))

CFILES    := $(shell find $(END_PATH) -type f -name '*.c')
COBJFILES := $(patsubst %.c,$(BUILD_OUT)/%.o,$(CFILES))

CXXFILES    := $(shell find $(END_PATH) -type f -name '*.cpp')
CXXOBJFILES := $(patsubst %.cpp,$(BUILD_OUT)/%.o,$(CXXFILES))

ASMFILES  := $(shell find $(END_PATH) -type f -name '*.asm')
ASMOBJFILES := $(patsubst %.asm,$(BUILD_OUT)/%.o,$(ASMFILES))

CLANG_CFILES := $(shell find $(END_PATH) ./app/ -type f -name '*.cpp') $(shell find $(END_PATH) -type f -name '*.c')
CLANG_HFILES := $(shell find $(END_PATH) ./app/ -type f -name '*.h')


LINK_PATH := ./kernel/arch/$(ARCH)/linker.ld
# user_lib code files
USRCFILES    := $(shell find libs/ -type f -name '*.cpp') $(shell find libs/ -type f -name '*.c')
USRHFILES    := $(shell find libs/ -type f -name '*.h')
# user app code files
USRAPPCFILES := $(shell find app/ -type f -name '*.cpp') $(shell find app/ -type f -name '*.c')
USRAPPHFILES := $(shell find app/ -type f -name '*.h')


CC         = ./scripts/cross_compiler/bin/x86_64-pc-wingos-gcc
CXX        = ./scripts/cross_compiler/bin/x86_64-pc-wingos-g++
LD         = ./scripts/cross_compiler/bin/x86_64-pc-wingos-ld
ECHFS_PATH = ./echfs/echfs-utils

OBJ := $(shell find $(BUILD_OUT) -type f -name '*.o')

APP_FS_MAKEFILE_FLAGS 	= all -j$(nproc)
APP_FS_CHANGE 			= ./libs/ ./app/
APP_FILE_CHANGE 		= $(shell find $(APP_FS_CHANGE) -type f -name '*.cpp') $(shell find $(APP_FS_CHANGE) -type f -name '*.c')
KERNEL_HDD = ./build/disk.hdd
KERNEL_ELF = kernel.elf

QEMUFLAGS :=  -m 4G -device pvpanic -smp 6 -serial stdio -enable-kvm -d cpu_reset -hda $(KERNEL_HDD) \
		-nic user,model=e1000 -M q35 -cpu host 

.DEFAULT_GOAL =$(KERNEL_ELF)
CHARDFLAGS := $(CFLAGS)               \
        -DBUILD_TIME='"$(BUILD_TIME)"' \
        -std=c11                     \
        -g \
        -masm=intel                    \
        -fno-pic                       \
        -no-pie \
        -m64 \
		-mno-avx \
		-mno-sse \
	    -Wall \
	    -MD \
	    -MMD \
	    -Werror \
        -Os \
        -mcmodel=kernel \
        -mno-80387                     \
        -mno-red-zone                  \
        -fno-rtti \
        -fno-exceptions \
	    -ffreestanding                 \
        -fno-stack-protector           \
        -fno-omit-frame-pointer        \
	    -fno-isolate-erroneous-paths-attribute \
        -fno-delete-null-pointer-checks \
        -I./kernel/generic                        \
	    -I./kernel/arch/$(ARCH) \
        -I./libs/libc \
        -I./libs/
CXXHARDFLAGS := $(CFLAGS)               \
        -DBUILD_TIME='"$(BUILD_TIME)"' \
        -std=c++20                     \
        -g \
        -masm=intel                    \
        -fno-pic                       \
        -no-pie \
        -m64 \
	    -Wall \
	    -MD \
		-mno-sse \
		-mno-avx \
	    -MMD \
	    -Werror \
        -Os \
        -mcmodel=kernel \
        -mno-80387                     \
        -mno-red-zone                  \
        -fno-rtti \
        -fno-exceptions \
	    -ffreestanding                 \
        -fno-stack-protector           \
        -fno-omit-frame-pointer        \
	    -fno-isolate-erroneous-paths-attribute \
        -fno-delete-null-pointer-checks \
        -I./kernel/generic                        \
	    -I./kernel/arch/$(ARCH) \
        -I./libs/libc \
        -I./libs/

LDHARDFLAGS := $(LDFLAGS)        \
        -z max-page-size=0x1000   \
        -T $(LINK_PATH)


.PHONY:setup_echfs_utils
setup_echfs_utils:
	@make -C echfs/ clean -j$(nproc)
	@make -C echfs/ all -j$(nproc)

.PHONY:setup_toolchain
setup_toolchain:
	@bash ./scripts/make_cross_compiler.sh

.PHONY:setup_limine
setup_limine:
	

.PHONY:first_setup
first_setup: 
	@make setup_toolchain -j$(nproc)
	@make setup_echfs_utils -j$(nproc)
	@make setup_limine -j$(nproc)

.PHONY:bochs
bochs: $(KERNEL_HDD)
	-rm disk.img
	@bximage -q -mode=convert -imgmode=flat $(KERNEL_HDD) disk.img
	@bochs 

.PHONY:disk
disk: $(KERNEL_HDD)

.PHONY:run
run: $(KERNEL_HDD)
	qemu-system-x86_64 $(QEMUFLAGS)
	
debug: $(KERNEL_HDD)
	qemu-system-x86_64 -s -S $(QEMUFLAGS)

.PHONY:runvbox
runvbox: $(KERNEL_HDD)
	@VBoxManage -q startvm --putenv VBOX_GUI_DBG_ENABLED=true wingOS64
	@nc localhost 1234

.PHONY:format
format:
	clang-format -i --style=file $(CLANG_CFILES)
	clang-format -i --style=file $(CLANG_HFILES)
foreachramfs: 
	@for f in $(shell find initfs/ -maxdepth 64 -type f); do $(ECHFS_PATH) -m -p0 $(KERNEL_HDD) import $${f} $${f}; done

.PHONY:app
app: $(APP_FILE_CHANGE)
	@bash ./scripts/make_sysroot.sh

.PHONY:super
super:
	@make app -j12
	@make format
	@make -j12

	@objdump kernel.elf -f -s -d --source > kernel.map
	@make run

.PHONY:check
check:
	@make clean
	@make $(KERNEL_ELF) -j12
	@make app -j12

-include $(DPEND_FILES)
$(BUILD_OUT)/%.o: %.c 
	@$(DIRECTORY_GUARD)
	@echo "[KERNEL $(ARCH)] (c) $<"
	@$(CC) $(CHARDFLAGS) -c $< -o $@
$(BUILD_OUT)/%.o: %.cpp 
	@$(DIRECTORY_GUARD)
	@echo "[KERNEL $(ARCH)] (cpp) $<"
	@$(CXX) $(CXXHARDFLAGS) -c $< -o $@
%.h : %.h 
	@echo "[KERNEL $(ARCH)] (h) $<"

$(BUILD_OUT)/%.o: %.asm
	@$(DIRECTORY_GUARD)
	@echo "[KERNEL $(ARCH)] (asm) $<"
	@nasm $< -o $@ -felf64 -F dwarf -g -w+all -Werror


.PHONY:$(KERNEL_ELF)
$(KERNEL_ELF): $(COBJFILES) $(CXXOBJFILES) $(ASMOBJFILES) $(LINK_PATH)
	@ld $(LDHARDFLAGS) $(COBJFILES) $(CXXOBJFILES) $(ASMOBJFILES) -o $@

$(KERNEL_HDD): $(KERNEL_ELF) 
	-rm -rf $(KERNEL_HDD)
	-mkdir build
	sudo bash ./scripts/make_disk.sh

.PHONY:clean
clean:
	-rm -f $(DPEND_FILES)
	-rm -f app/**.o
	-rm -f usr_lib/**.o
	-rm -f $(KERNEL_HDD) $(KERNEL_ELF) $(OBJ)

.PHONY:all
all:
	@make -C . super
