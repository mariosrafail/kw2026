extends RefCounted
const STRIDE:=36
static func encode(frames: Array) -> PackedByteArray:
	var out =PackedByteArray();out.resize(frames.size()*STRIDE)
	for i in range(frames.size()):
		var f: Dictionary=frames[i];var offset =i*STRIDE
		out.encode_u32(offset,int(f.seq));out.encode_u32(offset+4,int(f.ct));out.encode_u32(offset+8,int(f.js));out.encode_u32(offset+12,int(f.gs))
		out.encode_float(offset+16,f.move.x);out.encode_float(offset+20,f.move.y);out.encode_float(offset+24,f.yaw);out.encode_float(offset+28,f.pitch)
		out[offset+32]=(1 if f.fire else 0)|(2 if f.aim else 0)|(4 if f.sprint else 0)|(8 if f.side>0 else 0)|(16 if f.reload else 0)
		out[offset+33]=clampi(int(f.weapon),0,2)
	return out
static func decode(bytes: PackedByteArray) -> Array:
	if bytes.is_empty() or bytes.size()>STRIDE*4 or bytes.size()%STRIDE!=0:return []
	var result: Array=[]
	for i in range(bytes.size()/STRIDE):
		var p =i*STRIDE
		var flags =int(bytes[p+32])
		if flags>31 or bytes[p+33]>2 or bytes[p+34]!=0 or bytes[p+35]!=0:return []
		result.append({"seq":bytes.decode_u32(p),"ct":bytes.decode_u32(p+4),"js":bytes.decode_u32(p+8),"gs":bytes.decode_u32(p+12),"move":Vector2(bytes.decode_float(p+16),bytes.decode_float(p+20)),"yaw":bytes.decode_float(p+24),"pitch":bytes.decode_float(p+28),"fire":bool(flags&1),"aim":bool(flags&2),"sprint":bool(flags&4),"side":1.0 if flags&8 else -1.0,"reload":bool(flags&16),"weapon":int(bytes[p+33])})
	return result
