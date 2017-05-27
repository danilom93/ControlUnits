library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.myTypes.all;

entity dlx_fsm_cu is
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

architecture dlx_fsm_cu_arch of dlx_fsm_cu is
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
  -- FSM
  -- it takes 3 clock cycles to complete an instruction
  -- at each clock cycle, a new state is taken
	
  -- FSM 3 states + 1 reset state
	type TYPE_STATE is (STATE0, STATE1, STATE2, RESET);
	signal CURRENT_STATE : TYPE_STATE;
	signal NEXT_STATE : TYPE_STATE;

  -- Here there is NO PIPELINE, so only one control word is needed
  signal OP_CODE_s : std_logic_vector(OP_CODE_SIZE-1 downto 0);	-- signal used to take the OPCODE
  signal FUNC_s : std_logic_vector(FUNC_SIZE-1 downto 0);	-- -- signal used to take the FUNC
  signal ctrl_w_s : std_logic_vector(CW_SIZE-1 downto 0);	-- control word signal

begin

  OP_CODE_s <= OP_CODE;
  FUNC_s <= FUNC;
	
  -- process that manages the current state, sensitive to the Clk and Rst
  process(Clk, Rst)
  begin
    if Rst='0' then
      CURRENT_STATE <= RESET;
    elsif (Clk ='1' and Clk'EVENT) then
      CURRENT_STATE <= NEXT_STATE;
    end if;
    end process;

  -- process that assigns the different outputs depending on the state in which the FSM is, then switches to the next
  process(CURRENT_STATE)
	begin
		case CURRENT_STATE is
			when STATE0 =>
        RF1 <= ctrl_w_s(CW_SIZE-1);	-- takes the MSB
        RF2 <= ctrl_w_s(CW_SIZE-2);	-- takes the MSB-1 bit
        EN1 <= ctrl_w_s(CW_SIZE-3);
				NEXT_STATE <= STATE1;
			when STATE1 =>
        S1 <= ctrl_w_s(CW_SIZE-4);
        S2 <= ctrl_w_s(CW_SIZE-5);
        ALU_SEL <= ctrl_w_s(CW_SIZE-6 downto CW_SIZE-7);	-- takes 2 bits
        EN2 <= ctrl_w_s(CW_SIZE-8);
				NEXT_STATE <= STATE2;
			when STATE2 =>
        RM <= ctrl_w_s(CW_SIZE-9);
        WM <= ctrl_w_s(CW_SIZE-10);
        EN3 <= ctrl_w_s(CW_SIZE-11);
        S3 <= ctrl_w_s(CW_SIZE-12);
        WF1 <= ctrl_w_s(CW_SIZE-13);
				NEXT_STATE <= STATE0;
			when RESET =>
				NEXT_STATE <= STATE0;
		end case;
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


end dlx_fsm_cu_arch;
