module adc_sampler (
    input  logic        clk,            // 50 MHz clock
    input  logic        rst,            

    // start/done interface
    input  logic        start,          // Start signal to start storing data
    output logic        done_sampling,  // done pulse 

    // ADC
    input  logic        ADC_OTR,        // Out of range indicator, unused
    input  logic [11:0] D,              // 12-bit ADC output
    output logic        ADC_CLK,        // 20 MHz continuous clock to ADC


    input  logic [11:0] rd_addr,        // Read address driven by top level
    output logic [11:0] rd_data         // 12-bit sample at rd_addr

);

//M10K buffer, creates 816 words, each 12 bits
    (* ramstyle = "M10K" *) logic [11:0] sample_buffer [0:815];

//This is needed to read the data from the M10K buffer, the 12 bit data rd_data is stored at the location specified by rd_addr in sample_buffer
    always_ff @(posedge clk) begin
        rd_data <= sample_buffer[rd_addr];
    end


// 20 MHz clock from PLL
    logic clk_adc;      

    pll_20MHz pll_inst (
        .refclk   (clk),       // 50 MHz input
        .rst      (rst),       // system reset (active-high)
        .outclk_0 (clk_adc)    // 20 MHz output
    );

    assign ADC_CLK = clk_adc;


//OTR is not used
    logic otr_unused;
    assign otr_unused = ADC_OTR;


//FSM
    typedef enum logic [1:0] {
        S_IDLE,         
        S_SAMPLING,     
        S_DONE          
    } state_t;

    state_t state, next_state;

//Detect start signal
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

    logic sampling_done_sync;


    always_ff @(posedge clk) begin
        if (rst)
            state <= S_IDLE;
        else
            state <= next_state;
    end


    always_comb begin
        next_state = state;

        case (state)
            S_IDLE: begin
                if (start_rise)
                    next_state = S_SAMPLING;
            end

            S_SAMPLING: begin
                if (sampling_done_sync)
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

//Two flop synchroniser to prevent metastability
    logic sampling_active_sys;
    logic sync_ff1, sync_ff2;
    logic sampling_active_adc;

    assign sampling_active_sys = (state == S_SAMPLING);

    always_ff @(posedge clk_adc) begin
        if (rst) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else begin
            sync_ff1 <= sampling_active_sys;
            sync_ff2 <= sync_ff1;
        end
    end

    assign sampling_active_adc = sync_ff2;



//at the next clock edge D_reg holds the value sampled 8 clock cycles ago

    logic [11:0] D_reg;

    always_ff @(negedge clk_adc) begin
        D_reg <= D;
    end



    logic [11:0] sample_cnt;
    logic        sampling_done_adc;

    always_ff @(posedge clk_adc) begin
            if (rst) begin
                sample_cnt        <= 12'd0;
                sampling_done_adc <= 1'b0;
            end else if (sampling_active_adc && !sampling_done_adc) begin
                sample_buffer[sample_cnt] <= D_reg;

                if (sample_cnt == 12'd815) begin
                    sampling_done_adc <= 1'b1;
                end else begin
                    sample_cnt <= sample_cnt + 12'd1;
                end
            end else if (!sampling_active_adc) begin
                sample_cnt        <= 12'd0;
                sampling_done_adc <= 1'b0;
            end
        end


//sync sampling done signal back to 50 MHz
    logic done_sync_ff1, done_sync_ff2;

    always_ff @(posedge clk) begin
        if (rst) begin
            done_sync_ff1 <= 1'b0;
            done_sync_ff2 <= 1'b0;
        end else begin
            done_sync_ff1 <= sampling_done_adc;
            done_sync_ff2 <= done_sync_ff1;
        end
    end

    assign sampling_done_sync = done_sync_ff2;

//Output that ADC is done
    assign done_sampling = (state == S_DONE);



endmodule