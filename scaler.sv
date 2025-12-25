//======================================================
//   - i_mode : 00 BYPASS, 01 1/2, 10 1/3
//   - i_method : 00 : sampling , 01: average, 10 : cross
//
//       i_mode ==00 이면 해당사항 X 무조건 바이패스
//       i_mode ==01 이면 i_method[0]만 고려
//       i_mode ==10 이면 i_methode모두 고려  
//======================================================
// 1/2 패딩 : 가로, 세로 , 가로/세로 겹치는 부분 모두 지원함
// 1/3 패딩 : 가로 1픽셀, 2픽셀 지원 
//          : 세로 1픽셀(%3==2) 지원 (2픽셀은 구현 못함)
//=======================================================
//   R/G/B 모두 구현
//========================================================
// sync : bypass-> 1pclk delay
//      : 1/2mode-> 3pclk delay
//      : 1/3mode-> 4pclk delay
// 싱크는 de 시작점에 맞춰서 delay시켜줬음
//======================================================

module scaler_core #(
    parameter int DATA_WIDTH = 10
)(
    input  logic                  clk,
    input  logic                  rstn,
    input  logic                  i_vsync,
    input  logic                  i_hsync,
    // 00:bypass, 01:1/2, 10:1/3
    input  logic [1:0]            i_mode,        
    //  00:sampling , 01: average , 10: cross 
    input  logic [1:0]            i_method,        
   
    // -------- from line buffer (3-tap) --------
    input  logic                  i_de,
    input  logic [DATA_WIDTH-1:0] i_cur_r,
    input  logic [DATA_WIDTH-1:0] i_cur_g,
    input  logic [DATA_WIDTH-1:0] i_cur_b,

    input  logic [DATA_WIDTH-1:0] i_tap0_r,
    input  logic [DATA_WIDTH-1:0] i_tap0_g,
    input  logic [DATA_WIDTH-1:0] i_tap0_b,

    input  logic [DATA_WIDTH-1:0] i_tap1_r,
    input  logic [DATA_WIDTH-1:0] i_tap1_g,
    input  logic [DATA_WIDTH-1:0] i_tap1_b,

    input  logic [11:0]           i_x_cnt,
    input  logic [11:0]           i_y_cnt,
    input  logic                  i_y_half,   // y % 2
    input  logic [1:0]            i_y_third,  // y % 3
    input  logic                  last_line,

    // -------- scaled output --------
    output logic                  o_de_scaled,
    output logic [DATA_WIDTH-1:0] o_r_scaled,
    output logic [DATA_WIDTH-1:0] o_g_scaled,
    output logic [DATA_WIDTH-1:0] o_b_scaled,

    // sync 맞추기
    output logic o_vsync,
    output logic o_hsync
);

//de falling edge 확인
//last 라인 확인
reg d_de, d_last_line;
wire fall_de;
reg fall_last_line;

always_ff @( posedge clk or negedge rstn ) begin 
    if(!rstn)begin
        d_de <=0;
        d_last_line <=0;
        fall_last_line <=0; // 패딩하기 위한
    end else begin
        d_de <= i_de;
        d_last_line <= last_line;
        if((d_last_line==1'b1) && (last_line == 1'b0)) begin
            fall_last_line <= 1'b1;
        end else begin
            fall_last_line <= 1'b0;
        end
    end
end

assign fall_de = (d_de==1'b1) && (i_de==1'b0);



 //================================================================================
  // 1/2 스케일: 2x2 윈도우
  // 2-stage shift (d0, d1)
  //==============================================================================

    // cur 라인 (2x2용)
    logic [DATA_WIDTH-1:0] cur_r_d0_2,  cur_r_d1_2;
    logic [DATA_WIDTH-1:0] cur_g_d0_2,  cur_g_d1_2;
    logic [DATA_WIDTH-1:0] cur_b_d0_2,  cur_b_d1_2;

    // tap0 라인 (2x2용)
    logic [DATA_WIDTH-1:0] tap0_r_d0_2, tap0_r_d1_2;
    logic [DATA_WIDTH-1:0] tap0_g_d0_2, tap0_g_d1_2;
    logic [DATA_WIDTH-1:0] tap0_b_d0_2, tap0_b_d1_2;

    // x 방향 2픽셀 시프트 (cur/tap0)
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            cur_r_d0_2  <= '0; cur_r_d1_2  <= '0;
            cur_g_d0_2  <= '0; cur_g_d1_2  <= '0;
            cur_b_d0_2  <= '0; cur_b_d1_2  <= '0;

            tap0_r_d0_2 <= '0; tap0_r_d1_2 <= '0;
            tap0_g_d0_2 <= '0; tap0_g_d1_2 <= '0;
            tap0_b_d0_2 <= '0; tap0_b_d1_2 <= '0;
        end
        else if (i_de) begin
            // cur
            cur_r_d1_2  <= cur_r_d0_2;
            cur_r_d0_2  <= i_cur_r;

            cur_g_d1_2  <= cur_g_d0_2;
            cur_g_d0_2  <= i_cur_g;

            cur_b_d1_2  <= cur_b_d0_2;
            cur_b_d0_2  <= i_cur_b;

            // tap0
            tap0_r_d1_2 <= tap0_r_d0_2;
            tap0_r_d0_2 <= i_tap0_r;

            tap0_g_d1_2 <= tap0_g_d0_2;
            tap0_g_d0_2 <= i_tap0_g;

            tap0_b_d1_2 <= tap0_b_d0_2;
            tap0_b_d0_2 <= i_tap0_b;
        end
    end


    logic calc_en_half ;
    logic last_pix_pad;  //가로패딩
    logic last_pix_pad_line; //가로세로패딩겹치는구간

    // i_x_cnt홀수  + i_de==1 +
    // i_y_half==1  다음 클락에 enable!
    always_ff @( posedge clk or negedge  rstn ) begin 
        if(!rstn) begin
            calc_en_half <= 1'b0;
            last_pix_pad <= 1'b0;
            last_pix_pad_line<=1'b0;
        end else begin
            if(last_line && (i_y_cnt%2==0))begin
                calc_en_half <=1'b0; // 마지막 read라인 + 짝수라인을 가진..-> X
            end else if (last_line && (i_y_cnt%2 ==1) && (i_y_half) && (i_x_cnt%2==1)) begin
                calc_en_half <= 1'b1; // 마지막 read라인 + 홀수라인을 가진..-> O
            end else if (i_de && (i_y_half) && (i_x_cnt%2==1) ) begin
                calc_en_half <= 1'b1; 
            end else if (!((d_last_line==1'b1) && (last_line == 1'b0) ) &&
                        fall_de && (i_x_cnt%2==0)&& (!i_y_half)) begin
                            //가로패딩
                calc_en_half <= 1'b1; 
                last_pix_pad <= 1'b1;
            end else if ((d_last_line==1'b1) && (last_line == 1'b0) 
                        && fall_de && (i_x_cnt%2==0) && (i_y_half))  begin
                            // 가로세로패딩
                calc_en_half <= 1'b1; 
                last_pix_pad_line <= 1'b1;  
                         
            end else begin
                calc_en_half <= 1'b0;
                last_pix_pad <= 1'b0;
                last_pix_pad_line <=1'b0;
            end
        end
    end
   


    // 2x2 평균 (채널별 합 4개 → >>2)
    logic [DATA_WIDTH+1:0] sum_r2, sum_g2, sum_b2;
    logic [DATA_WIDTH-1:0] avg_r2, avg_g2, avg_b2;

    // 2x2 sampling 결과 (예: cur 라인의 중앙 픽셀 사용)
    logic [DATA_WIDTH-1:0] samp_r2, samp_g2, samp_b2;

    always_comb begin
        if (last_pix_pad_line) begin
            sum_r2 = (tap0_r_d0_2)*4;
            sum_g2 = (tap0_g_d0_2)*4;
            sum_b2 = (tap0_b_d0_2)*4;
        end else if (last_line) begin
            // 마지막 라인은 곱하기2배해서 나눠줘야함!
            // padding 
            // (i_y_cnt%2==0) 일때는 어짜피 en X
            sum_r2 = (tap0_r_d0_2 + tap0_r_d1_2)*2;
            sum_g2 = (tap0_g_d0_2 + tap0_g_d1_2)*2;
            sum_b2 = (tap0_b_d0_2 + tap0_b_d1_2)*2;
        end else if(last_pix_pad)begin
            // 라스트 픽셀이 홀수라서 패딩
            sum_r2 = (cur_r_d0_2 + tap0_r_d0_2)*2;
            sum_g2 = (cur_g_d0_2 + tap0_g_d0_2)*2;
            sum_b2 = (cur_b_d0_2 + tap0_b_d0_2)*2;
        end else begin
            sum_r2 = cur_r_d0_2  + cur_r_d1_2
               + tap0_r_d0_2 + tap0_r_d1_2;
            sum_g2 = cur_g_d0_2  + cur_g_d1_2
               + tap0_g_d0_2 + tap0_g_d1_2;

            sum_b2 = cur_b_d0_2  + cur_b_d1_2
               + tap0_b_d0_2 + tap0_b_d1_2;

        end

        avg_r2 = sum_r2 >> 2;   // /4
        avg_g2 = sum_g2 >> 2;
        avg_b2 = sum_b2 >> 2;

        // ------ 2x2 sampling ------
        if (last_pix_pad_line) begin
            samp_r2 = tap0_r_d0_2;   
            samp_g2 = tap0_g_d0_2;
            samp_b2 = tap0_b_d0_2;
        end else if (last_line) begin
            samp_r2 = tap0_r_d1_2;   
            samp_g2 = tap0_g_d1_2;
            samp_b2 = tap0_b_d1_2;
        end else if(last_pix_pad)begin
            samp_r2 = tap0_r_d0_2;   
            samp_g2 = tap0_g_d0_2;
            samp_b2 = tap0_b_d0_2;
        end else begin
            samp_r2 = tap0_r_d1_2;   
            samp_g2 = tap0_g_d1_2;
            samp_b2 = tap0_b_d1_2;
        end

    
    end

    

//========================================================================
// 1/3 스케일 : 3x3 윈도우 (각 라인별 3픽셀 시프트)
//====================================================================
    // cur 라인
    logic [DATA_WIDTH-1:0] cur_r_d0,  cur_r_d1_3,  cur_r_d2_3;
    logic [DATA_WIDTH-1:0] cur_g_d0,  cur_g_d1_3,  cur_g_d2_3;
    logic [DATA_WIDTH-1:0] cur_b_d0,  cur_b_d1_3,  cur_b_d2_3;
    // tap0 라인
    logic [DATA_WIDTH-1:0] tap0_r_d0, tap0_r_d1_3, tap0_r_d2_3;
    logic [DATA_WIDTH-1:0] tap0_g_d0, tap0_g_d1_3, tap0_g_d2_3;
    logic [DATA_WIDTH-1:0] tap0_b_d0, tap0_b_d1_3, tap0_b_d2_3;
    // tap1 라인
    logic [DATA_WIDTH-1:0] tap1_r_d0, tap1_r_d1_3, tap1_r_d2_3;
    logic [DATA_WIDTH-1:0] tap1_g_d0, tap1_g_d1_3, tap1_g_d2_3;
    logic [DATA_WIDTH-1:0] tap1_b_d0, tap1_b_d1_3, tap1_b_d2_3;

    // x 방향 3픽셀 시프트
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            cur_r_d0  <= '0; cur_r_d1_3  <= '0; cur_r_d2_3  <= '0;
            cur_g_d0  <= '0; cur_g_d1_3  <= '0; cur_g_d2_3  <= '0;
            cur_b_d0  <= '0; cur_b_d1_3  <= '0; cur_b_d2_3  <= '0;

            tap0_r_d0 <= '0; tap0_r_d1_3 <= '0; tap0_r_d2_3 <= '0;
            tap0_g_d0 <= '0; tap0_g_d1_3 <= '0; tap0_g_d2_3 <= '0;
            tap0_b_d0 <= '0; tap0_b_d1_3 <= '0; tap0_b_d2_3 <= '0;

            tap1_r_d0 <= '0; tap1_r_d1_3 <= '0; tap1_r_d2_3 <= '0;
            tap1_g_d0 <= '0; tap1_g_d1_3 <= '0; tap1_g_d2_3 <= '0;
            tap1_b_d0 <= '0; tap1_b_d1_3 <= '0; tap1_b_d2_3 <= '0;
        end
        else if (i_de) begin
            // cur
            cur_r_d2_3 <= cur_r_d1_3;
            cur_r_d1_3 <= cur_r_d0;
            cur_r_d0   <= i_cur_r;

            cur_g_d2_3 <= cur_g_d1_3;
            cur_g_d1_3 <= cur_g_d0;
            cur_g_d0   <= i_cur_g;

            cur_b_d2_3 <= cur_b_d1_3;
            cur_b_d1_3 <= cur_b_d0;
            cur_b_d0   <= i_cur_b;

            // tap0
            tap0_r_d2_3 <= tap0_r_d1_3;
            tap0_r_d1_3 <= tap0_r_d0;
            tap0_r_d0   <= i_tap0_r;

            tap0_g_d2_3 <= tap0_g_d1_3;
            tap0_g_d1_3 <= tap0_g_d0;
            tap0_g_d0   <= i_tap0_g;

            tap0_b_d2_3 <= tap0_b_d1_3;
            tap0_b_d1_3 <= tap0_b_d0;
            tap0_b_d0   <= i_tap0_b;

            // tap1
            tap1_r_d2_3 <= tap1_r_d1_3;
            tap1_r_d1_3 <= tap1_r_d0;
            tap1_r_d0   <= i_tap1_r;

            tap1_g_d2_3 <= tap1_g_d1_3;
            tap1_g_d1_3 <= tap1_g_d0;
            tap1_g_d0   <= i_tap1_g;

            tap1_b_d2_3 <= tap1_b_d1_3;
            tap1_b_d1_3 <= tap1_b_d0;
            tap1_b_d0   <= i_tap1_b;
        end
    end

    // x % 3 카운터
    logic [1:0] x_mod3;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            x_mod3 <= 2'd0;
        end
        else if (!i_de) begin
            x_mod3 <= 2'd0;
        end
        else if (x_mod3 == 2'd2) begin
            x_mod3 <= 2'd0;
        end
        else begin
            x_mod3 <= x_mod3 + 2'd1;
        end
    end

    


    logic calc_en_third;
    logic last_pix_pad_3_1;
    logic last_pix_pad_3_2;
    logic last_pix_pad_en;
    logic last_line_3_1;


    // i_x_cnt홀수  + i_de==1 +
    // i_y_half==1  다음 클락에 enable!
    always_ff @( posedge clk or negedge  rstn ) begin 
        if(!rstn) begin
            calc_en_third <= 1'b0;
            last_line_3_1 <=1'b0;
        end else begin
            // last line
            // 세로%3 ==2
            if (last_line && (i_y_third==2'd2)&&(x_mod3==2'd2))begin
                calc_en_third <= 1'b1;
                last_line_3_1 <=1'b1;
            end
            // no last_line
            else if(i_de&& (i_y_third==2'd2)&&(x_mod3==2'd2)) begin
                calc_en_third <= 1'b1; 
            end else if (fall_de&& (i_y_third==2'd0)
                &&(x_mod3==2'd2)&&(i_x_cnt!=0)) begin
                calc_en_third <= 1'b1; 
            end else if (last_pix_pad_en) begin
                calc_en_third <= 1'b1; 
            end else begin
                calc_en_third <= 1'b0; 
                last_line_3_1 <=1'b0;
            end
        end
    end

    always_ff @( posedge clk or negedge  rstn ) begin 
        if(!rstn) begin
            last_pix_pad_3_1<= 1'b0;
            last_pix_pad_3_2<= 1'b0;
        end else begin
            if(fall_de&& (i_y_third==2'd0)&&
                (x_mod3==2'd2)&&(i_x_cnt!=0)) begin
                last_pix_pad_3_1<= 1'b1; 
            end else if(last_pix_pad_en) begin
                last_pix_pad_3_2<= 1'b1; 
            end else begin
                last_pix_pad_3_1<= 1'b0; 
                last_pix_pad_3_2<= 1'b0;
            end
        end
    end

    // %3==1 -> 2번 딜레이 필요해서 en 신호 따로 만들어줌

    always_ff @( posedge clk or negedge rstn ) begin : blockName
        if(!rstn) begin
            last_pix_pad_en <=0;
        end else begin
            if(fall_de&& (i_y_third==2'd0)&&
                (x_mod3==2'd1) &&(i_x_cnt!=0)) begin
                last_pix_pad_en <=1; 
            end else begin
                last_pix_pad_en <=0;
            end
        
        end
    end
   
   
        

    // 3x3 평균 (채널별 합 9개 → /9)
    logic [DATA_WIDTH+3:0] sum_r3, sum_g3, sum_b3;
    logic [DATA_WIDTH-1:0] avg_r3, avg_g3, avg_b3;

    // 3x3 sampling / cross 후보
    logic [DATA_WIDTH-1:0] samp_r3, samp_g3, samp_b3;
    logic [DATA_WIDTH-1:0] cross_r3, cross_g3, cross_b3;
    logic [DATA_WIDTH+2:0] sum_r3_cross, sum_g3_cross, sum_b3_cross;


    always_comb begin
        
        if (last_line_3_1) begin // 세로라인%3 ==2d일떄
            sum_r3 = (tap0_r_d2_3+tap0_r_d1_3 + tap0_r_d0 ) *2
                    + (tap1_r_d2_3 + tap1_r_d1_3 + tap1_r_d0 ) ;
            sum_g3 = (tap0_g_d2_3+tap0_g_d1_3 + tap0_g_d0 ) *2
                    + (tap1_g_d2_3 + tap1_g_d1_3 + tap1_g_d0 ) ;
            sum_b3 = (tap0_b_d2_3+tap0_b_d1_3 + tap0_b_d0 ) *2
                    + (tap1_b_d2_3 + tap1_b_d1_3 + tap1_b_d0 ) ;
        end  else if(last_pix_pad_3_2) begin //1순위
            // 가로픽셀%3 ==1 일때
           sum_r3 = (tap1_r_d0 + tap0_r_d0 + cur_r_d0)*3; // 패딩!
           sum_g3 = (tap1_g_d0 + tap0_g_d0 + cur_g_d0)*3; 
           sum_b3 = (tap1_b_d0 + tap0_b_d0 + cur_b_d0)*3; 
        end else if ( last_pix_pad_3_1)begin // 2순위
             // 가로픽셀%3 ==2 일때
           sum_r3 = (tap1_r_d0 + tap0_r_d0 + cur_r_d0)*2
                    +tap1_r_d1_3 + tap0_r_d1_3 + cur_r_d1_3 ; // 패딩!
           sum_g3 = (tap1_g_d0 + tap0_g_d0 + cur_g_d0)*2
                    +tap1_g_d1_3 + tap0_g_d1_3 + cur_g_d1_3 ; 
           sum_b3 = (tap1_b_d0 + tap0_b_d0 + cur_b_d0)*2
                    +tap1_b_d1_3 + tap0_b_d1_3 + cur_b_d1_3 ;
        end else begin
            // 가로픽셀%3==0 일때 
            sum_r3 = tap1_r_d2_3 + tap1_r_d1_3 + tap1_r_d0
               + tap0_r_d2_3 + tap0_r_d1_3 + tap0_r_d0
               + cur_r_d2_3  + cur_r_d1_3  + cur_r_d0;

            sum_g3 = tap1_g_d2_3 + tap1_g_d1_3 + tap1_g_d0
                + tap0_g_d2_3 + tap0_g_d1_3 + tap0_g_d0
                + cur_g_d2_3  + cur_g_d1_3  + cur_g_d0;

            sum_b3 = tap1_b_d2_3 + tap1_b_d1_3 + tap1_b_d0
                + tap0_b_d2_3 + tap0_b_d1_3 + tap0_b_d0
                + cur_b_d2_3  + cur_b_d1_3  + cur_b_d0;

        end
       
        avg_r3 = sum_r3 / 9;
        avg_g3 = sum_g3 / 9;
        avg_b3 = sum_b3 / 9;

        // ----- 3x3 sampling -----
        // 왼쪽 맨위 (가장과거의 픽셀)

         if(last_pix_pad_3_2)begin
            samp_r3 = tap1_r_d0;
            samp_g3 = tap1_g_d0;
            samp_b3 = tap1_b_d0;
        end else if(last_pix_pad_3_1) begin
            samp_r3 = tap1_r_d1_3;
            samp_g3 = tap1_g_d1_3;
            samp_b3 = tap1_b_d1_3;
        end else begin
            //(last_line && (i_y_third==2'd2)&&(x_mod3==2'd2)
            //(fall_last_line && (i_y_third==2'd2)
            samp_r3 = tap1_r_d2_3;
            samp_g3 = tap1_g_d2_3;
            samp_b3 = tap1_b_d2_3;
        end
        

        // ----- 3x3 cross 
        if(last_pix_pad_3_2)begin
            sum_r3_cross = tap1_r_d0 + cur_r_d0 + tap0_r_d0*4;
            sum_g3_cross = tap1_g_d0 + cur_g_d0 + tap0_g_d0*4;
            sum_b3_cross = tap1_b_d0 + cur_b_d0 + tap0_b_d0*4;
        end else if(last_pix_pad_3_1) begin
            sum_r3_cross = tap1_r_d0 + cur_r_d0 + tap0_r_d0*3 + tap0_r_d1_3;
            sum_g3_cross = tap1_g_d0 + cur_g_d0 + tap0_g_d0*3 + tap0_g_d1_3;
            sum_b3_cross = tap1_b_d0 + cur_b_d0 + tap0_b_d0*3 + tap0_b_d1_3;
        end else begin
            sum_r3_cross = tap1_r_d1_3 + cur_r_d1_3 + tap0_r_d1_3*2
                    + tap0_r_d0   + tap0_r_d2_3;
            sum_g3_cross = tap1_g_d1_3 + cur_g_d1_3 + tap0_g_d1_3*2
                        + tap0_g_d0   + tap0_g_d2_3;
            sum_b3_cross = tap1_b_d1_3 + cur_b_d1_3 + tap0_b_d1_3*2
                        + tap0_b_d0   + tap0_b_d2_3;
        end
        

        cross_r3 = sum_r3_cross / 6;
        cross_g3 = sum_g3_cross / 6;
        cross_b3 = sum_b3_cross / 6;
    end


    // sync 3clk delay용 레지스터
    logic vsync_d0, vsync_d1, vsync_d2;
    logic hsync_d0, hsync_d1, hsync_d2;

    // 3-stage shift
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            vsync_d0 <= 1'b0;
            vsync_d1 <= 1'b0;
            vsync_d2 <= 1'b0;
            hsync_d0 <= 1'b0;
            hsync_d1 <= 1'b0;
            hsync_d2 <= 1'b0;
        end
        else begin
            vsync_d0 <= i_vsync;
            vsync_d1 <= vsync_d0;
            vsync_d2 <= vsync_d1;

            hsync_d0 <= i_hsync;
            hsync_d1 <= hsync_d0;
            hsync_d2 <= hsync_d1;
        end
    end






//==========================================
// 싱크 딜레이 
// 모드에 따라 de 시작점을 맞춰서
// 같이 딜레이 시켜줌!
//==========================================

    always_ff @( posedge clk or negedge rstn ) begin 
        if(!rstn) begin
            o_vsync <= 1'b0;
            o_hsync <= 1'b0;
        end else begin
            if(i_mode==2'b00) begin // 1pclk뒤 바로
                o_vsync <= i_vsync; //i_vsync는 버퍼컨트롤러로 부터 받는 신호
                o_hsync <= i_hsync;
            end else if(i_mode==2'b01) begin
                o_vsync <=vsync_d1; 
                o_hsync <=hsync_d1;
            end else if(i_mode==2'b10)begin
                o_vsync <= vsync_d2; 
                o_hsync <= hsync_d2;
            end
        end
    end



//==========================================
// 최종 출력 MUX (DE=0일 때 항상 0 출력)
//==========================================

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            o_de_scaled <= 1'b0;
            o_r_scaled  <= '0;
            o_g_scaled  <= '0;
            o_b_scaled  <= '0;
        end
        else begin

             case (i_mode)
                2'b00: begin // BYPASS (i_method 무시)
                    o_de_scaled <= i_de;
                    if (i_de) begin
                        o_r_scaled <= i_cur_r;
                        o_g_scaled <= i_cur_g;
                        o_b_scaled <= i_cur_b;
                    end
                    else begin
                        o_r_scaled <= '0;
                        o_g_scaled <= '0;
                        o_b_scaled <= '0;
                    end
                end

                2'b01: begin // 1/2 스케일
                    o_de_scaled <= calc_en_half;
                    if (calc_en_half) begin
                        // i_method[0]만 사용 (bit1은 don't care)
                        if (i_method[0] == 1'b0) begin
                            // sampling
                            o_r_scaled <= samp_r2;
                            o_g_scaled <= samp_g2;
                            o_b_scaled <= samp_b2;
                        end
                        else begin
                            // average
                            o_r_scaled <= avg_r2;
                            o_g_scaled <= avg_g2;
                            o_b_scaled <= avg_b2;
                        end
                    end
                    else begin
                        o_r_scaled <= '0;
                        o_g_scaled <= '0;
                        o_b_scaled <= '0;
                    end
                end

                2'b10: begin // 1/3 스케일
                    o_de_scaled <= calc_en_third;
                    if (calc_en_third) begin
                        unique case (i_method)
                            2'b00: begin // sampling
                                o_r_scaled <= samp_r3;
                                o_g_scaled <= samp_g3;
                                o_b_scaled <= samp_b3;
                            end
                            2'b01: begin // average
                                o_r_scaled <= avg_r3;
                                o_g_scaled <= avg_g3;
                                o_b_scaled <= avg_b3;
                            end
                            2'b10: begin // cross
                                o_r_scaled <= cross_r3;
                                o_g_scaled <= cross_g3;
                                o_b_scaled <= cross_b3;
                            end
                            default: begin
                                //  average로
                                o_r_scaled <= avg_r3;
                                o_g_scaled <= avg_g3;
                                o_b_scaled <= avg_b3;
                            end
                        endcase
                    end
                    else begin
                        o_r_scaled <= '0;
                        o_g_scaled <= '0;
                        o_b_scaled <= '0;
                    end
                end

                default: begin
                    o_de_scaled <= 1'b0;
                    o_r_scaled  <= '0;
                    o_g_scaled  <= '0;
                    o_b_scaled  <= '0;
                end
            endcase
        end
    end

    



endmodule
