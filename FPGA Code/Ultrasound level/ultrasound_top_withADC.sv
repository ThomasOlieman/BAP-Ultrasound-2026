module ultrasound_top_withADC (
    // System
    input  logic        clk,            // 50 MHz system clock
    input  logic        rst,            

    // start/done interface
    input  logic [7:0]  channel_sel,    // [7:4] = TX element, [3:0] = RX element
    input  logic        start,          // Start trigger
    output logic        done,           // Done signal

    // TX TMUX9616
    input  logic        TX_DOUT,
    output logic        TX_DIN,
    output logic        TX_CLK_Mux,
    output logic        TX_LE,
    output logic        TX_CLR,

    // RX TMUX9616
    input  logic        RX_DOUT,
    output logic        RX_DIN,
    output logic        RX_CLK_Mux,
    output logic        RX_LE,
    output logic        RX_CLR,

    // MD1213 #1 outputs (main pulser)
    output logic        INA1,
    output logic        INB1,
    output logic        OE1,

    // MD1213 #2 outputs (damper)
    output logic        INA2,
    output logic        INB2,
    output logic        OE2,

    // ADC
    input  logic        ADC_OTR,
    input  logic [11:0] D,
    output logic        ADC_CLK,        // 20 MHz to ADC


    input  logic [11:0] rd_addr,        // Read address (driven by top level)
    output logic [11:0] rd_data         // 12-bit sample at rd_addr

);


    logic tx_mux_start;
    logic tx_mux_done;

    logic rx_mux_start;
    logic rx_mux_done;

    logic pulser_start;
    logic pulser_done;

    logic adc_start;
    logic adc_done;

    logic [11:0] adc_delay_cnt;


    mux_controller tx_mux (
        .clk         (clk),
        .rst         (rst),
        .element_sel (channel_sel[7:4]),
        .start       (tx_mux_start),
        .done        (tx_mux_done),
        .DOUT        (TX_DOUT),
        .DIN         (TX_DIN),
        .CLK_Mux     (TX_CLK_Mux),
        .LE          (TX_LE),
        .CLR         (TX_CLR)
    );

    mux_controller rx_mux (
        .clk         (clk),
        .rst         (rst),
        .element_sel (channel_sel[3:0]),
        .start       (rx_mux_start),
        .done        (rx_mux_done),
        .DOUT        (RX_DOUT),
        .DIN         (RX_DIN),
        .CLK_Mux     (RX_CLK_Mux),
        .LE          (RX_LE),
        .CLR         (RX_CLR)
    );

    hv_pulser2cycles pulser (
        .clk         (clk),
        .rst         (rst),
        .start       (pulser_start),
        .done        (pulser_done),
        .INA1        (INA1),
        .INB1        (INB1),
        .OE1         (OE1),
        .INA2        (INA2),
        .INB2        (INB2),
        .OE2         (OE2)
    );

    adc_sampler adc (
        .clk          (clk),
        .rst          (rst),
        .start        (adc_start),
        .done_sampling(adc_done),
        .ADC_OTR      (ADC_OTR),
        .D            (D),
        .ADC_CLK      (ADC_CLK),
        .rd_addr      (rd_addr),
        .rd_data      (rd_data)
    );


    typedef enum logic [3:0] {
        S_IDLE,
        S_MUX_CONFIG,
        S_MUX_WAIT,
        S_PULSE,
        S_PULSE_WAIT,
        S_ADC_DELAY,
        S_ADC_START,
        S_ADC_WAIT,
        S_DONE
    } state_t;

    state_t state, next_state;

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
            else if (state == S_IDLE && start_rise)
                start_rise <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            adc_delay_cnt <= 12'd0;
        end else begin
            case (state)
                S_ADC_DELAY: adc_delay_cnt <= adc_delay_cnt + 12'd1;
                default:     adc_delay_cnt <= 12'd0;
            endcase
        end
    end


    always_comb begin
        next_state = state;

        case (state)
            S_IDLE: begin
                if (start_rise)
                    next_state = S_MUX_CONFIG;
            end

            S_MUX_CONFIG: begin
                next_state = S_MUX_WAIT;
            end

            S_MUX_WAIT: begin
                if (tx_mux_done && rx_mux_done)
                    next_state = S_PULSE;
            end

            S_PULSE: begin
                next_state = S_PULSE_WAIT;
            end

            S_PULSE_WAIT: begin
                if (pulser_done)
                    next_state = S_ADC_DELAY;
            end

            S_ADC_DELAY: begin
                // Wait 2336 cycles starts at precisely 3.5 cm with 1470m/s velocity

                if (adc_delay_cnt == 12'd2335)
                    next_state = S_ADC_START;
            end

            S_ADC_START: begin
                next_state = S_ADC_WAIT;
            end

            S_ADC_WAIT: begin
                if (adc_done)
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


    // TX mux start
    assign tx_mux_start = (state == S_MUX_CONFIG);

    // RX mux start
    assign rx_mux_start = (state == S_MUX_CONFIG);

    // HV pulser start
    assign pulser_start = (state == S_PULSE);

    // ADC start
    assign adc_start = (state == S_ADC_START);

    // Done signal
    assign done = (state == S_DONE);

endmodule