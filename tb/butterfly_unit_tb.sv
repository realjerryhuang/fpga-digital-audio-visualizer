`timescale 1ns / 1ps

// Stale testbench; needs updating to support pipelined butterfly_unit
module butterfly_unit_tb #(
    parameter WIDTH = 32
) (
);

    logic [WIDTH-1:0] A, B, W, X0, X1;
    butterfly_unit dut(A, B, W, X0, X1);

    initial begin
        int errors = 0;

        /* TEST #1:
            A = 1000 + 2000j
            B = 300 - 400j
            W = 1 + 1j
            X0 = A + B * W = 1699 + 1900j (approx.)
            X1 = A - B * W = 301 + 2100j (approx.) */
        A = 32'b0000001111101000_0000011111010000;  // (1000, 2000)
        B = 32'b0000000100101100_1111111001110000;	// (300, -400)
        W = 32'b0111111111111111_0111111111111111;	// (32767, 32767)
        #10;
        assert ((X0 == {16'd1699, 16'd1900}) &&
                (X1 == {16'd301, 16'd2100}))
            else begin
                errors++;
                $error("TEST #1 FAILED: X0=%0d+%0dj    X1 = %0d+%0dj",
                    $signed(X0[WIDTH-1:WIDTH/2]), $signed(X0[WIDTH/2-1:0]),
                    $signed(X1[WIDTH-1:WIDTH/2]), $signed(X1[WIDTH/2-1:0]));
            end
        
        /* TEST #2:
            A = -1500 + 500j
            B = 200 + 300j
            W = 0 - 1j
            X0 = A + BW = -1200 + 300j
            X1 = A - BW = -1800 + 700j */
        A = 32'b1111101000100100_0000000111110100;	// (-1500, 500)
        B = 32'b0000000011001000_0000000100101100;	// (200, 300)
        W = 32'b0000000000000000_1000000000000000;	// (0, -32768)
        #10;
        assert ((X0 === {-16'd1200, 16'd300}) &&   // (-1200, 300)
                (X1 === {-16'd1800, 16'd700}))      // (-1800, 700)
            else begin
                errors++;
                $error("TEST #2 FAILED: X0=%0d+%0dj    X1=%0d+%0dj",
                    $signed(X0[WIDTH-1:WIDTH/2]), $signed(X0[WIDTH/2-1:0]),
                    $signed(X1[WIDTH-1:WIDTH/2]), $signed(X1[WIDTH/2-1:0]));
            end
        
        /* TEST #3
            A = 0 + 0j
            B = 1024 - 1024j
            W = 1 - 1j
            X0 = A + BW = -1 - 2048j (approx.)
            X1 = A - BW = 1 + 2048j (approx.) */
        A = 32'b0000000000000000_0000000000000000;	// (0, 0)
        B = 32'b0000010000000000_1111110000000000;	// (1024, -1024)
        W = 32'b0111111111111111_1000000000000000;	// (32767, -32768)
        #10;
        assert ((X0 === {16'hFFFF, 16'hF800}) &&	// (-1, -2048)
                (X1 === {16'h0001, 16'h0800}))	// ( 1, 2048)
            else begin
                errors++;
                $error("TEST #3 FAILED: X0=%0d+%0dj    X1=%0d+%0dj",
                    $signed(X0[WIDTH-1:WIDTH/2]), $signed(X0[WIDTH/2-1:0]),
                    $signed(X1[WIDTH-1:WIDTH/2]), $signed(X1[WIDTH/2-1:0]));
            end;

        if (errors == 0) 
            $display("ALL TESTS PASSED.");
        else
            $display ("%0d TEST(S) FAILED.", errors);
        $finish;
    end

endmodule