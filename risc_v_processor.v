`timescale 1ns/1ps

//================ PROGRAM COUNTER =================
module program_counter(
input clk,
input reset,
input [31:0] next_pc,
output reg [31:0] pc
);

always @(posedge clk or posedge reset)
begin
    if(reset)
        pc <= 0;
    else
        pc <= next_pc;
end

endmodule


//================ PC + 4 =================
module pc_adder(
input [31:0] pc,
output [31:0] pc_plus4
);

assign pc_plus4 = pc + 4;

endmodule


//================ INSTRUCTION MEMORY =================
module instruction_memory(
input [31:0] addr,
output [31:0] instruction
);

reg [31:0] memory [0:255];

initial begin
    $readmemh("program.mem", memory);
end

assign instruction = memory[addr[9:2]];

endmodule


//================ REGISTER FILE =================
module register_file(
input clk,
input reg_write,
input [4:0] rs1,
input [4:0] rs2,
input [4:0] rd,
input [31:0] write_data,
output [31:0] read_data1,
output [31:0] read_data2
);

reg [31:0] registers [0:31];
integer i;

initial begin
    for(i=0;i<32;i=i+1)
        registers[i] = 0;
end

assign read_data1 = registers[rs1];
assign read_data2 = registers[rs2];

always @(posedge clk)
begin
    if(reg_write && rd!=0)
        registers[rd] <= write_data;
end

endmodule


//================ IMMEDIATE GENERATOR =================
module immediate_generator(
input [31:0] instruction,
output reg [31:0] imm
);

wire [6:0] opcode = instruction[6:0];

always @(*) begin

case(opcode)

// I type
7'b0010011,
7'b0000011,
7'b1100111:
imm = {{20{instruction[31]}},instruction[31:20]};

// S type
7'b0100011:
imm = {{20{instruction[31]}},instruction[31:25],instruction[11:7]};

// B type
7'b1100011:
imm = {{19{instruction[31]}},instruction[31],instruction[7],
       instruction[30:25],instruction[11:8],1'b0};

// J type
7'b1101111:
imm = {{11{instruction[31]}},instruction[31],
       instruction[19:12],
       instruction[20],
       instruction[30:21],
       1'b0};

// U type (LUI, AUIPC)
7'b0110111,
7'b0010111:
imm = {instruction[31:12],12'b0};

default:
imm = 32'b0;

endcase

end

endmodule

//================ ALU =================
module alu(
input [31:0] a,
input [31:0] b,
input [3:0] alu_control,
output reg [31:0] result
);

always @(*) begin

case(alu_control)

4'b0000: result = a + b;                       // ADD
4'b0001: result = a - b;                       // SUB
4'b0010: result = a & b;                       // AND
4'b0011: result = a | b;                       // OR
4'b0100: result = a ^ b;                       // XOR

// Newly Added Operations
4'b0101: result = a << b[4:0];                 // SLL
4'b0110: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // SLT
4'b0111: result = (a < b) ? 32'd1 : 32'd0;     // SLTU
4'b1000: result = a >> b[4:0];                 // SRL
4'b1001: result = $signed(a) >>> b[4:0];       // SRA

default: result = 32'b0;

endcase

end

endmodule


//================ DATA MEMORY =================
module data_memory(
input clk,
input mem_read,
input mem_write,
input [31:0] address,
input [31:0] write_data,
output reg [31:0] read_data
);

reg [31:0] memory [0:255];
integer i;

initial begin
    for(i=0;i<256;i=i+1)
        memory[i] = 0;
end

// write
always @(posedge clk)
begin
    if(mem_write)
        memory[address[9:2]] <= write_data;
end

// read
always @(*)
begin
    if(mem_read)
        read_data = memory[address[9:2]];
    else
        read_data = 32'b0;
end

endmodule

//================ CONTROL UNIT =================
module control_unit(
input [6:0] opcode,
output reg reg_write,
output reg alu_src,
output reg mem_read,
output reg mem_write,
output reg mem_to_reg,
output reg branch,
output reg jump,
output reg jalr
);

always @(*) begin

reg_write = 0;
alu_src = 0;
mem_read = 0;
mem_write = 0;
mem_to_reg = 0;
branch = 0;
jump = 0;
jalr = 0;

case(opcode)

// R-Type
7'b0110011:
reg_write = 1;

// I-Type Arithmetic
7'b0010011: begin
reg_write = 1;
alu_src = 1;
end

// Load
7'b0000011: begin
reg_write = 1;
alu_src = 1;
mem_read = 1;
mem_to_reg = 1;
end

// Store
7'b0100011: begin
alu_src = 1;
mem_write = 1;
end

// Branch
7'b1100011:
branch = 1;

// JAL
7'b1101111: begin
reg_write = 1;
jump = 1;
end

// JALR
7'b1100111: begin
reg_write = 1;
alu_src = 1;
jalr = 1;
end

// LUI (U-Type)
7'b0110111: begin
reg_write = 1;
end

// AUIPC (U-Type)
7'b0010111: begin
reg_write = 1;
end

endcase

end

endmodule


//================ ALU CONTROL =================
module alu_control(
input [2:0] funct3,
input [6:0] funct7,
input [6:0] opcode,
output reg [3:0] alu_ctrl
);

always @(*) begin

case(opcode)

// R-Type Instructions
7'b0110011: begin
    case({funct7,funct3})

        {7'b0000000,3'b000}: alu_ctrl = 4'b0000; // ADD
        {7'b0100000,3'b000}: alu_ctrl = 4'b0001; // SUB
        {7'b0000000,3'b111}: alu_ctrl = 4'b0010; // AND
        {7'b0000000,3'b110}: alu_ctrl = 4'b0011; // OR
        {7'b0000000,3'b100}: alu_ctrl = 4'b0100; // XOR

        {7'b0000000,3'b001}: alu_ctrl = 4'b0101; // SLL
        {7'b0000000,3'b010}: alu_ctrl = 4'b0110; // SLT
        {7'b0000000,3'b011}: alu_ctrl = 4'b0111; // SLTU
        {7'b0000000,3'b101}: alu_ctrl = 4'b1000; // SRL
        {7'b0100000,3'b101}: alu_ctrl = 4'b1001; // SRA

        default: alu_ctrl = 4'b0000;

    endcase
end


// I-Type Arithmetic (ADDI)
7'b0010011: begin
    case(funct3)

        3'b000: alu_ctrl = 4'b0000; // ADDI
        3'b010: alu_ctrl = 4'b0110; // SLTI
        3'b011: alu_ctrl = 4'b0111; // SLTIU
        3'b100: alu_ctrl = 4'b0100; // XORI
        3'b110: alu_ctrl = 4'b0011; // ORI
        3'b111: alu_ctrl = 4'b0010; // ANDI

        3'b001: alu_ctrl = 4'b0101; // SLLI
        3'b101: begin
            if(funct7 == 7'b0000000)
                alu_ctrl = 4'b1000; // SRLI
            else
                alu_ctrl = 4'b1001; // SRAI
        end

        default: alu_ctrl = 4'b0000;

    endcase
end


default:
    alu_ctrl = 4'b0000;

endcase

end

endmodule


//================ BRANCH UNIT =================
module branch_unit(
input [31:0] a,
input [31:0] b,
input [2:0] funct3,
output reg branch_taken
);

always @(*) begin

case(funct3)

3'b000: branch_taken = (a == b);                         // BEQ
3'b001: branch_taken = (a != b);                         // BNE
3'b100: branch_taken = ($signed(a) < $signed(b));        // BLT
3'b101: branch_taken = ($signed(a) >= $signed(b));       // BGE
3'b110: branch_taken = (a < b);                          // BLTU
3'b111: branch_taken = (a >= b);                         // BGEU

default: branch_taken = 0;

endcase

end

endmodule
//================ TOP PROCESSOR =================
module risc_v_processor(
input clk,
input reset
);

wire [31:0] pc;
wire [31:0] next_pc;
wire [31:0] pc_plus4;
wire [31:0] instruction;

program_counter PC(clk,reset,next_pc,pc);
pc_adder ADD(pc,pc_plus4);
instruction_memory IM(pc,instruction);

wire [4:0] rs1 = instruction[19:15];
wire [4:0] rs2 = instruction[24:20];
wire [4:0] rd  = instruction[11:7];

wire [2:0] funct3 = instruction[14:12];
wire [6:0] funct7 = instruction[31:25];
wire [6:0] opcode = instruction[6:0];

wire reg_write, alu_src, mem_read, mem_write, mem_to_reg, branch, jump, jalr;

control_unit CU(opcode,reg_write,alu_src,mem_read,mem_write,mem_to_reg,branch,jump,jalr);

wire [31:0] read_data1, read_data2;
wire [31:0] write_data;

register_file RF(clk,reg_write,rs1,rs2,rd,write_data,read_data1,read_data2);

wire [31:0] imm;

immediate_generator IG(instruction,imm);

wire [3:0] alu_ctrl;

alu_control ALUCTRL(funct3,funct7,opcode,alu_ctrl);

wire [31:0] alu_input2 = alu_src ? imm : read_data2;

wire [31:0] alu_result;

alu ALU(read_data1,alu_input2,alu_ctrl,alu_result);

wire branch_taken;

branch_unit BU(read_data1,read_data2,funct3,branch_taken);

wire [31:0] branch_target = pc + imm;
wire [31:0] jump_target   = pc + imm;
wire [31:0] jalr_target   = (read_data1 + imm) & ~1;

assign next_pc =
    jalr ? jalr_target :
    jump ? jump_target :
    (branch && branch_taken) ? branch_target :
    pc_plus4;

wire [31:0] mem_data;

data_memory DM(clk,mem_read,mem_write,alu_result,read_data2,mem_data);


// -------- Added for U-Type --------
wire lui   = (opcode == 7'b0110111);
wire auipc = (opcode == 7'b0010111);


// -------- Modified Write Back --------
assign write_data =
    (jump || jalr) ? pc_plus4 :
    lui ? imm :
    auipc ? (pc + imm) :
    mem_to_reg ? mem_data :
    alu_result;

endmodule