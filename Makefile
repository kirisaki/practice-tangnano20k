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

# ---- RTL ソース（*_tb.* は除外）----
RTL_GLOB      := $(wildcard *.v *.sv) $(wildcard rtl/*.v rtl/*.sv)
SRC_V         := $(filter-out %_tb.v %_tb.sv,$(RTL_GLOB))

# ---- Icarus (Simulation) ----
SIM_TB        ?= sim/tb_top.v
SIM_OUT       := $(BUILD_DIR)/sim.out
SIM_SRC       := $(SRC_V)

.PHONY: all sim run wave sram flash bit pnr json probe clean veryclean test

all: sram

# ===== Simulation =====
sim: $(SIM_OUT)

$(SIM_OUT): $(SIM_SRC) $(SIM_TB) | $(BUILD_DIR)
	@echo ">> Icarus build"
	@echo "   RTL: $(SIM_SRC)"
	@echo "   TB : $(SIM_TB)"
	iverilog -g2012 -DSIM -I . -I rtl -o $@ $(SIM_SRC) $(SIM_TB)

run: sim
	vvp $(SIM_OUT)

wave:
	gtkwave $(BUILD_DIR)/wave.vcd 2>/dev/null || true

test: run wave

# ===== Synthesis / PnR / Pack / Load =====
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
	$(RM) -r $(BUILD_DIR)/*.json $(BUILD_DIR)/*.fs $(BUILD_DIR)/sim.out $(BUILD_DIR)/wave.vcd 2>/dev/null || true

veryclean:
	$(RM) -r $(BUILD_DIR) 2>/dev/null || true
