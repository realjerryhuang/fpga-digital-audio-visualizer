module clock_divider
	#(parameter DIVISOR = 2)(		// 25 MHz clock at 50% DC from 100 MHz system clock
		input logic clk_in,			// Input clock (100 MHz)
		input logic rst,			// Active high reset
		output logic clk_out		// Output clock
	);

	logic [$clog2(DIVISOR)-1:0] counter = 0;	// Stores 16 bits
	
	always_ff @(posedge clk_in, posedge rst)	// Async reset
		// Reset:
		if (rst) begin
			counter <= '0;
			clk_out <= 1'b0;
		end
		// Clock transition:
		else if (counter == DIVISOR-1) begin
			counter <= '0;
			clk_out <= ~clk_out;
		end
		// Accumulate:
		else counter <= counter + 1;
endmodule