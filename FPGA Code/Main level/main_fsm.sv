

module main_fsm (
    input  logic        clk,
    input  logic        rst_n,
    // UART RX
    input  logic [7:0]  rx_data,
    input  logic        rx_valid,
    // UART TX
    output logic [7:0]  tx_data,
    output logic        tx_valid,
    input  logic        tx_ready,
    // FSM1 control
    output logic        start_fsm1,
    input  logic        finished_fsm1,
    // FSM2 control
    output logic        start_fsm2,
    output logic [7:0]  param_byte,
    input  logic        finished_fsm2,
    // FSM1 memory
    output logic [2:0]  mem1_raddr,
    input  logic [15:0] mem1_rdata,
    // FSM2 memory
    output logic [11:0] mem2_raddr,
    input  logic [11:0] mem2_rdata,
    // Debug
    output logic [3:0]  dbg_state
);
    typedef enum logic [3:0] {
        S_IDLE          = 4'd0,
        S_RUN_FSM1      = 4'd1,
        S_RUN_FSM2      = 4'd2,
        S_TX_FLAG       = 4'd3,
        S_TX_LEN_LO     = 4'd4,
        S_TX_LEN_HI     = 4'd5,
        // FSM1 path
        S_FSM1_LOAD     = 4'd6,    // assert raddr (= pair_idx[2:0])
        S_FSM1_LATCH    = 4'd7,    // latch sample_A from mem1_rdata
        S_FSM1_B0       = 4'd8,    // send sample_A[7:0]
        S_FSM1_B1       = 4'd9,    // send sample_A[15:8]; next sample or FSM2
        // FSM2 path
        S_PACK_REQ_A    = 4'd10,
        S_PACK_REQ_B    = 4'd11,
        S_PACK_LATCH_B  = 4'd12,
        S_PACK_B0       = 4'd13,
        S_PACK_B1       = 4'd14,
        S_PACK_B2       = 4'd15
    } state_t;

    state_t      state;
    logic [7:0]  trigger_byte;
    logic        fsm1_was_run;
    logic        region_is_fsm2;  // 0 = FSM1 region, 1 = FSM2 region
    logic [10:0] pair_idx;        // FSM1: sample index [2:0] and FSM2: pair [11:0] (other not needed for FSM1)
    logic [15:0] sample_A, sample_B;

    assign param_byte = trigger_byte;
    assign dbg_state  = state;



    logic sub_idx;
    always_comb begin
        unique case (state)
            S_PACK_REQ_A: sub_idx = 1'b0;
            S_PACK_REQ_B: sub_idx = 1'b1;
            default:      sub_idx = 1'b1;
        endcase
    end
    assign mem1_raddr = pair_idx[2:0];
    assign mem2_raddr = {pair_idx[10:0], sub_idx};

    // 12-bit mem2_rdata is extended with 0s to match the 16-bit sample registers
    logic [15:0] mem_rdata_mux;
    assign mem_rdata_mux = region_is_fsm2 ? {4'b0, mem2_rdata} : mem1_rdata;

    // TX byte selection
    // FSM1: 16 bytes (8 samples * 2 bytes)
    // FSM2: 1224 bytes  (408 pairs * 3 bytes)
    logic [15:0] payload_len;
    assign payload_len = fsm1_was_run ? 16'd1240 : 16'd1224;

    always_comb begin
        tx_data  = 8'h00;
        tx_valid = 1'b0;
        unique case (state)
            S_TX_FLAG:   begin tx_data = {7'b0, fsm1_was_run};            tx_valid = 1'b1; end
            S_TX_LEN_LO: begin tx_data = payload_len[7:0];                tx_valid = 1'b1; end
            S_TX_LEN_HI: begin tx_data = payload_len[15:8];               tx_valid = 1'b1; end
            // FSM1 byte states
            S_FSM1_B0:   begin tx_data = sample_A[7:0];                   tx_valid = 1'b1; end
            S_FSM1_B1:   begin tx_data = sample_A[15:8];                  tx_valid = 1'b1; end
            // FSM2 byte states
            S_PACK_B0:   begin tx_data = sample_A[7:0];                   tx_valid = 1'b1; end
            S_PACK_B1:   begin tx_data = {sample_B[3:0], sample_A[11:8]}; tx_valid = 1'b1; end
            S_PACK_B2:   begin tx_data = sample_B[11:4];                  tx_valid = 1'b1; end
            default: ;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= S_IDLE;
            trigger_byte   <= 8'h00;
            fsm1_was_run   <= 1'b0;
            region_is_fsm2 <= 1'b0;
            pair_idx       <= 11'd0;
            sample_A       <= 16'd0;
            sample_B       <= 16'd0;
            start_fsm1     <= 1'b0;
            start_fsm2     <= 1'b0;
        end else begin
            start_fsm1 <= 1'b0;
            start_fsm2 <= 1'b0;
            case (state)
                S_IDLE: begin
                    if (rx_valid) begin
                        trigger_byte <= rx_data;
                        fsm1_was_run <= (rx_data == 8'h00);
                        if (rx_data == 8'h00) begin
                            start_fsm1 <= 1'b1;
                            state      <= S_RUN_FSM1;
                        end else begin
                            start_fsm2 <= 1'b1;
                            state      <= S_RUN_FSM2;
                        end
                    end
                end
                S_RUN_FSM1: begin
                    if (finished_fsm1) begin
                        start_fsm2 <= 1'b1;
                        state      <= S_RUN_FSM2;
                    end
                end
                S_RUN_FSM2: begin
                    if (finished_fsm2) state <= S_TX_FLAG;
                end
                S_TX_FLAG: begin
                    if (tx_ready) state <= S_TX_LEN_LO;
                end
                S_TX_LEN_LO: begin
                    if (tx_ready) state <= S_TX_LEN_HI;
                end
                S_TX_LEN_HI: begin
                    if (tx_ready) begin
                        pair_idx <= 11'd0;
                        if (fsm1_was_run) begin
                            region_is_fsm2 <= 1'b0;
                            state          <= S_FSM1_LOAD;
                        end else begin
                            region_is_fsm2 <= 1'b1;
                            state          <= S_PACK_REQ_A;
                        end
                    end
                end
                //FSM1 packing (16-bit --> 2 bytes per sample)
                S_FSM1_LOAD: begin
                    state <= S_FSM1_LATCH;
                end
                S_FSM1_LATCH: begin
                    sample_A <= mem_rdata_mux;
                    state    <= S_FSM1_B0;
                end
                S_FSM1_B0: begin
                    if (tx_ready) state <= S_FSM1_B1;
                end
                S_FSM1_B1: begin
                    if (tx_ready) begin
                        if (pair_idx == 11'd7) begin
                            // Last FSM1 sample sent--> move on to FSM2 region.
                            region_is_fsm2 <= 1'b1;
                            pair_idx       <= 11'd0;
                            state          <= S_PACK_REQ_A;
                        end else begin
                            pair_idx <= pair_idx + 11'd1;
                            state    <= S_FSM1_LOAD;
                        end
                    end
                end
                // FSM2 packing (12-bit --> 3 bytes per 2-sample pair)
                S_PACK_REQ_A: begin
                    state <= S_PACK_REQ_B;
                end
                S_PACK_REQ_B: begin
                    sample_A <= mem_rdata_mux;
                    state    <= S_PACK_LATCH_B;
                end
                S_PACK_LATCH_B: begin
                    sample_B <= mem_rdata_mux;
                    state    <= S_PACK_B0;
                end
                S_PACK_B0: begin
                    if (tx_ready) state <= S_PACK_B1;
                end
                S_PACK_B1: begin
                    if (tx_ready) state <= S_PACK_B2;
                end
                S_PACK_B2: begin
                    if (tx_ready) begin
                        if (pair_idx == 11'd407) begin
                            // finished FSM2 (and the whole packet)
                            state <= S_IDLE;
                        end else begin
                            pair_idx <= pair_idx + 11'd1;
                            state    <= S_PACK_REQ_A;
                        end
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
