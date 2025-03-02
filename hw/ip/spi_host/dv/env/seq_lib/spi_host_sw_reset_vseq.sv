// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// sw_reset test vseq
// sequence does a software reset while ongoing host transactions
// checks for rx and tx queue empty post reset application
class spi_host_sw_reset_vseq extends spi_host_tx_rx_vseq;
  `uvm_object_utils(spi_host_sw_reset_vseq)
  `uvm_object_new

  int num_resets = 1; //TODO increase number of Iterations.
  bit [7:0] fifo_entries = 0;
  bit [7:0] read_q[$];
  bit rxempty;
  bit txempty;

  virtual task body();
    for (int i = 0; i < num_resets; i++) begin
      fork
        begin : isolation_fork
          fork
            start_reactive_seq();
          join_none

          begin
            wait_ready_for_command();
            start_spi_host_trans(2); //TODO random transactions
            csr_spinwait(.ptr(ral.status.active), .exp_data(1'b0));
            csr_spinwait(.ptr(ral.status.rxqd), .exp_data(8'h0));
            cfg.clk_rst_vif.wait_clks(100);
          end

          disable fork;
        end

        begin
          csr_spinwait(.ptr(ral.status.active), .exp_data(1'b1));
          csr_spinwait(.ptr(ral.status.rxqd), .exp_data(8'h2));
          cfg.clk_rst_vif.wait_clks(200);
          csr_rd(.ptr(ral.status.txqd), .value(fifo_entries));
          spi_host_init();
          cfg.clk_rst_vif.wait_clks(100);
        end

      join

      csr_rd_check(.ptr(ral.status.rxempty), .compare_value(1'b0));
      csr_rd_check(.ptr(ral.status.txempty), .compare_value(1'b0));
    end  // end for loop
  endtask : body

endclass : spi_host_sw_reset_vseq
