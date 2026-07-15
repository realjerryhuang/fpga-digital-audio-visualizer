module butterfly_unit 
	#(parameter WIDTH = 32)		// # bits used in complex calculations 
	(input logic [WIDTH-1:0] A, B,	// complex operands
	input logic [WIDTH-1:0] W,		// twiddle factor
	output logic [WIDTH-1:0] out0, 	// A + B * W
	output logic [WIDTH-1:0] out1	// A - B * W
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
	
	// Internal signals, splitting each output into real and imaginary components
	logic signed [WIDTH/2-1:0] out0_re, out0_im;    
    logic signed [WIDTH/2-1:0] out1_re, out1_im;
    
    // W * B = (W_re + jW_im) * (B_re + jB_im)
    //		 = (W_re * B_re - W_im * B_im) + j(W_im * B_re + W_re * B_im)
    logic signed [WIDTH:0] WxB_re, WxB_im;
    assign WxB_re = W_re * B_re - W_im * B_im;
    assign WxB_im = W_im * B_re + W_re * B_im;
	
	// A + truncated (B * W)
    assign out0_re = A_re + $signed(WxB_re[WIDTH-2:WIDTH/2-1]);
    assign out0_im = A_im + $signed(WxB_im[WIDTH-2:WIDTH/2-1]);
    assign out1_re = A_re - $signed(WxB_re[WIDTH-2:WIDTH/2-1]);
    assign out1_im = A_im - $signed(WxB_im[WIDTH-2:WIDTH/2-1]);
    
    // Combine real and imaginary components of output signals
    assign out0 = {out0_re, out0_im};
    assign out1 = {out1_re, out1_im};
    
endmodule