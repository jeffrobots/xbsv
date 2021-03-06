// Copyright (c) 2013 Quanta Research Cambridge, Inc.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Connectable::*;
import GetPut::*;
import ClientServer::*;
import FIFOF::*;
import PortalMemory::*;
import MemTypes::*;
import MemreadEngine::*;
import MemwriteEngine::*;
import Adapter::*;
import BRAM::*;
import Pipe::*;
import RbmTypes::*;
import MemTypes::*;

typedef 8 BurstLen;

interface VectorSource#(numeric type dsz, type a);
   interface PipeOut#(a) pipe;
   method Action start(SGLId h, Bit#(ObjectOffsetSize) a, Bit#(ObjectOffsetSize) l);
   method ActionValue#(Bool) finish();
endinterface

module  mkMemreadVectorSource#(Server#(MemengineCmd,Bool) memreadServer, PipeOut#(Bit#(asz)) pipeOut)(VectorSource#(asz, a))
   provisos (Bits#(a,asz),
	     Div#(asz,8,abytes),
	     Log#(abytes,ashift),
	     Mul#(abytes, 8, asz)
	     );
   Bool verbose = False;
   let asz = valueOf(asz);
   let ashift = valueOf(ashift);
   method Action start(SGLId p, Bit#(ObjectOffsetSize) a, Bit#(ObjectOffsetSize) l);
      if (verbose) $display("VectorSource.start h=%d a=%h l=%h ashift=%d", p, a, l, ashift);
      memreadServer.request.put(MemengineCmd { sglId: p, base: a << ashift, len: truncate(l << ashift), burstLen: (fromInteger(valueOf(BurstLen)) << ashift) });
      // Bit#(8) foo = (fromInteger(valueOf(BurstLen)) << ashift);
      // $display("feck %d", foo);
   endmethod
   method finish = memreadServer.response.get;
   interface PipeOut pipe = mapPipe(unpack, pipeOut);
endmodule

interface VectorSink#(numeric type dsz, type a);
   interface PipeIn#(a) pipe;
   method Action start(SGLId h, Bit#(ObjectOffsetSize) a, Bit#(ObjectOffsetSize) l);
   method ActionValue#(Bool) finish();
endinterface

module  mkMemwriteVectorSink#(Server#(MemengineCmd,Bool) memwriteServer, PipeIn#(Bit#(asz)) pipeIn)(VectorSink#(asz, a))
   provisos (Bits#(a,asz),
	     Div#(asz,8,abytes),
	     Log#(abytes,ashift),
	     Mul#(abytes, 8, asz)
	     );
   Bool verbose = False;
   let asz = valueOf(asz);
   let ashift = valueOf(ashift);
   method Action start(SGLId p, Bit#(ObjectOffsetSize) a, Bit#(ObjectOffsetSize) l);
      if (verbose) $display("VectorSink.start h=%d a=%h l=%h ashift=%d", p, a, l, ashift);
      // I set burstLen==1 so that testmm works for all J,K,N. If we want burst writes we will need to rethink this (mdk)
      let cmd = MemengineCmd { sglId: p, base: a << ashift, len: truncate(l << ashift), burstLen: fromInteger(valueOf(abytes)) };
      memwriteServer.request.put(cmd);
      //$display("%d %d %d %d", cmd.sglId, cmd.base, cmd.len, cmd.burstLen);
   endmethod
   method finish = memwriteServer.response.get;
   interface PipeIn pipe = mapPipeIn(pack, pipeIn);
endmodule
