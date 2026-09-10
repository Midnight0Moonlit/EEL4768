`default_nettype none

module rf #(
    parameter BYPASS_EN = 0
) (
    input  wire        i_clk,
    input  wire        i_rst,
    
    input  wire [ 4:0] i_rs1_raddr,
    output wire [31:0] o_rs1_rdata,
    
    input  wire [ 4:0] i_rs2_raddr,
    output wire [31:0] o_rs2_rdata,
    
    input  wire        i_rd_wen,
    input  wire [ 4:0] i_rd_waddr,
    input  wire [31:0] i_rd_wdata
);

    //32 registers of 32-bit width
    reg [31:0] registers [31:0];

    //Synchronous reset and write logic
    always @(posedge i_clk) begin
        if (i_rst) begin
            registers[0]  <= 32'h0; registers[1]  <= 32'h0; registers[2]  <= 32'h0; registers[3]  <= 32'h0;
            registers[4]  <= 32'h0; registers[5]  <= 32'h0; registers[6]  <= 32'h0; registers[7]  <= 32'h0;
            registers[8]  <= 32'h0; registers[9]  <= 32'h0; registers[10] <= 32'h0; registers[11] <= 32'h0;
            registers[12] <= 32'h0; registers[13] <= 32'h0; registers[14] <= 32'h0; registers[15] <= 32'h0;
            registers[16] <= 32'h0; registers[17] <= 32'h0; registers[18] <= 32'h0; registers[19] <= 32'h0;
            registers[20] <= 32'h0; registers[21] <= 32'h0; registers[22] <= 32'h0; registers[23] <= 32'h0;
            registers[24] <= 32'h0; registers[25] <= 32'h0; registers[26] <= 32'h0; registers[27] <= 32'h0;
            registers[28] <= 32'h0; registers[29] <= 32'h0; registers[30] <= 32'h0; registers[31] <= 32'h0;
        end else if (i_rd_wen && (i_rd_waddr != 5'd0)) begin
            registers[i_rd_waddr] <= i_rd_wdata;
        end
    end

    //Combinational reads
    wire [31:0] rs1_raw_data = (i_rs1_raddr == 5'd0) ? 32'h0 : registers[i_rs1_raddr];
    wire [31:0] rs2_raw_data = (i_rs2_raddr == 5'd0) ? 32'h0 : registers[i_rs2_raddr];

    //Bypass detection
    wire bypass_rs1 = (BYPASS_EN != 0) && i_rd_wen && (i_rd_waddr != 5'd0) && (i_rs1_raddr == i_rd_waddr);
    wire bypass_rs2 = (BYPASS_EN != 0) && i_rd_wen && (i_rd_waddr != 5'd0) && (i_rs2_raddr == i_rd_waddr);

    //Final output assignments
    assign o_rs1_rdata = bypass_rs1 ? i_rd_wdata : rs1_raw_data;
    assign o_rs2_rdata = bypass_rs2 ? i_rd_wdata : rs2_raw_data;

endmodule

`default_nettype wire
