// bsv libraries
import Vector::*;
import FIFO::*;
import Connectable::*;

// portz libraries
import Portal::*;
import AxiMasterSlave::*;
import Directory::*;
import CtrlMux::*;
import Portal::*;
import Leds::*;


// generated by tool
import EchoIndicationProxy::*;
import EchoRequestWrapper::*;
import SwallowWrapper::*;

// defined by user
import Echo::*;
import Swallow::*;

module mkPortalTop(PortalTop);

   // instantiate user portals
   EchoIndicationProxy echoIndicationProxy <- mkEchoIndicationProxy(7);
   EchoRequestInternal echoRequestInternal <- mkEchoRequestInternal(echoIndicationProxy.ifc);
   EchoRequestWrapper echoRequestWrapper <- mkEchoRequestWrapper(1008,echoRequestInternal.ifc);
   
   Swallow swallow <- mkSwallow();
   SwallowWrapper swallowWrapper <- mkSwallowWrapper(1009, swallow);
   
   Vector#(3,StdPortal) portals;
   portals[0] = echoIndicationProxy.portalIfc;
   portals[1] = echoRequestWrapper.portalIfc; 
   portals[2] = swallowWrapper.portalIfc; 
   let interrupt_mux <- mkInterruptMux(portals);
   
   // instantiate system directory
   Directory dir <- mkDirectoryDbg(portals,interrupt_mux);
   Vector#(1,StdPortal) directories;
   directories[0] = dir.portalIfc;
   
   // when constructing the ctrl mux, directories must be the first argument
   let ctrl_mux <- mkAxiSlaveMux(directories,portals);
   
   interface ReadOnly interrupt = interrupt_mux;
   interface StdAxi3Slave ctrl = ctrl_mux;
   interface LEDS leds = echoRequestInternal.leds;

endmodule : mkPortalTop