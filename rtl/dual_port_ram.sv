module dual_port_ram #(
    parameter WIDTH = 32,
    parameter N = 128
) (
    input logic clk,
    input logic write_en_a, write_en_b,
    input logic [$clog2(N)-1:0] addr_a, addr_b,
    input logic [WIDTH-1:0] write_data_a, write_data_b,
    output logic [WIDTH-1:0] read_data_a, read_data_b
);

    logic [WIDTH-1:0] mem [0:N-1];

    always_ff @(posedge clk)
        if (write_en_a)
            mem[addr_a] <= write_data_a;
        else
            read_data_a <= mem[addr_a];

    always_ff @(posedge clk)
        if (write_en_b)
            mem[addr_b] <= write_data_b;
        else
            read_data_b <= mem[addr_b];

endmodule