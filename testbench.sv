`timescale 1ns / 1ps

`include "clk_gen.sv"
`include "gen_rgb.sv"   // tb_rgb_random 이 들어있는 파일

module testbench;


  logic r_rst_n;
  logic r_clk_en;
  logic w_pclk;
  logic w_ram_clk;

  // clock generation
  clk_gen  #(
    .FREQ   (100    ),
    .DUTY   (50       ),
    .PHASE  (0        )
  ) u_clk_gen (
    .i_clk_en (r_clk_en ),
    .o_clk    (w_pclk   )
  );
  
  clk_gen  #(
    .FREQ   (200    ),
    .DUTY   (50       ),
    .PHASE  (0        )
  ) u_clk_gen_ram (
    .i_clk_en (r_clk_en ),
    .o_clk    (w_ram_clk   )
  );
  

  parameter int VSYNC_POL = 0;  // 0: Active High, 1: Active Low
  parameter int HSYNC_POL = 0;  // 0: Active High, 1: Active Low

  parameter int VSW   = 2*4;   // Vertical Sync Width [line]
  parameter int VBP   = 1*4;   // Vertical Back Porch [line]
  //parameter int VACT  = 4*4+1;   // Vertical Active [line]
  parameter int VACT  = 9;   // Vertical Active [line]
  parameter int HACT  = 9;  // Horizontal Active [clock]
  parameter int VFP   = 1*4;   // Vertical Front Porch [line]

  parameter int HSW   = 1 *4;   // Horizontal Sync Width [clock]
  parameter int HBP   = 2 *4;   // Horizontal Back Porch [clock]
  //parameter int HACT  = 10*1+1;  // Horizontal Active [clock]
  //parameter int HACT  = 8+1;  // Horizontal Active [clock]
  parameter int HFP   = 2 *4;   // Horizontal Front Porch [clock]

  parameter int VTOT  = VSW + VBP + VACT + VFP; // Vertical Total [line]
  parameter int HTOT  = HSW + HBP + HACT + HFP; // Horizontal Total [Clock]
  parameter int ADDR_WIDTH     = 8;
  parameter int RGB_WIDTH      = 10;   // 10bit R/G/B
  parameter int RAM_DATA_WIDTH = 30;   // 10+10+10

  logic       tb_start;
  int         tb_frames;
  logic       tb_busy;
  logic       tb_done;

  logic       tb_vsync, tb_hsync, tb_de;
  logic [9:0] tb_r, tb_g, tb_b;

  // TB에서 FSM에 넣어줄 랜덤 RGB
  logic [9:0] gen_r, gen_g, gen_b;

  logic       w_vsync, w_hsync, w_de;
 // logic [9:0]  o_cur_r;  
 // logic [9:0]  o_cur_g;  
 // logic [9:0]  o_cur_b;
 // logic [9:0]  o_tap0_r; 
 // logic [9:0]  o_tap0_g;
 // logic [9:0]  o_tap0_b;
 // logic [9:0]  o_tap1_r; 
 // logic [9:0]  o_tap1_g; 
 // logic [9:0]  o_tap1_b;

  logic [9:0]  w_r_scaled, w_g_scaled, w_b_scaled;

  logic       [1:0]  i_mode;
  logic       [1:0]  i_method; 
  //==========================================================
  // Video Timing Generator FSM 인스턴스
  //==========================================================
  video_timing_fsm #(
    .VSW       (VSW),
    .VBP       (VBP),
    .VACT      (VACT),
    .VFP       (VFP),

    .HSW       (HSW),
    .HBP       (HBP),
    .HACT      (HACT),
    .HFP       (HFP),

    .VSYNC_POL (VSYNC_POL),
    .HSYNC_POL (HSYNC_POL)
  ) u_video_timing_fsm (
    .pclk     (w_pclk),
    .rstn     (r_rst_n),

    .i_start  (tb_start),
    .i_frames (tb_frames),

    .o_busy   (tb_busy),
    .o_done   (tb_done),

    .i_r      (gen_r),
    .i_g      (gen_g),
    .i_b      (gen_b),

    .o_vsync  (tb_vsync),
    .o_hsync  (tb_hsync),
    .o_de     (tb_de),
    .o_r      (tb_r),
    .o_g      (tb_g),
    .o_b      (tb_b)
  );

  //==========================================================
  // TB용 Random RGB Generator 
  //  de == 1일 때 매 픽셀마다 랜덤 RGB 생성
  //==========================================================
  tb_rgb_random #(
    .WIDTH(10)
  ) u_tb_rgb_random (
    .pclk (w_pclk),
    .rstn (r_rst_n),

    .o_r  (gen_r),
    .o_g  (gen_g),
    .o_b  (gen_b)
  );


  scaler_top #(
    .VSW       (VSW),
    .VBP       (VBP),
    .VACT      (VACT),
    .VFP       (VFP),

    .HSW       (HSW),
    .HBP       (HBP),
    .HACT      (HACT),
    .HFP       (HFP),

    .VSYNC_POL (VSYNC_POL),
    .HSYNC_POL (HSYNC_POL),
    .ADDR_WIDTH(ADDR_WIDTH),
    .RGB_WIDTH(RGB_WIDTH),   // 10bit R/G/B
    .RAM_DATA_WIDTH(RAM_DATA_WIDTH)  // 10+10+10
  ) dut_scaler_top(
    .ram_clk    (w_ram_clk),
    .clk        (w_pclk  ),
    .rstn       (r_rst_n ),
    .i_mode     (i_mode),// 00:bypass, 01:1/2, 10:1/3
    .i_method   (i_method),   
    .i_vsync    (tb_vsync),
    .i_hsync    (tb_hsync),
    .i_de       (tb_de   ),
    .i_r_data   (tb_r    ),
    .i_g_data   (tb_g    ),
    .i_b_data   (tb_b    ),
    // 출력 비디오 (스케일된 결과)
    .o_vsync    (w_vsync ),
    .o_hsync    (w_hsync ),
    .o_de_scaled(w_de),
    .o_r_scaled(w_r_scaled),
    .o_g_scaled(w_g_scaled),
    .o_b_scaled(w_b_scaled)
);
 

  //==========================================================
  // Test Sequence
  //==========================================================
  initial begin
    r_rst_n   <= 0;
    r_clk_en  <= 1;
    tb_start  <= 0;
    tb_frames <= 3;   // 원하는 프레임 수
    i_mode    <= 1;
    i_method  <= 0;

    testbench.u_clk_gen.clk_disp();

    #(20ns)
    r_rst_n <= 1;

    repeat (10) @(posedge w_pclk);

    // FSM 시작
    tb_start <= 1;
    @(posedge w_pclk);
    tb_start <= 0;

    // 완료될 때까지 대기
    wait(tb_done);

    repeat (100) @(posedge w_pclk);
    $finish;
  end

  //==========================================================
  // waveform dump
  //==========================================================
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, testbench);
  end 

endmodule