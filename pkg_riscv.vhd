library ieee;
use ieee.std_logic_1164.all;

package pkg_riscv is

    -- ==============================================================================
    -- Základní OpCody (Opcodes) pro RISC-V RV32I (spodních 7 bitů instrukce)
    -- ==============================================================================
    
    -- R-Type (Matematika mezi dvěma registry: ADD, SUB, AND, OR, XOR...)
    constant OPC_OP       : std_logic_vector(6 downto 0) := "0110011";
    
    -- I-Type (Matematika s konstantou: ADDI, ANDI, ORI...)
    constant OPC_OP_IMM   : std_logic_vector(6 downto 0) := "0010011";
    
    -- Paměťové operace
    constant OPC_LOAD     : std_logic_vector(6 downto 0) := "0000011"; -- Čtení z RAM (LW, LB)
    constant OPC_STORE    : std_logic_vector(6 downto 0) := "0100011"; -- Zápis do RAM (SW, SB)
    
    -- Skoky (Branches a Jumps)
    constant OPC_BRANCH   : std_logic_vector(6 downto 0) := "1100011"; -- Podmíněné skoky (BEQ, BNE)
    constant OPC_JAL      : std_logic_vector(6 downto 0) := "1101111"; -- Jump and Link
    constant OPC_JALR     : std_logic_vector(6 downto 0) := "1100111"; -- Jump and Link Register
    
    -- Práce s horními bity (U-Type)
    constant OPC_LUI      : std_logic_vector(6 downto 0) := "0110111"; -- Load Upper Immediate
    constant OPC_AUIPC    : std_logic_vector(6 downto 0) := "0010111"; -- Add Upper Immediate to PC

    -- Systémová instrukce (Řízení procesoru, přerušení a systémové registry)
    constant OPC_SYSTEM   : std_logic_vector(6 downto 0) := "1110011";

end package pkg_riscv;