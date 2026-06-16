module hv_pulser2cycles (

    input  logic clk,       // 50 MHz system clock
    input  logic rst,       

    // start/done interface
    input  logic start,     // Start trigger
    output logic done,      // Done pulse

    // MD1213 #1 outputs (main pulser)
    output logic INA1,
    output logic INB1,
    output logic OE1,

    // MD1213 #2 outputs (damper)
    output logic INA2,
    output logic INB2,
    output logic OE2
);


    typedef enum logic [3:0] {
        S_IDLE,
        S_C1_PMOS_ON,
        S_C1_DEAD_1,
        S_C1_NMOS_ON,
        S_C1_DEAD_2,
        S_C2_PMOS_ON,
        S_C2_DEAD_1,
        S_C2_NMOS_ON,
        S_C2_DEAD_2,
        S_DAMP_PMOS_ON,
        S_DAMP_DEAD,
        S_DAMP_NMOS_ON,
        S_DAMP_OFF,
        S_DONE
    } state_t;

    state_t state, next_state;


// rising edge detection
    logic start_d;
    logic start_rise;

    always_ff @(posedge clk) begin
        if (rst) begin
            start_d    <= 1'b0;
            start_rise <= 1'b0;
        end else begin
            start_d <= start;

            if (start && ~start_d && state == S_IDLE)
                start_rise <= 1'b1;
            else if (start_rise)
                start_rise <= 1'b0;
        end
    end


    always_ff @(posedge clk) begin
        if (rst)
            state <= S_IDLE;
        else
            state <= next_state;
    end

//Cycle counter
    logic [3:0] cy_cnt;

    always_ff @(posedge clk) begin
        if (rst)
            cy_cnt <= 4'd0;
        else if (state != next_state)
            cy_cnt <= 4'd0;
        else
            cy_cnt <= cy_cnt + 4'd1;
    end


    always_comb begin
        next_state = state;

        case (state)
            S_IDLE: begin
                if (start_rise)
                    next_state = S_C1_PMOS_ON;
            end

            S_C1_PMOS_ON: begin             // 6 cycles = 120 ns
                if (cy_cnt == 4'd5)
                    next_state = S_C1_DEAD_1;
            end

            S_C1_DEAD_1: begin              // 3 cycles = 60 ns
                if (cy_cnt == 4'd2)
                    next_state = S_C1_NMOS_ON;
            end

            S_C1_NMOS_ON: begin             // 6 cycles = 120 ns
                if (cy_cnt == 4'd5)
                    next_state = S_C1_DEAD_2;
            end

            S_C1_DEAD_2: begin              // 3 cycles = 60 ns
                if (cy_cnt == 4'd2)
                    next_state = S_C2_PMOS_ON;
            end

            S_C2_PMOS_ON: begin             // 6 cycles = 120 ns
                if (cy_cnt == 4'd5)
                    next_state = S_C2_DEAD_1;
            end

            S_C2_DEAD_1: begin              // 3 cycles = 60 ns
                if (cy_cnt == 4'd2)
                    next_state = S_C2_NMOS_ON;
            end

            S_C2_NMOS_ON: begin             // 6 cycles = 120 ns
                if (cy_cnt == 4'd5)
                    next_state = S_C2_DEAD_2;
            end

            S_C2_DEAD_2: begin              // 3 cycles = 60 ns
                if (cy_cnt == 4'd2)
                    next_state = S_DAMP_PMOS_ON;
            end

            S_DAMP_PMOS_ON: begin           // 3 cycles = 60 ns
                if (cy_cnt == 4'd2)
                    next_state = S_DAMP_DEAD;
            end
 
            S_DAMP_DEAD: begin              // 3 cycles = 60 ns
                if (cy_cnt == 4'd1)
                    next_state = S_DAMP_NMOS_ON;
            end
 
            S_DAMP_NMOS_ON: begin           // 3 cycles = 60 ns, NMOS damp
                if (cy_cnt == 4'd2)
                    next_state = S_DAMP_OFF;
            end

            S_DAMP_OFF: begin               // 1 cycle = 20 ns
                next_state = S_DONE;
            end

            S_DONE: begin                   // 1 cycle = 20 ns
                next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end


    always_comb begin

        OE1  = 1'b1;
        INA1 = 1'b0;
        INB1 = 1'b1;
        OE2  = 1'b1;
        INA2 = 1'b0;
        INB2 = 1'b1;
        done = 1'b0;

        case (state)
            S_IDLE: begin
                // Both FETs off — defaults apply
                OE1 = 1'b0;
                OE2 = 1'b0;
            end

            S_C1_PMOS_ON: begin
                INA1 = 1'b1;    // PMOS1 on -> +20V
                INB1 = 1'b1;    // NMOS1 off
            end

            S_C1_DEAD_1: begin
                INA1 = 1'b0;    // PMOS1 off
                INB1 = 1'b1;    // NMOS1 off
            end

            S_C1_NMOS_ON: begin
                INA1 = 1'b0;    // PMOS1 off
                INB1 = 1'b0;    // NMOS1 on -> -20V
            end

            S_C1_DEAD_2: begin
                INA1 = 1'b0;    // PMOS1 off
                INB1 = 1'b1;    // NMOS1 off
            end

            S_C2_PMOS_ON: begin
                INA1 = 1'b1;    // PMOS1 on -> +20V
                INB1 = 1'b1;    // NMOS1 off
            end

            S_C2_DEAD_1: begin
                INA1 = 1'b0;    // PMOS1 off
                INB1 = 1'b1;    // NMOS1 off
            end

            S_C2_NMOS_ON: begin
                INA1 = 1'b0;    // PMOS1 off
                INB1 = 1'b0;    // NMOS1 on -> -20V
            end

            S_C2_DEAD_2: begin
                INA1 = 1'b0;    // PMOS1 off
                INB1 = 1'b1;    // NMOS1 off
            end

            S_DAMP_PMOS_ON: begin
                INA1 = 1'b0;    // PMOS1 off
                INB1 = 1'b1;    // NMOS1 off
                INA2 = 1'b1;    // Damper PMOS on -> output to 0V
                INB2 = 1'b1;    // Damper NMOS off
            end

            S_DAMP_DEAD: begin
                INA1 = 1'b0;    // PMOS1 off
                INB1 = 1'b1;    // NMOS1 off
                INA2 = 1'b0;    // Damper PMOS off
                INB2 = 1'b1;    // Damper NMOS off  -> both off (shoot-through guard)
            end
 
            S_DAMP_NMOS_ON: begin
                INA1 = 1'b0;    // PMOS1 off
                INB1 = 1'b1;    // NMOS1 off
                INA2 = 1'b0;    // Damper PMOS off
                INB2 = 1'b0;    // Damper NMOS on  -> pull node down toward 0
            end

            S_DONE: begin
                done = 1'b1;    
            end

            default: begin
            end
        endcase
    end

endmodule