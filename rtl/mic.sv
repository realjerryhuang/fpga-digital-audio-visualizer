module mic (
    input logic clk, rst,
    input logic vauxp6, vauxn6,     // Differential analog input for microphone (channel 6)
    output logic [15:0] mic_data,	// 16-bit ADC data output
    output logic mic_ready 			// Indicates when new ADC data is ready
);

    // Internal signals for ADC data and control
    logic [15:0] adc_raw_data;      // Raw ADC data from the XADC IP
    logic adc_data_ready;           // Indicates when new ADC data is ready
    logic adc_eoc;                  // End of conversion signal from XADC
    logic adc_busy;                 // Busy signal from XADC
    logic [4:0] channel_out;        // Channel output from XADC

    // ADC IP instantiation
    xadc_wiz_0 XADC_INST (
        .dadr_in(7'h16),            // Address for the ADC channel (channel 6)
        .dclk_in(clk),              // Clock input for the ADC
        .reset_in(rst),             // Reset input for the ADC
        .den_in(adc_eoc),           // Enable signal for the ADC
        .di_in(16'h0),              // Data input to the ADC (not used)
        .dwe_in(1'b0),              // Write enable signal for the adc (not used)
        .vauxp6(vauxp6),            // Analog positive input for channel 6
        .vauxn6(vauxn6),            // Analog negative input for channel 6
        .vp_in(1'b0),               // External positive reference voltage (not used
        .vn_in(1'b0),               // External negative reference voltage (not used)
        
        .busy_out(adc_busy),        // Connect the busy signal
        .channel_out(channel_out),  // Connect the channel output signal
        .do_out(adc_raw_data),      // Connect the raw ADC data output (16 bits)
        .drdy_out(adc_data_ready),  // Connect the data ready signal
        .eoc_out(adc_eoc),          // Connect the end of conversion signal
        .eos_out(),                 // End of sequence signal (not used)
        .alarm_out()                // Alarm output signal (not used)
    );

    // Capture ADC data and set ready flag
    always_ff @(posedge clk) begin
        if (rst) begin
            mic_data <= 7'd0;
            mic_ready <= 1'b0;
        end
        else if (adc_data_ready) begin
            /* XADC on Artix-7 is a 12-bit converter but do_out port is 16 bits wide.
            The conversion result is stored left-justified (MSB-aligned) and the last
            few bits are filled with zeros. This is reconstructed here as a defensive
            mask and to make the intent clear (functionally the same as adc_raw_data).
            
            In unipolar mode, the XADC outputs values from 0 to 4095 (12 bits). To 
            center the data around zero for signed representation, we subtract 2048 
            (0x800) from the value, which becomes 0x8000 upon left-aligning. This 
            effectively shifts the range from [0, 4095] to [-2048, 2047], which is 
            suitable for signed 16-bit representation. */

            mic_data <= {adc_raw_data[15:4], 4'b0000} - 16'h8000;
            mic_ready <= 1'b1;
        end
        else
            mic_ready <= 1'b0;
    end
    
endmodule