`include "uvm_macros.svh"
import uvm_pkg::*;

class sender extends uvm_component;
    `uvm_component_utils(sender)

    logic [31:0] data;

    uvm_blocking_put_port #(logic [31:0]) send;

    function new(string path = "sender", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        send = new("send", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            for(int i = 0; i< 5; i++) begin
                data = $random;
                send.put(data);
                #20;
            end
        end
    endtask
endclass

class receiver extends uvm_component;
    `uvm_component_utils(receiver)

    logic [31:0] datar;

    uvm_blocking_get_port #(logic [31:0]) recv;

    function new(string path = "receiver", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        recv = new("recv", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            for(int i = 0; i< 5; i++) begin
                #40;
                recv.get(datar);
            end
        end
    endtask
endclass

class test extends uvm_test;
    `uvm_component_utils(test)

    sender s;
    receiver r;
    uvm_tlm_fifo #(logic [31:0]) fifo;

    function new(string path = "test",uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        s = sender::type_id::create("s", this);
        r = receiver::type_id::create("r", this);
        fifo = new("fifo", this, 10);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        s.send.connect(fifo.put_export);
        r.recv.connect(fifo.get_export);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        #200;
        phase.drop_objection(this);
    endtask
endclass

module tb;
    initial begin
        run_test("test");
    end
endmodule


