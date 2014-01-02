// bsv libraries
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;


// portz libraries
import AxiMasterSlave::*;
import Directory::*;
import CtrlMux::*;
import Portal::*;
import Leds::*;
import PortalMemory::*;
import AxiRDMA::*;
import BsimRDMA::*;
import PortalMemory::*;
import PortalRMemory::*;

// generated by tool
import MempokeRequestWrapper::*;
import DMARequestWrapper::*;
import MempokeIndicationProxy::*;
import DMAIndicationProxy::*;

// defined by user
import Mempoke::*;

interface Top;
   interface StdAxi3Slave     ctrl;
   interface StdAxi3Master    m_axi;
   interface ReadOnly#(Bool)  interrupt;
   interface LEDS             leds;
endinterface

module mkZynqTop(Top);

   DMAIndicationProxy dmaIndicationProxy <- mkDMAIndicationProxy(9);
   DMAWriteBuffer#(64,16) dma_stream_write_chan <- mkDMAWriteBuffer();
   DMAReadBuffer#(64,16) dma_stream_read_chan <- mkDMAReadBuffer();

   Vector#(1, DMAReadClient#(64))   readClients = newVector();
   Vector#(1, DMAWriteClient#(64)) writeClients = newVector();
   writeClients[0] = dma_stream_write_chan.dmaClient;
   readClients[0]  = dma_stream_read_chan.dmaClient;
`ifdef BSIM
   BsimDMAServer#(64)     dma <- mkBsimDMAServer(dmaIndicationProxy.ifc, readClients, writeClients);
`else
   Integer               numRequests = 8;
   AxiDMAServer#(64,8)   dma <- mkAxiDMAServer(dmaIndicationProxy.ifc, numRequests, readClients, writeClients);
`endif
   DMARequestWrapper dmaRequestWrapper <- mkDMARequestWrapper(1005,dma.request);

   
   MempokeIndicationProxy mempokeIndicationProxy <- mkMempokeIndicationProxy(7);
   MempokeRequest mempokeRequest <- mkMempokeRequest(mempokeIndicationProxy.ifc, dma_stream_write_chan.dmaServer, dma_stream_read_chan.dmaServer);
   MempokeRequestWrapper mempokeRequestWrapper <- mkMempokeRequestWrapper(1008,mempokeRequest);

   Vector#(4,StdPortal) portals;
   portals[0] = mempokeRequestWrapper.portalIfc;
   portals[1] = mempokeIndicationProxy.portalIfc; 
   portals[2] = dmaRequestWrapper.portalIfc;
   portals[3] = dmaIndicationProxy.portalIfc; 
   
   Directory dir <- mkDirectory(portals);
   Vector#(1,StdPortal) directories;
   directories[0] = dir.portalIfc;
   
   // when constructing ctrl and interrupt muxes, directories must be the first argument
   let ctrl_mux <- mkAxiSlaveMux(directories,portals);
   let interrupt_mux <- mkInterruptMux(portals);
`ifndef BSIM
   let axi_master <- mkAxi3Master(dma.m_axi);
`endif
   
   interface ReadOnly interrupt = interrupt_mux;
   interface StdAxi3Slave ctrl = ctrl_mux;
`ifndef BSIM
   interface StdAxi3Master m_axi = axi_master;
`endif
endmodule

import "BDPI" function Action      initPortal(Bit#(32) d);
import "BDPI" function Bool                    writeReq();
import "BDPI" function ActionValue#(Bit#(32)) writeAddr();
import "BDPI" function ActionValue#(Bit#(32)) writeData();
import "BDPI" function Bool                     readReq();
import "BDPI" function ActionValue#(Bit#(32))  readAddr();
import "BDPI" function Action        readData(Bit#(32) d);


module mkBsimTop();
   Top top <- mkZynqTop;
   let wf <- mkPipelineFIFO;
   let init_seq = (action 
		      initPortal(0);
		      initPortal(1);
		      initPortal(2);
		      initPortal(3);
		      initPortal(4);
                   endaction);
   let init_fsm <- mkOnce(init_seq);
   rule init_rule;
      init_fsm.start;
   endrule
   rule wrReq (writeReq());
      let wa <- writeAddr;
      let wd <- writeData;
      top.ctrl.write.writeAddr(wa,0,0,0,0,0,0);
      wf.enq(wd);
   endrule
   rule wrData;
      wf.deq;
      top.ctrl.write.writeData(wf.first,0,0,0);
   endrule
   rule rdReq (readReq());
      let ra <- readAddr;
      top.ctrl.read.readAddr(ra,0,0,0,0,0,0);
   endrule
   rule rdResp;
      let rd <- top.ctrl.read.readData;
      readData(rd);
   endrule
endmodule