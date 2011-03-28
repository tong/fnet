package fnet;

import flash.events.NetStatusEvent;
import flash.net.NetConnection;
import flash.net.NetGroup;

typedef ChatMessage = {
	var user : String;
	var message : String;
	//var type : String;
	//var sequence : Int;
}

class Chat extends NetGroup {
	
	public dynamic function onMessage( m : ChatMessage ) : Void;
	//public dynamic function onPrivateChatOpen() : Void;
	
	public var username(default,null) : String;
	//public var group(default,null) : NetGroup;
	
	var sequence : Int;
	
	public function new( username : String, group : String, nc : NetConnection ) {
		super( nc, group );
		this.username = username;
		sequence = 0;
		addEventListener( NetStatusEvent.NET_STATUS, onNetStatus, false, 0, true );
	}
	
	public function sendMessage( t : String ) {
		var m : Dynamic = {
			user : username,
			message : t
		};
		m.seq = sequence++;
		m.type = 'chat';
		post( m );
		recieveMesssage( m );
	}
	
	/*
	public function openPrivateChat( users : Array<{name:String,id:String}> ) {
		//var name = "GROUPCHAT_"+Math.round( Math.random()*100000 );
		var arr = new Array<String>();
		for( u in users ) arr.push( u.name );
		arr.sort(function(a:String,b:String){
			return if( a == b ) 0 else if( a > b ) 1 else -1; 
		});
		var name = arr.join("/");
		//...WTF
		
		var m : Dynamic = {
	//		username : u.name,
			type : 'openPrivateChat',
			sender : username,
	//		sequence : sequence++,
			users : users,
			groupname : name
		};
		for( u in users ) {
			m.sequence = sequence++;
			sendToNearest( m, convertPeerIDToGroupAddress( u.id ) );
		}
	}
	*/
	
	function recieveMesssage( m : ChatMessage ) {
		onMessage( m );
	}
	
	/*
	function openPrivateChatReceive( m : Dynamic ) {
		trace("openPrivateChatReceive");
		//onPrivateChatOpen();
	}
	*/
	
	function onNetStatus( e : NetStatusEvent ) {
		#if DEBUG_FNET
		//trace( e.info.code );
		#end
		switch( e.info.code ) {
		case 'NetGroup.Posting.Notify' :
			switch( e.info.message.type ) {
			case 'chat' : recieveMesssage( e.info.message );
			}
		/*
		case 'NetGroup.SendTo.Notify' :
			switch( e.info.message.type ) {
			case 'openPrivateChat' : openPrivateChatReceive( e.info.message );
			}
		*/
		}
	}
	
}
