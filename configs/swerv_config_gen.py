#!/usr/bin/env python
from fusesoc.capi2.generator import Generator
import os
import shutil
import subprocess
import tempfile

class SwervConfigGenerator(Generator):
    def run(self):
        files = [
            {"configs/snapshots/default/common_defines.vh" : {
                "copyto"    : "config/common_defines.vh",
                "file_type" : "systemVerilogSource"}},
            {"configs/snapshots/default/pic_ctrl_verilator_unroll.sv" : {
                "copyto" : "config/pic_ctrl_verilator_unroll.sv",
                "is_include_file" : True,
                "file_type" : "systemVerilogSource"}},
            {"configs/snapshots/default/pic_map_auto.h" : {
                "copyto" : "config/pic_map_auto.h",
                "is_include_file" : True,
                "file_type" : "systemVerilogSource"}}]

        tmp_dir = os.path.join(tempfile.mkdtemp(), 'core')
        shutil.copytree(self.files_root, tmp_dir)

        cwd = tmp_dir

        env = os.environ.copy()
        env['RV_ROOT'] = tmp_dir
        args = ['configs/swerv.config'] + self.config.get('args', [])
        rc = subprocess.call(args, cwd=cwd, env=env)
        if rc:
            exit(1)

        filenames = []
        for f in files:
            for k in f:
                filenames.append(k)

        for f in filenames:
            d = os.path.dirname(f)
            if d and not os.path.exists(d):
                os.makedirs(d)
            shutil.copy2(os.path.join(cwd, f),f)

        self.add_files(files)

g = SwervConfigGenerator()
g.run()
g.write()
