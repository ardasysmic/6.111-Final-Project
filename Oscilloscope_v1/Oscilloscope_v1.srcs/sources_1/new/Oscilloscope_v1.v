`timescale 1ns / 1ps
`include "VerticalScaler.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2016 01:36:27 PM
// Design Name: 
// Module Name: Oscilloscope_v1
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Oscilloscope_v1
   #(parameter  DISPLAY_X_BITS = 11,
                DISPLAY_Y_BITS = 11,
                ADDRESS_BITS = 12,
                RGB_BITS = 12,
                X_MIDDLE_VOLTAGE_CHARACTER_4 = 1_088,
                Y_MIDDLE_VOLTAGE_CHARACTER_4 = 496,
                X_MIDDLE_VOLTAGE_CHARACTER_3 = 1_108,
                Y_MIDDLE_VOLTAGE_CHARACTER_3 = 496,
                X_MIDDLE_VOLTAGE_CHARACTER_2 = 1_128,
                Y_MIDDLE_VOLTAGE_CHARACTER_2 = 496,
                X_MIDDLE_VOLTAGE_CHARACTER_1 = 1_148,
                Y_MIDDLE_VOLTAGE_CHARACTER_1 = 496,
                X_MIDDLE_VOLTAGE_CHARACTER_0 = 1_168,
                Y_MIDDLE_VOLTAGE_CHARACTER_0 = 496,
                X_TIME_PER_DIVISION_CHARACTER_4 = 700,
                Y_TIME_PER_DIVISION_CHARACTER_4 = 980,
                X_TIME_PER_DIVISION_CHARACTER_3 = 720,
                Y_TIME_PER_DIVISION_CHARACTER_3 = 980,
                X_TIME_PER_DIVISION_CHARACTER_2 = 740,
                Y_TIME_PER_DIVISION_CHARACTER_2 = 980,
                X_TIME_PER_DIVISION_CHARACTER_1 = 760,
                Y_TIME_PER_DIVISION_CHARACTER_1 = 980,
                X_TIME_PER_DIVISION_CHARACTER_0 = 780,
                Y_TIME_PER_DIVISION_CHARACTER_0 = 980,
                SELECT_CHARACTER_BITS = 7) 
   (input CLK100MHZ,
   input vauxp11,
   input vauxn11,
   input [13:0] SW,
   input BTNU, input BTND, input BTNC, input BTNL,
   //input reset,
   output wire [15:0] LED,
   output [7:0] an,
   output dp,
   output [6:0] seg,
   output reg VGA_HS,
   output reg VGA_VS,
   output reg [3:0] VGA_R, output reg [3:0] VGA_G, output reg [3:0] VGA_B
    );
    
    wire reset;
    assign reset = 0;
    //debounce rdb(.reset(reset), .clock(CLK100MHZ), .noisy(CPU_RESETN), .clean(reset));
    
    wire CLK108MHZ;
    //instantiate clock divider
    clk_wiz_0 ClockDivider
       (
       // Clock in ports
        .clk_in1(CLK100MHZ),      // input clk_in1
        // Clock out ports
        .clk_out1(CLK108MHZ),    // output clk_out1
        // Status and control signals
        .reset(reset), // input reset
        .locked(locked));
        
    // Scope settings
    wire signed [11:0] triggerThreshold;
    wire [9:0] verticalScaleFactorTimes8;
    wire [5:0] samplePeriod;
    
    
    // these come from MeasureSignal
    wire signed [11:0] signalMin;
    wire signed [11:0] signalMax;
    wire [11:0] signalPeriod;
    wire signed [11:0] signalAverage;
    
    ScopeSettings myss(.clock(CLK108MHZ), .sw(SW[13:6]),
                        .triggerThreshold(triggerThreshold), .verticalScaleFactorTimes8(verticalScaleFactorTimes8),
                        .samplePeriod(samplePeriod),
                        .signalMin(signalMin), .signalMax(signalMax), .signalPeriod(signalPeriod),                        
                        .btnu(btnu_1pulse), .btnd(btnd_1pulse), .btnc(btnc_1pulse), .btnl(btnl_1pulse));
    
    // Button input debouncers
    debounce (.reset(reset), .clock(CLK108MHZ), .noisy(BTNU), .clean(btnu_clean));
    debounce (.reset(reset), .clock(CLK108MHZ), .noisy(BTND), .clean(btnd_clean));
    debounce (.reset(reset), .clock(CLK108MHZ), .noisy(BTNC), .clean(btnc_clean));
    debounce (.reset(reset), .clock(CLK108MHZ), .noisy(BTNL), .clean(btnl_clean));
    
    ButtonSinglePulse(.clock(CLK108MHZ), .btn(btnu_clean), .btn1pulse(btnu_1pulse));
    ButtonSinglePulse(.clock(CLK108MHZ), .btn(btnd_clean), .btn1pulse(btnd_1pulse));
    ButtonSinglePulse(.clock(CLK108MHZ), .btn(btnc_clean), .btn1pulse(btnc_1pulse));
    ButtonSinglePulse(.clock(CLK108MHZ), .btn(btnl_clean), .btn1pulse(btnl_1pulse));
    
    assign LED[9:0] = verticalScaleFactorTimes8;
    
    // XADC IP module
    wire eoc;
    wire ready;
    wire [15:0] XADCdataOut;   
    reg [6:0] Address_in = 7'h1b; // select VAUXP/N11 as input [see Artix 7 XADC]
    //xadc instantiation connect the eoc_out .den_in to get continuous conversion
    xadc_wiz_0  XLXI_7 (.daddr_in(Address_in), //addresses can be found in the artix 7 XADC user guide DRP register space
                         .dclk_in(CLK108MHZ), 
                         .den_in(eoc),
//                         .convst_in(CLK108MHZ), 
                         .di_in(), 
                         .dwe_in(), 
                         .busy_out(),
                         .vauxp11(vauxp11),
                         .vauxn11(vauxn11),
                         .vn_in(),
                         .vp_in(),
                         .alarm_out(),
                         .do_out(XADCdataOut),
                         .reset_in(reset), // ddr
                         .eoc_out(eoc), // ddr high for one cycle on end of conversion
                         .channel_out(),
                         .drdy_out(ready));
      
      // ADC controller
      wire adcc_ready;
      wire adccRawReady;
      wire signed [11:0] ADCCdataOut;
      wire signed [11:0] adccRawDataOut;

      ADCController adcc(
                             .clock(CLK108MHZ),
                             .reset(reset),
                             .sampleEnabled(1),
                             .samplePeriod(samplePeriod),
                             .inputReady(eoc),
                             .dataIn(XADCdataOut[15:4]),
                             .ready(adcc_ready),
                             .dataOut(ADCCdataOut),
                             .rawReady(adccRawReady), // not affected by samplePeriod
                             .rawDataOut(adccRawDataOut)
                             );

//    wire adcc_ready;
//    wire [11:0] ADCCdataOut;
//    assign adcc_ready = 1;
//    FakeADCC adcc(.clock(CLK65MHZ), .dataOut(ADCCdataOut));

   // edge type detector
   wire risingEdgeReady;
   wire signed [13:0] slope;
    EdgeTypeDetector myed
     (.clock(CLK108MHZ),
      .dataReady(adccRawReady),
      .dataIn(adccRawDataOut),
      .risingEdgeReady(risingEdgeReady),
      .estimatedSlope(slope),
      .estimatedSlopeIsPositive(positiveSlope));
    
    wire [11:0] bufferDataOut;
    wire activeBramSelect;
    BufferSelector mybs(
        .clock(CLK108MHZ),
        .drawStarting(drawStarting),
        .activeBramSelect(activeBramSelect)
        );
    
    buffer Buffer (.clock(CLK108MHZ), .ready(adcc_ready), .dataIn(ADCCdataOut),
        .isTrigger(isTriggered), .disableCollection(0), .activeBramSelect(activeBramSelect),
        //.isTrigger(isTriggered), .disableCollection(0), .activeBramSelect(sw[0]),
        .reset(reset),
        .readTriggerRelative(1),
        .readAddress(curveAddressOut),
        .dataOut(bufferDataOut));
    
    wire [11:0] buffer2DataOut;  
    buffer Buffer2 (.clock(CLK108MHZ), .ready(risingEdgeReady), .dataIn(slope),
                .isTrigger(isTriggered), .disableCollection(0), .activeBramSelect(activeBramSelect),
                //.isTrigger(isTriggered), .disableCollection(0), .activeBramSelect(sw[0]),
                .reset(reset),
                .readTriggerRelative(1),
                .readAddress(curveAddressOut2),
                .dataOut(buffer2DataOut));

//    wire [11:0] bufferDataOut;
//    ConstantFakeBuffer buffer(.address(), .dataOut(bufferDataOut));
        
    wire isTriggered;
    TriggerRisingEdgeSteady #(.DATA_BITS(12))
            Trigger
            (.clock(CLK108MHZ),
            .threshold(triggerThreshold),
            .dataReady(adccRawReady),
            .dataIn(adccRawDataOut),
            .triggerDisable(~positiveSlope),
            .isTriggered(isTriggered)
            );
     
     MeasureSignal mymeas
                (
                .clock(CLK108MHZ),
                .dataReady(adccRawReady),
                .dataIn(adccRawDataOut),
                .isTrigger(isTriggered),
                .signalMax(signalMax),
                .signalMin(signalMin),
                .signalPeriod(signalPeriod),
                .signalAverage(signalAverage)
                );
     
     
     // Create display system and sprites    
     wire [DISPLAY_X_BITS-1:0] displayX;
     wire [DISPLAY_Y_BITS-1:0] displayY;
     wire vsync;
     wire hsync;
     wire blank;
     xvga1280_1024 myXVGA(.vclock(CLK108MHZ),
        .displayX(displayX), // pixel number on current line
        .displayY(displayY), // line number
        .vsync(vsync), .hsync(hsync), .blank(blank));
    
    // draw grid lines
    wire [DISPLAY_X_BITS-1:0] gridDisplayX;
    wire [DISPLAY_Y_BITS-1:0] gridDisplayY;
    wire gridVsync;
    wire gridHsync;
    wire gridBlank;
    wire [RGB_BITS-1:0] gridPixel;
    Grid myGrid(.clock(CLK108MHZ), .displayX(displayX), .displayY(displayY), .hsync(hsync), .vsync(vsync), .blank(blank),
                .gridDisplayX(gridDisplayX), .gridDisplayY(gridDisplayY), .gridHsync(gridHsync), 
                .gridVsync(gridVsync), .gridBlank(gridBlank), .pixel(gridPixel));
        
    wire drawStarting;
    wire [ADDRESS_BITS-1:0] curveAddressOut;
    wire [DISPLAY_X_BITS-1:0] curveDisplayX;
    wire [DISPLAY_Y_BITS-1:0] curveDisplayY;
    wire curveHsync;
    wire curveVsync;
    wire curveBlank;
    wire [RGB_BITS-1:0] curvePixel;
    
    wire [11:0] dataIn;
    assign dataIn = bufferDataOut;
    Curve #(.ADDRESS_BITS(ADDRESS_BITS))
            myCurve
            (.clock(CLK108MHZ),
            .dataIn(dataIn),
            .verticalScaleFactorTimes8(verticalScaleFactorTimes8),
            //.verticalScaleFactorTimes8(SW[13:6]),
            .displayX(gridDisplayX),
            .displayY(gridDisplayY),
            .hsync(gridHsync),
            .vsync(gridVsync),
            .blank(gridBlank),
            .previousPixel(gridPixel),
            .pixel(curvePixel),
            .drawStarting(drawStarting),
            .address(curveAddressOut),
            .curveDisplayX(curveDisplayX),
            .curveDisplayY(curveDisplayY),
            .curveHsync(curveHsync),
            .curveVsync(curveVsync),
            .curveBlank(curveBlank)
            );
            
    wire [ADDRESS_BITS-1:0] curveAddressOut2;
    wire [DISPLAY_X_BITS-1:0] curveDisplayX2;
    wire [DISPLAY_Y_BITS-1:0] curveDisplayY2;
    wire curveHsync2;
    wire curveVsync2;
    wire curveBlank2;
    wire [RGB_BITS-1:0] curvePixel2;
            
            wire [11:0] dataIn2;
            assign dataIn2 = buffer2DataOut;
            Curve #(.ADDRESS_BITS(ADDRESS_BITS), .RGB_COLOR(12'h0FF))
                    myCurve2
                    (.clock(CLK108MHZ),
                    .dataIn(dataIn2),
                    .verticalScaleFactorTimes8(0),
                    .displayX(curveDisplayX),
                    .displayY(curveDisplayY),
                    .hsync(curveHsync),
                    .vsync(curveVsync),
                    .blank(curveBlank),
                    .previousPixel(curvePixel),
                    .pixel(curvePixel2),
                    .drawStarting(),
                    .address(curveAddressOut2),
                    .curveDisplayX(curveDisplayX2),
                    .curveDisplayY(curveDisplayY2),
                    .curveHsync(curveHsync2),
                    .curveVsync(curveVsync2),
                    .curveBlank(curveBlank2)
                    );
     
     wire [RGB_BITS-1:0] tlsPixel;
     wire [DISPLAY_X_BITS-1:0] tlsDisplayX;
     wire [DISPLAY_Y_BITS-1:0] tlsDisplayY;
     wire tlsHsync, tlsVsync, tlsBlank;
     HorizontalLineSprite mytls
                (.clock(CLK108MHZ),
                //.level(`VERTICAL_SCALE(triggerThreshold, verticalShiftLeftFactor)),
                .level(triggerThreshold * $signed(verticalScaleFactorTimes8) / 'sd8),
                .displayX(curveDisplayX2),
                .displayY(curveDisplayY2),
                .hsync(curveHsync2),
                .vsync(curveVsync2),
                .blank(curveBlank2),
                .previousPixel(curvePixel2),
                .pixel(tlsPixel),
                .spriteDisplayX(tlsDisplayX),
                .spriteDisplayY(tlsDisplayY),
                .spriteHsync(tlsHsync),
                .spriteVsync(tlsVsync),
                .spriteBlank(tlsBlank)
                );    
                  
    wire textHsync, textVsync, textBlank;
    wire [RGB_BITS-1:0] textPixel;
    wire [DISPLAY_X_BITS-1:0] textDisplayX;
    wire [DISPLAY_Y_BITS-1:0] textDisplayY;
    wire [SELECT_CHARACTER_BITS-1:0] middleVoltageCharacter4;
    assign middleVoltageCharacter4 = 7'd21;
    wire [SELECT_CHARACTER_BITS-1:0] middleVoltageCharacter3;
    assign middleVoltageCharacter3 = 7'd16;
    wire [SELECT_CHARACTER_BITS-1:0] middleVoltageCharacter2;
    assign middleVoltageCharacter2 = 7'd16;
    wire [SELECT_CHARACTER_BITS-1:0] middleVoltageCharacter1;
    assign middleVoltageCharacter1 = 7'd77;
    wire [SELECT_CHARACTER_BITS-1:0] middleVoltageCharacter0;
    assign middleVoltageCharacter0 = 7'd54;
    wire [SELECT_CHARACTER_BITS-1:0] timePerDivisionCharacter4;
    assign timePerDivisionCharacter4 = 7'd0;
    wire [SELECT_CHARACTER_BITS-1:0] timePerDivisionCharacter3;
    assign timePerDivisionCharacter3 = 7'd17;
    wire [SELECT_CHARACTER_BITS-1:0] timePerDivisionCharacter2;
    assign timePerDivisionCharacter2 = 7'd16;
    wire [SELECT_CHARACTER_BITS-1:0] timePerDivisionCharacter1;
    assign timePerDivisionCharacter1 = 7'd77;
    wire [SELECT_CHARACTER_BITS-1:0] timePerDivisionCharacter0;
    assign timePerDivisionCharacter0 = 7'd83;
    Text myText (.clock(CLK108MHZ), 
        .xMiddleVoltage4(X_MIDDLE_VOLTAGE_CHARACTER_4), .yMiddleVoltage4(Y_MIDDLE_VOLTAGE_CHARACTER_4), .middleVoltageCharacter4(middleVoltageCharacter4),
        .xMiddleVoltage3(X_MIDDLE_VOLTAGE_CHARACTER_3), .yMiddleVoltage3(Y_MIDDLE_VOLTAGE_CHARACTER_3), .middleVoltageCharacter3(middleVoltageCharacter3),
        .xMiddleVoltage2(X_MIDDLE_VOLTAGE_CHARACTER_2), .yMiddleVoltage2(Y_MIDDLE_VOLTAGE_CHARACTER_2), .middleVoltageCharacter2(middleVoltageCharacter2),
        .xMiddleVoltage1(X_MIDDLE_VOLTAGE_CHARACTER_1), .yMiddleVoltage1(Y_MIDDLE_VOLTAGE_CHARACTER_1), .middleVoltageCharacter1(middleVoltageCharacter1),
        .xMiddleVoltage0(X_MIDDLE_VOLTAGE_CHARACTER_0), .yMiddleVoltage0(Y_MIDDLE_VOLTAGE_CHARACTER_0), .middleVoltageCharacter0(middleVoltageCharacter0),
        .xTimePerDivision4(X_TIME_PER_DIVISION_CHARACTER_4), .yTimePerDivision4(Y_TIME_PER_DIVISION_CHARACTER_4), .timePerDivisionCharacter4(timePerDivisionCharacter4),
        .xTimePerDivision3(X_TIME_PER_DIVISION_CHARACTER_3), .yTimePerDivision3(Y_TIME_PER_DIVISION_CHARACTER_3), .timePerDivisionCharacter3(timePerDivisionCharacter3),
        .xTimePerDivision2(X_TIME_PER_DIVISION_CHARACTER_2), .yTimePerDivision2(Y_TIME_PER_DIVISION_CHARACTER_2), .timePerDivisionCharacter2(timePerDivisionCharacter2),
        .xTimePerDivision1(X_TIME_PER_DIVISION_CHARACTER_1), .yTimePerDivision1(Y_TIME_PER_DIVISION_CHARACTER_1), .timePerDivisionCharacter1(timePerDivisionCharacter1),
        .xTimePerDivision0(X_TIME_PER_DIVISION_CHARACTER_0), .yTimePerDivision0(Y_TIME_PER_DIVISION_CHARACTER_0), .timePerDivisionCharacter0(timePerDivisionCharacter0),
        .displayX(tlsDisplayX), .displayY(tlsDisplayY), 
        .hsync(tlsHsync), .vsync(tlsVsync), .blank(tlsBlank), .previousPixel(tlsPixel),
        .displayXOut(textDisplayX), .displayYOut(textDisplayY), 
        .hsyncOut(textHsync), .vsyncOut(textVsync), .blankOut(textBlank), .pixel(textPixel), .addressA(addressA));
     
     always @(posedge CLK108MHZ) begin
        {VGA_R, VGA_G, VGA_B} <= !textBlank ? textPixel : 12'b0;
        VGA_HS <= tlsHsync;
        VGA_VS <= tlsVsync;
     end
         
endmodule
