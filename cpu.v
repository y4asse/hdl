module cpu (
	input clk , rst , run , halt ,
	output [7:0] addr , data_in , data_out, register_aout, register_bout,
	output await , fetcha , fetchb , execa , execb
);
//作成する
wire [7:0] pc_out,  opecode, operand, pc_in, register_cin, ram_data_out, ram_data_in, ram_addr;
wire rden, wren, pc_load, register_cload;
wire [2:0] register_asel, register_bsel, register_csel;
assign addr = ram_addr;
assign ram_data_out = data_out;
assign ram_data_in = data_in;
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
assign pc_load = 1'b0;
assign pc_in = 8'b0;

// register
register r (
	clk,
	rst,
	register_cload,
	register_asel,//0～7の8個
	register_bsel,//0～7の8個
	opecode[2:0],//register_csel,//代入先のレジスタr[c]
	register_cin, //register_cin,
	register_aout,
	register_bout
);

assign register_asel = 3'b011; //r[3]
function [2:0] select_register_asel;
	input [7:0] _opecode;
	input [7:0] _operand;
	begin
		case (_opecode[7:3])
			//LDの時
			5'b01000 : select_register_asel = _operand[7:5];
			default: select_register_asel = 3'b011; //r[3]を出力
		endcase
	end
endfunction

assign register_bsel = 3'b100; //r[4]

assign register_cin = operand;
function [7:0] select_register_cin;
	input [7:0] _opecode;
	input [7:0] _operand;
	input _execa;
	begin
		if(_execa	== 1'b1) begin
			case(_opecode[7:3])
				//LDIの時operandをそのままcinに代入
				5'b01010 : select_register_cin = _operand;
				//LDの時ram_data_outをcinに代入
				5'b01000 : select_register_cin = ram_data_out;
				//MOVの時
				5'b00001 : select_register_cin = _operand;
			endcase
		end else
			select_register_cin = 8'b0;
	end
endfunction

assign register_cload = select_register_cload(opecode[7:3], execa);
//cloadはr[c]に書き込むときにhighになる,逆にcloadがhighのときのみcinが使われるので，cinは関数でなくてよいので，operandをそのまま使う
function select_register_cload;
	input [4:0] _opecode_slice;
	input _execa;
	begin
		if (_execa == 1'b1) begin
			case (_opecode_slice)
				//LDIの時
				5'b01010 : select_register_cload = 1;
				//LDの時
				5'b01000 : select_register_cload = 1;
				default: select_register_cload = 0;
			endcase
		end else 
			select_register_cload = 0;
	end
endfunction

// assign register_asel = select_register_asel(execa, operand);
// function [2:0] select_register_asel;
// 	input _execa;
// 	input [7:0] _opecode;
// 	begin
// 		if(_execa == 1) select_register_asel = _opecode[7:4];
// 		else select_register_asel = 3'b0;
// 	end
// endfunction

// assign register_csel = select_register_csel(opcode[2:0]);
// function [2:0] select_register_csel;
// 	input [2:0] _opecode_slice;
// 	begin
// 		//LDI| 0 1 0 1 0 c2 c1 c0 | m7 m6 m5 m4 m3 m2 m1 m0 | m → r[c]
// 		if (_opecode_slice == 3'010) select_register_csel = operand[2:0];
// 		else select_register_csel = 3'b0;
// 	end
// endfunction






// ram
/* こ こ で ， r a m に 接 続 さ れ る 信 号 線 を 宣 言 */
//また，状態が execa もしくは execb のとき，opcode に応じて読み込みか書き込みか決まる（例えば，LD か
//ST か）ので，必要に応じて rden と wren のどちらを High にして，どちらを Low にするかを決める．つまり，rden
//と wren の信号の接続には，fetcha，fetchb，execa，execb，opcode が必要である．
ram ra(
	ram_addr ,//select_addrによってpc_outかopecodeの下部か選ばれる
	clk,//in, ok
	ram_data_in ,//writeの時にmem[addr]に格納する値
	rden,//rden(読み出し許可)(0 or 1)(selectされる)
	wden , //wden(0 or 1)(selectされる)
	ram_data_out //アドレスに格納された値が data out[7:0] から出力されることとなる（オペコードになる）
);

// assign opcode = data_out;//ff使ってfetchaのときのdataoutをopcodeに代入する？？
// assign operand = data_out;//ff使ってfetchbのときのdataoutをoperandに代入する？？
//opecode, operandを取り出し，保存
generate
	genvar i;
	for (i =0; i <8; i=i +1) begin : gen
	// opecode
	//opecodeとは，fetcha が High のとき，pc_out の値を読み込むための信号線である．
	dffe opecode_dffe(
	.d(data_out[i]) ,
	. clk ( !clk ),
	. clrn (! rst ),
	. prn (1'b1) ,
	. ena (fetcha),
	.q( opecode[i]));

	//operand
	//operandとは，fetchb が High のとき，pc_out の値を読み込むための信号線である．
	dffe operand_dffe(
	.d(data_out[i]) ,
	. clk ( !clk ),
	. clrn (! rst ),
	. prn (1'b1) ,
	. ena (fetchb),
	.q( operand[i]));
	end
endgenerate

//rden, wdenがhighかlowかを決める
assign { rden, wren } = assign_ram(fetcha, fetchb, execa, execb, opecode[7:3]);
function [1:0] assign_ram ;	//rden, wdenを決める
		input _fetcha ;
		input _fetchb ;
		input _execa;
		input _execb;
		input [4:0] _opecode_slice; //(opecode_q)
		begin
			if (_fetcha == 1'b1 || _fetchb == 1'b1) begin
                // 状態が fetcha もしくは fetchb のとき，ram からデータを読み込むので rden が High，wren が Low となればよい．
                assign_ram = {1'b1, 1'b0};
			end else if (_execa == 1 || _execb == 1) begin //opcode に応じてramに対しての読み込みか書き込みか決まる．
				case(_opecode_slice)
					//LDの時
					5'b01000: assign_ram = {1'b1, 1'b0}; //rdenをhighにする(ramから読み込む)
					default: assign_ram = {1'b1, 1'b0}; //rdenをhighにする(ramから読み込む)
				endcase
				//ST, STSの時にwrenをhighにする
				// if (_opecode_slice == 5'b01100 || _opecode_slice == 5'b01101) begin
				// 	assign_ram = {1'b0, 1'b1}; //wrenをhighにする(ramに書き込む)
				// end else begin
				// 	assign_ram = {1'b1, 1'b0}; //rdenをhighにする(ramから読み込む)
				// end
			end
		end
endfunction

assign ram_addr = select_ram_addr ( fetcha , fetchb , pc_out , execa, opecode);
function [7:0] select_ram_addr ;
	input _fetcha ;
	input _fetchb ;
	input [7:0] _pc_out ;
	input _execa;
	input [7:0] _opecode;
	begin
		if (_fetcha == 1'b1 || _fetchb == 1'b1) select_ram_addr = _pc_out;
		else if (_execa == 1) begin
			case(_opecode)
				//LDの時ram[r[a]]になる(r[a]はregisterの方からもらう)
				5'b01000: select_ram_addr = register_aout;
				default: select_ram_addr = _pc_out;
			endcase
		end
	end
endfunction


// alu
/* こ こ で ， a l u に 接 続 さ れ る 信 号 線 を 宣 言 */
//module alu (
//	input clk , rst , ena ,
//	input [1:0] ctrl ,
//	input [7:0] ain , bin ,
//	output cflag , zflag ,
//	output [7:0] sout
//);
//alu a (
//	clk,
//	rst,
//	ena,
//	ctrl,
//	ain,
//	bin
//	cflag,
//	zflag,
//	sout
//);

endmodule
