`timescale 1ns / 1ps

//======================================================
//  scaler_top
//   - i_mode : 00 BYPASS, 01 1/2, 10 1/3
//   - i_method : 00 : sampling , 01: average, 10 : cross
//======================================================
// instance : line_buf, RAM2 , scaler_core
//======================================================
module scaler_top #(
    // Vertical timing
    parameter int VSW   = 2,
    parameter int VBP   = 1,
    parameter int VACT  = 4,
    parameter int VFP   = 1,

    // Horizontal timing
    parameter int HSW   = 1,
    parameter int HBP   = 2,
    parameter int HACT  = 10,
    parameter int HFP   = 1,

    // RAM / data
    parameter int ADDR_WIDTH     = 10,
    parameter int RGB_WIDTH      = 10,   // 10bit R/G/B
    parameter int RAM_DATA_WIDTH = 30,   // 10+10+10
    parameter int VSYNC_POL      = 0,    // 0: active high
    parameter int HSYNC_POL      = 0
)(
    input  logic                   clk,        // pclk (line_ctrl / scaler_core)
    input  logic                   ram_clk,   
    input  logic                   rstn,

    input  logic [1:0]             i_mode,     // 00:bypass, 01:1/2, 10:1/3
    input  logic [1:0]             i_method, 
    input  logic                   i_vsync,
    input  logic                   i_hsync,
    input  logic                   i_de,
    input  logic [RGB_WIDTH-1:0]   i_r_data,
    input  logic [RGB_WIDTH-1:0]   i_g_data,
    input  logic [RGB_WIDTH-1:0]   i_b_data,
    output logic                   o_vsync,
    output logic                   o_hsync,
    output logic                   o_de_scaled,
    output logic [RGB_WIDTH-1:0]   o_r_scaled,
    output logic [RGB_WIDTH-1:0]   o_g_scaled,
    output logic [RGB_WIDTH-1:0]   o_b_scaled
);

 
    
    localparam int VTOTAL = VSW + VBP + VACT + VFP;
    localparam int HTOTAL = HSW + HBP + HACT + HFP;

   
    logic                   cs1, we1;
    logic                   cs2, we2;
    logic [ADDR_WIDTH-1:0]  addr1, addr2;
    logic [RAM_DATA_WIDTH-1:0] din1,  din2;
    logic [RAM_DATA_WIDTH-1:0] dout1, dout2;

  
    logic                    de_lb;
    logic [RGB_WIDTH-1:0]    cur_r,  cur_g,  cur_b;
    logic [RGB_WIDTH-1:0]    tap0_r, tap0_g, tap0_b;
    logic [RGB_WIDTH-1:0]    tap1_r, tap1_g, tap1_b;

    logic [11:0]             x_cnt;
    logic [11:0]             y_cnt;
    logic                    y_half;
    logic [1:0]              y_third;
    logic last_line;

    logic w_o_hsync,w_o_vsync;

    
    line_buf_ctrl #(
        .VSW        (VSW),
        .VBP        (VBP),
        .VACT       (VACT),
        .VFP        (VFP),
        .VTOTAL     (VTOTAL),

        .HSW        (HSW),
        .HBP        (HBP),
        .HACT       (HACT),
        .HFP        (HFP),
        .HTOTAL     (HTOTAL),

        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (RAM_DATA_WIDTH),
        .VSYNC_POL  (VSYNC_POL),
        .HSYNC_POL  (HSYNC_POL)
    ) u_line_buf_ctrl (
        .clk            (clk),
        .rstn           (rstn),

        .i_mode         (i_mode),

        .i_vsync        (i_vsync),
        .i_hsync        (i_hsync),
        .i_de           (i_de),
        .i_r_data       (i_r_data),
        .i_g_data       (i_g_data),
        .i_b_data       (i_b_data),

        .o_vsync        (w_o_vsync),
        .o_hsync        (w_o_hsync),
        .o_de           (de_lb),

        .o_cur_r        (cur_r),
        .o_cur_g        (cur_g),
        .o_cur_b        (cur_b),

        .o_tap0_r       (tap0_r),
        .o_tap0_g       (tap0_g),
        .o_tap0_b       (tap0_b),

        .o_tap1_r       (tap1_r),
        .o_tap1_g       (tap1_g),
        .o_tap1_b       (tap1_b),

        .o_x_cnt        (x_cnt),
        .o_y_cnt        (y_cnt),
        .o_y_half (y_half),
        .o_y_third(y_third),
        .last_line(last_line),

        .o_cs1          (cs1),
        .o_we1          (we1),
        .o_cs2          (cs2),
        .o_we2          (we2),

        .o_addr1        (addr1),
        .o_din1         (din1),
        .o_addr2        (addr2),
        .o_din2         (din2),
        .i_dout1        (dout1),
        .i_dout2        (dout2)
    );

    single_port_ram #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (RAM_DATA_WIDTH)
    ) u_sram1 (
        .clk    (ram_clk),
        .i_cs   (cs1),
        .i_we   (we1),
        .i_addr (addr1),
        .i_din  (din1),
        .o_dout (dout1)
    );

    single_port_ram #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (RAM_DATA_WIDTH)
    ) u_sram2 (
        .clk    (ram_clk),
        .i_cs   (cs2),
        .i_we   (we2),
        .i_addr (addr2),
        .i_din  (din2),
        .o_dout (dout2)
    );


    scaler_core #(
        .DATA_WIDTH (RGB_WIDTH)
    ) u_scaler_core (
        .clk             (clk),
        .rstn            (rstn),

        .i_mode          (i_mode),
        .i_method        (i_method),
        .i_vsync        (w_o_vsync),
        .i_hsync        (w_o_hsync),
        .o_hsync        (o_hsync),
        .o_vsync        (o_vsync),

        .i_de            (de_lb),
        .i_cur_r         (cur_r),
        .i_cur_g         (cur_g),
        .i_cur_b         (cur_b),

        .i_tap0_r        (tap0_r),
        .i_tap0_g        (tap0_g),
        .i_tap0_b        (tap0_b),

        .i_tap1_r        (tap1_r),
        .i_tap1_g        (tap1_g),
        .i_tap1_b        (tap1_b),

        .i_x_cnt         (x_cnt),
        .i_y_cnt         (y_cnt),
        .i_y_half  (y_half),
        .i_y_third (y_third),
        .last_line(last_line),

        .o_de_scaled     (o_de_scaled),
        .o_r_scaled      (o_r_scaled),
        .o_g_scaled      (o_g_scaled),
        .o_b_scaled      (o_b_scaled)
    );

    
endmodule
