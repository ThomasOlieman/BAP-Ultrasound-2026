
// Placeholder for the real FSM1

module fsm1_stub (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    output logic        finished,
    output logic        we,
    output logic [2:0]  waddr,
    output logic [15:0] wdata
);
    typedef enum logic [1:0] { S_IDLE, S_WRITE, S_DONE } state_t;

    state_t     state;
    logic [3:0] count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            count    <= 0;
            we       <= 1'b0;
            waddr    <= 3'd0;
            wdata    <= 16'd0;
            finished <= 1'b0;
        end else begin
            we       <= 1'b0;
            finished <= 1'b0;
            case (state)
                S_IDLE: begin
                    count <= 0;
                    if (start) state <= S_WRITE;
                end
                S_WRITE: begin
                    we    <= 1'b1;
                    waddr <= count[2:0];
                    wdata <= {13'b0, count[2:0]};
                    if (count == 4'd7) begin
                        state <= S_DONE;
                    end else begin
                        count <= count + 4'd1;
                    end
                end
                S_DONE: begin
                    finished <= 1'b1;
                    state    <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
