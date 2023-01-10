# Configuration
Q ?= @
PLATFORM ?= simulator

# Verbose
ifeq ("$(origin V)", "command line")
  ifeq ($(V),1)
    Q=
  endif
endif

# Host detection
ifeq ($(PLATFORM),simulator)
  ifeq ($(OS),Windows_NT)
    HOST = windows
  else
    uname_s := $(shell uname -s)
    ifeq ($(uname_s),Darwin)
      HOST = macos
    else ifeq ($(uname_s),Linux)
      HOST = linux
    else
      $(error Your OS wasn't recognized, please manually define HOST. For instance, 'make HOST=windows' 'make HOST=linux' 'make HOST=macos')
    endif
  endif
endif

ifeq ($(PLATFORM),device)
  CC = arm-none-eabi-gcc
  CXX = arm-none-eabi-g++
  LINK_GC = 1
  LTO = 1
else
  SIMULATOR_PATH =
  LD_DYNAMIC_LOOKUP_FLAG = -Wl,-undefined,dynamic_lookup
  ifeq ($(HOST),windows)
    ifeq ($(OS),Windows_NT)
      MINGW_TOOLCHAIN_PREFIX=
    else
      MINGW_TOOLCHAIN_PREFIX=x86_64-w64-mingw32-
    endif
    CC = $(MINGW_TOOLCHAIN_PREFIX)gcc
    CXX = $(MINGW_TOOLCHAIN_PREFIX)g++
    GDB = $(MINGW_TOOLCHAIN_PREFIX)gdb --args
    EXE = exe
    LD_DYNAMIC_LOOKUP_FLAG = -Lepsilon_simulators/$(HOST) -lepsilon
  else ifeq ($(HOST),linux)
    CC = gcc
    CXX = g++
    GDB = gdb --args
    EXE = bin
  else
    CXX = clang++
    GDB = lldb --
    EXE = app
    SIMULATOR_PATH = /Contents/MacOS/Epsilon
  endif
  LINK_GC = 0
  LTO = 0
  SIMULATOR ?= epsilon_simulators/$(HOST)/epsilon.$(EXE)$(SIMULATOR_PATH)
endif

NWLINK = npx --yes -- nwlink@0.0.17
BUILD_DIR = output/$(PLATFORM)

define object_for
$(addprefix $(BUILD_DIR)/,$(addsuffix .o,$(basename $(1))))
endef

src = $(addprefix src/,\
  converter.cpp \
  input_field.cpp \
  main.cpp \
  store.cpp \
  view.cpp \
)

CXXFLAGS = -std=c++11 -fno-exceptions -Wno-nullability-completeness -Wall -ggdb
ifeq ($(PLATFORM),device)
CXXFLAGS += $(shell $(NWLINK) eadk-cflags)
CXXFLAGS += -Os -DPLATFORM_DEVICE=1
LDFLAGS = -Wl,--relocatable -nostartfiles --specs=nano.specs
# LDFLAGS += --specs=nosys.specs # Alternatively, use full-fledged newlib
else
# Only keep the header path from the eadk-cflags provided by nwlink
CXXFLAGS += $(shell $(NWLINK) eadk-cflags | sed -n -e 's/.*\(-I[^ ]*\).*/\1/p')
CXXFLAGS += -Iinclude/ -g -O0 -fPIC
LDFLAGS += -shared $(LD_DYNAMIC_LOOKUP_FLAG)
endif

ifeq ($(LINK_GC),1)
CXXFLAGS += -fdata-sections -ffunction-sections
LDFLAGS += -Wl,-e,main -Wl,-u,eadk_app_name -Wl,-u,eadk_app_icon -Wl,-u,eadk_api_level
LDFLAGS += -Wl,--gc-sections
endif

ifeq ($(LTO),1)
CXXFLAGS += -flto -fno-fat-lto-objects
CXXFLAGS += -fwhole-program
CXXFLAGS += -fvisibility=internal
LDFLAGS += -flinker-output=nolto-rel
endif

ifeq ($(PLATFORM),device)

.PHONY: build
build: $(BUILD_DIR)/app.nwa

.PHONY: check
check: $(BUILD_DIR)/app.bin

.PHONY: run
run: $(BUILD_DIR)/app.nwa
	@echo "INSTALL $<"
	$(Q) $(NWLINK) install-nwa $<

$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.nwa
	@echo "BIN     $@"
	$(Q) $(NWLINK) nwa-bin $< $@

$(BUILD_DIR)/%.elf: $(BUILD_DIR)/%.nwa
	@echo "ELF     $@"
	$(Q) $(NWLINK) nwa-elf $< $@

$(BUILD_DIR)/app.nwa: $(call object_for,$(src)) $(BUILD_DIR)/icon.o
	@echo "LD      $@"
	$(Q) $(CC) $(CXXFLAGS) $(LDFLAGS) $^ -o $@

else

$(SIMULATOR):
	@echo "UNZIP   $<"
	$(Q) unzip epsilon_simulators.zip
	chmod +x $(SIMULATOR)

.PHONY: build
build: $(BUILD_DIR)/app.nws

.PHONY: run
run: $(BUILD_DIR)/app.nws $(SIMULATOR)
	@echo "RUN     $<"
	$(Q) $(SIMULATOR) --nwb $<

.PHONY: debug
debug: $(BUILD_DIR)/app.nws $(SIMULATOR)
	@echo "DEBUG   $<"
	$(Q) $(GDB) $(SIMULATOR) --nwb $<

$(BUILD_DIR)/app.nws: $(call object_for,$(src)) $(SIMULATOR)
	@echo "LD      $@"
	$(Q) $(CC) $(CXXFLAGS) $(call object_for,$(src)) $(LDFLAGS) -o $@

endif

$(addprefix $(BUILD_DIR)/,%.o): %.cpp | $(BUILD_DIR)
	@echo "CC      $^"
	$(Q) $(CXX) $(CXXFLAGS) -c $^ -o $@

$(BUILD_DIR)/icon.o: src/icon.png
	@echo "ICON    $<"
	$(Q) $(NWLINK) png-icon-o $< $@

.PRECIOUS: $(BUILD_DIR)
$(BUILD_DIR):
	$(Q) mkdir -p $@/src

.PHONY: clean
clean:
	@echo "CLEAN"
	$(Q) rm -rf $(BUILD_DIR)
