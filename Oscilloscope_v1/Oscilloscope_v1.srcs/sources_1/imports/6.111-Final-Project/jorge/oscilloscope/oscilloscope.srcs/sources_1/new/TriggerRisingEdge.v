`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2016 12:43:05 PM
// Design Name: 
// Module Name: TriggerRisingEdge
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


module TriggerRisingEdge
    #(parameter DATA_BITS = 12)
    (input clock,
    input [DATA_BITS-1:0] threshold,
    input [DATA_BITS-1:0] dataIn,
    input triggerDisable,
    output isTriggered
    );
    
    reg [DATA_BITS-1:0] previousData;

    always @(posedge clock) begin
        previousData <= dataIn;
    end
    
    assign isTriggered = (previousData<threshold && dataIn>=threshold && !triggerDisable);
        
endmodule