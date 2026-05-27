SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

WLED_VERSION ?= 16.0.0
WLED_DIR := $(CURDIR)/wled-src
VENV_DIR ?= $(CURDIR)/.venv
VENV_BIN := $(VENV_DIR)/bin
VENV_PYTHON := $(VENV_BIN)/python
PLATFORMIO := $(VENV_BIN)/platformio
PIO := $(PLATFORMIO)
ESPTOOL := $(VENV_BIN)/esptool

BUILD_OUTPUT_ROOT := $(CURDIR)/build_output
BUILD_BIN_DIR := $(BUILD_OUTPUT_ROOT)/build
FIRMWARE_OUTPUT_DIR := $(BUILD_OUTPUT_ROOT)/firmware

OUTPUT_FILENAME := WLED_$(WLED_VERSION)_sp530e.bin
OUTPUT_PATH := $(FIRMWARE_OUTPUT_DIR)/$(OUTPUT_FILENAME)
PIO_BUILD_DIR := $(WLED_DIR)/.pio/build/sp530e

OVERRIDE_FILE := $(CURDIR)/platformio_override.ini

.PHONY: help venv install-tools prepare build firmware clean

help:
	@echo "Local custom WLED build (ESP32-C3)"
	@echo
	@echo "Usage:"
	@echo "  make firmware WLED_VERSION=16.0.0"
	@echo
	@echo "Available targets:"
	@echo "  venv     - Create a local Python virtual environment"
	@echo "  install-tools - Install/upgrade pip, platformio and esptool in venv"
	@echo "  prepare  - Download and prepare WLED sources (skip if already present)"
	@echo "  build    - Compile env:sp530e and copy generated .bin files into build_output/build"
	@echo "  firmware - Merge final binary into build_output/firmware/"
	@echo "  clean    - Remove venv, downloaded sources, and generated output files"

venv: $(VENV_PYTHON)

$(VENV_PYTHON):
	python3 -m venv "$(VENV_DIR)"

install-tools: $(ESPTOOL) $(PLATFORMIO)

$(ESPTOOL) $(PLATFORMIO): | $(VENV_PYTHON)
	"$(VENV_PYTHON)" -m pip install --upgrade pip
	"$(VENV_PYTHON)" -m pip install --upgrade platformio esptool

prepare: $(WLED_DIR)/platformio.ini

$(WLED_DIR)/platformio.ini:
	rm -rf "$(WLED_DIR)"
	mkdir -p "$(WLED_DIR)"
	wget "https://codeload.github.com/wled/WLED/tar.gz/refs/tags/v$(WLED_VERSION)" -O "/tmp/wled.tar.gz"
	tar -xzf "/tmp/wled.tar.gz" --strip-components=1 -C "$(WLED_DIR)"
	rm -f "/tmp/wled.tar.gz"
	[[ -f "$(OVERRIDE_FILE)" ]] || { echo "Error: $(OVERRIDE_FILE) not found"; exit 1; }
	cp "$(OVERRIDE_FILE)" "$(WLED_DIR)/platformio_override.ini"
	echo "Copied override file to $(WLED_DIR)/platformio_override.ini"

build: install-tools prepare $(BUILD_BIN_DIR)/sp530e.bin

$(BUILD_BIN_DIR)/sp530e.bin: prepare
	[[ -f "$(OVERRIDE_FILE)" ]] || { echo "Error: $(OVERRIDE_FILE) not found"; exit 1; }
	cp "$(OVERRIDE_FILE)" "$(WLED_DIR)/platformio_override.ini"
	echo "Copied override file to $(WLED_DIR)/platformio_override.ini"
	cd "$(WLED_DIR)" && ("$(PIO)" run --environment sp530e --verbose || "$(PIO)" run --environment sp530e --verbose)
	mkdir -p "$(BUILD_BIN_DIR)"
	cp "$(WLED_DIR)/build_output/firmware/sp530e.bin" "$(BUILD_BIN_DIR)/sp530e.bin"
	echo "Copied build .bin files to $(BUILD_BIN_DIR)"

firmware: $(OUTPUT_PATH)

$(OUTPUT_PATH): $(BUILD_BIN_DIR)/sp530e.bin
	BUILDDIR="$(PIO_BUILD_DIR)"; \
	BOOT_APP0="$$(find ~/.platformio -name boot_app0.bin | head -1)"; \
	[[ -n "$$BOOT_APP0" ]] || { echo "Error: boot_app0.bin not found under ~/.platformio"; exit 1; }; \
	mkdir -p "$(FIRMWARE_OUTPUT_DIR)"; \
	"$(ESPTOOL)" --chip esp32c3 merge-bin \
		--pad-to-size 4MB \
		-o "$(OUTPUT_PATH)" \
		0x0 "$$BUILDDIR/bootloader.bin" \
		0x8000 "$$BUILDDIR/partitions.bin" \
		0xe000 "$$BOOT_APP0" \
		0x10000 "$(BUILD_BIN_DIR)/sp530e.bin"
	@echo "Done: $(OUTPUT_PATH)"

clean:
	rm -rf "$(VENV_DIR)" "$(WLED_DIR)" "$(BUILD_OUTPUT_ROOT)"
