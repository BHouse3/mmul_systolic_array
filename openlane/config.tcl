set ::env(DESIGN_NAME) top_hardened
set ::env(VERILOG_FILES) [glob $::env(DESIGN_DIR)/src/*.v]
set ::env(CLOCK_PORT) "clk"
set ::env(CLOCK_NET) "clk"
set ::env(CLOCK_PERIOD) "10.0"
set ::env(MAX_FANOUT_CONSTRAINT) 10
set ::env(FP_SIZING) relative
#set ::env(DIE_AREA) "0 0 300 300"
set ::env(FP_CORE_UTIL) 30
set ::env(PL_TARGET_DENSITY) 0.55
set ::env(GLB_RT_MAXLAYER) 5
set ::env(MAGIC_DRC_USE_GDS) 1
