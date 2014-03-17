# Makefile for AutoQuad Flight Controller firmware
#
# ! Use of this makefile requires setup of a compatible development environment.
# ! For latest development recommendations, check here: http://autoquad.org/wiki/wiki/development/
# ! This file is ignored when building with CrossWorks Studio.
#
# All paths are relative to Makefile location
# Usage examples:
# 		make all											# default Release type builds .hex and .elf binaries
#		make all BUILD_TYPE=Debug					# build with compiler debugging flags/options enabled
#		make all BOARD_REV=1 INCR_BUILDNUM=0	# build for rev 1 (post Oct-2012) hardware, don't increment the buildnumber


# Include user-specific settings file, if any, in regular Makefile format.
# This file can set any default variable values you wish to override (all defaults are listed below).
# The .user file is not included with the source code distribution, so it will not be overwritten.
-include Makefile.user

# Defaults - modify here, on command line, or in Makefile.user
#
# Output folder name; Use 'Debug' to set debug compiler options;
BUILD_TYPE ?= Release
# Path to source files - no trailing slash
SRC_PATH ?= .
# Board version to build for (6)
BOARD_VER ?= 6
# Board revision to build for (0 = v6 initial release revision, 1 = v6 Oct. 2012 revision)
BOARD_REV ?= 0
# Specify a DIMU version number to enable DIMU support in AQ, zero to disable (eg. DIMU_VER=1.1)
DIMU_VER ?= 0
# Increment build number? (0|1)  This is automatically disabled for debug builds.
INCR_BUILDNUM ?= 1
# Use the single-folder source file organization from AQ repo? (0|1)
FLAT_SRC ?= 1
# Produced binaries file name prefix (version/revision/build/hardware info will be automatically appended)
BIN_NAME ?= aq
# Build debug version? (0|1; true by default if build_type contains the word "debug")
ifeq ($(findstring Debug, $(BUILD_TYPE)), Debug)
	DEBUG_BUILD ?= 1
else 
	DEBUG_BUILD ?= 0
endif
# Flashing interface (Linux only)
USB_DEVICE ?= /dev/ttyUSB0

# You may also use BIN_SUFFIX to append text 
# to generated bin file name after version string;
# BIN_SUFFIX = 


# System-specific folder paths and commands
#
# compiler base path
CC_PATH ?= /usr/share/crossworks_for_arm_2.3
#CC_PATH ?= C:/devel/gcc/crossworks_for_arm_2.3

# shell commands (Windows needs Cygwin or MSys)
EXE_AWK ?= gawk 
EXE_MV ?= mv 
EXE_MKDIR ?= mkdir -p
# Windows examples:
#EXE_AWK := C:/cygwin/bin/gawk
#EXE_MV := C:/cygwin/bin/mv
#EXE_MKDIR := mkdir

# Path to libraries/includes
# see "External libraries required by AQ" below
AQLIB_PATH ?= ..
#AQLIB_PATH = C:/devel/AQ/lib

# Where to put the built objects and binaries.
# A sub-folder is created along this path, named as the BUILD_TYPE (eg. build/Release).
#BUILD_PATH ?= .
BUILD_PATH ?= ../build

# Add preprocessor definitions here (eg. CC_VARS=-DCOMM_DISABLE_FLOW_CONTROL1 to disable flow control on USART 1)
CC_VARS ?=


# defaults end

#
## probably don't need to change anything below here ##
#

# build/object directory
OBJ_PATH = $(BUILD_PATH)/$(BUILD_TYPE)/obj
# bin file(s) output path
BIN_PATH = $(BUILD_PATH)/$(BUILD_TYPE)

# command to execute (later, if necessary) for increasing build number in buildnum.h
CMD_BUILDNUMBER = $(shell $(EXE_AWK) '$$2 ~ /BUILDNUMBER/{ $$NF=$$NF+1 } 1' $(SRC_PATH)/buildnum.h > $(SRC_PATH)/tmp_buildnum.h && $(EXE_MV) $(SRC_PATH)/tmp_buildnum.h $(SRC_PATH)/buildnum.h)

# get current revision and build numbers
FW_VER := $(shell $(EXE_AWK) 'BEGIN { FS = "[ \"]+" }$$2 ~ /FI(MR|RM)WARE_VERSION/{print $$3}' $(SRC_PATH)/getbuildnum.h)
REV_NUM := $(shell $(EXE_AWK) '$$2 ~ /REVISION/{print $$4}' $(SRC_PATH)/buildnum.h)
BUILD_NUM := $(shell $(EXE_AWK) '$$2 ~ /BUILDNUMBER/{print $$NF}' $(SRC_PATH)/buildnum.h)
ifeq ($(INCR_BUILDNUM), 1)
	BUILD_NUM := $(shell echo $$[$(BUILD_NUM)+1])
endif

# Resulting bin file names before extension
ifeq ($(DEBUG_BUILD), 1)
	# debug build gets a consistent name to simplify dev setup
	BIN_NAME := $(BIN_NAME)-debug
	INCR_BUILDNUM = 0
else
	BIN_NAME := $(BIN_NAME)v$(FW_VER).r$(REV_NUM).b$(BUILD_NUM)-rev$(BOARD_REV)
	ifneq ($(DIMU_VER), 0)
		BIN_NAME := $(BIN_NAME)-dimu$(DIMU_VER)
	endif
	ifdef BIN_SUFFIX
		BIN_NAME := $(BIN_NAME)-$(BIN_SUFFIX)
	endif
endif

# Compiler-specific paths
CC_BIN_PATH = $(CC_PATH)/gcc/arm-unknown-eabi/bin
CC_LIB_PATH = $(CC_PATH)/lib
CC_INC_PATH = $(CC_PATH)/include
CC = $(CC_BIN_PATH)/cc1
AS = $(CC_BIN_PATH)/as
LD = $(CC_BIN_PATH)/ld
OBJCP = $(CC_BIN_PATH)/objcopy

## External libraries required by AQ
# Generated MAVLink header files (https://github.com/AutoQuad/mavlink/tree/master/include)
MAVINC_PATH = $(AQLIB_PATH)/mavlink/include/autoquad
# Files from Crossworks SMT32 package: autoquad.ld (STM32f4.ld), STM32F40_41xxx.vec, STM32_Startup.s, & the /include folder
STMLIB_PATH = $(AQLIB_PATH)/STM32
# STM32F4 libs from ST (http://www.st.com/web/en/catalog/tools/PF257901)
STM32DRIVER_PATH = $(AQLIB_PATH)/STM32F4xx_DSP_StdPeriph_Lib_V1.3.0/Libraries/STM32F4xx_StdPeriph_Driver
STM32CMSIS_PATH = $(AQLIB_PATH)/STM32F4xx_DSP_StdPeriph_Lib_V1.3.0/Libraries/CMSIS

# all include flags for the compiler
CC_INCLUDES :=  -I$(SRC_PATH) -I$(STMLIB_PATH)/include -I$(STM32DRIVER_PATH)/inc -I$(STM32CMSIS_PATH)/Include -I$(MAVINC_PATH) -I$(CC_INC_PATH)

# compiler flags
CC_OPTS = -mcpu=cortex-m4 -mthumb -mlittle-endian -mfpu=fpv4-sp-d16 -mfloat-abi=hard -nostdinc -fsingle-precision-constant -Wall -finline-functions -Wdouble-promotion -std=c99 \
	-fno-dwarf2-cfi-asm -fno-builtin -ffunction-sections -fdata-sections -fno-common -fmessage-length=0 -quiet

# macro definitions to pass via compiler command line
#
CC_VARS += -D__ARM_ARCH_7EM__ -D__CROSSWORKS_ARM -D__ARM_ARCH_FPV4_SP_D16__ -D__TARGET_PROCESSOR=STM32F407VG -D__TARGET_F4XX= -DSTM32F4XX= -DSTM32F40_41xxx -D__FPU_PRESENT \
	-DARM_MATH_CM4 -D__THUMB -DNESTED_INTERRUPTS -DCTL_TASKING -DUSE_STDPERIPH_DRIVER
	
# set AQ hardware version and revision
CC_VARS += -DBOARD_VERSION=$(BOARD_VER) -DBOARD_REVISION=$(BOARD_REV)

# build AQ with specific digital IMU version, if specified (fall back to AIMU on v6 hardware)
ifneq ($(DIMU_VER), 0)
	CC_VARS += -DDIMU_VERSION=$(subst .,,$(DIMU_VER))
endif

# Additional target(s) to build based on conditionals
#
EXTRA_TARGETS =
ifeq ($(INCR_BUILDNUM), 1)
	EXTRA_TARGETS = BUILDNUMBER
endif

# build type flags/defs (debug vs. release)
# (exclude STARTUP_FROM_RESET in debug builds if using Rowley debugger)
ifeq ($(DEBUG_BUILD), 1)
	BT_CFLAGS = -DDEBUG -DUSE_FULL_ASSERT -O1 -ggdb -g2
	BT_CFLAGS += -DSTARTUP_FROM_RESET
else
	BT_CFLAGS = -DNDEBUG -DSTARTUP_FROM_RESET -O2
endif


# all compiler options
CFLAGS = $(CC_OPTS) $(CC_INCLUDES) $(CC_VARS) $(BT_CFLAGS)

# assembler options
AS_OPTS = --traditional-format -mcpu=cortex-m4 -mthumb -EL -mfpu=fpv4-sp-d16 -mfloat-abi=hard

# linker (ld) options
LINKER_OPTS = -ereset_handler --omagic -defsym=__do_debug_operation=__do_debug_operation_mempoll -u__do_debug_operation_mempoll -defsym=__vfprintf=__vfprintf_double_long_long -u__vfprintf_double_long_long \
	-defsym=__vfscanf=__vfscanf_double_long_long -u__vfscanf_double_long_long --fatal-warnings -EL --gc-sections -T$(STMLIB_PATH)/autoquad.ld -Map $(OBJ_PATH)/autoquad.map -u_vectors

# eabi linker libs
# ! These are proprietary Rowley libraries, approved for personal use with the AQ project (see http://forum.autoquad.org/viewtopic.php?f=31&t=44&start=50#p8476 )
EXTRA_LIB_FILES = libm_v7em_fpv4_sp_d16_hard_t_le_eabi.a libc_v7em_fpv4_sp_d16_hard_t_le_eabi.a libcpp_v7em_fpv4_sp_d16_hard_t_le_eabi.a \
	libdebugio_v7em_fpv4_sp_d16_hard_t_le_eabi.a libc_targetio_impl_v7em_fpv4_sp_d16_hard_t_le_eabi.a libc_user_libc_v7em_fpv4_sp_d16_hard_t_le_eabi.a

EXTRA_LIBS := $(addprefix $(CC_LIB_PATH)/, $(EXTRA_LIB_FILES))


# AQ code objects to create (correspond to .c source to compile)
AQ_OBJS := 1wire.o adc.o algebra.o analog.o aq_init.o aq_mavlink.o aq_timer.o \
	comm.o command.o compass.o config.o control.o \
	can.o canCalib.o canSensors.o canUart.o canOSD.o \
	d_imu.o digital.o esc32.o eeprom.o \
	ff.o filer.o flash.o fpu.o futaba.o \
	gimbal.o gps.o getbuildnum.o grhott.o hmc5983.o \
	imu.o util.o logger.o \
	main_ctl.o mlinkrx.o motors.o mpu6000.o ms5611.o \
	nav.o nav_ukf.o pid.o ppm.o pwm.o \
	radio.o rotations.o rcc.o rtc.o run.o \
	sdio.o serial.o signaling.o spektrum.o spi.o srcdkf.o supervisor.o \
	telemetry.o ublox.o \
	system_stm32f4xx.o STM32_Startup.o thumb_crt0.o

# CoOS
COOS_OBJS = arch.o core.o event.o flag.o kernelHeap.o mbox.o mm.o mutex.o port.o queue.o sem.o serviceReq.o task.o time.o timer.o utility.o

# USB functions/drivers
USB_OBJS = usb.o usb_bsp.o usb_core.o usb_dcd.o usb_dcd_int.o \
	usbd_core.o  usbd_desc.o  usbd_ioreq.o  usbd_req.o usbd_storage_msd.o \
	usbd_cdc_msc_core.o usbd_msc_bot.o usbd_msc_data.o usbd_msc_scsi.o
#  usb_hcd.o usb_hcd_int.o

# STM32 drivers from STM32F4xx_StdPeriph_Driver/src/
STM32_SYS_OBJ_FILES =  misc.o stm32f4xx_adc.o stm32f4xx_can.o stm32f4xx_dma.o stm32f4xx_exti.o stm32f4xx_flash.o stm32f4xx_gpio.o stm32f4xx_hash.o stm32f4xx_hash_md5.o \
	stm32f4xx_pwr.o stm32f4xx_rcc.o stm32f4xx_rtc.o stm32f4xx_sdio.o stm32f4xx_spi.o stm32f4xx_syscfg.o stm32f4xx_tim.o stm32f4xx_usart.o
STM32_SYS_OBJS := $(addprefix STM32SYS/, $(STM32_SYS_OBJ_FILES))

# ARM drivers from CMSIS/DSP_Lib/Source/
DSPLIB_OBJ_FILES = BasicMathFunctions/arm_scale_f32.o \
	SupportFunctions/arm_fill_f32.o SupportFunctions/arm_copy_f32.o \
	MatrixFunctions/arm_mat_init_f32.o MatrixFunctions/arm_mat_inverse_f32.o MatrixFunctions/arm_mat_trans_f32.o \
	MatrixFunctions/arm_mat_mult_f32.o MatrixFunctions/arm_mat_add_f32.o MatrixFunctions/arm_mat_sub_f32.o \
	StatisticsFunctions/arm_mean_f32.o StatisticsFunctions/arm_std_f32.o
DSPLIB_OBJS := $(addprefix STM32DSPLIB/, $(DSPLIB_OBJ_FILES))


# all objects
C_OBJECTS := $(addprefix $(OBJ_PATH)/, $(AQ_OBJS) $(STM32_SYS_OBJS) $(DSPLIB_OBJS) $(COOS_OBJS) $(USB_OBJS))

# dependency files generated by previous make runs
DEPS := $(C_OBJECTS:.o=.d)


#
## Target definitions
#

.PHONY: all clean

all: CREATE_BUILD_FOLDER $(EXTRA_TARGETS) $(BIN_PATH)/$(BIN_NAME).hex

clean:
	-rm -fr $(OBJ_PATH)
#	rm -f $(BIN_PATH)/*.*

# include auto-generated depenency targets
-include $(DEPS)

$(OBJ_PATH)/%.o: $(SRC_PATH)/%.c
	@echo "## Compiling $< -> $@ ##"
	$(CC) $(CFLAGS) -MD $(basename $@).d -MQ $@ $< -o $(basename $@).lst
	@echo "## Assembling --> $@ ##"
	$(AS) $(AS_OPTS) $(basename $@).lst -o $@
	@rm -f $(basename $@).lst

$(OBJ_PATH)/STM32SYS/%.o: $(STM32DRIVER_PATH)/src/%.c
	@echo "## Compiling $< -> $@ ##"
	$(CC) $(CFLAGS) -MD $(basename $@).d -MQ $@ $< -o $(basename $@).lst
	@echo "## Assembling --> $@ ##"
	$(AS) $(AS_OPTS) $(basename $@).lst -o $@
	@rm -f $(basename $@).lst

$(OBJ_PATH)/STM32DSPLIB/%.o: $(STM32CMSIS_PATH)/DSP_Lib/Source/%.c
	-$(EXE_MKDIR) $(@D)
	@echo "## Compiling $< -> $@ ##"
	$(CC) $(CFLAGS) -MD $(basename $@).d -MQ $@ $< -o $(basename $@).lst
	@echo "## Assembling --> $@ ##"
	$(AS) $(AS_OPTS) $(basename $@).lst -o $@
	@rm -f $(basename $@).lst

$(OBJ_PATH)/STM32_Startup.o: $(STMLIB_PATH)/STM32_Startup.s
	@echo "## Compiling $< -> $@ ##"
	$(CC) $(CFLAGS) -MD $(basename $@).d -MQ $@ -E -lang-asm $< -o $(basename $@).lst
	@echo "## Assembling --> $@ ##"
	$(AS) $(AS_OPTS) -gdwarf-2 $(basename $@).lst -o $@
	@rm -f $(basename $@).lst

$(OBJ_PATH)/thumb_crt0.o: $(SRC_PATH)/thumb_crt0.s
	@echo "## Compiling $< -> $@ ##"
	$(CC) $(CFLAGS) -MD $(basename $@).d -MQ $@ -E -lang-asm $< -o $(basename $@).lst
	@echo "## Assembling --> $@ ##"
	$(AS) $(AS_OPTS) -gdwarf-2 $(basename $@).lst -o $@
	@rm -f $(basename $@).lst

$(BIN_PATH)/$(BIN_NAME).elf: $(C_OBJECTS)
	@echo "## Linking --> $@ ##"
	$(LD) -X $(LINKER_OPTS) -o $@ --start-group $(C_OBJECTS) $(EXTRA_LIBS) --end-group

$(BIN_PATH)/$(BIN_NAME).bin: $(BIN_PATH)/$(BIN_NAME).elf
	@echo "## Objcopy $< --> $@ ##"
	$(OBJCP) -O binary $< $@

$(BIN_PATH)/$(BIN_NAME).hex: $(BIN_PATH)/$(BIN_NAME).elf
	@echo "## Objcopy $< --> $@ ##"
	$(OBJCP) -O ihex $< $@

CREATE_BUILD_FOLDER :
	@echo "Creating Build folders if necessary"
	-$(EXE_MKDIR) $(OBJ_PATH)
	-$(EXE_MKDIR) $(OBJ_PATH)/STM32SYS
	-$(EXE_MKDIR) $(OBJ_PATH)/STM32DSPLIB

BUILDNUMBER :
	@echo "Incrementing Build Number"
	$(CMD_BUILDNUMBER)

## Flash-Loader (Linux only) 			##
## Requires AQ ground tools sources	##
$(SRC_PATH)/../ground/loader: $(SRC_PATH)/../ground/loader.c
	(cd $(SRC_PATH)/../ground/ ; make loader)

flash: $(SRC_PATH)/../ground/loader
	$(SRC_PATH)/../ground/loader -p $(USB_DEVICE) -b 115200 -f $(BIN_PATH)/$(BIN_NAME).hex
