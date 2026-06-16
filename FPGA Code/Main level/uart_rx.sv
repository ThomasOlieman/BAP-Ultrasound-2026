module uart_rx #(
    parameter int CLKS_PER_BIT = 434
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx,
    output logic [7:0] rx_data,
    output logic       rx_valid
);
    typedef enum logic [2:0] {
        S_IDLE, S_START, S_DATA, S_STOP, S_CLEANUP
    } state_t;

    state_t      state;
    logic [15:0] clk_count;
    logic [2:0]  bit_index;
    logic [7:0]  data_reg;
    logic        rx_sync_0, rx_sync_1;

    // Two-flop synchronizer for the asynchronous RX line
    always_ff @(posedge clk) begin
        rx_sync_0 <= rx;
        rx_sync_1 <= rx_sync_0;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            clk_count <= 0;
            bit_index <= 0;
            data_reg  <= 8'h00;
            rx_data   <= 8'h00;
            rx_valid  <= 1'b0;
        end else begin
            rx_valid <= 1'b0;
            case (state)
                S_IDLE: begin
                    clk_count <= 0;
                    bit_index <= 0;
                    if (rx_sync_1 == 1'b0) state <= S_START;
                end
                S_START: begin
                    if (clk_count == (CLKS_PER_BIT - 1) / 2) begin
                        if (rx_sync_1 == 1'b0) begin
                            clk_count <= 0;
                            state     <= S_DATA;
                        end else begin
                            state <= S_IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end
                S_DATA: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 16'd1;
                    end else begin
                        clk_count           <= 0;
                        data_reg[bit_index] <= rx_sync_1;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 3'd1;
                        end else begin
                            bit_index <= 0;
                            state     <= S_STOP;
                        end
                    end
                end
                S_STOP: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 16'd1;
                    end else begin
                        rx_data   <= data_reg;
                        rx_valid  <= 1'b1;
                        clk_count <= 0;
                        state     <= S_CLEANUP;
                    end
                end
                S_CLEANUP: state <= S_IDLE;
                default:   state <= S_IDLE;
            endcase
        end
    end
endmodule
