module cpu (
	input clk , rst , run , halt ,
	output [7:0] addr , data_in , data_out, register_aout, register_bout, rand, code,ram_out,
	output await , fetcha , fetchb , execa , execb, wren_out, rden_out, alu_ena_out, alu_zflag, alu_cflag 
);
//作成する
wire [7:0] pc_out,  opecode, operand, pc_in, register_cin, ram_data_out, ram_data_in, ram_addr;
wire rden, wren, pc_load, register_cload;
wire [2:0] register_asel, register_bsel, register_csel;
assign addr = ram_addr;
assign ram_out = ram_data_out;
assign data_in = ram_data_in;
assign rand = operand;
assign code = opecode;
assign wren_out = wren;
assign rden_out = rden;
assign alu_ena_out = alu_ena;
// stage
stage s(
	clk,//in
	rst,//in
	run,//in
	halt , //halt
	await,//out
	fetcha,//out
	fetchb,//out
	execa,//out
	execb//out
);


// pc
pc p(
	clk,//in, ok
	rst,//in, ok
	fetcha || fetchb,//in, inc , ok
	pc_load, //in, load, ok
	pc_in, //in, in
	pc_out  //out, out(1, 2, 3, ...)
);
assign pc_load = select_pc_load(execa, opecode, alu_zflag);
function select_pc_load;
	input _execa;
	input [7:0] _opecode;
	input _alu_zflag;
	begin
		if(_execa == 1) begin
			//JMPの時
			if(_opecode == 8'b00111111)
				select_pc_load = 1;
			//JNZの時
			else if(_opecode == 8'b00100011 && _alu_zflag != 1)
				select_pc_load = 1;
		end else 
			select_pc_load = 0;
	end
endfunction

assign pc_in = select_pc_in(execa, opecode, operand);
function [7:0] select_pc_in;
	input _execa;
	input [7:0] _opecode;
	input [7:0] _operand;
	begin
		if (_execa == 1) begin
			case(_opecode)
				//JMPの時
				8'b00111111 : select_pc_in = _operand;
				//JNZの時
				8'b00100011 : select_pc_in = _operand;
			endcase
		end
	end
endfunction

// register
register r (
	clk,
	rst,
	register_cload,
	register_asel,//0～7の8個
	register_bsel,//0～7の8個
	opecode[2:0],//register_csel,//代入先のレジスタr[c]
	register_cin, //register_cin,代入する値
	register_aout,
	register_bout
);

assign register_asel = select_register_asel(opecode, operand, fetcha, fetchb, execa, execb); //r[3]
function [2:0] select_register_asel;
	input [7:0] _opecode;
	input [7:0] _operand;
	input _fetcha;
	input _fetchb;
	input _execa;
	input _execb;
	begin
		if(_fetcha == 1 || _fetchb == 1) 
			select_register_asel = 3'b011; //r[3]を出力
		else if(_execa == 1 || _execb == 1) begin
			case (_opecode[7:3])
				//LDの時
				5'b01000 : select_register_asel = _operand[7:5];
				//MOVの時
				5'b00001 : select_register_asel = _operand[7:5];
				//STSの時
				5'b01100 : select_register_asel = _operand[7:5];
				//STの時
				5'b01100 : select_register_asel = _operand[7:5];
				//INCの時
				5'b10000 : select_register_asel = _operand[7:5];
				//DECの時
				5'b10001 : select_register_asel = _operand[7:5];
				//ADDの時
				5'b10010 : select_register_asel = _operand[7:5];
				//SUBの時
				5'b10011 : select_register_asel = _operand[7:5];
				default: select_register_asel = 3'b011; //r[3]を出力
			endcase
		end 
	end
endfunction

assign register_bsel = select_register_bsel(opecode, operand, fetcha, fetchb, execa, execb); //r[4]
function [2:0] select_register_bsel;
	input [7:0] _opecode;
	input [7:0] _operand;
	input _fetcha;
	input _fetchb;
	input _execa;
	input _execb;
	begin
		if(_fetcha == 1 || _fetchb == 1) 
			select_register_bsel = 3'b100; //r[4]を出力
		else if(_execa == 1 || _execb == 1) begin
			case (_opecode[7:3])
				//STの時
				5'b01100 : select_register_bsel = _opecode[2:0];
				//ADDの時
				5'b10010 : select_register_bsel = _operand[4:2];
				//SUBの時
				5'b10011 : select_register_bsel = _operand[4:2];
				default: select_register_bsel = 3'b100; //r[4]を出力
			endcase
		end 
	end
endfunction

assign register_cin = select_register_cin(opecode[7:3], operand, execa,execb, ram_data_out, register_aout, alu_sout);
function [7:0] select_register_cin;
	input [4:0] _opecode_slice;
	input [7:0] _operand;
	input _execa;
	input _execb;
	input [7:0] _ram_data_out;
	input [7:0] _register_aout;
	input [7:0] _alu_sout;
	begin
		if(_execa == 1) begin
			case(_opecode_slice)
				//LDIの時operandをそのままcinに代入
				5'b01010 : select_register_cin = _operand;
				//MOVの時
				5'b00001 : select_register_cin = _register_aout;
				//INCの時
				5'b10000 : select_register_cin = _alu_sout;
				//DECの時
				5'b10001 : select_register_cin = _alu_sout;
				//ADDの時
				5'b10010 : select_register_cin = _alu_sout;
				//SUBの時
				5'b10011 : select_register_cin = _alu_sout;
				default: select_register_cin = 8'b0;
			endcase
		end else if(_execb == 1) begin
			case(_opecode_slice)
				//LDの時ram_data_outをcinに代入
				5'b01000 : select_register_cin = _ram_data_out;
				//LDSの時
				5'b01001 : select_register_cin = _ram_data_out;
			endcase
		end else
			select_register_cin = 8'b0;
	end
endfunction

assign register_cload = select_register_cload(opecode[7:3],execa, execb, fetcha, fetchb);
//cloadはr[c]に書き込むときにhighになる,逆にcloadがhighのときのみcinが使われるので，cinは関数でなくてよいので，operandをそのまま使う
function select_register_cload;
	input [4:0] _opecode_slice;
	input _execa;
	input _execb;
	input _fetcha;
	input _fetchb;
	begin
		if (_fetcha == 1 || _fetchb == 1) 
			select_register_cload = 0;
		else if (_execa == 1) begin
			case (_opecode_slice)
				//LDIの時
				5'b01010 : select_register_cload = 1;
				//MOVの時
				5'b00001 : select_register_cload = 1;
				//INCの時
				5'b10000 : select_register_cload = 1;
				//DECの時
				5'b10001 : select_register_cload = 1;
				//ADDの時
				5'b10010 : select_register_cload = 1;
				//SUBの時
				5'b10011 : select_register_cload = 1;
				default: select_register_cload = 0;
			endcase
		end else if (_execb == 1) begin 
			case (_opecode_slice)
				//LDの時
				5'b01000 : select_register_cload = 1;
				//LDSの時
				5'b01001 : select_register_cload = 1;
				default: select_register_cload = 0;
			endcase
		end else
			select_register_cload = 0;
	end
endfunction


// ram
ram ra(
	ram_addr ,//select_addrによってpc_outかopecodeの下部か選ばれる
	clk,//in, ok
	ram_data_in ,//writeの時にmem[addr]に格納する値
	rden,//rden(読み出し許可)(0 or 1)(selectされる)
	wren , //wren(0 or 1)(selectされる)
	ram_data_out //アドレスに格納された値が data out[7:0] から出力されることとなる（オペコードになる）
);

assign ram_addr = select_ram_addr ( fetcha , fetchb , pc_out , execa,execb,  opecode[7:3], operand, register_aout, register_bout);
function [7:0] select_ram_addr ;
	input _fetcha ;
	input _fetchb ;
	input [7:0] _pc_out ;
	input _execa;
	input _execb;
	input [4:0] _opecode_slice;
	input [7:0] _operand;
	input [7:0] _register_aout;
	input [7:0] _register_bout;
	begin
		if (_fetcha == 1 || _fetchb == 1) 
			select_ram_addr = _pc_out;
		else if (_execa == 1 || _execb == 1) begin
			case(_opecode_slice)
				//LDの時ram[r[a]]になる(r[a]はregisterの方からもらう)
				5'b01000: select_ram_addr = _register_aout;
				//LDSの時
				5'b01001: select_ram_addr = _operand;
				//STSの時
				5'b01101: select_ram_addr = _operand;
				//STの時
				5'b01100: select_ram_addr = _register_bout;
				default: select_ram_addr = 8'b0;
			endcase
		end
	end
endfunction

assign ram_data_in = select_ram_data_in ( fetcha , fetchb , execa,execb,  opecode[7:3], operand, register_aout, register_bout);
function [7:0] select_ram_data_in;
	input _fetcha ;
	input _fetchb ;
	input _execa;
	input _execb;
	input [4:0] _opecode_slice;
	input [7:0] _operand;
	input [7:0] _register_aout;
	input [7:0] _register_bout;
	begin
		if(_execa == 1 || _execb == 1) begin
			case(_opecode_slice)
				//STSの時
				5'b01101: select_ram_data_in = _register_aout;
				//STの時
				5'b01100: select_ram_data_in = _register_aout;
				default: select_ram_data_in = 8'b0;
			endcase
		end else
			select_ram_data_in = 8'b0;
	end
endfunction

//rden, wdenがhighかlowかを決める
assign { rden, wren } = assign_ram(fetcha, fetchb, execa, execb, opecode[7:3]);
function [1:0] assign_ram ;	//rden, wdenを決める
		input _fetcha ;
		input _fetchb ;
		input _execa;
		input _execb;
		input [4:0] _opecode_slice;
		begin
			if (_fetcha == 1 || _fetchb == 1) begin
                // 状態が fetcha もしくは fetchb のとき，ram からデータを読み込むので rden が High，wren が Low となればよい．
                assign_ram = {1'b1, 1'b0};
			end else if (_execa == 1) begin //opcode に応じてramに対しての読み込みか書き込みか決まる．
				case(_opecode_slice)
					//STの時
					5'b01100: assign_ram = {1'b0, 1'b1}; //wrenをhighにする(ramに書き込む)
					//STSの時
					5'b01101: assign_ram = {1'b0, 1'b1}; //wrenをhighにする(ramに書き込む)
					default: assign_ram = {1'b1, 1'b0}; //rdenをhighにする(ramから読み込む)
				endcase
			end else if (_execb == 1) begin //opcode に応じてramに対しての読み込みか書き込みか決まる．
				case(_opecode_slice)
					//LDの時
					5'b01000: assign_ram = {1'b1, 1'b0}; //rdenをhighにする(ramから読み込む)
					//LDIの時
					5'b01010: assign_ram = {1'b1, 1'b0}; //rdenをhighにする(ramから読み込む)
					//STSの時
					5'b01101: assign_ram = {1'b0, 1'b1}; //wrenをhighにする(ramに書き込む)
					//STの時
					5'b01100: assign_ram = {1'b0, 1'b1}; //wrenをhighにする(ramに書き込む)
					default: assign_ram = {1'b1, 1'b0}; //rdenをhighにする(ramから読み込む)
				endcase
			end 
		end
endfunction

// alu
wire [7:0] alu_ain, alu_bin, alu_sout;
wire alu_ena;
wire [1:0] alu_ctrl;
alu a (
	clk,
	rst,
	alu_ena, //hの時演算結果によりフラグを更新する
	alu_ctrl,//00->a+1, 01->a-1, 10->a+b, 11->a-b
	register_aout, //alu_ain=r[a]固定でいい(registerの方で値を制御する)
	register_bout, //alu_ain=r[b]固定でいい(registerの方で値を制御する)
	alu_cflag, //out
	alu_zflag, //out
	alu_sout //out
);

assign alu_ena = select_alu_ena (opecode[7:3], execa);
function select_alu_ena;
	input [4:0] _opecode_slice;
	input _execa;
	begin
		if(_execa == 1) begin
			case(_opecode_slice)
				//INCの時
				5'b10000: select_alu_ena = 1;
				//DECの時
				5'b10001: select_alu_ena = 1;
				//ADDの時
				5'b10010: select_alu_ena = 1;
				//SUBの時
				5'b10011: select_alu_ena = 1;
				// //JZの時
				// 8'b00100010 : select_alu_ena = 1;
				default: select_alu_ena = 0;
			endcase
		end else
			select_alu_ena = 0;	
	end
endfunction

assign alu_ctrl = select_alu_ctrl (opecode[7:3]);
function [1:0] select_alu_ctrl;
	input [4:0] _opecode_slice;
	begin
		case(_opecode_slice)
			//INCの時
			5'b10000: select_alu_ctrl = 2'b00;
			//DECの時
			5'b10001: select_alu_ctrl = 2'b01;
			//ADDの時
			5'b10010: select_alu_ctrl = 2'b10;
			//SUBの時
			5'b10011: select_alu_ctrl = 2'b11;
			default: select_alu_ctrl = 2'b00;
		endcase
	end
endfunction


//generate
generate
	genvar i;
	for (i =0; i <8; i=i +1) begin : gen
	// opecode
	//opecodeとは，fetcha が High のとき，pc_out の値を読み込むための信号線である．
		dffe opecode_dffe(
		.d(ram_data_out[i]) ,
		. clk ( !clk ),
		. clrn (! rst ),
		. prn (1'b1) ,
		. ena (fetcha),
		.q( opecode[i]));

		//operand
		//operandとは，fetchb が High のとき，pc_out の値を読み込むための信号線である．
		dffe operand_dffe(
		.d(ram_data_out[i]) ,
		. clk ( !clk ),
		. clrn (! rst ),
		. prn (1'b1) ,
		. ena (fetchb),
		.q( operand[i]));
	end
endgenerate

endmodule
