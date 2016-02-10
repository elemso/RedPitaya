////////////////////////////////////////////////////////////////////////////////
// Module: Acquire
// Author: Iztok Jeras
// (c) Red Pitaya  (redpitaya.com)
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module asg_tb #(
  // clock time periods
  realtime  TP = 4.0ns,  // 250MHz
  // trigger
  int unsigned TN = 1,
  // data parameters
  int unsigned DWO = 14,  // RAM data width
  int unsigned DWM = 16,  // data width for multiplier (gain)
  // buffer parameters
  int unsigned CWM = 14,  // counter width magnitude (fixed point integer)
  int unsigned CWF = 16   // counter width fraction  (fixed point fraction)
);

localparam int unsigned DN = 1;
localparam type DAT_T = logic signed [DWO-1:0];

// system signals
logic          clk ;  // clock
logic          rstn;  // reset - active low

// control
logic               ctl_rst;  // set FSM to reset
// trigger
logic      [TN-1:0] trg_i  ;  // input
logic               trg_o  ;  // output event
// interrupts
logic               irq_trg;  // trigger
logic               irq_stp;  // stop
// configuration
logic      [TN-1:0] cfg_trg;  // trigger mask
logic [CWM+CWF-1:0] cfg_siz;  // data tablesize
logic [CWM+CWF-1:0] cfg_stp;  // pointer step    size
logic [CWM+CWF-1:0] cfg_off;  // pointer initial offset (used to define phase)
// configuration (burst mode)
logic               cfg_ben;  // burst enable
logic               cfg_inf;  // infinite
logic     [CWM-1:0] cfg_bdl;  // data length
logic     [ 32-1:0] cfg_bln;  // period length (data+idle)
logic     [ 16-1:0] cfg_bnm;  // number of repetitions

DAT_T dat [];

// stream input/output
axi4_stream_if #(.DAT_T (DAT_T)) str (.ACLK (clk), .ARESETn (rstn));

////////////////////////////////////////////////////////////////////////////////
// clock and time stamp
////////////////////////////////////////////////////////////////////////////////

initial        clk = 1'h0;
always #(TP/2) clk = ~clk;

////////////////////////////////////////////////////////////////////////////////
// test sequence
////////////////////////////////////////////////////////////////////////////////

initial begin
  // for now initialize configuration to an idle value
  ctl_rst = 1'b0;
  // control
  trg_i   = '0;
  // configuration
  cfg_trg = '1;
  cfg_siz = 2**CWM-1;
  cfg_stp = 1 << CWF;
  cfg_off = 0 << CWF;
  // configuration (burst mode)
  cfg_ben = 1'b0;
  cfg_inf = 0;
  cfg_bdl = 0;
  cfg_bln = 0;
  cfg_bnm = 0;

  // reset sequence
  rstn = 1'b0;
  repeat(4) @(posedge clk);
  rstn = 1'b1;
  repeat(4) @(posedge clk);

  // writing to buffer
  dat = new [1<<CWM];
  for (int i=0; i<dat.size(); i++) begin
    dat[i] = i;
  end
  buf_write(dat);

  // end simulation
  repeat(400) @(posedge clk);
  $finish();
end

// write buffer
task buf_write (
  DAT_T dat []
);
  for (int i=0; i<dat.size(); i++) begin
    busm.write(i, dat[i]);  // write table
  end
endtask: buf_write

// drain check incremental sequence
task drn_inc (
  int from,
  int to
);
  DAT_T [DN-1:0] dat;
  logic [DN-1:0] kep;
  logic          lst;
  int unsigned   tmg;
  for (int i=from; i<=to; i++) begin
    str_drn.get(dat, kep, lst, tmg);
      $display ("data %d is %x/%b", i, dat, lst);
    if ((dat !== DAT_T'(i)) || (lst !== 1'(i==to))) begin
      $display ("data %d is %x/%b, should be %x/%b", i, dat, lst, DAT_T'(i), 1'(i==to));
    end
  end
endtask: drn_inc

////////////////////////////////////////////////////////////////////////////////
// module instance
////////////////////////////////////////////////////////////////////////////////

sys_bus_if bus (.clk (clk), .rstn (rstn));

sys_bus_model busm (.bus (bus));

asg #(
  .DN    (DN),
  .DAT_T (DAT_T),
  // buffer parameters
  .CWM (CWM),
  .CWF (CWF)
) asg (
  // stream output
  .sto      (str),
  // control
  .ctl_rst  (ctl_rst),
  // trigger
  .trg_i    (trg_i),
  .trg_o    (trg_o),
  // interrupts
  .irq_trg  (irq_trg),
  .irq_stp  (irq_stp),
  // configuration
  .cfg_trg  (cfg_trg),
  .cfg_siz  (cfg_siz),
  .cfg_stp  (cfg_stp),
  .cfg_off  (cfg_off),
  // configuration (burst mode)
  .cfg_ben  (cfg_ben),
  .cfg_inf  (cfg_inf),
  .cfg_bdl  (cfg_bdl),
  .cfg_bln  (cfg_bln),
  .cfg_bnm  (cfg_bnm),
  // CPU buffer access
  .bus      (bus)
);

axi4_stream_drn #(
  .DAT_T (DAT_T)
) str_drn (
  .str      (str)
);

////////////////////////////////////////////////////////////////////////////////
// waveforms
////////////////////////////////////////////////////////////////////////////////

initial begin
  $dumpfile("asg_tb.vcd");
  $dumpvars(0, asg_tb);
end

endmodule: asg_tb
