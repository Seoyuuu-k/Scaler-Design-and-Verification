`timescale 1ns / 1ps

module line_buf_ctrl_top #(
    parameter int VSW        = 2,
    parameter int VBP        = 1,
    parameter int VACT       = 4,
    parameter int VFP        = 1,

    parameter int HSW        = 1,
    parameter int HBP        = 2,
    parameter int HACT       = 10,
    parameter int HFP        = 1,

    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 30,
    parameter int VSYNC_POL  = 0,    // 0: active high, 1: active low
    parameter int HSYNC_POL  = 0     // 0: active high, 1: active low
)(
    input              clk,
    input              ram_clk,

    input       [1:0]  i_mode,
    
    input              rstn,
    input              i_vsync,
    input              i_hsync,
    input              i_de,
    input       [9:0]  i_r_data,
    input       [9:0]  i_g_data,
    input       [9:0]  i_b_data,
    output             o_vsync,
    output             o_hsync,
    output             o_de,
    output  logic [9:0]  o_cur_r,  
    output  logic [9:0]  o_cur_g,  
    output  logic [9:0]  o_cur_b,
    output  logic [9:0]  o_tap0_r, 
    output  logic [9:0]  o_tap0_g,
    output  logic [9:0]  o_tap0_b,
    output  logic [9:0]  o_tap1_r, 
    output  logic [9:0]  o_tap1_g, 
    output  logic [9:0]  o_tap1_b
);

    logic                  cs1, we1;
    logic                  cs2, we2;
    logic [ADDR_WIDTH-1:0] addr1, addr2;
    logic [DATA_WIDTH-1:0] din1,  din2;
    logic [DATA_WIDTH-1:0] dout1, dout2;

    localparam int VTOTAL = VSW + VBP + VACT + VFP;
    localparam int HTOTAL = HSW + HBP + HACT + HFP;

    




    line_buf_ctrl #(
        .VSW       (VSW),
        .VBP       (VBP),
        .VACT      (VACT),
        .VFP       (VFP),
        .VTOTAL    (VTOTAL),
        .HSW       (HSW),
        .HBP       (HBP),
        .HACT      (HACT),
        .HFP       (HFP),
        .HTOTAL    (HTOTAL),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .VSYNC_POL (VSYNC_POL),
        .HSYNC_POL (HSYNC_POL)
    ) u_line_buf_ctrl (
        .clk      (clk),
        .rstn        (rstn),

        .i_mode(i_mode), 

        .i_vsync  (i_vsync),
        .i_hsync  (i_hsync),
        .i_de     (i_de),
        .i_r_data (i_r_data),
        .i_g_data (i_g_data),
        .i_b_data (i_b_data),

        .o_vsync  (o_vsync),
        .o_hsync  (o_hsync),
        .o_de     (o_de),


        .o_cur_r(o_cur_r),  
        .o_cur_g(o_cur_g),  
        .o_cur_b(o_cur_b),
        .o_tap0_r(o_tap0_r), 
        .o_tap0_g(o_tap0_g),
        .o_tap0_b(o_tap0_b),
        .o_tap1_r(o_tap1_r), 
        .o_tap1_g(o_tap1_g), 
        .o_tap1_b(o_tap1_b),

        .o_cs1    (cs1),
        .o_we1    (we1),
        .o_cs2    (cs2),
        .o_we2    (we2),

        .o_addr1  (addr1),
        .o_din1   (din1),
        .o_addr2  (addr2),
        .o_din2   (din2),

        .i_dout1  (dout1),
        .i_dout2  (dout2)
    );


    single_port_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) U_SRAM1 (
        .clk   (ram_clk),
        .i_cs  (cs1),
        .i_we  (we1),
        .i_addr(addr1),
        .i_din (din1),
        .o_dout(dout1)
    );

    single_port_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) U_SRAM2 (
        .clk   (ram_clk),
        .i_cs  (cs2),
        .i_we  (we2),
        .i_addr(addr2),
        .i_din (din2),
        .o_dout(dout2)
    );

endmodule



module line_buf_ctrl #(
    parameter int VSW        = 1,
    parameter int VBP        = 1,
    parameter int VACT       = 4,
    parameter int VFP        = 1,
    parameter int VTOTAL     = 7,

    // ----- Horizontal timing -----
    parameter int HSW        = 1,
    parameter int HBP        = 2,
    parameter int HACT       = 10,
    parameter int HFP        = 1,
    parameter int HTOTAL     = 14,

    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 30,
    parameter int VSYNC_POL  = 0,    // 0: active high, 1: active low
    parameter int HSYNC_POL  = 0     // 0: active high, 1: active low
)(
    input                    clk,
    input                    rstn,

    input       [1:0]        i_mode,

    input                    i_vsync,
    input                    i_hsync,
    input                    i_de,
    input       [9:0]        i_r_data,
    input       [9:0]        i_g_data,
    input       [9:0]        i_b_data,

    output  logic            o_vsync,
    output  logic            o_hsync,
    output  logic            o_de,

    output  logic [9:0]  o_cur_r,  
    output  logic [9:0]  o_cur_g,  
    output  logic [9:0]  o_cur_b,

    output  logic [9:0]  o_tap0_r, 
    output  logic [9:0]  o_tap0_g,
    output  logic [9:0]  o_tap0_b,

    output  logic [9:0]  o_tap1_r, 
    output  logic [9:0]  o_tap1_g, 
    output  logic [9:0]  o_tap1_b,

    // 스케일러에게 보낼 신호들!
    output logic [11:0] o_x_cnt,
    output logic [11:0] o_y_cnt,
    output logic        o_y_half,   // y_cnt[0]
    output logic [1:0]  o_y_third,  // y_cnt % 3
    output logic        last_line,

    // --- External RAM control ---
    output logic             o_cs1,
    output logic             o_we1,
    output logic             o_cs2,
    output logic             o_we2,

    output logic [ADDR_WIDTH-1:0] o_addr1,
    output logic [DATA_WIDTH-1:0] o_din1,
    output logic [ADDR_WIDTH-1:0] o_addr2,
    output logic [DATA_WIDTH-1:0] o_din2,
    input  logic [DATA_WIDTH-1:0] i_dout1,
    input  logic [DATA_WIDTH-1:0] i_dout2
);

  
    wire vsync_act = (VSYNC_POL == 0) ? i_vsync : ~i_vsync;
    wire hsync_act = (HSYNC_POL == 0) ? i_hsync : ~i_hsync; 
    wire de_act    = i_de;   

    logic vsync_d, de_d;
    

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            vsync_d <= 1'b0;
            de_d    <= 1'b0;
        end else begin
            vsync_d <= vsync_act;
            de_d    <= de_act;
        end
    end

    wire vsync_rise = (~vsync_d &  vsync_act);   // 프레임 시작
    wire de_rise    = (~de_d    &  de_act);      // 한 라인 시작



    typedef enum int {
        ST_IDLE           = 0,
        ST_LINE_DELAY     = 1,
        ST_VSW            = 2,
        ST_FIRST_DE_WAIT  = 3, 
        ST_FIRST_LINE_ACT = 4, 
        ST_ACTIVE_WAIT    = 5,
        ST_LINE_ACTIVE    = 6,
        ST_LAST_LINE_WAIT = 7,
        ST_LAST_LINE_ACT  = 8,
        ST_END            = 9
    } state_t;

    state_t state;

    int p_cnt;
    int cnt_hact;
    int cnt_vact;
    logic v_sync_start;
    int last_cnt;


    //폴라리티반영!!!
    wire vsync_pol = (VSYNC_POL==0)? 1'b1 :1'b0;
    wire hsync_pol = (HSYNC_POL==0)? 1'b1 :1'b0;

    //====================================================
    // FSM
    //====================================================
    always_ff @(posedge clk or negedge rstn) begin 
        if (!rstn) begin
            state   <= ST_IDLE;

            p_cnt     <= 0;
            cnt_hact  <= 0;
            cnt_vact  <= 0;
            last_cnt <=0;

            o_cs1   <= 1'b0; o_we1   <= 1'b0;
            o_cs2   <= 1'b0; o_we2   <= 1'b0;

            o_vsync <= ~vsync_pol;
            o_hsync <= ~hsync_pol;
            o_de    <= 1'b0;

            o_addr1 <= '0;
            o_addr2 <= '0;
            o_din1  <= '0;
            o_din2  <= '0;
            last_line <= 1'b0;
        end else begin
            last_cnt <=0;
            o_cs1   <= 1'b0; o_we1   <= 1'b0;
            o_cs2   <= 1'b0; o_we2   <= 1'b0;

            o_vsync <= ~vsync_pol;
            o_hsync <= ~hsync_pol;
            o_de    <= 1'b0;

            o_addr1 <= '0;
            o_addr2 <= '0;
            o_din1  <= '0;
            o_din2  <= '0;
            last_line <= 1'b0;

            // -----------------------------
            // 1) BYPASS 모드: 걍 통과
            // -----------------------------
            if (i_mode == 2'b00) begin
                o_vsync <= i_vsync;
                o_hsync <= i_hsync;
                o_de    <= i_de;
                state   <= ST_IDLE;  

            end else begin

            case (state) 
                //-----------------------------------------
                ST_IDLE : begin
                    if (vsync_rise) begin
                        p_cnt    <= 0;
                        cnt_vact <= 0;
                        state    <= ST_LINE_DELAY;
                    end
                end

                //-----------------------------------------
                // 한 라인 delay (전체 HTOTAL 만큼)
                //-----------------------------------------
                ST_LINE_DELAY : begin
                    if (p_cnt == HTOTAL-1) begin
                        p_cnt <= 0;
                        state <= ST_VSW;
                        o_vsync <= vsync_pol;       
                        o_hsync <= i_hsync;
                        v_sync_start <=1'b1;     
                    end else begin
                        p_cnt <= p_cnt + 1;
                    end
                end 

                //-----------------------------------------
                // VSW 구간
                //-----------------------------------------
                ST_VSW : begin
                    o_vsync <= vsync_pol;       
                    o_hsync <= i_hsync; 
                    v_sync_start <=1'b0;       

                    if (p_cnt == (HTOTAL*VSW)-1) begin
                        p_cnt <= 0;
                        state <= ST_FIRST_DE_WAIT;
                        o_vsync <= ~vsync_pol;
                        o_hsync <= i_hsync;
                    end else begin
                        p_cnt <= p_cnt + 1;
                    end
                end 
            
                //-----------------------------------------
                // 첫 Active 라인 시작 대기 (DE rise)
                //-----------------------------------------
                ST_FIRST_DE_WAIT : begin
                    o_vsync <= ~vsync_pol;
                    o_hsync <= i_hsync;

                    if (de_rise) begin
                        p_cnt    <= 0;
                        state    <= ST_FIRST_LINE_ACT;
                        cnt_vact <= 0;
                        o_vsync <= ~vsync_pol;
                        o_hsync <= i_hsync;
                        o_de    <= 1'b0; 

                        o_cs1   <= 1'b1; o_we1 <= 1'b1;
                        o_cs2   <= 1'b0; o_we2 <= 1'b0;

                        o_addr1 <= p_cnt; 
                        o_addr2 <= '0;
                        o_din1  <= {i_r_data, i_g_data, i_b_data};
                        o_din2  <= '0;
                    end
                end

                //-----------------------------------------
                // 첫 Active 라인: 쓰기만, 출력 0
                //-----------------------------------------
                ST_FIRST_LINE_ACT : begin
                    o_vsync <= ~vsync_pol;
                    o_hsync <= i_hsync;
                    o_de    <= 1'b0; 

                    o_cs1   <= 1'b1; o_we1 <= 1'b1;
                    o_cs2   <= 1'b0; o_we2 <= 1'b0;

                    o_addr1 <= p_cnt+1; 
                    o_addr2 <= '0;
                    o_din1  <= {i_r_data, i_g_data, i_b_data};
                    o_din2  <= '0;
                
                  if (p_cnt == HACT-1) begin
                        p_cnt    <= 0;
                        state    <= ST_ACTIVE_WAIT;
                        cnt_vact <=  1;
                        o_de <= 1'b0;
                        o_vsync <= ~vsync_pol;
                        o_hsync <= i_hsync;

                        o_cs1   <= 1'b0; o_we1 <= 1'b0;
                        o_cs2   <= 1'b0; o_we2 <= 1'b0;
                        o_addr1 <= '0; 
                        o_addr2 <= '0;
                        o_din1  <= '0;
                        o_din2  <= '0;
                    end else begin
                        p_cnt <= p_cnt + 1;
                    end
                end 
               
                //-----------------------------------------
                // 다음 라인 DE 기다림
                //-----------------------------------------
                ST_ACTIVE_WAIT : begin
                    o_de <= 1'b0;
                    o_vsync <= ~vsync_pol;
                    o_hsync <= i_hsync;
                    p_cnt <= 0;


                    if (de_rise) begin // 첫라인 시작
                        p_cnt <= 0;
                        state <= ST_LINE_ACTIVE;
                        o_de    <= 1'b1;

                        case (i_mode)
                           2'b01 : begin // 1/2 mode
                            if ((cnt_vact % 2) == 1) begin // 홀수 라인
                                o_cs1   <= 1'b1; o_we1 <= 1'b0;
                                o_cs2   <= 1'b1; o_we2 <= 1'b1;

                                o_addr1 <= p_cnt; 
                                o_addr2 <= p_cnt;   
                                o_din1  <= '0;
                                o_din2  <= {i_r_data, i_g_data, i_b_data};
                                end else begin            // 짝수 라인
                                    o_cs1   <= 1'b1; o_we1 <= 1'b1;
                                    o_cs2   <= 1'b1; o_we2 <= 1'b0;

                                    o_addr1 <= p_cnt; 
                                    o_addr2 <= p_cnt;
                                    o_din1  <= {i_r_data, i_g_data, i_b_data};
                                    o_din2  <= '0;
                                end
                            end

                           2'b10 : begin // 1/3 mode
                            // 3줄 패턴
                                case (cnt_vact % 3)
                                    2'd0: begin
                                        // line0: RAM1에 write
                                        o_cs1   <= 1'b1; o_we1 <= 1'b1;
                                        o_cs2   <= 1'b0; o_we2 <= 1'b0;
                                        o_addr1 <= p_cnt;
                                        o_din1  <= {i_r_data, i_g_data, i_b_data};
                                    end
                                    2'd1: begin
                                        // line1: RAM2에 write
                                        o_cs1   <= 1'b0; o_we1 <= 1'b0;
                                        o_cs2   <= 1'b1; o_we2 <= 1'b1;
                                        o_addr2 <= p_cnt;
                                        o_din2  <= {i_r_data, i_g_data, i_b_data};
                                    end
                                    2'd2: begin
                                        // line2: read only (RAM1,RAM2 둘다 read)
                                        o_cs1   <= 1'b1; o_we1 <= 1'b0;
                                        o_cs2   <= 1'b1; o_we2 <= 1'b0;
                                        o_addr1 <= p_cnt;
                                        o_addr2 <= p_cnt;
                                    end
                                endcase
                           end
                        endcase

                end
                end
                


                //-----------------------------------------
                // 중간 라인들: 읽기 + 쓰기
                //-----------------------------------------
                ST_LINE_ACTIVE : begin
                    o_vsync <= ~vsync_pol;
                    o_hsync <= i_hsync;
                    o_de    <= 1'b1;

                    case (i_mode)
                           2'b01 : begin // 1/2 mode
                            if ((cnt_vact % 2) == 1) begin // 홀수 라인
                                o_cs1   <= 1'b1; o_we1 <= 1'b0;
                                o_cs2   <= 1'b1; o_we2 <= 1'b1;
                                o_addr1 <= p_cnt+1;
                                o_addr2 <= p_cnt+1;   
                                o_din1  <= '0;
                                o_din2  <= {i_r_data, i_g_data, i_b_data};
                                end else begin            // 짝수 라인
                                    o_cs1   <= 1'b1; o_we1 <= 1'b1;
                                    o_cs2   <= 1'b1; o_we2 <= 1'b0;
                                    o_addr1 <= p_cnt+1; 
                                    o_addr2 <= p_cnt+1;
                                    o_din1  <= {i_r_data, i_g_data, i_b_data};
                                    o_din2  <= '0;
                                end
                            end

                           2'b10 : begin // 1/3 mode
                                case (cnt_vact % 3)
                                    2'd0: begin
                                        o_cs1   <= 1'b1; o_we1 <= 1'b1;
                                        o_cs2   <= 1'b0; o_we2 <= 1'b0;
                                        o_addr1 <= p_cnt+1;
                                        o_din1  <= {i_r_data, i_g_data, i_b_data};
                                    end
                                    2'd1: begin
                                        o_cs1   <= 1'b0; o_we1 <= 1'b0;
                                        o_cs2   <= 1'b1; o_we2 <= 1'b1;
                                        o_addr2 <= p_cnt+1;
                                        o_din2  <= {i_r_data, i_g_data, i_b_data};
                                    end
                                    2'd2: begin                  
                                        o_cs1   <= 1'b1; o_we1 <= 1'b0;
                                        o_cs2   <= 1'b1; o_we2 <= 1'b0;
                                        o_addr1 <= p_cnt+1;
                                        o_addr2 <= p_cnt+1;

                                    end
                                endcase
                           end
                        endcase

                
                  if (p_cnt == HACT-1) begin
                        //p_cnt <= 0;

                        if (cnt_vact == VACT-1) begin
                            cnt_vact <= cnt_vact + 1;
                            state    <= ST_LAST_LINE_WAIT;
                            o_de <= 1'b0;
                            o_vsync <= ~vsync_pol;
                            o_hsync <= i_hsync;
                            o_cs1   <= 1'b0; o_we1 <= 1'b0;
                            o_cs2   <= 1'b0; o_we2 <= 1'b0;
                            o_addr1 <= '0; 
                            o_addr2 <= '0;
                            o_din1  <= '0;
                            o_din2  <= '0;
                        end else begin
                            cnt_vact <= cnt_vact + 1;
                            state    <= ST_ACTIVE_WAIT;
                            o_de <= 1'b0;
                            o_vsync <= ~vsync_pol;
                            o_hsync <= i_hsync;
                            o_cs1   <= 1'b0; o_we1 <= 1'b0;
                            o_cs2   <= 1'b0; o_we2 <= 1'b0;
                            o_addr1 <= '0; 
                            o_addr2 <= '0;
                            o_din1  <= '0;
                            o_din2  <= '0;
                        end
                    end else begin
                        p_cnt <= p_cnt + 1;
                    end
                end

                //-----------------------------------------
                // 마지막 라인 전의 HSW/HBP/HFP 기다림
                //-----------------------------------------
                ST_LAST_LINE_WAIT : begin
                    p_cnt <=0;
                    o_hsync <= i_hsync;
                    if (last_cnt == (HFP + HBP + HSW) - 1) begin
                        last_line <= 1'b1; // 라스트라인알려줌
                        last_cnt <= 0;
                        p_cnt <=0;
                        state <= ST_LAST_LINE_ACT;
                        o_vsync <= ~vsync_pol;
                        o_hsync <= i_hsync;
                        o_de    <= 1'b1;

                        case (i_mode)
                           2'b01 : begin // 1/2 mode
                            if ((cnt_vact % 2) == 1) begin // 홀수 라인
                                o_cs1   <= 1'b1; o_we1 <= 1'b0;
                                o_cs2   <= 1'b0; o_we2 <= 1'b0;
                                o_addr1 <= '0;   o_addr2 <= '0;  
                                o_din1  <= '0;   o_din2  <= '0;
                                end else begin            // 짝수 라인
                                    o_cs1   <= 1'b0; o_we1 <= 1'b0;
                                    o_cs2   <= 1'b1; o_we2 <= 1'b0;
                                    o_addr1 <= '0; o_addr2 <= '0;
                                    o_din1  <= '0;
                                    o_din2  <= '0;
                                end
                            end

                           2'b10 : begin // 1/3 mode
                                case (cnt_vact % 3)
                                    2'd0: begin
                                    end
                                    2'd1: begin
                                        o_cs1   <= 1'b1; o_we1 <= 1'b0;
                                        o_cs2   <= 1'b0; o_we2 <= 1'b0;
                                        o_addr2 <= '0;
                                    end
                                    2'd2: begin
                                        o_cs1   <= 1'b1; o_we1 <= 1'b0;
                                        o_cs2   <= 1'b1; o_we2 <= 1'b0;
                                        o_addr1 <= '0;
                                        o_addr2 <= '0;
                                    end
                                endcase
                           end
                        endcase

                    end else begin
                        last_cnt <= last_cnt + 1;
                    end
                end 
               
                //-----------------------------------------
                // 마지막 라인 Active
                //-----------------------------------------
                ST_LAST_LINE_ACT : begin
                    last_line <= 1'b1;
                    o_vsync <= ~vsync_pol;
                    o_hsync <= i_hsync;
                    o_de    <= 1'b1; // 1로 강제
                    


                     case (i_mode)
                           2'b01 : begin // 1/2 mode
                            if ((cnt_vact % 2) == 1) begin // 홀수 라인
                                o_cs1   <= 1'b1; o_we1 <= 1'b0;
                                o_cs2   <= 1'b0; o_we2 <= 1'b0;
                                o_addr1 <= p_cnt+1;  o_addr2 <= '0;  
                                o_din1  <= '0;       o_din2  <= '0;
                            end else begin // 짝수 라인
                                o_cs1   <= 1'b0; o_we1 <= 1'b0;
                                o_cs2   <= 1'b1; o_we2 <= 1'b0;
                                o_addr1 <= '0;   o_addr2 <= p_cnt+1;
                                o_din1  <= '0;   o_din2  <= '0;
                             end
                            end

                           2'b10 : begin // 1/3 mode
                            // 3줄 패턴
                                case (cnt_vact % 3)
                                    2'd0: begin
                                        ;
                                    end
                                    2'd1: begin
                                        o_cs1   <= 1'b1; o_we1 <= 1'b0;
                                        o_cs2   <= 1'b0; o_we2 <= 1'b0;
                                        o_addr1 <= p_cnt+1; ;
                                    end
                                    2'd2: begin
                                        o_cs1   <= 1'b1; o_we1 <= 1'b0;
                                        o_cs2   <= 1'b1; o_we2 <= 1'b0;
                                        o_addr1 <= p_cnt+1;;
                                        o_addr2 <= p_cnt+1;;
                                    end
                                endcase
                           end
                        endcase

                    if (p_cnt == HACT-1) begin
                        //p_cnt <= 0;
                        state <= ST_END;
                        last_line <= 1'b0;
                        o_vsync <= ~vsync_pol;
                        o_hsync <= i_hsync;
                        o_de    <= 1'b0;

                        o_cs1   <= 1'b0; o_we1 <= 1'b0;
                        o_cs2   <= 1'b0; o_we2 <= 1'b0;

                        o_addr1 <= '0; 
                        o_addr2 <= '0;  
                        o_din1  <= '0;
                        o_din2  <= '0;
                    end else begin
                        p_cnt <= p_cnt + 1;
                    end
                end

                //-----------------------------------------
                ST_END : begin
                    o_vsync <= ~vsync_pol;
                    o_hsync <= i_hsync;
                    o_de    <= 1'b0;
                  

                    if (vsync_rise) begin
                        p_cnt    <= 0;
                        cnt_vact <= 0;
                        state    <= ST_LINE_DELAY;
                    end
                end
            endcase
        end
        end
    end


logic [DATA_WIDTH-1:0] tap0_bus;  
logic [DATA_WIDTH-1:0] tap1_bus;  

always_comb begin
    tap0_bus = '0;
    tap1_bus = '0;

    case (i_mode)
        2'b01: begin 
            
            if (o_de) begin
                if ((cnt_vact % 2) == 1) tap0_bus = i_dout1;
                else tap0_bus = i_dout2;
            end
        end

        2'b10: begin // 1/3 mode
            //last라인일때, 아직못나간 data나갈수있게
            if (o_de && (cnt_vact % 3) == 2) begin
                tap1_bus = i_dout1; 
                tap0_bus = i_dout2; 
            end else if(last_line && (cnt_vact % 3) == 2)begin
                tap1_bus = i_dout1;  
                tap0_bus = i_dout2; 
            end else if(last_line && (cnt_vact % 3) == 1)begin
                tap0_bus = i_dout1; 
            end
        end

        default: begin
            tap0_bus = '0;
            tap1_bus = '0;
        end
    endcase
end

// 1clk delay cur
// 타이밍 맞춰야함
logic [9:0] d_cur_r, d_cur_g, d_cur_b;

always_ff @( posedge clk or negedge rstn ) begin : blockName
    if(!rstn) begin
        d_cur_r <= 10'd0;
        d_cur_g <= 10'd0;
        d_cur_b <= 10'd0;
    end else begin
        d_cur_r <= i_r_data;
        d_cur_g <= i_g_data;
        d_cur_b <= i_b_data;
    end
end



always_comb begin

    o_cur_r  = 10'd0;
    o_cur_g  = 10'd0;
    o_cur_b  = 10'd0;
    o_tap0_r = 10'd0;
    o_tap0_g = 10'd0;
    o_tap0_b = 10'd0;
    o_tap1_r = 10'd0;
    o_tap1_g = 10'd0;
    o_tap1_b = 10'd0;

    if (!rstn) begin
    end else begin
        if (i_mode == 2'b00) begin
            // BYPASS mode
            if (o_de) begin
                o_cur_r = d_cur_r;
                o_cur_g = d_cur_g;
                o_cur_b = d_cur_b;
            end

        end else begin
            //1/2, 1/3 mode
            if (o_de) begin
                o_cur_r = d_cur_r;
                o_cur_g = d_cur_g;
                o_cur_b = d_cur_b;
            end

            if (o_de) begin
                //rgb 구별
                o_tap0_r = tap0_bus[29:20];
                o_tap0_g = tap0_bus[19:10];
                o_tap0_b = tap0_bus[9:0];

                o_tap1_r = tap1_bus[29:20];
                o_tap1_g = tap1_bus[19:10];
                o_tap1_b = tap1_bus[9:0];
            end
        end
    end
end


// scaler로 보낼 타이밍 신호들!
logic [11:0] y_cnt , x_cnt;

assign x_cnt = p_cnt;
assign y_cnt = cnt_vact;

assign o_x_cnt         = x_cnt;
assign o_y_cnt         = y_cnt;
assign o_y_half  = y_cnt[0];      // y%2
assign o_y_third = y_cnt % 3;     // y%3


  
endmodule