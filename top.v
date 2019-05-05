`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Difference from "double_out":
//				1. this project was created on Jan. 10th, I did it for
//					the Dual-projector journal paper;
//				2. the "lut" is not from .txt file, it is from EEPROM;
//				3. generate different .bit files, when calibration, each projector
//					outputs 3-frequency 28-frame SLI patterns, when scanning, one projector
//					outputs unit frequency 8-frame SLI patterns, the other outputs high
//					frequency (f_h=16f_u) 8-frame SLI patterns;
//				4. switch mode by defining "CALIB" or not
// Note: replaced the PLL_BASE with ipCore, changed the 2 delay parameters in 
//       i2c_master to (107000000, 257000000), and NET "CLOCK_EXT" IN_TERM = UNTUNED_SPLIT_25;
//
// Revision History: March, 2019 solved the red pixel issue that haunted us for so long,
//                   the Si514 does NOT work reliably if there's no BUFPLL, so I had to
//							port the entire hdmi_encoder module which includes the OSERDES
//							to this porject. Luckily it gets me out of trouble. The two parameters
//							in "i2c_master.v" don't matter any more.
// Again: this project is created and perfected for the dual-projector journal paper
//////////////////////////////////////////////////////////////////////////////////
`define CALIB
module top(
				input CLOCK_IN,
				input CLOCK_EXT,
				//////////// HDMI 1 //////////
				output [2:0] TMDS1_POSITIVE,
				output [2:0] TMDS1_NEGATIVE,
				output TMDS1_CLOCK_P,
				output TMDS1_CLOCK_N,				
				/////////// HDMI 2 //////////
				output [2:0] TMDS2_POSITIVE,
				output [2:0] TMDS2_NEGATIVE,
				output TMDS2_CLOCK_P,
				output TMDS2_CLOCK_N,
				
				input  sync_in_1,					//isolated PIN4
				input  sync_in_2,				//PIN12
				output sync_out_1,
				output sync_out_2,
				
				output SCL,
				inout  SDA,
				
				//UART with AVR
			   input  wire RST_N,
			   input  wire CCLK,
				
				//SPI with AVR
			   output wire SPI_MISO,
			   input  wire SPI_SS,
			   input  wire SPI_MOSI,
			   input  wire SPI_SCK,
				
				output [7:0] LED
    );

wire clockx2, clockx10;
wire clock_pix, clock_tmds;
wire dds_start, hdmi_start;
wire [7:0] pdata1, pdata2;
wire SYNC_HS, SYNC_VS, goo;
wire CLK_40M, CLK_50M;

reg [7:0] lut [0:1023];
reg [10:0] m;

reg [31:0] phsr1, phsr2;
reg [31:0] phsr1LR, phsr2LR;
reg projector;
reg [7:0] co_n;
reg [7:0] co_K;
reg [7:0] frame;
reg [31:0] phase_inc, phase_inc_LR;
reg [31:0] phase_off_8;
reg sync_out_2r;
reg srst;
reg [1:0] delay_st;
reg stch;

integer i;
integer outfile;
initial
begin
	m = 0;	
	phsr1 = 0; phsr2 = 0;
	phsr1LR = 0; phsr2LR = 0;
	projector = 0;
	co_n = 0;
	co_K = 0;
	frame = 0;
	phase_inc = 0;
	phase_inc_LR = 0;
	phase_off_8 = 0;
	sync_out_2r = 0;
	srst = 0;
	delay_st = 2'b11;
	stch = 0;
	
   
	/*$readmemh("ml750.txt", lut);
	outfile = $fopen("cout.txt");
	for(i=0; i<1024; i=i+1)begin
	$fdisplay(outfile, "%d:%h" , i, lut[i]); end*/
end

assign LED = lut[1023][7:0];
i2c_master	PROGAMMABLE_OSC(
					.CLOCK_IN				(CLOCK_IN),
					.CLOCK_OUT1				(CLK_40M),
					.CLOCK_OUT2				(CLK_50M),
		
					.SCL						(SCL),
					.SDA						(SDA),
		
					.DDS_START				(dds_start),
					.wLED						()
);


wire locked;
wire bufpll_lock;
wire gclk, clockx1;
wire clkfbout, serdes;
wire DE;
PLL_BASE # (
    .CLKIN_PERIOD(10),
    .CLKFBOUT_MULT(10), //set VCO to 10x of CLKIN
    .CLKOUT0_DIVIDE(1),
    .CLKOUT1_DIVIDE(10),
    .CLKOUT2_DIVIDE(5),
    .COMPENSATION("INTERNAL")
  ) PLL_EXT (
    .CLKFBOUT(clkfbout),
    .CLKOUT0(clockx10),
    .CLKOUT1(clockx1),
    .CLKOUT2(clockx2),
    .CLKOUT3(),
    .CLKOUT4(),
    .CLKOUT5(),
    .LOCKED(locked),
    .CLKFBIN(clkfbout),
    .CLKIN(CLOCK_EXT),
    .RST(~dds_start)
);

/*pll_ip PLLb10(
	.CLK_IN1				(CLOCK_EXT),
   .CLK_OUT1			(clock_pix),	
   .CLK_OUT2			(clockx10),
	.CLK_OUT3			(clockx2),
   .RESET				(~dds_start),	//input
	.LOCKED				(locked)			//output
 );*/
BUFG clkt2 (.I(clockx2), .O(gclk));
BUFG clkt1 (.I(clockx1), .O(clock_pix));
BUFPLL #(.DIVIDE(5))
ioclk_buf (
	.PLLIN				(clockx10),
	.GCLK					(gclk),
	.LOCKED				(locked),
	.IOCLK				(clock_tmds),
	.SERDESSTROBE		(serdes),
	.LOCK					(bufpll_lock)
);


BUFG startbufg(.I(dds_start), .O(hdmi_start));

hdmi_top HDMI_TIMING(
					.clock_pixel			(clock_pix),
					.clock_TMDS				(clock_tmds),
					.HDMI_START				(bufpll_lock),				//hdmi_start
					
					/*.iRed						(8'h00),
					.iGreen					(pdata1),
					.iBlue					(8'h00),*/
					
					.oRequest				(goo),
					.SYNC_H					(SYNC_HS),
					.SYNC_V					(SYNC_VS),
					.DE						(DE),
					.LED						()
);

/*hdmi_top HDMI2(
					.clock_pixel			(clock_pix),
					.clock_TMDS				(clock_tmds),
					.HDMI_START				(bufpll_lock),				//hdmi_start
					
					.iRed						(8'h00),
					.iGreen					(pdata2),
					.iBlue					(8'h00),
					
					.oRequest				(),						//NC
					.SYNC_H					(),						//NC
					.SYNC_V					(),						//NC
					.DE						(),
					.LED						()
);

*//*** ADD THE OSERDES TO GET RID OF THE UNSTABLE CLOCK ISSUE (HOPEFULLY) ***/
dvi_encoder_top PORT_1 (
    .pclk        (clock_pix),
    .pclkx2      (gclk),
    .pclkx10     (clock_tmds),
    .serdesstrobe(serdes),
    .rstin       (~bufpll_lock),
    .blue_din    (pdata1),
    .green_din   (0),
    .red_din     (pdata1),
    .hsync       (SYNC_HS),
    .vsync       (SYNC_VS),
    .de          (DE),
    .TMDS        ({TMDS1_CLOCK_P, TMDS1_POSITIVE}),
    .TMDSB       ({TMDS1_CLOCK_N, TMDS1_NEGATIVE})
);

dvi_encoder_top PORT_2 (
    .pclk        (clock_pix),
    .pclkx2      (gclk),
    .pclkx10     (clock_tmds),
    .serdesstrobe(serdes),
    .rstin       (~bufpll_lock),
    .blue_din    (pdata2),
    .green_din   (0),
    .red_din     (pdata2),
    .hsync       (SYNC_HS),
    .vsync       (SYNC_VS),
    .de          (DE),
    .TMDS        ({TMDS2_CLOCK_P, TMDS2_POSITIVE}),
    .TMDSB       ({TMDS2_CLOCK_N, TMDS2_NEGATIVE})
);
/*** SPI receiver used to load the LUT of the projector ***/
wire new_spi;
wire [7:0] rx_spi;
wire spi_bss;

avr_interface#(.CLK_RATE(50000000), .SERIAL_BAUD_RATE(500000))
INSTANTIATION1(
				 .clk								(CLK_50M),
				 .rst								(~RST_N),			 
				 .cclk							(CCLK),
				 
				 // AVR SPI Signals
				 .spi_miso						(SPI_MISO),
				 .spi_mosi						(SPI_MOSI),
				 .spi_sck						(SPI_SCK),
				 .spi_ss							(SPI_SS),
				 .spi_channel					(),
				 
				 // AVR Serial Signals
				 .tx								(),
				 .rx								(),
				 
				 // ADC Interface Signals
				 .channel						(),
				 .new_sample					(new_spi),
				 .sample							(),
				 .sample_channel				(),
				 
				 .spi_rcv						(rx_spi),
				 
				 // Serial TX User Interface
				 .tx_data						(),
				 .new_tx_data					(),			//trig the transmission of a new byte
				 .tx_busy						(),				//1: being transmitting; 0: IDLE
				 .tx_block						(1'b1),
				 
				 // Serial Rx User Interface
				 .rx_data						(),
				 .new_rx_data					()							//indicate that just received a new byte

);

edgedtct SPI_ON_REC(
				.clk		(CLK_50M),
				.signl	(new_spi),
				.re		(spi_bss)
);

always@(posedge CLK_50M)
begin
	if(spi_bss)
	begin
		if(m<=1023)
		begin
			lut[m] = rx_spi;
			m = m + 1;
		end
		else
			m = m;
	end
end
/**************** Sinusoidal wave generation *******************/
wire [31:0] phase_i1, phase_i2;
wire [31:0] phase_o1, phase_o2;
wire [31:0] pout1, pout2;
wire [31:0] pout1_lr, pout2_lr;
ddsc PROJECTOR_1(
			.clk				(SYNC_HS),
			.sclr				((!hdmi_start) || (!goo)),
			
			.pinc_in			(phase_i1),
			.poff_in			(phase_o1),
			.cosine			(),
			.phase_out		(pout1)
);

ddsc PROJECTOR_2(
			.clk				(SYNC_HS),
			.sclr				((!hdmi_start) || (!goo)),
			
			.pinc_in			(phase_i2),
			.poff_in			(phase_o2),
			.cosine			(),
			.phase_out		(pout2)
);
/***************************************************/
ddsc PROJECTOR_1LR(
			.clk				(clock_pix),
			.sclr				((!hdmi_start) || (!DE)),
			
			.pinc_in			(phase_i1),
			.poff_in			(phase_o1),
			.cosine			(),
			.phase_out		(pout1_lr)
);
ddsc PROJECTOR_2LR(
			.clk				(clock_pix),
			.sclr				((!hdmi_start) || (!DE)),
			
			.pinc_in			(phase_i2),
			.poff_in			(phase_o2),
			.cosine			(),
			.phase_out		(pout2_lr)
);
assign pdata1 = (frame < 28) ? lut[pout1[31:22]] : lut[pout1_lr[31:22]];
assign pdata2 = (frame < 28) ? lut[pout2[31:22]] : lut[pout2_lr[31:22]];

`ifdef CALIB				//select this macro when calibrating
wire wrst;

always@(*)
begin
	begin
		case(frame)								//[0,23); [24, 623]; [624, 648)
													//Note: for the middle and high frequency patterns, the offsets are different from the
													//      unit frequency patterns, they start from 24*6 and 24*36, instead of 24, they real
													//      starting point is not ROW24, it's ROW0 which is out of the field of view
			// f = 1
			0: begin
					phsr1 = 32'd159072863;
					phsr2 = 32'd159072863;
				end
			1: begin
					phsr1 = 32'd695943775;
					phsr2 = 32'd1232814687;
				end
			2: begin
					phsr1 = 32'd1232814687;
					phsr2 = 32'd2306556511;
				end
			3: begin
					phsr1 = 32'd1769685599;
					phsr2 = 32'd3380298335;
				end
			4: begin
					phsr1 = 32'd2306556511;
					phsr2 = 32'd159072863;
				end
			5: begin
					phsr1 = 32'd2843427423;
					phsr2 = 32'd1232814687;
				end
			6: begin
					phsr1 = 32'd3380298335;
					phsr2 = 32'd2306556511;
				end
			7: begin
					phsr1 = 32'd3917169247;
					phsr2 = 32'd3380298335;
				end
				
				// f = 6
			8: begin
					phsr1 = 32'd954437177;				//32'd159072863*6;
					phsr2 = 32'd954437177;
				end
			9: begin
					phsr1 = 32'd1491308089;
					phsr2 = 32'd2028179001;
				end
		  10: begin
					phsr1 = 32'd2028179001;
					phsr2 = 32'd3101920825;
				end
		  11: begin
					phsr1 = 32'd2565049913;
					phsr2 = 32'd4175662649;
				end
		  12: begin
					phsr1 = 32'd3101920825;
					phsr2 = 32'd954437177;
				end
		  13: begin
					phsr1 = 32'd3638791737;
					phsr2 = 32'd2028179001;
				end
		  14: begin
					phsr1 = 32'd4175662649;
					phsr2 = 32'd3101920825;
				end
		  15: begin
					phsr1 = 32'd417566265;
					phsr2 = 32'd4175662649;
			   end
		
		      // f = 36
		  16: begin
					phsr1 = 32'd1431655765;				//32'd159072863*36 - 2^32;
					phsr2 = 32'd1431655765;
				end
		  17: begin
					phsr1 = 32'd1968526677;
					phsr2 = 32'd2505397589;
				end
		  18: begin
					phsr1 = 32'd2505397589;
					phsr2 = 32'd3579139413;
				end
		  19: begin
					phsr1 = 32'd3042268501;
					phsr2 = 32'd357913941;
				end
		  20: begin
					phsr1 = 32'd3579139413;
					phsr2 = 32'd1431655765;
				end
		  21: begin
					phsr1 = 32'd4116010325;
					phsr2 = 32'd2505397589;
				end
		  22: begin
					phsr1 = 32'd357913941;
					phsr2 = 32'd3579139413;
				end
		  23: begin
					phsr1 = 32'd894784853;
					phsr2 = 32'd357913941;
				end
		  default: begin
					phsr1 = 32'd0;
					phsr2 = 32'd0;
		      end
		endcase
	end
end

always@(*)
begin
		case(frame)
			//f = 1
			28: begin
					 phsr1LR = 32'd357913941;
					 phsr2LR = 32'd357913941;
				 end
		   29: begin
					 phsr1LR = 32'd894784853;
					 phsr2LR = 32'd1431655765;
				 end
		   30: begin
					 phsr1LR = 32'd1431655765;
					 phsr2LR = 32'd2505397589;
				 end
		   31: begin
					 phsr1LR = 32'd1968526677;
					 phsr2LR = 32'd3579139413;
				 end
			32: begin
					 phsr1LR = 32'd2505397589;
					 phsr2LR = 32'd357913941;
				 end
		   33: begin
					 phsr1LR = 32'd3042268501;
					 phsr2LR = 32'd1431655765;
				 end
		   34: begin
					 phsr1LR = 32'd3579139413;
					 phsr2LR = 32'd2505397589;
				 end
		   35: begin
					 phsr1LR = 32'd4116010325;
					 phsr2LR = 32'd3579139413;
				 end
			//f = 6
			36: begin
					 phsr1LR = 32'd2147483648;
					 phsr2LR = 32'd2147483648;
				 end
		   37: begin
					 phsr1LR = 32'd2684354560;
					 phsr2LR = 32'd3221225472;
				 end
		   38: begin
					 phsr1LR = 32'd3221225472;
					 phsr2LR = 32'd0;
				 end
		   39: begin
					 phsr1LR = 32'd3758096384;
					 phsr2LR = 32'd1073741824;
				 end
			40: begin
					 phsr1LR = 32'd0;
					 phsr2LR = 32'd2147483648;
				 end
		   41: begin
					 phsr1LR = 32'd5368870912;
					 phsr2LR = 32'd3221225472;
				 end
		   42: begin
					 phsr1LR = 32'd1073741824;
					 phsr2LR = 32'd0;
				 end
		   43: begin
					 phsr1LR = 32'd1610612736;
					 phsr2LR = 32'd1073741824;
				 end
			//f = 36
			44: begin
					 phsr1LR = 32'd0;
					 phsr2LR = 32'd0;
				 end
		   45: begin
					 phsr1LR = 32'd536870912;
					 phsr2LR = 32'd1073741824;
				 end
		   46: begin
					 phsr1LR = 32'd1073741824;
					 phsr2LR = 32'd2147483648;
				 end
		   47: begin
					 phsr1LR = 32'd1610612736;
					 phsr2LR = 32'd3221225472;
				 end
			48: begin
					 phsr1LR = 32'd2147483648;
					 phsr2LR = 32'd0;
				 end
		   49: begin
					 phsr1LR = 32'd2684354560;
					 phsr2LR = 32'd1073741824;
				 end
		   50: begin
					 phsr1LR = 32'd3221225472;
					 phsr2LR = 32'd2147483648;
				 end
		   51: begin
					 phsr1LR = 32'd3758096384;
					 phsr2LR = 32'd3221225472;
				 end
			default: begin
					      phsr1LR = 32'd0;
							phsr2LR = 32'd0;
					   end
		endcase
end

always@(frame)
begin
	if(frame<28)
	begin
		co_n <= frame % 8;
		co_K <= (frame / 8) + 1;
	end
	else
	begin
		co_n <= (frame - 28) % 8;
		co_K <= ((frame - 28) / 8) + 1;
	end
end


always@(frame)
begin
		case(co_K)
		  1: begin
				  phase_inc = 32'd6628036;				//2^32 / 648 (1 wave length across 648 rows)
				  phase_inc_LR = 32'd4473924;
			  end
		  2: begin
				  phase_inc = 32'd39768216;			//2^32 / 108 (6 wave lengths)
				  phase_inc_LR = 32'd26843546;
			  end
		  3: begin
				  phase_inc = 32'd238609294;			//2^32 / 18  (36 wave lengths)
			     phase_inc_LR = 32'd161061274;
			  end
		  default: begin
						  phase_inc = 32'd0;
						  phase_inc_LR = 32'd0;
					  end
		endcase
end
/********************* Add 8 new frames **************************/
assign phase_i1 = (frame < 24) ? phase_inc : (((frame > 27) && (frame < 52)) ? phase_inc_LR : 32'd0);
assign phase_i2 = (frame < 24) ? phase_inc : (((frame > 27) && (frame < 52)) ? phase_inc_LR : 32'd0);
assign phase_o1 = (frame < 24) ? phsr1 : (((frame > 27) && (frame < 52)) ? phsr1LR : phase_off_8);
assign phase_o2 = (frame < 24) ? phsr2 : (((frame > 27) && (frame < 52)) ? phsr2LR : phase_off_8);

always@(frame)
begin
		if((frame==25)||(frame==27)||(frame==53)||(frame==55))
				phase_off_8 <= 2147483648;
		else if((frame==24)||(frame==26)||(frame==52)||(frame==54))
				phase_off_8 <= 32'd0;
		else
				phase_off_8 <= 32'd0;
end

always@(negedge SYNC_VS or negedge sync_in_1)
begin
	   if(!sync_in_1) begin
			frame = 55;
			projector = 0;
		end
		else if(sync_in_2)
		begin
				if((delay_st==2'b11)||(delay_st==2'b10))				//before was: if(delay_st==2'b11)
				begin
					projector = 1;
					if(frame<55)
						frame = frame + 1;
					else
						frame = 0;
				end
				
				else begin
						frame = frame;
						projector = 0;
				end
		end
		else begin
				frame = frame;
				projector = 0;
		end
end

always@(clock_pix)
begin
	if(goo == 0)
		srst = 1;
	else
		srst = 0;
end
assign wrst = srst;

always@(frame)
begin
	if(frame % 8 == 1)
			sync_out_2r = 1'b1;
	else
			sync_out_2r = 1'b0;
end
assign sync_out_2 = sync_out_2r;

always@(negedge SYNC_VS or negedge sync_in_1)
begin
	if(sync_in_1 == 0)
		begin
			stch = 0;
			delay_st = 2'b11;
		end
	else if(sync_in_2 == 0)
		begin
			stch = 0;
			delay_st = 2'b11;
		end
	else begin
					if(delay_st == 2'b11)
						begin
							delay_st = 2'b10;
							stch = 0;
						end
					else if(delay_st == 2'b10)
						begin
							delay_st = 2'b10;				//before was: delay_st = 2'b11;	
							stch = 1;
						end
					else if(delay_st == 2'b01)
						begin
							delay_st = 2'b00;
							stch = 1;
						end
					else
						begin delay_st = 2'b00; stch = 1;  end
	end
end
assign sync_out_1 = (stch == 1'b1) ? SYNC_VS : 0;

`else							//select this macro when scanning
wire wrst;

always@(posedge wrst)
begin
	begin
		case(frame)
			0: begin
					phsr1 = 0;
					phsr2 = 0;
				end
			1: begin
					phsr1 = 32'd536870912;
					phsr2 = 32'd1073741824;
				end
			2: begin
					phsr1 = 32'd1073741824;
					phsr2 = 32'd2147483648;
				end
			3: begin
					phsr1 = 32'd1610612736;
					phsr2 = 32'd3221225472;
				end
			4: begin
					phsr1 = 32'd2147483648;
					phsr2 = 0;
				end
			5: begin
					phsr1 = 32'd2684354560;
					phsr2 = 32'd1073741824;
				end
			6: begin
					phsr1 = 32'd3221225472;
					phsr2 = 32'd2147483648;
				end
			7: begin
					phsr1 = 32'd3758096384;
					phsr2 = 32'd3221225472;
				end
		  default: begin
					phsr1 = 32'd2147483648;
					phsr2 = 32'd2147483648;
		      end
		endcase
	end
end

always@(frame)
	co_n <= frame % 8;


/*always@(frame)
begin
		case(co_K)
		  1: phase_inc = 32'd6628036;		//32'd7158279;				//2^32 / 480 (1 wave length)
		  2: phase_inc = 32'd39768216;	//32'd42949673;			//2^32 / 60  (8 wave lengths)
		  3: phase_inc = 32'd159072863;	//32'd171798692;			//2^32 / 15  (32 wave lengths)
		  default: phase_inc = 32'd0;
		endcase
end*/
/********************* Add 8 new frames **************************/
assign phase_i1 = phase_inc;
assign phase_i2 = phase_inc;
assign phase_o1 = phsr1;
assign phase_o2 = phsr2;

always@(negedge SYNC_VS or negedge sync_in_1)
begin
	   if(!sync_in_1) begin
			frame = 7;
			projector = 0;
		end
		else if(sync_in_2)
		begin
				if((delay_st==2'b11)||(delay_st==2'b10))				//before was: if(delay_st==2'b11)
				begin
					projector = 1;
					if(frame<7)
						frame = frame + 1;
					else
						frame = 0;
				end
				
				else begin
						frame = frame;
						projector = 0;
				end
		end
		else begin
				frame = frame;
				projector = 0;
		end
end

always@(clock_pix)
begin
	if(goo == 0)
		srst = 1;
	else
		srst = 0;
end
assign wrst = srst;

always@(frame)
begin
	if(frame % 8 == 1)
			sync_out_2r = 1'b1;
	else
			sync_out_2r = 1'b0;
end
assign sync_out_2 = sync_out_2r;

always@(negedge SYNC_VS or negedge sync_in_1)
begin
	if(sync_in_1 == 0)
		begin
			stch = 0;
			delay_st = 2'b11;
		end
	else if(sync_in_2 == 0)
		begin
			stch = 0;
			delay_st = 2'b11;
		end
	else begin
					if(delay_st == 2'b11)
						begin
							delay_st = 2'b10;
							stch = 0;
						end
					else if(delay_st == 2'b10)
						begin
							delay_st = 2'b10;				//before was: delay_st = 2'b11;	
							stch = 1;
						end
					else if(delay_st == 2'b01)
						begin
							delay_st = 2'b00;
							stch = 1;
						end
					else
						begin delay_st = 2'b00; stch = 1;  end
	end
end
assign sync_out_1 = (stch == 1'b1) ? SYNC_VS : 0;
`endif
endmodule
