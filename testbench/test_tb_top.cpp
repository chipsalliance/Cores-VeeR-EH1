// SPDX-License-Identifier: Apache-2.0
// Copyright 2019 Western Digital Corporation or its affiliates.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
#include <stdlib.h>
#include <iostream>
#include <utility>
#include <string>
#include "Vtb_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"


vluint64_t main_time = 0;

double sc_time_stamp () {
 return main_time;
}


int main(int argc, char** argv) {
  std::cout << "\nVerilatorTB: Start of sim\n" << std::endl;

  // Check for +dumpon and remove it from argv
  bool dumpWaves = false;
  int newArgc = 0;
  for (int i = 0; i < argc; ++i)
    if (strcmp(argv[i], "+dumpon") == 0)
      dumpWaves = true;
    else
      argv[newArgc++] = argv[i];
  argc = newArgc;

  Verilated::commandArgs(argc, argv);

  Vtb_top* tb = new Vtb_top;

  // init trace dump
  Verilated::traceEverOn(true);
  VerilatedVcdC* tfp = new VerilatedVcdC;
  tb->trace (tfp, 24);
  if (dumpWaves)
    tfp->open ("sim.vcd");

  // Simulate
  while(!Verilated::gotFinish()){
      if (dumpWaves)
        tfp->dump (main_time);
      main_time += 5;
      tb->core_clk = !tb->core_clk;
      tb->eval();
  }

  if (dumpWaves)
    tfp->close();

  std::cout << "\nVerilatorTB: End of sim" << std::endl;
  exit(EXIT_SUCCESS);

}
