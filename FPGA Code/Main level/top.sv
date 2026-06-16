

module top #(
    parameter int CLKS_PER_BIT = 434   // 50 MHz / 115200 baud = 434 (used to speed up testbench simulation time)
)(
    // System
    input  logic        FPGA_CLK1_50,
    input  logic        KEY0,
    output logic [3:0]  LED,

    // UART to CP2102
    input  logic        GPIO_0_RX,
    output logic        GPIO_0_TX,

    // TX TMUX9616
    input  logic        M1_DOUT,
    output logic        M1_DIN,
    output logic        M1_CLK_Mux,
    output logic        M1_LE,
    output logic        M1_CLR,

    // RX TMUX9616
    input  logic        M2_DOUT,
    output logic        M2_DIN,
    output logic        M2_CLK_Mux,
    output logic        M2_LE,
    output logic        M2_CLR,

    // MD1213 #1 (main pulser)
    output logic        P_INA1,
    output logic        P_INB1,
    output logic        P_OE1,

    // MD1213 #2 (damper)
    output logic        P_INA2,
    output logic        P_INB2,
    output logic        P_OE2,

    // ADC
    input  logic        ADC_OTR,
    input  logic [11:0] D,
    output logic        ADC_CLK
);
    logic clk;
    logic rst_n;
    assign clk   = FPGA_CLK1_50;
    assign rst_n = KEY0;

    // -- UART
    logic [7:0] rx_data;
    logic       rx_valid;
    logic [7:0] tx_data;
    logic       tx_valid;
    logic       tx_ready;

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
        .clk      (clk),
        .rst_n    (rst_n),
        .rx       (GPIO_0_RX),
        .rx_data  (rx_data),
        .rx_valid (rx_valid)
    );

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_data  (tx_data),
        .tx_valid (tx_valid),
        .tx_ready (tx_ready),
        .tx       (GPIO_0_TX)
    );

    //FSM1 + memory (still using the stub --> replace fsm1_stub later)
    // FSM1 samples are 16-bit        main_fsm sends each as 2 LE bytes
    logic        start_fsm1, finished_fsm1;
    logic        fsm1_we;
    logic [2:0]  fsm1_waddr;
    logic [15:0] fsm1_wdata;
    logic [2:0]  fsm1_raddr;
    logic [15:0] fsm1_rdata;

    fsm1_stub u_fsm1 (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start_fsm1),
        .finished (finished_fsm1),
        .we       (fsm1_we),
        .waddr    (fsm1_waddr),
        .wdata    (fsm1_wdata)
    );

    mem_fsm1 u_mem1 (
        .clk   (clk),
        .we    (fsm1_we),
        .waddr (fsm1_waddr),
        .wdata (fsm1_wdata),
        .raddr (fsm1_raddr),
        .rdata (fsm1_rdata)
    );

    // FSM2: ultrasound
    // buffer, exposes rd_addr / rd_data for main_fsm to read out.
    logic        start_fsm2, finished_fsm2;
    logic [7:0]  param_byte;
    logic [11:0] fsm2_raddr;
    logic [11:0] fsm2_rdata;

    ultrasound_top_withADC u_fsm2 (
        .clk         (clk),
        .rst         (~rst_n),         // Other code uses active-high reset
        .channel_sel (param_byte),     // [7:4] = TX element, [3:0] = RX element
        .start       (start_fsm2),
        .done        (finished_fsm2),

        .TX_DOUT     (M1_DOUT),
        .TX_DIN      (M1_DIN),
        .TX_CLK_Mux  (M1_CLK_Mux),
        .TX_LE       (M1_LE),
        .TX_CLR      (M1_CLR),

        .RX_DOUT     (M2_DOUT),
        .RX_DIN      (M2_DIN),
        .RX_CLK_Mux  (M2_CLK_Mux),
        .RX_LE       (M2_LE),
        .RX_CLR      (M2_CLR),

        .INA1        (P_INA1),
        .INB1        (P_INB1),
        .OE1         (P_OE1),
        .INA2        (P_INA2),
        .INB2        (P_INB2),
        .OE2         (P_OE2),

        .ADC_OTR     (ADC_OTR),
        .D           (D),
        .ADC_CLK     (ADC_CLK),

        .rd_addr     (fsm2_raddr),
        .rd_data     (fsm2_rdata)
    );

    //Main FSM
    logic [3:0] dbg_state;

    main_fsm u_main (
        .clk           (clk),
        .rst_n         (rst_n),
        .rx_data       (rx_data),
        .rx_valid      (rx_valid),
        .tx_data       (tx_data),
        .tx_valid      (tx_valid),
        .tx_ready      (tx_ready),
        .start_fsm1    (start_fsm1),
        .finished_fsm1 (finished_fsm1),
        .start_fsm2    (start_fsm2),
        .param_byte    (param_byte),
        .finished_fsm2 (finished_fsm2),
        .mem1_raddr    (fsm1_raddr),
        .mem1_rdata    (fsm1_rdata),
        .mem2_raddr    (fsm2_raddr),
        .mem2_rdata    (fsm2_rdata),
        .dbg_state     (dbg_state)
    );

    // temporary: LED[1:0] = dbg_state[1:0] to check ADC floating input value
    assign LED = {D[11], D[10], dbg_state[1:0]};
    // assign LED = dbg_state;


    // to suppress unused pins warning we got in Quartus:
    (* noprune *) logic [2:0] unused_inputs_q;
    always_ff @(posedge clk) begin
        unused_inputs_q <= {ADC_OTR, M2_DOUT, M1_DOUT};
    end
endmodule
