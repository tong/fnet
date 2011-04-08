package fnet;

import flash.events.EventDispatcher;
import flash.events.NetStatusEvent;
import flash.net.GroupSpecifier;
import flash.net.NetConnection;
import flash.net.NetGroup;
import flash.net.NetGroupReplicationStrategy;
import flash.utils.ByteArray;
import fnet.events.FileShareEvent;
import fnet.fileshare.SharedObject;

class FileShare extends EventDispatcher {
	
	public var groupname(default,null) : String;
	public var connected(default,null) : Bool;
	public var ng(default,null) : NetGroup;
	public var info : Dynamic;
	
	var nc : NetConnection;
	var so : SharedObject;
	
	public function new( nc : NetConnection ) {
		super();
		this.nc = nc;
		nc.addEventListener( NetStatusEvent.NET_STATUS, netStatus, false, 0, true );
		connected = false;
	}
	
	public function connect( groupname : String ) {
		this.groupname = groupname;
		setupGroup();
	}
	
	public function disconnect() {
		ng.close();
		//ng.removeEventListener( NetStatusEvent.NET_STATUS, netStatus );
	}
	
	public function share( data : ByteArray ) {
		trace("share "+groupname );
		so = SharedObject.ofData( data );
		ng.addHaveObjects( 0, so.length );
	}
	
	public function recieve() {
		trace("recieve "+groupname );
		so = new SharedObject();
		receiveObject( 0 );
	}
	
	public function getData() : ByteArray {
		return ( so == null ) ? null : so.getData();
	}
	
	function netStatus( e : NetStatusEvent ) {
		#if DEBUG_FNET
		trace( e.info.code );
		#end
		switch( e.info.code ) {
		case "NetGroup.Connect.Rejected",
			 "NetGroup.Connect.Failed" :
			connected = false;
			dispatchEvent( new FileShareEvent( FileShareEvent.DISCONNECT ) );
		case "NetGroup.Connect.Success" :
			ng.replicationStrategy = NetGroupReplicationStrategy.LOWEST_FIRST;
			connected = true;
			dispatchEvent( new FileShareEvent( FileShareEvent.CONNECT ) );
		case "NetGroup.Replication.Fetch.Result" :
			ng.addHaveObjects( e.info.index, e.info.index );
			so.chunks[e.info.index] = e.info.object;
			if( e.info.index == 0 ) {
				so.length = e.info.object;
				receiveObject( 1 );
			} else {
				if( e.info.index+1 < so.length ) {
					receiveObject( e.info.index+1 );
				} else {
					dispatchEvent( new FileShareEvent( FileShareEvent.RECIEVED, { data : so.getData() } ) );
					//ng.close();
				}
			}
		case "NetGroup.Replication.Request" :
			ng.writeRequestedObject( e.info.requestID, so.chunks[e.info.index] );
			if( e.info.index == so.chunks.length-1 ) {
				dispatchEvent( new FileShareEvent( FileShareEvent.SENT ) );
				//ng.close();
			}
		}
	}
	
	function setupGroup() {
		var g = new GroupSpecifier( groupname );
		g.serverChannelEnabled = g.objectReplicationEnabled = true;
		ng = new NetGroup( nc, g.groupspecWithAuthorizations() );
		ng.addEventListener( NetStatusEvent.NET_STATUS, netStatus );
	}
	
	function receiveObject( index : Int ) {
		ng.addWantObjects( index, index );
		so.fetchIndex = index;
	}
	
}
