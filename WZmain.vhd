---------------------------------------
---------------------------------------
---------------------------------------

-- project_reti_logiche v1.1

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

---------------------------------------

entity project_reti_logiche is
    port (
          i_clk         : in  std_logic;
          i_start       : in  std_logic;
          i_rst         : in  std_logic;
          i_data        : in  std_logic_vector(7 downto 0); --dato letto da memoria nella posizione specificata da o_
          o_address     : out std_logic_vector(15 downto 0); -- in questa variabile va indicata la posizione in memoria dalla quale leggere/sulla quale scrivere 
          o_done        : out std_logic; -- da settare 1 quando l'indirizzo (codificato o no) è stato salvato in memoria
          o_en          : out std_logic; -- da settare per LEGGERE o SCRIVERE in memoria
          o_we          : out std_logic; -- =1 per poter scrivere in memoria; DEVE essere =0 nel momento della INIT_RAM_SET
          o_data        : out std_logic_vector (7 downto 0) -- RESULT (indirizzo codificato da TIMMY)
          );
    end project_reti_logiche;

---------------------------------------
---------------------------------------
---------------------------------------

architecture behav of project_reti_logiche is

    -- definisco gli stati della FSM
    type state_type is (READY, INIT_RAM_SET, CHECK_OFFSET, CHECK, ADDRESS_UPDATE, COMPUTING, GET_FROM_RAM, ALMOST_DONE_POSITIVE, ALMOST_DONE_NEGATIVE, DONE);
    signal next_state, current_state: state_type;

    -- Signals

    signal o_done_next, o_en_next, o_we_next : std_logic := '0';
    signal o_data_next : std_logic_vector(7 downto 0) := "00000000";
    signal o_address_next : std_logic_vector(15 downto 0) := "0000000000000000";

    --booleani
    signal got_addr, got_addr_next : boolean := false;
    signal got_wz, got_wz_next : boolean := false;

    --variabili in cui salvi il valore in arrivo da i_data
    signal read_address, read_address_next : integer range 0 to 127 := 0;               --valore da codificare
    signal wz, wz_next : std_logic_vector(7 downto 0) := "00000000";                    --valore base della wz
    
    signal address, address_next : std_logic_vector(15 downto 0) := "0000000000000000"; --indirizzo di memoria per uso interno

    --output
    signal wz_bit, wz_bit_next : std_logic := '0';
    signal wz_num, wz_num_next : std_logic_vector(2 downto 0) := "000";
    signal wz_offset, wz_offset_next : std_logic_vector(3 downto 0) := "0000";
    
    --interi
    signal temp_wz_num, temp_wz_num_next : integer range 0 to 8 := 0;
    signal offset, offset_next : integer range -127 to 127 := 0;

begin

    process(i_clk, i_rst)
    
    begin
        if (i_rst = '1') then

            --Resetto tutti i segnali

            --booleani
            got_addr <= false;
            got_wz <= false;

            --variabili in cui salvi il valore in arrivo da i_data
            read_address <= 0;
            wz <= "00000000";

            address <= "0000000000000000";
        
            --output
            wz_bit <= '0';
            wz_num <= "000";
            wz_offset <= "0000";
            
            --interi
            temp_wz_num <= 0;
            offset <= 0;

            current_state <= READY;

        elsif (rising_edge(i_clk)) then

            --Aggiorno tutti i segnali
            o_done <= o_done_next;
            o_en <= o_en_next;
            o_we <= o_we_next;
            o_data <= o_data_next;
            o_address <= o_address_next;

            --booleani
            got_addr <= got_addr_next;
            got_wz <= got_wz_next;

            --variabili in cui salvi il valore in arrivo da i_data
            read_address <= read_address_next;
            wz <= wz_next;

            address <= address_next;
            
            --output
            wz_bit <= wz_bit_next;
            wz_num <= wz_num_next;
            wz_offset <= wz_offset_next;

            --interi
            temp_wz_num <= temp_wz_num_next;
            offset <= offset_next;

            current_state <= next_state;

        end if;
    end process;
    
    -- specifica della funzione di stato prossimo
    process(current_state, i_data, i_start, got_addr, got_wz, read_address, wz, address, temp_wz_num, offset, wz_bit, wz_num, wz_offset)

    begin
        --Inizializzo i segnali principali
        o_done_next <= '0';
        o_en_next <= '0';
        o_we_next <= '0';
        o_data_next <= "00000000";
        o_address_next <= "0000000000000000";

        --Inizializzo i segnali interni

        --booleani
        got_addr_next <= got_addr;
        got_wz_next <= got_wz;

        --variabili in cui salvi il valore in arrivo da i_data
        read_address_next <= read_address; 
        wz_next <= wz;

        address_next <= address;

        --output
        wz_bit_next <= wz_bit;
        wz_num_next <= wz_num;
        wz_offset_next <= wz_offset;
        
        --interi
        temp_wz_num_next <= temp_wz_num;
        offset_next <= offset;

        next_state <= current_state;

        case current_state is 

            when READY =>   --init dei componenti
                        if (i_start = '1' ) then
                            --preparo i segali per lo stato successivo
                            o_en_next <= '1';
                            o_address_next <= "0000000000001000";
                            next_state <= INIT_RAM_SET;
                        end if;                    


            when INIT_RAM_SET =>   
                        
                        o_en_next <= '1';
                        o_we_next <= '0';

                        if (not got_addr) then
                            next_state <= GET_FROM_RAM;
                                  
                        elsif (not got_wz) then
                            o_address_next <= "0000000000000000";
                            next_state <= CHECK;
                        end if;


            when CHECK =>  --stato in cui devo controllare se andare alla computazione o devo caricare un'altra wz
                        
                        if (got_addr and got_wz) then
                            next_state <= COMPUTING;
                        else
                            o_en_next <= '1';
                            next_state <= GET_FROM_RAM;
                        end if;
                        

            when GET_FROM_RAM =>  --carico il valore in una variabile e aggiorno i booleani
    
                        if (not got_addr) then
                            read_address_next <= to_integer(unsigned(i_data));
                            got_addr_next <= true;

                            next_state <= INIT_RAM_SET;

                        elsif (not got_wz) then
                            wz_next <= i_data;
                            got_wz_next <= true;

                            next_state <= ADDRESS_UPDATE;
                        end if;
                        

            when ADDRESS_UPDATE => --controllo se ho analizzato tutte le wz
                        if (temp_wz_num = 8) then
                            next_state <= ALMOST_DONE_NEGATIVE;
                        else
                            o_en_next <= '1';
                            o_address_next <= address;
                            next_state <= CHECK;
                        end if;


            when COMPUTING =>  
                        offset_next <= (read_address - to_integer(unsigned(wz)));
                        next_state <= CHECK_OFFSET;

                                                    
            when CHECK_OFFSET =>

                        if ((offset >= 0) and (offset <= 3)) then
                            if (offset = 0) then
                                wz_offset_next <= "0001";
                            elsif (offset = 1) then
                                wz_offset_next <= "0010";
                            elsif (offset = 2) then
                                wz_offset_next <= "0100";
                            elsif (offset = 3) then
                                wz_offset_next <= "1000";
                            end if;
                            
                            wz_bit_next <= '1';
                            wz_num_next <= std_logic_vector(to_unsigned( temp_wz_num , 3));
                            next_state <= ALMOST_DONE_POSITIVE;

                        else
                            address_next <= address + "0000000000000001";
                            got_wz_next <= false;
                            temp_wz_num_next <= (temp_wz_num + 1);

                            next_state <= ADDRESS_UPDATE;
                        end if;

            
            when ALMOST_DONE_NEGATIVE =>
                        o_en_next <= '1';
                        o_we_next <= '1';
                        o_address_next <= "0000000000001001";
                        o_data_next <= (wz_bit & std_logic_vector(to_unsigned( read_address , 7)));
                        o_done_next <= '1';

                        next_state <= DONE;

                     
            when ALMOST_DONE_POSITIVE => 
                        o_en_next <= '1';
                        o_we_next <= '1';
                        o_address_next <= "0000000000001001";
                        o_data_next <= (wz_bit & wz_num & wz_offset);
                        o_done_next <= '1';
                        
                        next_state <= DONE;
                        

            when DONE => 
                        
                        if (i_start = '0') then
                            
                            --Resetto tutti i segnali
                            got_addr_next <= false;
                            got_wz_next <= false;

                            read_address_next <= 0;
                            wz_next <= "00000000";
                            address_next <= "0000000000000000";
                            temp_wz_num_next <= 0;

                            o_done_next <= '0';

                            next_state <= READY;
                        end if;
                        
            when others =>
                        next_state <= READY;

        end case;
    end process ;
end behav; 