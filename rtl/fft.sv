module fft #(
    parameter WIDTH = 32,       // # bits used in complex calculations
    parameter N = 128           // N-point FFT
) (
    input logic clk, rst,                   // Synchronous reset
    input logic [WIDTH-1:0] in [0:N-1],     // Time-domain input samples
    input logic start,
    output logic [WIDTH-1:0] out [0:N-1],   // Frequency-domain output samples
    output logic done
);

    localparam NUM_STAGES = $clog2(N);      		// Number of FFT stages (and also the number of butterfly units)
    localparam NUM_PAIRS_PER_STAGE = N/2;   		// Number of butterfly computations per stage
    localparam ADDR_WIDTH = $clog2(N);
    localparam PAIR_CNT_WIDTH = $clog2(NUM_PAIRS_PER_STAGE);

    localparam OPFETCH_LAT = 1;             		// Latency of operand fetch from RAM (read)
    localparam BU_LAT = 2;                  		// Latency of butterfly unit (multiply, add)
    localparam PIPE_DEPTH = OPFETCH_LAT + BU_LAT;   // Latency of result being valid and ready for writeback
	localparam COMP_PERIOD = PIPE_DEPTH + 1;		// Latency of one full computation (read, multiply, add, write)


	// Stage s cannot start issuing until stage s-1 has completed 2^(s-1)+1 computations
	localparam int unsigned TOTAL_COMPS = N + NUM_STAGES - 2;
	function automatic int unsigned start_comp(input int unsigned s);
		return (1 << s) + s - 1;
	endfunction


    // Index-mapping functions
    function automatic int unsigned bit_reverse(input int unsigned val, input int bits);
        int unsigned result = 0;
        for (int i = 0; i < bits; i++)
            result |= ((val >> i) & 1) << (bits - 1 - i);
        return result;
    endfunction

    // Stages s = 0, ..., NUM_STAGES-1
    //  p is the butterfly's position from 0, ..., (N/2)-1 within stage s
    function automatic void stageN_addrs(input int unsigned p, input int unsigned s, input int unsigned NUM_STAGES,
                                        output int unsigned idx_top, output int unsigned idx_bot,
                                        output int unsigned tw_idx);
        // At each stage, the data is divided into groups, and each group is divided into a top and bottom half
        int unsigned half = 1 << s;       // 2^s
        int unsigned group = 1 << (s+1);    // 2^(s+1)
        int unsigned g = p / half;          // Which group this butterfly belongs to
        int unsigned j = p % half;          // Position within that group's top half
        idx_top = g*group + j;
        idx_bot = idx_top + half;
        tw_idx = j * (1 << (NUM_STAGES-1-s));
    endfunction
    

    // Control FSM
    typedef enum logic [1:0] {IDLE, SORT, COMPUTE, DONE} statetype;
    statetype state, nextstate;

	// Running counters
	logic [$clog2(TOTAL_COMPS+1)-1:0] comp_cnt;
	logic [1:0] phase_cnt;		// 0 = read, 1 = multiply, 2 = add, 3 = write

    // State register
    always_ff @(posedge clk) begin
        if (rst)
            state <= IDLE;
        else
            state <= nextstate;
    end

    // Next state logic
    always_comb begin
		nextstate = state;
        case (state)
            IDLE:
                if (start)
                    nextstate = SORT;
            SORT:
				nextstate = COMPUTE;
			COMPUTE:
				if ((comp_cnt == TOTAL_COMPS-1) && (phase_cnt == COMP_PERIOD-1))
					nextstate = DONE;
			DONE:
				nextstate = IDLE;
        endcase
    end

	// Counter control
	always_ff @(posedge clk) begin
		if (rst || state == IDLE) begin
			comp_cnt <= '0;
			phase_cnt <= '0;
		end
		else if (state == COMPUTE) begin
			if (phase_cnt == COMP_PERIOD-1) begin
				phase_cnt <= '0;
				if (comp_cnt != TOTAL_COMPS-1)
					comp_cnt <= comp_cnt + 1'b1;
			end
			else
				phase_cnt <= phase_cnt + 1'b1;
		end
	end

	assign done = (state == DONE);

	// FFT stage management
	logic stage_active [0:NUM_STAGES-1];
	logic [PAIR_CNT_WIDTH-1:0] stage_position [0:NUM_STAGES-1];
	logic reading [0:NUM_STAGES-1];		// Pulses on phase 0 (send read request to RAM) only

	always_comb begin
		for (int s = 0; s < NUM_STAGES; s++) begin
			automatic int unsigned ss = start_comp(s);	// Stage s's start point in comp count units
			stage_active[s] = (state == COMPUTE) && (comp_cnt >= ss) && (comp_cnt < ss + NUM_PAIRS_PER_STAGE);
			stage_position[s] = stage_active[s] ? PAIR_CNT_WIDTH'(comp_cnt - ss) : '0;
			reading[s] = stage_active[s] && (phase_cnt == 0);
		end
	end


	// Input reorder
	logic [WIDTH-1:0] sorted_in [0:N-1];
	always_ff @(posedge clk) begin
		if (rst)
			for (int j = 0; j < N; j++)
				sorted_in[j] <= '0;
		else if (state == IDLE && start)
			for (int j = 0; j < N; j++)
				sorted_in[j] <= in[bit_reverse(j, NUM_STAGES)];
	end

    // Twiddle factors: use twiddle_gen.py script to generate new .mem file!
    logic [WIDTH-1:0] W_rom[0:NUM_PAIRS_PER_STAGE-1];
    initial $readmemh($sformatf("twiddle_N%0d.mem", N), W_rom);		// Load registers from memory


	// Per-stage address generation for this computation's read
	logic [ADDR_WIDTH-1:0] idx_top [0:NUM_STAGES-1];
	logic [ADDR_WIDTH-1:0] idx_bot [0:NUM_STAGES-1];
	logic [PAIR_CNT_WIDTH-1:0] tw_idx [0:NUM_STAGES-1];

	always_comb begin
		for (int s = 0; s < NUM_STAGES; s++) begin
			automatic int unsigned t, b, tw;
			stageN_addrs(stage_position[s], s, NUM_STAGES, t, b, tw);
			idx_top[s] = ADDR_WIDTH'(t);
			idx_bot[s] = ADDR_WIDTH'(b);
			tw_idx[s] = PAIR_CNT_WIDTH'(tw);
		end
	end

	logic [WIDTH-1:0] op0_a_reg, op0_b_reg;
	always_ff @(posedge clk) begin
		op0_a_reg <= sorted_in[idx_top[0]];
		op0_b_reg <= sorted_in[idx_bot[0]];
	end


    // Instantiating BRAMs to store intermediate results between stages  WIP
    logic write_en_a [0:NUM_STAGES-2];
    logic write_en_b [0:NUM_STAGES-2];
    logic [ADDR_WIDTH-1:0] addr_a [0:NUM_STAGES-2];
    logic [ADDR_WIDTH-1:0] addr_b [0:NUM_STAGES-2];
    logic [WIDTH-1:0] write_data_a [0:NUM_STAGES-2];
    logic [WIDTH-1:0] write_data_b [0:NUM_STAGES-2];
    logic [WIDTH-1:0] read_data_a [0:NUM_STAGES-2];
    logic [WIDTH-1:0] read_data_b [0:NUM_STAGES-2];

    genvar g;
    generate 
        for (g = 0; g < NUM_STAGES-1; g++) begin: gen_stage_mem
            dual_port_ram #(.WIDTH(WIDTH), .N(N)) u_stage_mem(
                .clk(clk),
                .write_en_a(write_en_a[g]),
                .write_en_b(write_en_b[g]),
                .addr_a(addr_a[g]),
                .addr_b(addr_b[g]),
                .write_data_a(write_data_a[g]),
                .write_data_b(write_data_b[g]),
                .read_data_a(read_data_a[g]),
                .read_data_b(read_data_b[g])
            );
        end
    endgenerate


    // Instantiating one butterfly unit per stage
	logic [WIDTH-1:0] bu_A [0:NUM_STAGES-1];
	logic [WIDTH-1:0] bu_B [0:NUM_STAGES-1];
	logic [WIDTH-1:0] bu_W [0:NUM_STAGES-1];
	logic [WIDTH-1:0] bu_X0 [0:NUM_STAGES-1];
	logic [WIDTH-1:0] bu_X1 [0:NUM_STAGES-1];

    genvar h;
    generate
        for (h = 0; h < NUM_STAGES; h++) begin: gen_stage_bu
            butterfly_unit #(.WIDTH(WIDTH)) u_stage_bu(
                .clk(clk),
                .rst(rst),
                .A(bu_A[h]),
                .B(bu_B[h]),
                .W(bu_W[h]),
                .X0(bu_X0[h]),
                .X1(bu_X1[h])
            );
        end
    endgenerate


	// Per-stage pipeline tag chain
	logic [ADDR_WIDTH-1:0] pl_top [0:NUM_STAGES-1][0:PIPE_DEPTH-1];
	logic [ADDR_WIDTH-1:0] pl_bot [0:NUM_STAGES-1][0:PIPE_DEPTH-1];
	logic pl_valid [0:NUM_STAGES-1][0:PIPE_DEPTH-1];
	logic [WIDTH-1:0] pl_tw [0:NUM_STAGES-1][0:PIPE_DEPTH-1];

	always_ff @(posedge clk) begin
		if (rst) begin
			for (int s = 0; s < NUM_STAGES; s++)
				for (int i = 0; i < PIPE_DEPTH; i++) pl_valid[s][i] <= 1'b0;
		end
		else begin
			for (int s = 0; s < NUM_STAGES; s++) begin
				for (int i = PIPE_DEPTH-1; i > 0; i--) begin
					pl_top[s][i] <= pl_top[s][i-1];
					pl_bot[s][i] <= pl_bot[s][i-1];
					pl_valid[s][i] <= pl_valid[s][i-1];
					pl_tw[s][i] <= pl_tw[s][i-1];
				end
				pl_top[s][0] <= idx_top[s];
				pl_bot[s][0] <= idx_bot[s];
				pl_valid[s][0] <= reading[s];
				pl_tw[s][0] <= W_rom[tw_idx[s]];
			end
		end
	end

	
	// Feed each stage's butterfly unit once its operand pair is ready
	always_comb begin
		for (int s = 0; s < NUM_STAGES; s++) begin
			automatic logic [WIDTH-1:0] opA, opB;
			if (s == 0) begin
				opA = op0_a_reg;
				opB = op0_b_reg;
			end
			else begin
				opA = read_data_a[s-1];
				opB = read_data_b[s-1];
			end
			bu_A[s] = pl_valid[s][0] ? opA : '0;
			bu_B[s] = pl_valid[s][0] ? opB : '0;
			bu_W[s] = pl_valid[s][0] ? pl_tw[s][0] : '0;
		end
	end


	// Read and write back into shared BRAMs between stages
	always_comb begin
		for (int s = 0; s < NUM_STAGES-1; s++) begin
			addr_a[s] = '0;
			addr_b[s] = '0;
			write_en_a[s] = '0;
			write_en_b[s] = '0;
			write_data_a[s] = '0;
			write_data_b[s] = '0;
		end

		for (int s = 1; s < NUM_STAGES; s++) begin
			if (reading[s]) begin
				addr_a[s-1] = idx_top[s];
				addr_b[s-1] = idx_bot[s];
			end
		end

		for (int s = 0; s < NUM_STAGES-1; s++) begin
			if (pl_valid[s][PIPE_DEPTH-1]) begin
				write_en_a[s] = 1'b1;
				write_en_b[s] = 1'b1;
				addr_a[s] = pl_top[s][PIPE_DEPTH-1];
				addr_b[s] = pl_bot[s][PIPE_DEPTH-1];
				write_data_a[s] = bu_X0[s];
				write_data_b[s] = bu_X1[s];
			end
		end
	end

	// Last stage writes to out
	always_ff @(posedge clk) begin
		if (rst)
			for (int j = 0; j < N; j++)
				out[j] <= '0;
		else if (pl_valid[NUM_STAGES-1][PIPE_DEPTH-1]) begin
			out[pl_top[NUM_STAGES-1][PIPE_DEPTH-1]] <= bu_X0[NUM_STAGES-1];
			out[pl_bot[NUM_STAGES-1][PIPE_DEPTH-1]] <= bu_X1[NUM_STAGES-1];
		end
	end
    
endmodule