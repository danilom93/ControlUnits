library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.myTypes.all;

entity dlx_cu is

    generic (
            INSTRUCTIONS_EXECUTION_CYCLES : integer := 3; -- Instructions Execution
    		MICROCODE_MEM_SIZE 	          : integer := 61; -- Microcode Memory Size
            RELOC_MEM_SIZE                : integer := 16; -- Microcode Relocation
    		CW_SIZE 	                  : integer := 13; -- Control Word Size
            OP_CODE_SIZE                  : integer := 6; -- Op Code Size
            FUNC_SIZE                     : integer := 11; -- Func Field Size for R-Type Ops
			ALU_SELECT_SIZE 	          : integer := 2); -- Number of control wires for the alu_op_code

    port (
			--INPUT
    		Clk 	                      : in std_logic; -- Clock
    		Rst 	                      : in std_logic; -- Reset:Active-Low
            OP_CODE 	                  : in std_logic_vector(OP_CODE_SIZE - 1 downto 0);
            FUNC 		                  : in std_logic_vector(FUNC_SIZE - 1 downto 0);

    		-- ID Control Signals
			EN1                           : out std_logic; -- Register File and pipeline reg Enable
			RF1                           : out std_logic; -- Register File read port 1 Enable
			RF2                           : out std_logic; -- Register File read port 2 Enable
			WF1                           : out std_logic; -- Register File write port Enable

    		-- EX Control Signals
    		EN2 	                      : out std_logic; -- pipe register Enable
    		S1 	                          : out std_logic; -- input selector first multiplexer
    		S2 	                          : out std_logic; -- input selector second multiplexer
    		ALU_SEL	                      : out std_logic_vector(ALU_SELECT_SIZE -1 downto 0); -- ALU Control bit

    		-- MEM Control Signals
    		EN3 	                      : out std_logic; -- memory and pipeline register Enable
    		RM 	                          : out std_logic; -- read out of memory enable
    		WM 	                          : out std_logic; -- write in of memory enable
    		S3 	                          : out std_logic); -- input selctor of multiplexer

end entity;

architecture arch of dlx_cu is

    type mem_array is array (integer range 0 to MICROCODE_MEM_SIZE - 1) of std_logic_vector(CW_SIZE - 1 downto 0);
    type reloc_mem_array is array (0 to RELOC_MEM_SIZE - 1) of unsigned(OP_CODE_SIZE + 1 downto 0);

    signal reloc_mem                      : reloc_mem_array := ( X"00", -- All R-Type Instructions are not Relocated
                                                X"10", -- NOP remaps the opcode 0x01 into 0x10
                                                X"13", -- ADDI1 remaps the opcode 0x02 into 0x13
                                                X"16", -- SUBI1
                                                X"19", -- ANDI1
                                                X"1C", -- ORI1
                                                X"1F", -- ADDI2
                                                X"22", -- SUBI2
                                                X"25", -- ANDI2
                                                X"28", -- ORI2
                                                X"2B", -- MOV
                                                X"2E", -- S_REG1
                                                X"31", -- S_REG2
                                                X"34", -- S_MEM2
                                                X"37", -- L_MEM1
                                                X"3A" -- L_MEM2
                                         );

-- All the R-type Instructions are found into the microcode memory
-- using their function field shifted by two (multiplied by 4)

-- Actually to use less resources different kinds of optimization can be done,
-- One of them is to reduce the length of the control word stored inside the microcode memory
-- in fact considering that each stage has a maximum of 5 control wires it is possible to
-- to store words of 5 bits rather than words of 13 bits

-- Another possibility is to store the entire word of 13 bits just one time, and use a sort
-- of mask combined with an and operation that brings to zero all the signals not used inside each stage

    signal microcode           : mem_array := ( "1110000000000", -- ADD_R
                                      			"0000100100000", -- ADD_R
                                      			"0000000000101", -- ADD_R
                                      			"0000000000000", -- Alignment (just to avoid complex math operations)
                                      			"1110000000000", -- SUB_R
                                      			"0000101100000", -- SUB_R
                                      			"0000000000101", -- SUB_R
                                      			"0000000000000", -- Alignment
                                      			"1110000000000", -- AND_R
                                      			"0000110100000", -- AND_R
                                      			"0000000000101", -- AND_R
                                      			"0000000000000", -- Alignment
                                      			"1110000000000", -- OR_R
                                      			"0000111100000", -- OR_R
                                      			"0000000000101", -- OR_R
                                      			"0000000000000", -- Alignment
                                                "0000000000000", -- NOP first remapped control word (0x10)
                                    			"0000000000000", -- NOP
                                    			"0000000000000", -- NOP
                                    			"0110000000000", -- ADDI1 second remapped control word (0x13)
                                    			"0001100100000", -- ADDI1
                                    			"0000000000101", -- ADDI1
                                    			"0110000000000", -- SUBI1
                                    			"0001101100000", -- SUBI1
                                    			"0000000000101", -- SUBI1
                                    			"0110000000000", -- ANDI1
                                    			"0001110100000", -- ANDI1
                                    			"0000000000101", -- ANDI1
                                    			"0110000000000", -- ORI1
                                    			"0001111100000", -- ORI1
                                    			"0000000000101", -- ORI1
                                    			"1010000000000", -- ADDI2
                                    			"0000000100000", -- ADDI2
                                    			"0000000000101", -- ADDI2
                                    			"1010000000000", -- SUBI2
                                    			"0000001100000", -- SUBI2
                                    			"0000000000101", -- SUBI2
                                    			"1010000000000", -- ANDI2
                                    			"0000010100000", -- ANDI2
                                    			"0000000000101", -- ANDI2
                                    			"1010000000000", -- ORI2
                                    			"0000011100000", -- ORI2
                                    			"0000000000101", -- ORI2
                                    			"1010000000000", -- MOV
                                    			"0000000100000", -- MOV
                                    			"0000000000001", -- MOV
                                    			"0110000000000", -- S_REG1
                                    			"0001100100000", -- S_REG1
                                    			"0000000000001", -- S_REG1
                                    			"1010000000000", -- S_REG2
                                    			"0000000100000", -- S_REG2
                                    			"0000000000001", -- S_REG2
                                    			"1110000000000", -- S_MEM2
                                    			"0000000100000", -- S_MEM2
                                    			"0000000001110", -- S_MEM2
                                    			"0110000000000", -- L_MEM1
                                    			"0001100100000", -- L_MEM1
                                    			"0000000010111", -- L_MEM1
                                    			"1010000000000", --L_MEM2
                                    			"0000000100000", --L_MEM2
                                    			"0000000010111" --L_MEM2
                                   );

    constant R_OPCODE                     : unsigned(OP_CODE_SIZE - 1 downto 0) := "000000";
    signal cw                             : std_logic_vector(CW_SIZE - 1 downto 0);
    signal uPC                            : integer range 0 to 64;
    signal ICount                         : integer range 0 to INSTRUCTIONS_EXECUTION_CYCLES;
    signal OpCode_s                       : unsigned(OP_CODE_SIZE - 1 downto 0);
    signal OpCode_Reloc                   : unsigned(OP_CODE_SIZE + 1 downto 0);
	signal func_s2                        : std_logic_vector(FUNC_SIZE +1 downto 0);
    signal func_s                         : unsigned(FUNC_SIZE + 1 downto 0);

begin

    -- Each control word is saved into the microcode memory, so it taken just changing the uPC value
    cw <= microcode(uPC);

    -- Decomposes the control word
    -- First stage
    EN1 <= cw(CW_SIZE - 3);
	RF1 <= cw(CW_SIZE - 1);
	RF2 <= cw(CW_SIZE - 2);

    -- Second stage
	S1 <= cw(CW_SIZE - 4);
	S2 <= cw(CW_SIZE - 5);
	EN2 <= cw(CW_SIZE - 8);
	ALU_SEL(1) <= cw(CW_SIZE - 6);
	ALU_SEL(0) <= cw(CW_SIZE - 7);

    -- Third stage
	WM <= cw(CW_SIZE - 10);
	RM <= cw(CW_SIZE - 9);
	EN3 <= cw(CW_SIZE - 11);
	S3 <= cw(CW_SIZE - 12);
	WF1 <= cw(CW_SIZE - 13);

    OpCode_s <= unsigned(OP_CODE);
    -- The reloc memory gives the right address on which to find the opcode
    OpCode_Reloc <= reloc_mem(conv_integer(OpCode_s));
    -- The function field is shifted by two
	func_s2 <= FUNC & "00";
    func_s <= unsigned(func_s2);

    uPC_Proc                              : process (Clk, Rst)

          begin
            if Rst = '0' then -- asynchronous reset (active low)

              uPC <= 0;
              ICount <= 0;
            elsif Clk'event and Clk = '1' then -- rising clock edge

                if (ICount = 0) then

	                 if (OpCode_s = R_OPCODE) then -- checks if it is a R-type opcode

                        -- if it is an R-type opcode the first stage of the control word can be found
                        -- inside the memory at the address given by the function field schifted by two
                        uPC <= conv_integer(func_s);
                     else

                        -- If is not an R-type opcode the first stage of the control word can be found
                        -- inside the memory at the remapped address given by the reloc memory
                        uPC <= conv_integer(OpCode_Reloc);
                     end if;
				 ICount <= ICount + 1;
             elsif (ICount < INSTRUCTIONS_EXECUTION_CYCLES) then   -- until each stages has been done

                upc <= upc + 1; -- increments the upc to point to the next stage
                ICount <= ICount + 1;
              else

                -- restart to manage the next instruction
                ICount <= 1;
                if (OpCode_s = R_OPCODE) then

                  uPC <= conv_integer(func_s);
                else

                  uPC <= conv_integer(OpCode_Reloc);
                end if;
              end if;
            end if;
      end process uPC_Proc;
end architecture;
