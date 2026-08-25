module butterfly_unit #(    // Pipelined into multiply and add stages!
    parameter WIDTH = 32    // # bits used in complex calculations
) (
    input logic clk, rst,           // Synchronous reset
    input logic [WIDTH-1:0] A, B,	// complex operands
	input logic [WIDTH-1:0] W,		// twiddle factor
	output logic [WIDTH-1:0] X0, 	// A + B * W
	output logic [WIDTH-1:0] X1	    // A - B * W
);
    
    // Internal signals, splitting each input into real and imaginary components
    logic signed [WIDTH/2-1:0] A_re, A_im;
    assign A_re = A[WIDTH-1:WIDTH/2];
    assign A_im = A[WIDTH/2-1:0];
    
    logic signed [WIDTH/2-1:0] B_re, B_im;
    assign B_re = B[WIDTH-1:WIDTH/2];
    assign B_im = B[WIDTH/2-1:0];    
    
    logic signed [WIDTH/2-1:0] W_re, W_im;
    assign W_re = W[WIDTH-1:WIDTH/2];
    assign W_im = W[WIDTH/2-1:0];	
	
    /* Stage 1: Multiply */
    // W * B = (W_re + jW_im) * (B_re + jB_im)
    //		 = (W_re * B_re - W_im * B_im) + j(W_im * B_re + W_re * B_im)
    logic signed [WIDTH:0] WxB_re, WxB_im;
    assign WxB_re = W_re * B_re - W_im * B_im;
    assign WxB_im = W_im * B_re + W_re * B_im;

    logic signed [WIDTH:0] WxB_re_reg, WxB_im_reg;
    logic signed [WIDTH/2-1:0] A_re_reg, A_im_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            WxB_re_reg <= '0;
            WxB_im_reg <= '0;
            A_re_reg <= '0;
            A_im_reg <= '0;
        end
        else begin
            WxB_re_reg <= WxB_re;
            WxB_im_reg <= WxB_im;
            A_re_reg <= A_re;
            A_im_reg <= A_im;
        end
    end

    /* Stage 2: Add and 1-Bit Scale */
	// Truncated B*W
    logic signed [WIDTH/2-1:0] BW_re_trunc, BW_im_trunc;
    assign BW_re_trunc = $signed(WxB_re_reg[WIDTH-2:WIDTH/2-1]);
    assign BW_im_trunc = $signed(WxB_im_reg[WIDTH-2:WIDTH/2-1]);
    
    // Sum/diff with one extra bit of width to prevent overflow
    logic signed [WIDTH/2:0] sum_re, diff_re, sum_im, diff_im;
    assign sum_re = A_re_reg + BW_re_trunc;
    assign diff_re = A_re_reg - BW_re_trunc;
    assign sum_im = A_im_reg + BW_im_trunc;
    assign diff_im = A_im_reg - BW_im_trunc;

    // Scaling down through arithmetic right shift by 1 (sign extension)
	logic signed [WIDTH/2-1:0] X0_re, X0_im;    
    logic signed [WIDTH/2-1:0] X1_re, X1_im;
    assign X0_re = sum_re >>> 1;
    assign X0_im = sum_im >>> 1;
    assign X1_re = diff_re >>> 1;
    assign X1_im = diff_im >>> 1;
    
    // Combine real and imaginary components of output signals
    always_ff @(posedge clk) begin
        if (rst) begin
            X0 <= '0;
            X1 <= '0;
        end
        else begin
            X0 <= {X0_re, X0_im};
            X1 <= {X1_re, X1_im};
        end
    end
    
endmodule 