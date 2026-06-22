SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

WLED_VERSION ?= 16.0.0
WLED_DIR := $(CURDIR)/wled-src
VENV_DIR ?= $(CURDIR)/.venv
VENV_BIN := $(VENV_DIR)/bin
VENV_PYTHON := $(VENV_BIN)/python
PLATFORMIO := $(VENV_BIN)/platformio
PIO := $(PLATFORMIO)

BUILD_OUTPUT_ROOT := $(CURDIR)/build_output

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
	@echo "  build    - Compile builds and copy generated app .bin into build_output/build"
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
	sed -i 's/16.0.0/16.0.0-custom1/g' wled-src/package.json

build: install-tools prepare 
	cp "$(OVERRIDE_FILE)" "$(WLED_DIR)/platformio_override.ini"
	echo "Copied override file to $(WLED_DIR)/platformio_override.ini"

	cd "$(WLED_DIR)" && "$(PIO)" run --target clean
	cd "$(WLED_DIR)" && "$(PIO)" run
	
	mkdir -p "$(BUILD_OUTPUT_ROOT)"
	cp "$(WLED_DIR)/build_output/release/"* "$(BUILD_OUTPUT_ROOT)/"
	echo "Copied build .bin files to $(BUILD_OUTPUT_ROOT)"
	find "$(BUILD_OUTPUT_ROOT)/" -type f

clean:
	rm -rf "$(VENV_DIR)" "$(WLED_DIR)" "$(BUILD_OUTPUT_ROOT)"
