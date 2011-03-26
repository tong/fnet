package fnet;

import flash.events.NetStatusEvent;
import flash.net.NetConnection;
import flash.net.NetGroup;

typedef ChatMessage = {
	var message : String;
	var user : String;
	//var type : String;
	//var sequence : Int;
}

class Chat extends NetGroup {
	
	public dynamic function onMessage( m : ChatMessage ) : Void;
	
	//public var group : NetGroup;
	
	var username : String;
	var sequence : Int;
	
	public function new( username : String, group : String, nc : NetConnection ) {
		super( nc, group );
		this.username = username;
		sequence = 0;
		addEventListener( NetStatusEvent.NET_STATUS, onNetStatus, false, 0, true );
	}
	
	public function sendMessage( t : String ) {
		var m : Dynamic = { message : t, user : username };
		m.seq = sequence++;
		m.type = 'chat';
		post( m );
		recieveMesssage( m );
	}
	
	function recieveMesssage( m : ChatMessage ) {
		onMessage( m );
	}
	
	function onNetStatus( e : NetStatusEvent ) {
		#if DEBUG_FNET
		//trace( e.info.code );
		#end
		switch( e.info.code ) {
		case 'NetGroup.Posting.Notify' :
			switch( e.info.message.type ) {
			case 'chat' : recieveMesssage( e.info.message );
			}
		}
	}
	
}
