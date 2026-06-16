
module mux_controller (
    input  logic        clk,        // 50 MHz system clock
    input  logic        rst,

    //Control
    input  logic [3:0]  element_sel, // 4-bit element select (0-15)
    input  logic        start,       // Start trigger (rising edge detected)
    output logic        done,        // sone pulse

    //To mux on PCB
    input  logic        DOUT,        //Data out, unused
    output logic        DIN,         //Data to shift register
    output logic        CLK_Mux,     //Clock for shift register
    output logic        LE,          //Latch enable
    output logic        CLR          //Clear can be used to open all switches, unused

    // For testing:
    // output logic [15:0] shift_data,
    // output logic [2:0] state_debug,
    // output logic start_rise,
    // output logic clk_en,
    // output logic [4:0] settle_cnt
);

//10 MHz clock clk_en
    logic [2:0] clk_div_cnt;
    logic       clk_en;
    
always_ff @(posedge clk) begin
        if (rst) begin
            clk_div_cnt <= 3'd0;
            clk_en      <= 1'd0;
        end else if (clk_div_cnt == 3'd4) begin
            clk_div_cnt <= 3'd0;
            clk_en      <= 1'd1;
        end else begin
            clk_div_cnt <= clk_div_cnt + 3'd1;
            clk_en      <= 1'd0;
        end
    end

//convert 4 bit input to 16 bit one hot encoded data
    logic [15:0] one_hot_data;

    assign one_hot_data = 16'd1 << element_sel;

//FSM 
    typedef enum logic [2:0] {
        S_IDLE,
        S_SHIFT_DIN,
        S_SHIFT_CLK,
        S_LATCH_LOW,
        S_LATCH_HIGH,
        S_SETTLE,
        S_DONE
    } state_t;

    state_t state, next_state;

    // assign state_debug = state; 

    logic [3:0] bit_cnt;
    logic [4:0] settle_cnt;
    logic [15:0] shift_data;
    
    logic start_d;
    logic start_rise;

    always_ff @(posedge clk) begin
        if (rst)
            state <= S_IDLE;
        else if (clk_en)
            state <= next_state;
    end

    always_comb begin
        next_state = state;

        case (state)
            S_IDLE: begin
                if (start_rise)
                    next_state = S_SHIFT_DIN;
            end

            S_SHIFT_DIN: begin
                    next_state = S_SHIFT_CLK;
            end

            S_SHIFT_CLK: begin
                    if (bit_cnt == 4'd0) //all data clocked in, set LE low
                        next_state = S_LATCH_LOW;
                    else    //not all data clocked in, load new value on DIN
                        next_state = S_SHIFT_DIN;
                end

            S_LATCH_LOW: begin
                    next_state = S_LATCH_HIGH;
            end

            S_LATCH_HIGH: begin
                    next_state = S_SETTLE;
            end

            S_SETTLE: begin
                if (settle_cnt >= 5'd29) //wait 3 us for switch to settle
                    next_state = S_DONE;
            end

            S_DONE: begin
                next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

always_ff @(posedge clk) begin
    if (rst) begin
        start_d    <= 1'd0;
        start_rise <= 1'd0;

    end else begin

        start_d <= start;

        if (start && ~start_d && state == S_IDLE) //detect rising edge start signal if in IDLE
            start_rise <= 1'd1;

        else if (clk_en && state == S_IDLE)
            start_rise <= 1'd0;
    end
end

    always_ff @(posedge clk) begin
        if (rst) begin
            bit_cnt    <= 4'd15;
            settle_cnt <= 5'd0;
            shift_data <= 16'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    bit_cnt    <= 4'd15;
                    settle_cnt <= 5'd0;
                    if (start_rise)
                        shift_data <= one_hot_data;
                end

                S_SHIFT_CLK: begin
                    if (clk_en && bit_cnt != 4'd0)
                        bit_cnt <= bit_cnt - 4'd1;
                end

                S_SETTLE: begin
                    if (clk_en)
                        settle_cnt <= settle_cnt + 5'd1;
                end

                default: ;
            endcase
        end
    end

//Output DIN, CLK, LE, Done
    assign DIN = shift_data[bit_cnt] & (state == S_SHIFT_DIN || state == S_SHIFT_CLK);
    assign CLK_Mux = (state == S_SHIFT_CLK);
    assign LE = (state != S_LATCH_LOW);
    assign done = (state == S_DONE);

//Output CLR is not used
    assign CLR = 1'd0;

//Input DOUT is not used
    logic unused;
    assign unused = DOUT;

endmodule
