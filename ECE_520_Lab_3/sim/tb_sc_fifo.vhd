library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity tb_sc_fifo is
    generic (
        CLK_PERIOD   : time    := 20 ns;
        NUM_RANDOM   : integer := 20;   -- must match n in generate_test_data.py
        READ_LATENCY : integer := 1
    );
end entity tb_sc_fifo;

architecture sim of tb_sc_fifo is

    -- Component declaration (works whether sc_fifo is VHDL or Verilog in Vivado)
    component sc_fifo is
        generic (
            READ_LATENCY : positive := 1
        );
        port (
            clk          : in  std_logic;
            srst         : in  std_logic;
            data_in      : in  std_logic_vector(15 downto 0);
            write_enable : in  std_logic;
            read_enable  : in  std_logic;
            data_count   : out std_logic_vector(5 downto 0);
            valid        : out std_logic;
            data_out     : out std_logic_vector(15 downto 0);
            almost_full  : out std_logic;
            almost_empty : out std_logic;
            full         : out std_logic;
            empty        : out std_logic
        );
    end component;

    constant DEPTH     : integer := 32;
    constant AE_THRESH : integer := 1;
    constant AF_THRESH : integer := 31;
    constant NUM_WORDS : integer := 4*DEPTH + 16 + NUM_RANDOM;  -- 144 pattern words + random

    signal clk          : std_logic := '0';
    signal srst         : std_logic := '1';
    signal data_in      : std_logic_vector(15 downto 0) := (others => '0');
    signal write_enable : std_logic := '0';
    signal read_enable  : std_logic := '0';
    signal data_count   : std_logic_vector(5 downto 0);
    signal valid        : std_logic;
    signal data_out     : std_logic_vector(15 downto 0);
    signal almost_full  : std_logic;
    signal almost_empty : std_logic;
    signal full         : std_logic;
    signal empty        : std_logic;
    signal sim_done     : boolean := false;

    type word_array_t is array (0 to NUM_WORDS-1) of std_logic_vector(15 downto 0);

    -- Returns the value of a hex digit, or -1 if c is not a hex digit
    function hex_digit(c : character) return integer is
    begin
        case c is
            when '0' to '9' => return character'pos(c) - character'pos('0');
            when 'a' to 'f' => return character'pos(c) - character'pos('a') + 10;
            when 'A' to 'F' => return character'pos(c) - character'pos('A') + 10;
            when others     => return -1;
        end case;
    end function;

begin

    UUT : sc_fifo
        generic map (
            READ_LATENCY => READ_LATENCY
        )
        port map (
            clk          => clk,
            srst         => srst,
            data_in      => data_in,
            write_enable => write_enable,
            read_enable  => read_enable,
            data_count   => data_count,
            valid        => valid,
            data_out     => data_out,
            almost_full  => almost_full,
            almost_empty => almost_empty,
            full         => full,
            empty        => empty
        );

    -- Clock generation (stops once the test finishes so the sim can end)
    clk_proc : process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    stim_proc : process
        file in_file      : text open read_mode  is "input_data.txt";
        file results_file : text open write_mode is "test_results.txt";

        variable file_data : word_array_t;  -- unread entries stay 'U' (like X in $readmemh)
        variable errors    : integer := 0;

        variable l      : line;
        variable c      : character;
        variable ok     : boolean;
        variable val    : natural;
        variable in_tok : boolean;
        variable idx    : natural := 0;

        -- FIFO bookkeeping: words go in and must come out in file order
        variable wr_idx    : natural := 0;  -- next file word to write
        variable exp_idx   : natural := 0;  -- next file word expected on data_out
        variable count_exp : natural := 0;  -- expected number of words in the FIFO
        variable last_out  : std_logic_vector(15 downto 0) := (others => '0');

        -- Equivalent of the "raw_fd | 1" multi-channel descriptor:
        -- write each message to the results file AND the console
        procedure log_msg(msg : string) is
            variable lo : line;
        begin
            write(lo, msg);
            writeline(results_file, lo);
            write(lo, msg);
            writeline(output, lo);
        end procedure;

        procedure fail(msg : string) is
        begin
            errors := errors + 1;
            log_msg("[" & time'image(now) & "] FAIL: " & msg);
        end procedure;

        -- Compare data_count and all four flags against the expected count
        procedure check_status is
        begin
            if to_integer(unsigned(data_count)) /= count_exp then
                fail("data_count=" & integer'image(to_integer(unsigned(data_count))) &
                     " expected=" & integer'image(count_exp));
            end if;
            if (empty = '1') /= (count_exp = 0) then
                fail("empty=" & std_logic'image(empty) & " count=" & integer'image(count_exp));
            end if;
            if (full = '1') /= (count_exp = DEPTH) then
                fail("full=" & std_logic'image(full) & " count=" & integer'image(count_exp));
            end if;
            if (almost_empty = '1') /= (count_exp <= AE_THRESH) then
                fail("almost_empty=" & std_logic'image(almost_empty) & " count=" & integer'image(count_exp));
            end if;
            if (almost_full = '1') /= (count_exp >= AF_THRESH) then
                fail("almost_full=" & std_logic'image(almost_full) & " count=" & integer'image(count_exp));
            end if;
        end procedure;

        -- One clock cycle with the given enables. Accepted writes take the next
        -- file word; rejected writes drive 0x1234, which must never come out.
        -- Every valid output must be the next word in file order.
        procedure cycle(wr, rd : std_logic) is
            variable wr_ok, rd_ok : boolean;
        begin
            wr_ok := wr = '1' and count_exp < DEPTH;
            rd_ok := rd = '1' and count_exp > 0;
            write_enable <= wr;
            read_enable  <= rd;
            if wr_ok then
                data_in <= file_data(wr_idx mod NUM_WORDS);
                wr_idx  := wr_idx + 1;
            else
                data_in <= x"1234";
            end if;
            if wr_ok and not rd_ok then
                count_exp := count_exp + 1;
            elsif rd_ok and not wr_ok then
                count_exp := count_exp - 1;
            end if;

            wait for CLK_PERIOD;

            if valid = '1' then
                if data_out /= file_data(exp_idx mod NUM_WORDS) then
                    fail("data_out=" & integer'image(to_integer(unsigned(data_out))) &
                         " expected=" & integer'image(to_integer(unsigned(file_data(exp_idx mod NUM_WORDS)))));
                end if;
                exp_idx  := exp_idx + 1;
                last_out := data_out;
            elsif data_out /= last_out then          -- output must hold between reads
                fail("data_out changed to " & integer'image(to_integer(unsigned(data_out))) &
                     " without valid");
            end if;
            check_status;
        end procedure;

        procedure check_reset is
        begin
            if data_out /= x"0000" then
                fail("data_out=" & integer'image(to_integer(unsigned(data_out))) & " after reset, expected 0");
            end if;
            if valid /= '0' then
                fail("valid=" & std_logic'image(valid) & " after reset, expected '0'");
            end if;
            count_exp := 0;
            exp_idx   := wr_idx;                     -- words in the FIFO were discarded
            last_out  := (others => '0');
            check_status;
        end procedure;

    begin
        -- Equivalent of $readmemh: whitespace-separated hex values, // comments allowed
        while not endfile(in_file) and idx < NUM_WORDS loop
            readline(in_file, l);
            in_tok := false;
            val    := 0;
            loop
                read(l, c, ok);
                if ok and hex_digit(c) >= 0 then
                    val    := (val * 16 + hex_digit(c)) mod 65536;
                    in_tok := true;
                else
                    if in_tok then
                        if idx < NUM_WORDS then
                            file_data(idx) := std_logic_vector(to_unsigned(val, 16));
                            idx := idx + 1;
                        end if;
                        in_tok := false;
                        val    := 0;
                    end if;
                    exit when (not ok) or c = '/' or c = '#';  -- end of line or start of comment
                end if;
            end loop;
        end loop;
        assert idx = NUM_WORDS
            report "input_data.txt has " & integer'image(idx) & " words, expected " &
                   integer'image(NUM_WORDS) & " (check NUM_RANDOM)"
            severity failure;

        -- Reset: outputs return to 0, empty = 1, full = 0
        srst <= '1';
        wait for 2 * CLK_PERIOD;
        check_reset;
        srst <= '0';

        -- All 1s, all 0s, alternating AAAA/5555, then a unique word in every
        -- memory location. Each fills the FIFO to full and drains it, checking
        -- the flags at every count. The first one also tries overflow/underflow.
        for t in 1 to 4 loop
            for i in 1 to DEPTH loop cycle('1', '0'); end loop;
            if t = 1 then cycle('1', '0'); end if;      -- overflow: ignored
            for i in 1 to DEPTH loop cycle('0', '1'); end loop;
            if t = 1 then cycle('0', '1'); end if;      -- underflow: ignored
            for i in 1 to READ_LATENCY loop cycle('0', '0'); end loop;
        end loop;

        -- Walking ones: write a word, read it back the next cycle
        for i in 1 to 16 loop
            cycle('1', '0');
            cycle('0', '1');
        end loop;

        -- Reset in the middle of operation (last word read was 0x8000):
        -- output must return to 0
        srst <= '1';
        wait for 2 * CLK_PERIOD;
        check_reset;
        srst <= '0';

        -- Simultaneous read and write: at empty (write only), at full (read
        -- only), and at half full (both, count unchanged)
        cycle('1', '1');
        for i in 1 to DEPTH - 1 loop cycle('1', '0'); end loop;
        cycle('1', '1');
        for i in 1 to DEPTH/2 - 1 loop cycle('0', '1'); end loop;
        for i in 1 to DEPTH loop cycle('1', '1'); end loop;
        while count_exp > 0 loop cycle('0', '1'); end loop;
        for i in 1 to READ_LATENCY + 2 loop cycle('0', '0'); end loop;

        -- Every word written must have come out exactly once
        if exp_idx /= wr_idx then
            fail(integer'image(wr_idx) & " words written but " &
                 integer'image(exp_idx) & " read out");
        end if;

        wait for 2 * CLK_PERIOD;
        if errors = 0 then
            log_msg("TEST PASSED");
        else
            log_msg("TEST FAILED: " & integer'image(errors) & " errors");
        end if;

        file_close(results_file);
        sim_done <= true;  -- stops the clock; with no more events the sim ends
        wait;
    end process;

end architecture sim;