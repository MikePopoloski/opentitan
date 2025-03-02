// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This sequence will enable the auto block feature and override
// the key output with their override values set in auto_block_out_ctl reg
class sysrst_ctrl_auto_blk_key_output_vseq extends sysrst_ctrl_base_vseq;
  `uvm_object_utils(sysrst_ctrl_auto_blk_key_output_vseq)

  `uvm_object_new

   rand uvm_reg_data_t override_value;
   rand uint16_t set_timer;
   rand int cycles;

   constraint cycles_c {cycles dist {
     [set_timer-10 : set_timer] :/5,
     [set_timer : set_timer+10] :/95
     };
   }

   constraint set_timer_c {
    set_timer dist {
      [10:100] :/ 95,
      [101:$]   :/ 5
    };
   }

   constraint num_trans_c {num_trans == 3;}

   task drive_pwrb();
    cfg.vif.pwrb_in = 1;
    cfg.clk_aon_rst_vif.wait_clks($urandom_range(1,20));
    cfg.vif.pwrb_in = 0;
    cfg.clk_aon_rst_vif.wait_clks(cycles+3);
    cfg.vif.pwrb_in = 1;
   endtask

   task body();

    bit enable_key0_out_sel, enable_key1_out_sel, enable_key2_out_sel;
    bit override_key0_out_value, override_key1_out_value, override_key2_out_value;

    `uvm_info(`gfn, "Starting the body from auto_blk_key_output_vseq", UVM_LOW)

    // Enable the auto block key feature
    ral.auto_block_debounce_ctl.auto_block_enable.set(1);
    csr_update(ral.auto_block_debounce_ctl);

    repeat (num_trans) begin

      `DV_CHECK_RANDOMIZE_FATAL(this)

      // Set the auto block debounce timer value
      csr_wr(ral.auto_block_debounce_ctl.debounce_timer, set_timer);
      `uvm_info(`gfn, $sformatf("Debounce timer set for: %0h",set_timer), UVM_LOW)

      // Set the key outputs to auto override with their values
      `DV_CHECK_RANDOMIZE_FATAL(ral.auto_block_out_ctl)
      csr_update(ral.auto_block_out_ctl);

      // It takes 2-3 clock cycles to sync the register values
      cfg.clk_aon_rst_vif.wait_clks(3);

      // Press the pwrb_in input key
      drive_pwrb();

      `uvm_info(`gfn, $sformatf("Value of cycles:%0d", cycles), UVM_LOW)

      enable_key0_out_sel = `gmv(ral.auto_block_out_ctl.key0_out_sel);
      enable_key1_out_sel = `gmv(ral.auto_block_out_ctl.key1_out_sel);
      enable_key2_out_sel = `gmv(ral.auto_block_out_ctl.key2_out_sel);

      override_key0_out_value = `gmv(ral.auto_block_out_ctl.key0_out_value);
      override_key1_out_value = `gmv(ral.auto_block_out_ctl.key1_out_value);
      override_key2_out_value = `gmv(ral.auto_block_out_ctl.key2_out_value);

      if (cycles >= set_timer) begin
        cfg.clk_aon_rst_vif.wait_clks(1);
        if(enable_key0_out_sel == 1) begin
         `DV_CHECK_EQ(override_key0_out_value, cfg.vif.key0_out);
        end
        if(enable_key1_out_sel == 1) begin
         `DV_CHECK_EQ(override_key1_out_value, cfg.vif.key1_out);
        end
        if(enable_key2_out_sel == 1) begin
         `DV_CHECK_EQ(override_key2_out_value, cfg.vif.key2_out);
        end
      end else begin
        `DV_CHECK_EQ(cfg.vif.key0_out, 0);
        `DV_CHECK_EQ(cfg.vif.key1_out, 0);
        `DV_CHECK_EQ(cfg.vif.key2_out, 0);
      end

      cfg.clk_aon_rst_vif.wait_clks(20);
    end
   endtask : body

endclass : sysrst_ctrl_auto_blk_key_output_vseq

