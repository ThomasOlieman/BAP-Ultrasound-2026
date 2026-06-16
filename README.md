# Ultrasound Front-End Controller (FPGA)
 
SystemVerilog source for the FPGA controller of a CMUT ultrasound front-end, developed for the BSc Graduation Project *Design and Implementation of a CMUT Ultrasound Front-End PCB for a Wearable Ultrasound Demonstrator* at Delft University of Technology (2026).

## Repository layout
 
```
FPGA Code/
  Main level/
    main_fsm.sv
    top.sv
    uart_rx.sv
    uart_tx.sv
  Shape Sensing placeholder/
    fsm1_stub.sv
    mem_fsm1.sv
  Ultrasound level/
    adc_sampler.sv
    hv_pulser2cycles.sv
    mux_controller.sv
    ultrasound_top_withADC.sv
README.md
```

 ## Authors 
 
Thomas Olieman and Jurre Steenwijk — Ultrasound subgroup.
Supervisor: dr. ir. M. A. P. Pertijs. Daily supervisor: Msc I. Bellouki.
Delft University of Technology, 2026.
 
## Related
 
Full thesis: *Design and Implementation of a CMUT Ultrasound Front-End PCB for a Wearable Ultrasound Demonstrator*.
