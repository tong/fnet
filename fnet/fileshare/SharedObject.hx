package fnet.fileshare;

import flash.utils.ByteArray;

class SharedObject {

	public var size(default,null) : Int;
	public var chunks(default,null) : Array<Dynamic>;
	public var length : Int;
	public var fetchIndex : Int;
	
	public function new() {
		size = length = fetchIndex = 0;
		chunks = new Array();
	}
	
	public function getData() : ByteArray {
		if( length <= 1 )
			return null;
		var ba = new ByteArray();	
		for( i in 1...length ) ba.writeBytes( chunks[i] );
		return ba;
	}
	
	public static function ofData( bytes : ByteArray ) : SharedObject {
		var so = new SharedObject();
		so.size = bytes.length;
		so.length = Math.floor( bytes.length/64000 )+1;
//		so.data = bytes.getData();
		so.chunks[0] = so.length+1;
		var i = 1;
		while( i < so.length ) {
			so.chunks[i] = new ByteArray();
			bytes.readBytes( so.chunks[i], 0, 64000 );
			i++;
		}
		so.chunks[so.length] = new ByteArray();
		bytes.readBytes( so.chunks[i], 0, bytes.bytesAvailable );
		so.length++;
		return so;
	}
}
