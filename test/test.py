# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

def ctz(n):
    i = 0
    while n % 2 == 0:
        i += 1
        n //= 2
    return i

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # Set the input values you want to test

    for i in range(256):
        dut.ui_in.value = i
        await ClockCycles(dut.clk, 1)

        n = i

        vals = int(dut.uo_out.value) | ((int(dut.uio_out.value[:6]) & 15) << 8)

        for j in range(3):
            if n == 0:
                if not ((vals & (1 << (3 + j*4))) == 0):
                    print("wrong valid", i, j)
            else:
                idx = ctz(n)
                if not (((vals >> j * 4) & 15) == idx | 8):
                    print("wrong value, ", i, j, ((vals >> j * 4) & 15), idx | 8)
                n &= ~(1 << idx)





