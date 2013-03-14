package fnet;

import flash.Lib;
import flash.events.EventDispatcher;
import flash.events.NetStatusEvent;
import flash.net.NetConnection;
import flash.net.NetStream;
import fnet.events.GameEvent;
import fnet.events.GroupEvent;

/**
	Full p2p mesh network for low latency realtime games.
*/
@:require(flash10_1)
class RealtimeApp extends PeerList {
	
	static inline var STREAMNAME = 'media';
	
	public var serverAddr(default,null) : String;
	public var streamMethod(default,null) : String;
	public var ns(default,null) : NetStream;
	
	var streams : Map<String,NetStream>;
	
	public function new( serverAddr : String, groupname : String,
					  	 ?streamMethod : String,
					  	 keepAliveTime : UInt = 120000,
				  		 expireTimeout : UInt = 300000, expireCheckTime : UInt = 10000 ) {
		super( groupname, keepAliveTime, expireTimeout, expireCheckTime );
		this.serverAddr = serverAddr;
		this.streamMethod = (streamMethod!=null) ? streamMethod : NetStream.DIRECT_CONNECTIONS;
	}
	
	public function connect( username : String, ?details : Dynamic ) {
		me.name = username;
		me.details = details;
		nc = new NetConnection();
		nc.addEventListener( NetStatusEvent.NET_STATUS, netStatus, false, 0, true );
		nc.connect( serverAddr );
	}
	
	public function disconnect() {
		if( !connected )
			return;
		nc.close();
		nc.removeEventListener( NetStatusEvent.NET_STATUS, netStatus );
		nc = null;
		cleanup();
	}
	
	public function sendData( data : Dynamic, f : String = 'recieveData' ) {
		ns.send( f, me.id, data );
	}
	
	override function netStatus( e : NetStatusEvent ) {
		switch( e.info.code ) {
		case "NetConnection.Connect.Closed",
			 "NetConnection.Connect.Failed",
			 "NetConnection.Connect.Rejected",
			 "NetConnection.Connect.AppShutdown",
			 "NetConnection.Connect.InvalidApp",
			 "NetGroup.Connect.Failed" :
			cleanup();
			dispatchEvent( new GroupEvent( GroupEvent.DISCONNECT ) );
			return;
		case "NetConnection.Connect.Success" :
			me.id = nc.nearID;
			me.stamp = Lib.getTimer();
			streams = new Map();
			ns = new NetStream( nc, streamMethod );
			ns.addEventListener( NetStatusEvent.NET_STATUS, netStatus, false, 0, true );
			ns.publish( STREAMNAME );
			ns.client = {
				onPeerConnect : function(ns:NetStream) : Bool {
					#if DEBUG_FNET
					trace( "Peer stream connected ["+ns.farID+"]" );
					#end
					return true;
				}
			};
			setupGroup();
			return;
		case 'NetStream.Connect.Closed' :
			//TODO handle if ns gets  lost 
		}
		super.netStatus( e );
	}
	
	override function addPeer( p : Dynamic ) : Peer {
		var peer = super.addPeer( p );
		var ns = new NetStream( nc, peer.id );
		ns.addEventListener( NetStatusEvent.NET_STATUS, netStatus, false, 0, true );
		ns.client = this;
		streams.set( peer.id, ns );
		ns.play( STREAMNAME );
		return peer;
	}
	
	override function removePeer( p : Peer ) {
		var ns = streams.get( p.id );
		ns.close();
		streams.remove( p.id );
		ns = null;
		super.removePeer( p );
	}
	
	function recieveData( peer : String, data : Dynamic ) {
		data.peer = peer;
		dispatchEvent( new GameEvent( GameEvent.DATA, data ) );
	}
	
}
