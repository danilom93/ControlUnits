library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.myTypes.all;

entity dlx_hw_cu is
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
end entity;

architecture dlx_hw_cu_arch of dlx_hw_cu is
	-- ALU OPERATIONS:	00 addition
	--					01 subtraction
	--					10 AND
	--					11 OR
	-- 13 bits have to be set into the array, corresponding to the control signals for each and every stage
	-- ADD, SUB, AND, OR -- ADDI1, SUBI1, ANDI1, ORI1, ADDI2, SUBI2, ANDI2, ORI2, MOV, S_REG1, S_REG2, S_MEM2
	-- L_MEM1, L_MEM2
	type mem_array is array (integer range 0 to MICROCODE_MEM_SIZE-1) of std_logic_vector(CW_SIZE-1 downto 0);
	signal ctrl_w_mem               : mem_array := (	"1110100100101", -- ADD R-Type op
																		"1110101100101", -- SUB R-Type op
																		"1110110100101", -- AND R-Type op
																		"1110111100101", -- OR R-Type op
																		"0000100000010", -- NOP
																		"0111100100101", -- ADDI1 I-Type op
																		"0111101100101", -- SUBI1 I-Type op
																		"0111110100101", -- ANDI1 I-Type op
																		"0111111100101", -- ORI1 I-Type op
																		"1010000100101", -- ADDI2 I-Type op
																		"1010001100101", -- SUBI2 I-Type op
																		"1010010100101", -- ANDI2 I-Type op
																		"1010011100101", -- ORI2 I-Type op
																		"1010000100101", -- MOV I-Type op
																		"0111100100001", -- S_REG1 I-Type op: R[RD] <= INP1
																		"1010000100001", -- S_REG2 I-Type op: R[RD] <= INP2
																		"1110000101100", -- S_MEM2 I-Type op: MEM[R[R1]+INP2] = R[R2]
																		"1111100110111", -- L_MEM1 I-Type op: R[R2] = MEM[R[R1]+INP1]
																		"1110000110111" -- L_MEM2 I-Type op: R[R2] = MEM[R[R1]+INP2]
																										);

	-- these signals are used to arrange the control words used during the pipeling
	signal OP_CODE_s : std_logic_vector(OP_CODE_SIZE-1 downto 0);	-- signal used to take the OPCODE
	signal FUNC_s : std_logic_vector(FUNC_SIZE-1 downto 0);	-- signal used to take the FUNC
	signal ctrl_w_s : std_logic_vector(CW_SIZE-1 downto 0);	-- control word signal

	signal ctrl_w1 : std_logic_vector(CW_SIZE-1 downto 0);		-- control word signal used for the first stage
	signal ctrl_w2 : std_logic_vector(CW_SIZE-1-3 downto 0);	-- control word signal used for the second stage
	signal ctrl_w3 : std_logic_vector(CW_SIZE-1-8 downto 0);	-- control word signal used for the third stage

begin

	OP_CODE_s <= OP_CODE;
	FUNC_s <= FUNC;

	-- first stage
	RF1 <= ctrl_w1(CW_SIZE-1);	-- takes the MSB
	RF2 <= ctrl_w1(CW_SIZE-2);	-- takes the MSB-1 bit
	EN1 <= ctrl_w1(CW_SIZE-3);

	-- second stage
	S1 <= ctrl_w2(CW_SIZE-4);
	S2 <= ctrl_w2(CW_SIZE-5);
	ALU_SEL <= ctrl_w2(CW_SIZE-6 downto CW_SIZE-7);	-- takes 2 bits
	EN2 <= ctrl_w2(CW_SIZE-8);

	-- third stage
	RM <= ctrl_w3(CW_SIZE-9);
	WM <= ctrl_w3(CW_SIZE-10);
	EN3 <= ctrl_w3(CW_SIZE-11);
	S3 <= ctrl_w3(CW_SIZE-12);
	WF1 <= ctrl_w3(CW_SIZE-13);

	-- process which manages the pipeline
	process(Clk, Rst)
	begin

		if Rst = '0' then

			ctrl_w1 <= (others => '0');	-- reset to zero
			ctrl_w2 <= (others => '0'); -- reset to zero
			ctrl_w3 <= (others => '0'); -- reset to zero

		elsif Clk'event and Clk = '1' then

			ctrl_w1 <= ctrl_w_s;													-- for the first stage of pipeline

			ctrl_w2 <= ctrl_w1(CW_SIZE-1-3 downto 0);						-- takes the bits for the second stage
																						-- discarding the ones for the first stage
																						-- which are RF1, RF2 and EN1

			ctrl_w3 <= ctrl_w2(CW_SIZE-1-8 downto 0);	-- takes the bits for the third stage
																						-- discarding the ones for the second stage
																						-- which are S1, S2, ALU(2 bits) and EN2
		end if;

	end process;
	
	-- process which prepares the control word based on the input signal FUNC and OPCODE
	process(OP_CODE_s, FUNC_s)
	begin
		case OP_CODE_s is

			-- in case of R-Type, the FUNC field is used to select the op
			-- while the OPCODE field is equal to "000000"
			when RTYPE =>
				case FUNC_s is
					when RTYPE_ADD =>
						ctrl_w_s <= ctrl_w_mem(conv_integer(FUNC_s));
					when RTYPE_SUB =>
						ctrl_w_s <= ctrl_w_mem(conv_integer(FUNC_s));
					when RTYPE_AND =>
						ctrl_w_s <= ctrl_w_mem(conv_integer(FUNC_s));
					when RTYPE_OR =>
						ctrl_w_s <= ctrl_w_mem(conv_integer(FUNC_s));
					when others => ctrl_w_s <= ctrl_w_mem(offset + conv_integer(NOP) - 1);
				end case;

			-- in case of I-Type, the OPCODE field is used instead
			when NOP =>
				ctrl_w_s <= ctrl_w_mem(offset + conv_integer(OP_CODE_s) - 1);
			when ITYPE_ADDI1 =>
				ctrl_w_s <= ctrl_w_mem(offset + conv_integer(OP_CODE_s) - 1);
			when ITYPE_SUBI1 =>
				ctrl_w_s <= ctrl_w_mem(offset + conv_integer(OP_CODE_s) - 1);
			when ITYPE_ANDI1 =>
				ctrl_w_s <= ctrl_w_mem(offset + conv_integer(OP_CODE_s) - 1);
			when ITYPE_ORI1 =>
				ctrl_w_s <= ctrl_w_mem(offset + conv_integer(OP_CODE_s) - 1);
			when ITYPE_ADDI2 =>
				ctrl_w_s <= ctrl_w_mem(offset + conv_integer(OP_CODE_s) - 1);
			when ITYPE_SUBI2 =>
				ctrl_w_s <= ctrl_w_mem(offset + conv_integer(OP_CODE_s) - 1);
			when ITYPE_ANDI2 =>
				ctrl_w_s <= ctrl_w_mem(offset + conv_integer(OP_CODE_s) - 1);
			when ITYPE_ORI2 =>
				ctrl_w_s <= ctrl_w_mem(offset + conv_integer(OP_CODE_s) - 1);
			when ITYPE_MOV =>
				ctrl_w_s <= ctrl_w_mem(offset + conv_integer(OP_CODE_s) - 1);
			when ITYPE_S_REG1 =>
				ctrl_w_s <= ctrl_w_mem(offset + conv_integer(OP_CODE_s) - 1);
			when ITYPE_S_REG2 =>
				ctrl_w_s <= ctrl_w_mem(offset + conv_integer(OP_CODE_s) - 1);
			when ITYPE_S_MEM2 =>
				ctrl_w_s <= ctrl_w_mem(offset + conv_integer(OP_CODE_s) - 1);
			when ITYPE_L_MEM1 =>
				ctrl_w_s <= ctrl_w_mem(offset + conv_integer(OP_CODE_s) - 1);
			when ITYPE_L_MEM2 =>
				ctrl_w_s <= ctrl_w_mem(offset + conv_integer(OP_CODE_s) - 1);
			when others =>
				ctrl_w_s <= ctrl_w_mem(offset + conv_integer(OP_CODE_s) - 1);

		end case;
	end process;

end architecture;
