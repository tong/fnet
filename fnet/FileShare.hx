package fnet;

import flash.events.NetStatusEvent;
import flash.net.GroupSpecifier;
import flash.net.NetConnection;
import flash.net.NetGroup;
import flash.net.NetGroupReplicationStrategy;
import flash.utils.ByteArray;

private class SharedObject {

	public var size(default,null) : Float;
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
		//so.data.readBytes( so.chunks[i], 0, so.data.bytesAvailable );
		bytes.readBytes( so.chunks[i], 0, bytes.bytesAvailable );
		so.length++;
		//trace("----- p2pSharedObject ----- "+so );
		//trace("packetLenght: "+(so.length));
		return so;
	}
}

/**
*/
class FileShare {
	
	public dynamic function onConnect() : Void;
	public dynamic function onDisconnect() : Void;
	public dynamic function onSent() : Void;
	public dynamic function onRecieved() : Void;
	
	public var connected(default,null) : Bool;
	public var serverAddr(default,null) : String;
	public var groupName(default,null) : String;
	public var data(getData,null) : ByteArray;
	
	var nc : NetConnection;
	var ng : NetGroup;
	var so : SharedObject;
	
	public function new( serverAddr : String, groupName : String ) {
		this.serverAddr = serverAddr;
		this.groupName = groupName;
		connected = false;
	}
	
	function getData() : ByteArray {
		if( so == null ) return null;
		return so.getData();
	}
	
	/**
	*/
	public function connect() {
		nc = new NetConnection();
		nc.addEventListener( NetStatusEvent.NET_STATUS, netStatus, false, 0, true );
		nc.connect( serverAddr );
	}
	
	/**
	*/
	public function disconnect() {
		if( !connected )
			return;
		nc.close();
		nc.removeEventListener( NetStatusEvent.NET_STATUS, netStatus );
		nc = null;
	}
	
	/**
		Start sharing data.
	*/
	public function share( ?data : ByteArray ) {
		if( data == null ) {
			if( so == null || so.length == 0 )
				throw "no data to share";
		} else {
			so = SharedObject.ofData( data );
		}
		ng.addHaveObjects( 0, so.length );
	}
	
	/**
	*/
	public function recieve() {
		so = new SharedObject();
		receiveObject( 0 );
	}
	
	function netStatus( e : NetStatusEvent ) {
		#if DEBUG_FNET
		trace( e.info.code );
		#end
		switch( e.info.code ) {
		case "NetConnection.Connect.Closed",
			 "NetConnection.Connect.Failed",
			 "NetConnection.Connect.Rejected",
			 "NetConnection.Connect.AppShutdown",
			 "NetConnection.Connect.InvalidApp",
			 "NetGroup.Connect.Failed" :
			connected = false;
			onDisconnect();
		case "NetConnection.Connect.Success" :
			setupGroup();
		case "NetGroup.Connect.Success" :
			onGroupConnected();
		case "NetGroup.Replication.Fetch.Result" :
			ng.addHaveObjects( e.info.index, e.info.index );
			so.chunks[e.info.index] = e.info.object;
			if( e.info.index == 0 ) {
				so.length = e.info.object;
				trace( "shared object packet lenght: "+so.length );
				receiveObject( 1 );
			} else {
				if( e.info.index+1 < so.length ) {
					receiveObject( e.info.index+1 );
				} else {
					/*
					trace( "recieving DONE" );
					trace("shared object packet length: "+so.length);
					trace( "shared object bytes available: "+so.data.bytesAvailable );
					trace( "shared object data length: "+so.data.length );
					*/
					onRecieved();
				}
			}
		case "NetGroup.Replication.Request" :
			ng.writeRequestedObject( e.info.requestID, so.chunks[e.info.index] );
			if( e.info.index == so.chunks.length-1 ) {
				onSent();
			}
		}
	}
	
	function setupGroup() {
		var g = new GroupSpecifier( groupName );
		g.serverChannelEnabled = g.objectReplicationEnabled = true;
		ng = new NetGroup( nc, g.groupspecWithAuthorizations() );
		ng.addEventListener( NetStatusEvent.NET_STATUS, netStatus );
	}
	
	function onGroupConnected() {
		ng.replicationStrategy = NetGroupReplicationStrategy.LOWEST_FIRST;
		connected = true;
		onConnect();
	}
	
	function receiveObject( index : Int ) {
		ng.addWantObjects( index, index );
		so.fetchIndex = index;
	}
	
}
