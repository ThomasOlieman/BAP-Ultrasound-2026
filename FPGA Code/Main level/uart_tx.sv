module uart_tx #(
    parameter int CLKS_PER_BIT = 434
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] tx_data,
    input  logic       tx_valid,
    output logic       tx_ready,
    output logic       tx
);
    typedef enum logic [1:0] {
        S_IDLE, S_START, S_DATA, S_STOP
    } state_t;

    state_t      state;
    logic [15:0] clk_count;
    logic [2:0]  bit_index;
    logic [7:0]  data_reg;

    assign tx_ready = (state == S_IDLE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            clk_count <= 0;
            bit_index <= 0;
            data_reg  <= 8'h00;
            tx        <= 1'b1;
        end else begin
            case (state)
                S_IDLE: begin
                    tx        <= 1'b1;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (tx_valid) begin
                        data_reg <= tx_data;
                        state    <= S_START;
                    end
                end
                S_START: begin
                    tx <= 1'b0;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 16'd1;
                    end else begin
                        clk_count <= 0;
                        state     <= S_DATA;
                    end
                end
                S_DATA: begin
                    tx <= data_reg[bit_index];
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 16'd1;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 3'd1;
                        end else begin
                            bit_index <= 0;
                            state     <= S_STOP;
                        end
                    end
                end
                S_STOP: begin
                    tx <= 1'b1;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 16'd1;
                    end else begin
                        clk_count <= 0;
                        state     <= S_IDLE;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
