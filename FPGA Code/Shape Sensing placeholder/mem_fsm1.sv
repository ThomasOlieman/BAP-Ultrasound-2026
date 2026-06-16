
module mem_fsm1 (
    input  logic        clk,
    input  logic        we,
    input  logic [2:0]  waddr,
    input  logic [15:0] wdata,
    input  logic [2:0]  raddr,
    output logic [15:0] rdata
);
    logic [15:0] mem [0:7];

    always_ff @(posedge clk) begin
        if (we) mem[waddr] <= wdata;
        rdata <= mem[raddr];
    end
endmodule
