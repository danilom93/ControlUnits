library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.myTypes.all;

entity cu_test is
end cu_test;

architecture TEST of cu_test is

	component dlx_hw_cu is
		generic	(
							MICROCODE_MEM_SIZE	    :	integer   := 19;	-- Microcode memory size
							ALU_SELECT_SIZE			    : integer   := 2;	-- AlU opcode size for seleceting the ops
							CW_SIZE	                : integer   := 13 -- Control word size: we need 13 control signals
		);
		port	(
						Clk                       : in std_logic;
						Rst                       : in std_logic;
						FUNC                      : in std_logic_vector(FUNC_SIZE-1 downto 0);
						OP_CODE                   : in std_logic_vector(OP_CODE_SIZE-1 downto 0);

						-- first stage
						EN1                       : out std_logic;
						RF1                       : out std_logic;
						RF2                       : out std_logic;

						-- second stage
						EN2                       : out std_logic;
						S1	                      : out std_logic;
						S2                        : out std_logic;
						ALU_SEL                       : out std_logic_vector(ALU_SELECT_SIZE-1 downto 0); -- ALU control signal

						-- third stage
						EN3                       : out std_logic;
						RM                        : out std_logic;
						WM                        : out std_logic;
						S3                        : out std_logic;
						WF1                       : out std_logic
		);
	end component;
	
	-- size of the selec signal for the ALU
	constant ALU_SEL_SIZE : integer:=2;

	signal Clk_s, Rst_s: std_logic := '0';
	signal EN1_s, RF1_s, RF2_s, EN2_s, S1_s, S2_s, EN3_s, RM_s, WM_s, S3_s, WF1_s: std_logic;
	signal ALU_SEL_s : std_logic_vector(ALU_SEL_SIZE-1 downto 0);
	signal FUNC_s : std_logic_vector(FUNC_SIZE-1 downto 0);
	signal OP_CODE_s : std_logic_vector(OP_CODE_SIZE-1 downto 0);

	begin

		cu: dlx_hw_cu
			generic map	(
				MICROCODE_MEM_SIZE => 19,
				ALU_SELECT_SIZE => ALU_SEL_SIZE,
				CW_SIZE => 13
			)
			port map	(
				Clk => Clk_s,
				Rst => Rst_s,
				FUNC => FUNC_s,
				OP_CODE => OP_CODE_s,
				EN1 => EN1_s,
				RF1 => RF1_s,
				RF2 => RF2_s,
				EN2 => EN2_s,
				S1 => S1_s,
				S2 => S2_s,
				ALU_SEL => ALU_SEL_s,
				EN3 => EN3_s,
				RM => RM_s,
				WM => WM_s,
				S3 => S3_s,
				WF1 => WF1_s
			);

		Clk_s <= not Clk_s after 1 ns;
		Rst_s <= '0', '1' after 4 ns;   -- reset is low active

		process
			begin

        wait for 4 ns;
------------------------------------------------
--------------- R-Type ops ---------------------
------------------------------------------------

        -- ADD RS1,RS2,RD
        OP_CODE_s <= RTYPE;
        FUNC_s <= RTYPE_ADD;
        wait for 2 ns;			-- wait for a clock period

	-- SUB RS1,RS2,RD
        OP_CODE_s <= RTYPE;
        FUNC_s <= RTYPE_SUB;
        wait for 2 ns;

	-- AND RS1,RS2,RD
        OP_CODE_s <= RTYPE;
        FUNC_s <= RTYPE_AND;
        wait for 2 ns;

	-- OR RS1,RS2,RD
        OP_CODE_s <= RTYPE;
        FUNC_s <= RTYPE_OR;
        wait for 2 ns;

------------------------------------------------
--------------- I-Type ops ---------------------
------------------------------------------------
	-- NOP
        OP_CODE_s <= NOP;
        wait for 2 ns;

        -- ADDI1 RS1,RD,INP1
        OP_CODE_s <= ITYPE_ADDI1;
        wait for 2 ns;

	-- SUBI1 RS1,RD,INP1
        OP_CODE_s <= ITYPE_SUBI1;
        wait for 2 ns;

	-- ANDI1 RS1,RD,INP1
        OP_CODE_s <= ITYPE_ANDI1;
        wait for 2 ns;

	-- ORI1 RS1,RD,INP1
        OP_CODE_s <= ITYPE_ORI1;
        wait for 2 ns;

	-- ADDI2 RS1,RD,INP1
        OP_CODE_s <= ITYPE_ADDI2;
        wait for 2 ns;

	-- SUBI2 RS1,RD,INP1
        OP_CODE_s <= ITYPE_SUBI2;
        wait for 2 ns;

	-- ANDI2 RS1,RD,INP1
        OP_CODE_s <= ITYPE_ANDI2;
        wait for 2 ns;

	-- ORI2 RS1,RD,INP1
        OP_CODE_s <= ITYPE_ORI2;
        wait for 2 ns;

	-- MOV RS1,RD,INP1
        OP_CODE_s <= ITYPE_MOV;
        wait for 2 ns;

	-- SREG1 RS1,RD,INP1
        OP_CODE_s <= ITYPE_S_REG1;
        wait for 2 ns;

	-- SREG2 RS1,RD,INP1
        OP_CODE_s <= ITYPE_S_REG2;
        wait for 2 ns;

	-- SMEM2 RS1,RD,INP1
        OP_CODE_s <= ITYPE_S_MEM2;
        wait for 2 ns;

	--LMEM1 RS1,RD,INP1
        OP_CODE_s <= ITYPE_L_MEM1;
        wait for 2 ns;

	--LMEM2 RS1,RD,INP1
        OP_CODE_s <= ITYPE_L_MEM2;
        wait for 2 ns;

        wait;
        end process;
end TEST;
