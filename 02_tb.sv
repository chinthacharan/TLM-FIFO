`include "uvm_macros.svh"
import uvm_pkg::*;

class transaction extends uvm_sequence_item;

    rand bit [3:0] a;
    rand bit [3:0] b;
    rand bit [3:0] c;
    rand bit [3:0] d;
    rand bit [1:0] sel;
         bit [3:0] y;

    function new(string path = "transaction");
        super.new(path);
    endfunction

    `uvm_object_utils_begin(transaction)
    `uvm_field_int(a, UVM_DEFAULT)
    `uvm_field_int(b, UVM_DEFAULT)
    `uvm_field_int(c, UVM_DEFAULT)
    `uvm_field_int(d, UVM_DEFAULT)
    `uvm_field_int(sel, UVM_DEFAULT)
    `uvm_field_int(y, UVM_DEFAULT)
    `uvm_object_utils_end
endclass


class generator extends uvm_sequence#(transaction);
    `uvm_object_utils(generator)

    transaction tr;

    function new(string path = "generator");
        super.new(path);
    endfunction

    virtual task body();
        repeat(15) begin
            tr = transaction::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize());
            finish_item(tr);
        end
    endtask
endclass

class driver extends uvm_driver#(transaction);
    `uvm_component_utils(driver)

    transaction tr;
    virtual mux_if mif;

    function new(string path = "driver", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual mux_if)::get(this,"","mif",mif))
            `uvm_error("drv", "unable to access Interface");
    endfunction

    virtual task run_phase(uvm_phase phase);
        tr = transaction::type_id::create("tr");
        forever begin
            seq_item_port.get_next_item(tr);
            mif.a <= tr.a;
            mif.b <= tr.b;
            mif.c <= tr.c;
            mif.d <= tr.d;
            mif.sel <= tr.sel;
            seq_item_port.item_done();
            #20;
        end
    endtask
endclass

class mon extends uvm_monitor;
    `uvm_component_utils(mon)

    uvm_analysis_port #(transaction) send;
    transaction tr;
    virtual mux_if mif;

    function new(string path = "mon", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        send = new("send", this);
        if(!uvm_config_db(virtual mux_if)::get("this", "", "mif", mif))
            `uvm_error("MON", "Unable to access the interface");
    endfunction

    virtual task run_phase(uvm_phase phase);
        tr = transaction::type_id::create("tr");
        forever begin
            #20;
            tr.a = mif.a;
            tr.b = mif.b;
            tr.c = mif.c;
            tr.d = mif.d;
            tr.sel = mif.sel;
            tr.y = mif.y;
            send.write(tr);
        end
    endtask
endclass

//////////////////////reference model
 
class ref_model extends uvm_monitor;
    `uvm_component_utils(ref_model)
     
    uvm_analysis_port#(transaction) send_ref;
    transaction tr;
    virtual mux_if mif;
     
        function new(input string inst = "ref_model", uvm_component parent = null);
        super.new(inst,parent);
        endfunction
        
        virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr = transaction::type_id::create("tr");
        send_ref = new("send_ref", this);
        if(!uvm_config_db#(virtual mux_if)::get(this,"","mif",mif))//uvm_test_top.env.agent.drv.aif
          `uvm_error("ref_model","Unable to access Interface");
        endfunction
        
        function void predict();
          case(tr.sel)
           2'b00 : tr.y = tr.a;
           2'b01 : tr.y = tr.b;
           2'b10 : tr.y = tr.c;
           2'b11 : tr.y = tr.d;      
          endcase
        endfunction
        
        virtual task run_phase(uvm_phase phase);
        forever begin
        #20;
        tr.a   = mif.a;
        tr.b   = mif.b;
        tr.c   = mif.c;
        tr.d   = mif.d;
        tr.sel = mif.sel;
        predict();
          `uvm_info("MON_REF", $sformatf("a:%0d  b:%0d c:%0d d:%0d sel:%0d y:%0d", tr.a, tr.b,tr.c,tr.d,tr.sel,tr.y), UVM_NONE);  
        send_ref.write(tr);
        end
       endtask 
     
endclass


class sco extends uvm_scoreboard;
    `uvm_component_utils(sco)

    transaction tr;
    
    uvm_tlm_analysis_fifo#(transaction) sco_data;
    uvm_tlm_analysis_fifo#(transaction) sco_data_ref;
  
  
 
 
    function new(input string inst = "sco", uvm_component parent = null);
    super.new(inst,parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tr    = transaction::type_id::create("tr");
    trref = transaction::type_id::create("tr_ref");
    sco_data = new("sco_data", this);
    sco_data_ref = new("sco_data_ref", this);  
      
    endfunction
    
 
  
  
     virtual task run_phase(uvm_phase phase); 
       forever begin
         sco_data.get(tr);
         sco_data_ref.get(trref);
 
         
         if(tr.compare(trref))
         `uvm_info("SCO", "Test Passed", UVM_NONE)
         else
         `uvm_info("SCO", "Test Failed", UVM_NONE)
     
      end
     endtask
     
 
endclass

class agent extends uvm_agent;
    `uvm_component_utils(agent)

    function new(string path = "agent", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    uvm_sequencer#(transaction) seqr;
    drv d;
    mon m;
    ref_model mref;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this);
        d = drv::type_id::create("d", this);
        m = mon::type_id::create("m", this);
        mref = ref_model::type_id::create("mref", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        d.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass

class env extends uvm_env;
    `uvm_component_utils(env)

    agent a;
    sco s;

    function new(string path = "env", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        a = agent::type_id::create("a", this);
        s = sco::type_id::create("s", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        a.m.send.connect(s.sco_data.analysis_export);
        a.mref.send_ref.connect(s.sco_data_ref.analysis_export);
    endfunction
endclass

class test extends uvm_test;
    `uvm_component_utils(test)

    env e;
    generator g;

    function new(string path = "test", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        e = env::type_id::create("e", this);
        g = generator::type_id::create("g");
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        g.start(e.a.seqr);
        #20;
        phase.drop_objection(this);
    endtask
endclass

module tb;
    mux_if mif();
    mux dut (.a(mif.a), .b(mif.b), .c(mif.c), .d(mif.d), .sel(mif.sel), .y(mif.y));
    initial begin
        uvm_config_db#(virtual mux_if)::set(null, "*", "mif", mif);
        run_test("test");
    end
endmodule


