//////////////////////////////////////////////////////////////////////////////////
// 
// Module Name:	NIC_utils 
// Project Name:	NIC_base
// Description:	Definition of constant function etc.
//
//////////////////////////////////////////////////////////////////////////////////

//computation of the $clog2 function, not always present in compiler(not usable constant function in icarus verilog)
function integer clog2;
input integer in;
begin
	in = in - 1;
	for (clog2 = 0; in > 0; clog2=clog2+1)
		in = in >> 1;
	end//for
endfunction

// Find First 1 - Start from MSB and count downwards, returns 0 when no bit set
function integer ff1;
input integer in;
input integer width;
integer i;
begin
	ff1 = 0;
	for (i = width-1; i >= 0; i=i-1) begin
		if (in[i])
			ff1 = i;
	end
end
endfunction

// Find Last 1 -  Start from LSB and count upwards, returns 0 when no bit set
function integer fl1;
input integer in;
input integer width;
integer i;
begin
	fl1 = 0;
	for (i = 0; i < width; i=i+1) begin
		if (in[i])
			fl1 = i;
	end
end
endfunction
