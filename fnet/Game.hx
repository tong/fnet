package fnet;

import flash.Lib;
import flash.events.NetStatusEvent;
import flash.net.GroupSpecifier;
import flash.net.NetConnection;
import flash.net.NetGroup;
import flash.net.NetGroupReceiveMode;
import flash.net.NetGroupSendMode;
import flash.net.NetGroupSendResult;
import flash.net.NetStream;
import haxe.Timer;

private class ListRouting {

	public static inline var REQUEST = 'request';
	public static inline var RESPONSE = 'response';
	
	public var type(default,null) : String;
	public var destination : String;
	public var sender : String;
	public var peers : Dynamic;
	public var time : Float;
	public var info : Dynamic;
	
	public function new( ?type : String ) {
		this.type = if( type == null ) REQUEST else type;
	}
}

/**
	Full, p2p mesh game network.
*/
class Game {
	
	static inline var STREAMNAME = "media";
	
	public dynamic function onConnect() : Void;
	public dynamic function onDisconnect( info : String ) : Void;
	public dynamic function onPeerConnect( peer : GamePeer ) : Void;
	public dynamic function onPeerDisconnect( peer : GamePeer ) : Void;
	public dynamic function onInfo( data : Dynamic ) : Void;
	public dynamic function onData( peer : GamePeer, data : Dynamic ) : Void;
	//public dynamic function onDataRequest( peer : GamePeer ) : Dynamic;
	public dynamic function onDataRequest() : Dynamic;
	
	public var connected(default,null) : Bool;
	public var serverAddress(default,null) : String;
	public var groupName(default,null) : String;
	public var streamMethod(default,null) : String;
	public var me(default,null) : GamePeer;
	public var peers(default,null) : Hash<GamePeer>;
	public var chat(default,null) : Chat;
	
	var nc : NetConnection;
	var ns : NetStream;
	var neighboured : Bool;
	var postSequence : UInt;
	var recieveStreams : Hash<NetStream>;
	var keepAliveTime : UInt;
	var keepAliveTimer : Timer;	
	var expireCheckTime : UInt;
	var expireTimeout : UInt;
	var expireTimer : Timer;
	
	public function new( serverAddr : String, groupName : String,
						 keepAliveTime : UInt = 120000, expireTimeout : UInt = 300000, expireCheckTime : UInt = 10000,
						 //keepAliveTime : UInt = 3000, expireTimeout : UInt = 10000, expireCheckTime : UInt = 3000,
						 ?streamMethod : String ) {
		
		this.serverAddress = serverAddr;
		this.groupName = groupName;
		this.keepAliveTime = keepAliveTime;
		this.expireTimeout = expireTimeout;
		this.expireCheckTime = expireCheckTime;
		this.streamMethod = ( streamMethod != null ) ? streamMethod : NetStream.DIRECT_CONNECTIONS;
		
		cleanup();
	}
	
	public function connect( userName : String, ?userDetails : Dynamic ) {
		me = createPeer();
		me.name = userName;
		me.details = userDetails;
		nc = new NetConnection();
		nc.addEventListener( NetStatusEvent.NET_STATUS, netStatus, false, 0, true );
		nc.connect( serverAddress );
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
	
	function netStatus( e : NetStatusEvent ) {
		#if DEBUG_FNET
		trace( e.info.code );
		#end
		switch( e.info.code ) {
		case "NetConnection.Connect.Success" :
			me.id = nc.nearID;
			me.stamp = Lib.getTimer();
			recieveStreams = new Hash();
			ns = new NetStream( nc, streamMethod );
			ns.addEventListener( NetStatusEvent.NET_STATUS, netStatus, false, 0, true );
			ns.publish( STREAMNAME );
			ns.client = {
				onPeerConnect : function(ns:NetStream) : Bool {
					#if DEBUG_FNET
					trace( "Peer connected ["+ns.farID+"]" );
					#end
					return true;
				}
			};
			var group = new GroupSpecifier( groupName );
			group.postingEnabled = true;
			group.routingEnabled = true;
			group.serverChannelEnabled = true;
			chat = new Chat( me.name, group.groupspecWithAuthorizations(), nc );
			chat.addEventListener( NetStatusEvent.NET_STATUS, netStatus, false, 0, true );
			
		case "NetConnection.Connect.Closed",
			 "NetConnection.Connect.Failed",
			 "NetConnection.Connect.Rejected",
			 "NetConnection.Connect.AppShutdown",
			 "NetConnection.Connect.InvalidApp",
			 "NetGroup.Connect.Failed" :
			cleanup();
			onDisconnect( e.toString() );
		
		case "NetStream.Connect.Rejected",
			 "NetStream.Connect.Failed" :
			//TODO
		
		case "NetGroup.Connect.Success" :
			me.address = chat.convertPeerIDToGroupAddress( nc.nearID );
			connected = true;
			onConnect();
		
		case "NetGroup.Neighbor.Connect" :
			if( !neighboured ) {
				neighboured = true;
				// immediately send a keep-alive to the group
				announceSelf();
				// start timers
				keepAliveTimer = new Timer( keepAliveTime );
				keepAliveTimer.run = announceSelf;
				expireTimer = new Timer( expireCheckTime );
				expireTimer.run = expirePeers;
				// request peerlist
				requestUsers( e.info.neighbor );
			}
			
		case "NetGroup.Neighbor.Disconnect" :
			var p = peers.get( e.info.peerID );
			if( p != null ) removePeer( p );
			
		case "NetGroup.Posting.Notify" :
			var m = e.info.message;
			if( m.id != null &&  m.name != null ) {
				updatePeer(m);
			}
			
		case "NetGroup.SendTo.Notify" :
			var i = e.info;
			if( i.message.destination == me.address ) {
				#if DEBUG_FNET
				trace( "ListRoutingObject:"+Std.string(i.message.type).toUpperCase() );
				#end
				switch( i.message.type ) {
				case ListRouting.REQUEST :
					//trace("REQUEST " );
					var r = new ListRouting( ListRouting.RESPONSE );
					r.destination = i.message.sender;
					r.time = Std.int( Lib.getTimer() );
					r.peers = createPeerRoutingObject();
					//TODO (custom) data callback here
					if( Std.parseFloat(i.message.time) < Lib.getTimer() ) {
						r.info = onDataRequest();
					}
					chat.sendToNearest( r, r.destination );
					
				case ListRouting.RESPONSE :
					//trace("RESPONSE " );
					var peerlist : Dynamic = i.message.peers;
					var neighborsTime = Std.parseInt( i.message.time );
					var neighborsAge = 0.0;
					for( id in Reflect.fields( peerlist ) ) {
						var p : Dynamic =  Reflect.field( peerlist, id );
						neighborsAge = neighborsTime - p.stamp + 1000;
						if( peers.exists( id ) ) {
							var peer = peers.get(id);
							var localAge = Lib.getTimer() - peer.stamp;
						//	trace("localAgelocalAge "+neighborsAge +" : "+ localAge);
							if( neighborsAge < localAge ) {
								peer.stamp = Lib.getTimer() - neighborsAge;
							}
						} else {
							p.id = id;
							var npeer = addPeer( p );
							npeer.stamp = Lib.getTimer()-neighborsAge; //?
						}
					}
					// TODO
					//trace(i.message.info != null);
					//trace(Std.parseFloat(i.message.time) > Lib.getTimer());
					if( i.message.info != null &&
						Std.parseFloat(i.message.time) > Lib.getTimer() ) {
						onInfo( i.message.info );
					}
				}
			} else if( !i.fromLocal ) {
				trace( "sendToNearest ","info");
				chat.sendToNearest( i.message, i.message.destination );
			}
		}
	}
	
	function createPeer() : GamePeer {
		return new GamePeer();
	}
	
	function requestUsers( peer : String ) {
		var r = new ListRouting();
		r.destination = peer;
		r.time = Std.int( Lib.getTimer() );
		r.sender = me.address;
		chat.sendToNearest( r, r.destination );
	}
	
	function announceSelf() {
		var id = chat.post( {
			seq : postSequence++,
			id : me.id,
			name : me.name
		});
		//trace("announcedSelf "+(id!=null) );
		me.stamp = Lib.getTimer();
	}
	
	function createPeerRoutingObject() : Dynamic {
		var o : Dynamic = {};
		for( p in peers ) attachPeerRoutingObject( o, p );
		attachPeerRoutingObject( o, me );
		return o;
	}
	
	function attachPeerRoutingObject( o : Dynamic, p : GamePeer ) {
		Reflect.setField( o, p.id, {
			name : p.name,
			stamp : p.stamp
		});
	}
	
	function updatePeer( p : Dynamic ) {
		if( !peers.exists( p.id ) )
			addPeer( p );
		else {
			peers.get( p.id ).stamp = Lib.getTimer();
		}
	}
	
	function addPeer( p : Dynamic ) : GamePeer {
		var peer = createPeer();
		peer.id = p.id;
		peer.name = p.name;
		peer.stamp = Lib.getTimer();
		peers.set( peer.id, peer );
		var ns = new NetStream( nc, peer.id );
		ns.addEventListener( NetStatusEvent.NET_STATUS, netStatus, false, 0, true );
		ns.client = this;
		ns.play( STREAMNAME );
		recieveStreams.set( peer.id, ns );
		onPeerConnect( peer );
		return peer;
	}
	
	function removePeer( p : GamePeer ) {
		peers.remove( p.id );
		var ns = recieveStreams.get( p.id );
		ns.close();
		recieveStreams.remove( p.id );
		ns = null;
		if( Lambda.count( peers ) == 0 ) {
			neighboured = false;
			if( keepAliveTimer != null ) {
				keepAliveTimer.stop();
				keepAliveTimer = null;
			}
			if( expireTimer != null ) {
				expireTimer.stop();
				expireTimer = null;
			}
		}
		onPeerDisconnect( p );
	}
	
	function expirePeers() {
		var stamp = Lib.getTimer();
		for( p in peers ) {
			if( p.id == me.id )
				continue;
			var age = stamp - p.stamp;
			//trace(age+":"+expireTimeout);
			if( age > expireTimeout ) {
				#if DEBUG_FNET
				trace( "User expired ["+age+"]", "warn" );
				#end
				removePeer( p );
			} /* else if( age > idleTimeout ) {
				//TODO
				//onPeerIdle();//onPeerStatus();
			}
			*/
		}
	}
	
	function cleanup() {
		connected = neighboured = false;
		postSequence = 0;
		peers = new Hash();
	}
	
	function recieveData( peerId : String, data : Dynamic ) {
		// update peer stamp here too?
		onData( peers.get( peerId ), data );
	}
	
}
