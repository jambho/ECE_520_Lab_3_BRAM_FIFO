library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity sc_fifo is
    generic (
        WIDTH : positive := 16;
        DEPTH : positive := 32;  
        ALMOST_EMPTY_THRESHOLD : natural  := 1;
        ALMOST_FULL_THRESHOLD : natural  := 31;
        READ_LATENCY : positive := 1;    
        G_USE_BMG_IP : boolean  := true  
    );
    port (
        clk : in  std_logic;
        srst : in  std_logic;
        data_in : in  std_logic_vector(WIDTH-1 downto 0);
        write_enable : in  std_logic;
        read_enable : in  std_logic;
        data_count : out std_logic_vector(integer(ceil(log2(real(DEPTH+1))))-1 downto 0);
        valid : out std_logic;
        data_out : out std_logic_vector(WIDTH-1 downto 0);
        almost_full : out std_logic;
        almost_empty : out std_logic;
        full : out std_logic;
        empty : out std_logic
    );
end entity sc_fifo;

architecture rtl of sc_fifo is 
    
    constant ADDR_W : positive := integer(ceil(log2(real(DEPTH))));
    constant COUNT_W : positive := integer(ceil(log2(real(DEPTH+1))));
    COMPONENT blk_mem_gen_0
        PORT (
            clka : IN STD_LOGIC;
            ena : IN STD_LOGIC;
            wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
            addra : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
            dina : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            clkb : IN STD_LOGIC;
            rstb : IN STD_LOGIC;
            enb : IN STD_LOGIC;
            addrb : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
<<<<<<< HEAD
            doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
=======
            doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            rsta_busy : OUT STD_LOGIC;
            rstb_busy : OUT STD_LOGIC 
>>>>>>> 9c999a566532bb286978b95a093d3d0d9246df83
        );
    END COMPONENT;

    signal wr_ptr : unsigned(ADDR_W-1 downto 0) := (others => '0');
    signal rd_ptr : unsigned(ADDR_W-1 downto 0) := (others => '0');
    signal count : unsigned(COUNT_W-1 downto 0) := (others => '0');
    signal empty_r : std_logic := '1';
    signal full_r : std_logic := '0';
    signal a_empty_r : std_logic := '1';
    signal a_full_r : std_logic := '0';
<<<<<<< HEAD
    signal enb_s : std_logic;
=======
>>>>>>> 9c999a566532bb286978b95a093d3d0d9246df83

    signal wr_ok : std_logic;
    signal rd_ok : std_logic;
    signal wea_v : std_logic_vector(0 downto 0);

    signal mem_dout : std_logic_vector(WIDTH-1 downto 0);

<<<<<<< HEAD
    type data_pipe_t is array (0 to READ_LATENCY-1) of std_logic_vector(WIDTH-1 downto 0);
=======
    type data_pipe_t is array (0 to REAL_LATENCY-1) of std_logic_vector(WIDTH-1 downto 0);
>>>>>>> 9c999a566532bb286978b95a093d3d0d9246df83
    signal dpipe : data_pipe_t := (others => (others =>'0'));
    signal val_pipe : std_logic_vector(0 to READ_LATENCY-1) := (others => '0');

begin
    wr_ok <= write_enable and not full_r and not srst;
    rd_ok <= read_enable and not empty_r and not srst;
    wea_v(0) <= wr_ok;
<<<<<<< HEAD
    enb_s <= rd_ok or srst;

    --BRAM declaration from IP catalogue
=======

    --Generate bram instance from IP Block Memory Generator
    gen_bram : generate
>>>>>>> 9c999a566532bb286978b95a093d3d0d9246df83
        u_bram : blk_mem_gen_0
            port map (
                clka => clk,
                ena => '1',
                wea => wea_v,
                addra => std_logic_vector(wr_ptr),
                dina => data_in,
                clkb => clk,
                rstb => srst,
<<<<<<< HEAD
                enb => enb_s,          
                addrb => std_logic_vector(rd_ptr),
                doutb => mem_dout
            );            
=======
                enb => rd_ok,          
                addrb => std_logic_vector(rd_ptr),
                doutb => mem_dout
            );            
    end generate gen_bram;
>>>>>>> 9c999a566532bb286978b95a093d3d0d9246df83

    process (clk)
        variable v_count : unsigned(COUNT_W-1 downto 0);
    begin
        if rising_edge(clk) then
            if srst = '1' then
                wr_ptr <= (others => '0');
                rd_ptr <= (others => '0');
                count <= (others => '0');
                empty_r <= '1';
                full_r <= '0';
                a_empty_r <= '1';
                a_full_r <= '0';
            else 
                if wr_ok = '1' then
                    wr_ptr <= wr_ptr + 1;
                end if;
                if rd_ok = '1' then 
                    rd_ptr <= rd_ptr + 1;
                end if;

                v_count := count;
<<<<<<< HEAD
                if wr_ok = '1' and rd_ok = '0' then
=======
                if wr_ok = '1' and rd_ok = '0';
>>>>>>> 9c999a566532bb286978b95a093d3d0d9246df83
                    v_count := count + 1;
                elsif wr_ok = '0' and rd_ok = '1' then
                    v_count := count - 1;
                end if;

                count <= v_count;
                if v_count = 0 then
                    empty_r <= '1';
                else 
                    empty_r <= '0';
                end if;

                if v_count = DEPTH then
                    full_r <= '1';
                else
                    full_r <= '0';
                end if;

                if v_count <= ALMOST_EMPTY_THRESHOLD then 
                    a_empty_r <= '1';
                else
                    a_empty_r <= '0';
                end if;

<<<<<<< HEAD
                if v_count >= ALMOST_FULL_THRESHOLD then 
=======
                if v_count <= ALMOST_FULL_THRESHOLD then 
>>>>>>> 9c999a566532bb286978b95a093d3d0d9246df83
                    a_full_r <= '1';
                else 
                    a_full_r <= '0';
                end if;
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if srst = '1' then
<<<<<<< HEAD
                val_pipe <= (others => '0');
                dpipe <= (others => (others => '0'));
            else 
                val_pipe(0) <= rd_ok;
                for i in 1 to READ_LATENCY-1 loop
                    val_pipe(i) <= val_pipe(i-1);
=======
                vpipe <= (others => '0');
                dpipe <= (others => (others => '0'));
            else 
                vpipe(0) <= rd_ok;
                for i in 1 to READ_LATENCY-1 loop
                    vpipe(i) <= vpipe(i-1);
>>>>>>> 9c999a566532bb286978b95a093d3d0d9246df83
                    if i = 1 then
                        dpipe(i) <= mem_dout;
                    else
                        dpipe(i) <= dpipe(i-1);
                    end if;
                end loop;
            end if;
        end if;
    end process;

    gen_lat1 : if READ_LATENCY = 1 generate
        data_out <= mem_dout;
<<<<<<< HEAD
    end generate;
    gen_latn : if READ_LATENCY > 1 generate
        data_out <= dpipe(READ_LATENCY -1);
    end generate;
    valid <= val_pipe(READ_LATENCY-1);
=======
    end generate
    gen_latn : if READ_LATENCY > 1 generate
        data_out <= dpipe(READ_LATENCY -1);
    end generate;
    valid <= vpipe(READ_LATENCY-1);
>>>>>>> 9c999a566532bb286978b95a093d3d0d9246df83
    data_count <= std_logic_vector(count);
    empty <= empty_r;
    full <= full_r;
    almost_empty <= a_empty_r;
    almost_full <= a_full_r;
    
end architecture rtl;