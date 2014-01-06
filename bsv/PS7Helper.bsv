// bsv libraries
import Clocks :: *;
import GetPut::*;

// portz libraries
import AxiMasterSlave::*;
import CtrlMux::*;
import PPS7::*;
import PS7::*;
import Portal::*;

interface ZynqPinsInternal#(numeric type c_dm_width, numeric type c_dq_width, numeric type c_dqs_width, numeric type data_width, numeric type gpio_width, numeric type id_width, numeric type mio_width);
    (* prefix="DDR_Addr" *) interface Inout#(Bit#(15))     addr;
    (* prefix="DDR_BankAddr" *) interface Inout#(Bit#(3))     bankaddr;
    (* prefix="DDR_CAS_n" *) interface Inout#(Bit#(1))     cas_n;
    (* prefix="DDR_CKE" *) interface Inout#(Bit#(1))     cke;
    (* prefix="DDR_CS_n" *) interface Inout#(Bit#(1))     cs_n;
    (* prefix="DDR_Clk_n" *) interface Inout#(Bit#(1))     clk_n;
    (* prefix="DDR_Clk_p" *) interface Inout#(Bit#(1))     clk;
    (* prefix="DDR_DM" *) interface Inout#(Bit#(c_dm_width))     dm;
    (* prefix="DDR_DQ" *) interface Inout#(Bit#(c_dq_width))     dq;
    (* prefix="DDR_DQS_n" *) interface Inout#(Bit#(c_dqs_width))     dqs_n;
    (* prefix="DDR_DQS_p" *) interface Inout#(Bit#(c_dqs_width))     dqs;
    (* prefix="DDR_DRSTB" *) interface Inout#(Bit#(1))     drstb;
    (* prefix="DDR_ODT" *) interface Inout#(Bit#(1))     odt;
    (* prefix="DDR_RAS_n" *) interface Inout#(Bit#(1))     ras_n;
    (* prefix="FIXED_IO_ddr_vrn" *) interface Inout#(Bit#(1))     vrn;
    (* prefix="FIXED_IO_ddr_vrp" *) interface Inout#(Bit#(1))     vrp;
    (* prefix="DDR_WEB" *) interface Inout#(Bit#(1))     web;
    (* prefix="FIXED_IO_mio" *)
    interface Inout#(Bit#(mio_width))       mio;
    (* prefix="FIXED_IO_ps" *)
    interface Pps7Ps#(4, 32, 4, 64, 64, 12, 54) ps;
    interface Clock                         fclk_clk0;
    interface Bit#(1)                       fclk_reset0_n;
endinterface

typedef ZynqPinsInternal#(4, 32, 4, 64/*data_width*/, 64/*gpio_width*/, 12/*id_width*/, 54) ZynqPins;

typedef AxiSlaveHighSpeed#(64/*data_width*/, 12/*id_width*/) HSSlave;
typedef AxiREQ#(12/*id_width*/) StdAxiREQ;

interface HackInterface;
endinterface

module mkPS7MasterInternal#(StdAxi3Master m_axi, HSSlave hp)(HackInterface);
    rule s_areqr_rule;
        let addr <- m_axi.read.readAddr();
        hp.axi.req_ar.put(StdAxiREQ{ addr: addr[31:0],
            len: m_axi.read.readBurstLen(),
            size: m_axi.read.readBurstWidth(),
            burst: m_axi.read.readBurstType(),
            prot: m_axi.read.readBurstProt(),
            cache: m_axi.read.readBurstCache(),
            id: m_axi.read.readId(), lock: 0, qos: 0});
    endrule

    rule s_areqw_rule;
        let addr <- m_axi.write.writeAddr();
        hp.axi.req_aw.put(StdAxiREQ{ addr: addr[31:0],
            len: m_axi.write.writeBurstLen(),
            size: m_axi.write.writeBurstWidth(),
            burst: m_axi.write.writeBurstType(),
            prot: m_axi.write.writeBurstProt(),
            cache: m_axi.write.writeBurstCache(),
            id: m_axi.write.writeId(), lock: 0, qos: 0});
    endrule

    rule s_arespb_rule;
        let s_arespb <- hp.axi.resp_b.get();
        m_axi.write.writeResponse(s_arespb.resp, s_arespb.id);
    endrule

    rule s_arespr_rule;
        let s_arespr <- hp.axi.resp_read.get();
        m_axi.read.readData(s_arespr.rd.data, s_arespr.r.resp, s_arespr.rd.last, s_arespr.r.id);
    endrule

    rule s_arespw_rule;
        let data <- m_axi.write.writeData();
        AxiWrite#(64/*data_width*/, 12/*id_width*/) s_arespw;
        s_arespw.wd.data = data;
        s_arespw.wstrb = m_axi.write.writeDataByteEnable();
        s_arespw.wd.last = m_axi.write.writeLastDataBeat();
        s_arespw.wid = m_axi.write.writeWid();
        hp.axi.resp_write.put(s_arespw);
    endrule
endmodule

module mkPS7Slave#(Clock axi_clock, Reset axi_reset, StdAxi3Slave ctrl, Integer nmasters, StdAxi3Master m_axi, ReadOnly#(Bool) interrupt)(ZynqPins);
    StdPS7 ps7 <- mkPS7(axi_clock, axi_reset);

    rule send_int_rule;
    ps7.irq.f2p({15'b0, interrupt ? 1'b1 : 1'b0});
    endrule

    rule m_ar_rule;
        let m_ar <- ps7.m_axi_gp[0].req_ar.get();
        ctrl.read.readAddr(m_ar.addr, m_ar.len, m_ar.size, m_ar.burst, m_ar.prot, m_ar.cache, m_ar.id);
    endrule

    rule m_aw_rule;
        let m_aw <- ps7.m_axi_gp[0].req_aw.get();
        ctrl.write.writeAddr(m_aw.addr, m_aw.len, m_aw.size, m_aw.burst, m_aw.prot, m_aw.cache, m_aw.id);
    endrule

    rule m_arespb_rule;
        AxiRESP#(12/*id_width*/) m_arespb;
        m_arespb.resp <- ctrl.write.writeResponse();
        m_arespb.id <- ctrl.write.bid();
        ps7.m_axi_gp[0].resp_b.put(m_arespb);
    endrule

    rule m_arespr_rule;
        let data <- ctrl.read.readData();
        AxiRead#(32/*data_width*/, 12/*id_width*/) m_arespr;
        m_arespr.rd.data = data;
        m_arespr.r.resp = 2'b0;
        m_arespr.rd.last = ctrl.read.last();
        m_arespr.r.id = ctrl.read.rid();
        ps7.m_axi_gp[0].resp_read.put(m_arespr);
    endrule

    rule m_arespw_rule;
        let m_arespw <- ps7.m_axi_gp[0].resp_write.get();
        ctrl.write.writeData(m_arespw.wd.data, m_arespw.wstrb, m_arespw.wd.last, m_arespw.wid);
    endrule

if (nmasters > 0) begin
    let myhp <- mkPS7MasterInternal(m_axi, ps7.s_axi_hp[0]);
end

    interface Inout  addr = ps7.ddr.addr;
    interface Inout  bankaddr = ps7.ddr.bankaddr;
    interface Inout  cas_n = ps7.ddr.cas_n;
    interface Inout  cke = ps7.ddr.cke;
    interface Inout  cs_n = ps7.ddr.cs_n;
    interface Inout  clk_n = ps7.ddr.clk_n;
    interface Inout  clk = ps7.ddr.clk;
    interface Inout  dm = ps7.ddr.dm;
    interface Inout  dq = ps7.ddr.dq;
    interface Inout  dqs_n = ps7.ddr.dqs_n;
    interface Inout  dqs = ps7.ddr.dqs;
    interface Inout  drstb = ps7.ddr.drstb;
    interface Inout  odt = ps7.ddr.odt;
    interface Inout  ras_n = ps7.ddr.ras_n;
    interface Inout  vrn = ps7.ddr.vrn;
    interface Inout  vrp = ps7.ddr.vrp;
    interface Inout  web = ps7.ddr.web;
    interface Inout  mio = ps7.mio;
    interface Pps7Ps ps = ps7.ps;
    interface Clock  fclk_clk0 = ps7.fclk.clk0;
    interface Bit    fclk_reset0_n = ps7.fclk_reset[0].n;
endmodule