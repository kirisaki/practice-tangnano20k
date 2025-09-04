TOP           ?= top
CST           ?= tangnano20k.cst
DEVICE        ?= GW2AR-LV18QN88C8/I7
PACK_DEVICE   ?= GW2A-18C
BOARD         ?= tangnano20k

OSSCAD        ?= $(HOME)/tools/oss-cad-suite
YOSYS         ?= $(OSSCAD)/bin/yosys
NEXTPNR       ?= $(OSSCAD)/bin/nextpnr-himbaechel
PACK          ?= $(OSSCAD)/bin/gowin_pack
OFL           ?= openFPGALoader

BUILD_DIR     := build
JSON          := $(BUILD_DIR)/$(TOP).json
PNRJSON       := $(BUILD_DIR)/pnr.json
BIT_FS        := $(BUILD_DIR)/$(TOP).fs

VOPTS         := --vopt family=GW2A-18C --vopt cst=$(CST)
BOARD_OPT     := $(if $(BOARD),-b $(BOARD),)

SRC_V         := $(filter-out %_tb.v %_tb.sv,$(wildcard *.v *.sv))

.PHONY: all sram flash bit pnr json probe clean veryclean

all: sram

json: $(JSON)
$(JSON): $(SRC_V) $(CST) | $(BUILD_DIR)
	$(YOSYS) -p "read_verilog -sv $(SRC_V); synth_gowin -family gw2a -top $(TOP) -json $@"

pnr: $(PNRJSON)
$(PNRJSON): $(JSON) $(CST) | $(BUILD_DIR)
	$(NEXTPNR) --json $(JSON) --device $(DEVICE) $(VOPTS) --write $(PNRJSON)

bit: $(BIT_FS)
$(BIT_FS): $(PNRJSON) | $(BUILD_DIR)
	$(PACK) -d $(PACK_DEVICE) -o $(BIT_FS) $(PNRJSON)

sram: bit
	$(OFL) $(BOARD_OPT) $(BIT_FS)

flash: bit
	$(OFL) $(BOARD_OPT) -f $(BIT_FS)

probe:
	$(OFL) --detect

$(BUILD_DIR):
	mkdir -p $@

clean:
	$(RM) -r $(BUILD_DIR)/*.json $(BUILD_DIR)/*.fs 2>/dev/null || true

veryclean:
	$(RM) -r $(BUILD_DIR) 2>/dev/null || true
