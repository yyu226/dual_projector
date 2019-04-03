`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:46:09 11/30/2015 
// Design Name: 
// Module Name:    hdmi_top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
`define FQ120HZ
module hdmi_top(
					clock_pixel,
					clock_TMDS,
					HDMI_START,
					/*iRed,
					iGreen,
					iBlue,*/					
					oRequest,
					SYNC_H,
					SYNC_V,
					DE,
					LED
    );
/********** Linux modeline 856x480_60.00 **********/
	 /*parameter HAPIX = 11'd856;
	 parameter HFPOR = 11'd24;
	 parameter HSPUL = 11'd80;
	 parameter HBPOR = 11'd104;
	 
	 parameter VAPIX = 11'd480;
	 parameter VFPOR = 11'd3;
	 parameter VSPUL = 11'd10;
	 parameter VBPOR = 11'd7;*/
/*********** FWVGA 854x480_60.00 ******************/
	 /*parameter HAPIX = 11'd854;
	 parameter HFPOR = 11'd21;
	 parameter HSPUL = 11'd85;
	 parameter HBPOR = 11'd106;
	 
	 parameter VAPIX = 11'd480;
	 parameter VFPOR = 11'd12;
	 parameter VSPUL = 11'd2;
	 parameter VBPOR = 11'd30;*/
/*********** SLI 800*600_120.00 ******************/
`ifdef FQ120HZ
	 parameter HAPIX = 11'd800;
	 parameter HFPOR = 11'd48;
	 parameter HSPUL = 11'd32;
	 parameter HBPOR = 11'd80;
	 
	 parameter VAPIX = 11'd600;
	 parameter VFPOR = 11'd3;
	 parameter VSPUL = 11'd4;
	 parameter VBPOR = 11'd29;
/*********** 800*600@60 ***********************/
`else
	 parameter HAPIX = 11'd800;
	 parameter HFPOR = 11'd40;
	 parameter HSPUL = 11'd128;
	 parameter HBPOR = 11'd88;
	 
	 parameter VAPIX = 11'd600;
	 parameter VFPOR = 11'd1;
	 parameter VSPUL = 11'd4;
	 parameter VBPOR = 11'd23;
`endif
/**** I\O List ****/
input clock_pixel;
input clock_TMDS;
input HDMI_START;

//input [7:0] iRed, iGreen, iBlue;

output oRequest;
output SYNC_H;
output SYNC_V;
output DE;
output [0:7] LED;
/**** Reg List ****/
reg [11:0] contX;
reg [11:0] contY;
reg syncH, syncV, actvA;

reg [3:0] TMDS_modulo;
reg shift_LOAD;
reg [9:0] TMDS_shift_red, TMDS_shift_green, TMDS_shift_blue;

reg [31:0] cntr;
/**** Wire List ****/
wire [7:0] red, green, blue;
wire [7:0] W, A;
wire [9:0] TMDS_red, TMDS_green, TMDS_blue;
wire oclock;

initial
begin
		contX <= 0; contY <= 0;
		//syncH <= 0; syncV <= 0;
		//actvA <= 0;
		
		TMDS_modulo <= 0;
		shift_LOAD <= 0;
		TMDS_shift_red <= 0; TMDS_shift_green <= 0; TMDS_shift_blue <= 0;
		
		cntr <= 0;
end

/************** RTL code **************/
always@(posedge clock_pixel)
		cntr <= cntr + 1;
assign LED = cntr[29:23];


always@(posedge clock_pixel)
begin
		if(contX == HAPIX+HFPOR+HSPUL+HBPOR-1)
				contX = 0;
		else
				contX = contX + 1;
end

always@(posedge clock_pixel)
begin
		if(contX == HAPIX+HFPOR+HSPUL+HBPOR-1)
		begin
				if(contY == VAPIX+VFPOR+VSPUL+VBPOR-1)
						contY = 0;
				else
						contY = contY + 1;
		end
		else
				contY = contY;
end

always@(posedge clock_pixel)
		syncH <= (contX >= HAPIX+HFPOR) && (contX < HAPIX+HFPOR+HSPUL);
always@(posedge clock_pixel)
		syncV <= (contY >= VAPIX+VFPOR) && (contY < VAPIX+VFPOR+VSPUL);
always@(posedge clock_pixel)
		actvA <= (contX < HAPIX) && (contY < VAPIX);

//*********** OUTPUT Control *******************
assign oRequest = (contY == VAPIX+VFPOR+VSPUL+VBPOR-1) || (contY < VAPIX);
assign SYNC_H = ~syncH;
assign SYNC_V = ~syncV;
assign DE = actvA;
//*********** Pattern to Display ****************
assign red = {contX[5:0] & {6{contY[4:3] == ~contX[4:3]}}, 2'b00};
assign green = contX[7:0] & {8{contY[6]}};
assign blue = contY[7:0];

/*assign W = {8{contX[7:0]==contY[7:0]}};
assign A = {8{contX[7:5]==3'h2 && contY[7:5]==3'h2}};

always @(posedge clock_pixel) red <= ({contX[5:0] & {6{contY[4:3]==~contX[4:3]}}, 2'b00} | W) & ~A;
always @(posedge clock_pixel) green <= (contX[7:0] & {8{contY[6]}} | W) & ~A;
always @(posedge clock_pixel) blue <= contY[7:0] | W | A;*/
//***********************************************
/*TMDS_encoder  iRED  (.clk(clock_pixel), .VD(iRed),   .CD(2'b00), 			  .VDE(actvA), .TMDS(TMDS_red));
TMDS_encoder  iGREEN(.clk(clock_pixel), .VD(iGreen), .CD(2'b00), 			  .VDE(actvA), .TMDS(TMDS_green));
TMDS_encoder  iBLUE (.clk(clock_pixel), .VD(iBlue),  .CD({syncV, syncH}), .VDE(actvA), .TMDS(TMDS_blue));

reg vstart = 0;
always@(posedge syncV)
	vstart = HDMI_START;
always@(posedge clock_TMDS)
begin
	if(!vstart)
	begin
		TMDS_shift_red   <= 0;
		TMDS_shift_green <= 0;
		TMDS_shift_blue  <= 0;
		
		TMDS_modulo <= 0;
	end
	else
	begin
		TMDS_shift_red   <= shift_LOAD ? TMDS_red   : TMDS_shift_red[9:1];
		TMDS_shift_green <= shift_LOAD ? TMDS_green : TMDS_shift_green[9:1];
		TMDS_shift_blue  <= shift_LOAD ? TMDS_blue  : TMDS_shift_blue[9:1];
		
		TMDS_modulo <= (TMDS_modulo == 9) ? 4'd0 : TMDS_modulo + 1;
	end
end
always@(posedge clock_TMDS)
		shift_LOAD <= (TMDS_modulo == 9);
*/
endmodule
