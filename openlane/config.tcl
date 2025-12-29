set ::env(DESIGN_NAME) top_hardened
set ::env(VERILOG_FILES) [glob $::env(DESIGN_DIR)/src/*.v]
set ::env(CLOCK_PORT) "clk"
set ::env(CLOCK_NET) "clk"
set ::env(CLOCK_PERIOD) "8"
#set ::env(MAX_FANOUT_CONSTRAINT) 5
set ::env(SYNTH_BUFFERING) 1
set ::env(FP_SIZING) relative
set ::env(FP_CORE_UTIL) 50
set ::env(PL_TARGET_DENSITY) 0.55
set ::env(GLB_RT_MAXLAYER) 5
set ::env(MAGIC_DRC_USE_GDS) 1
set ::env(DIODE_INSERTION_STRATEGY) 6
set ::env(IO_PCT) 0
