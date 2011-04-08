package fnet;

import flash.Lib;
import flash.events.EventDispatcher;
import flash.events.NetStatusEvent;
import flash.net.GroupSpecifier;
import flash.net.NetConnection;
import flash.net.NetGroup;
import haxe.Timer;
import fnet.events.PeerEvent;
import fnet.events.GroupEvent;

private class ListRouting {
	
	public static inline var REQUEST = 'request';
	public static inline var RESPONSE = 'response';
	
	public var type(default,null) : String;
	public var destination : String;
	public var sender : String;
	public var peers : Dynamic;
	public var time : Float;
	public var data : Dynamic;
	
	public function new( ?type : String ) {
		this.type = if( type == null ) REQUEST else type;
	}
}

/**
	Abstract base for groups.
*/
class PeerList extends EventDispatcher {
	
	/**
		A peer request callback for the current game state
	*/
	public dynamic function onDataRequest() : Dynamic;
	
	public var me(default,null) : Peer;
	public var peers(default,null) : Hash<Peer>;
	public var numPeers(getNumPeers,null) : UInt;
	public var groupname(default,null) : String;
	public var connected(default,null) : Bool;
	public var listRecieved(default,null) : Bool;
	public var ng(default,null) : NetGroup;
	
	var nc : NetConnection;
	var neighboured : Bool;
	var postSequence : UInt;
//	var listTimestamp : Float;
	var keepAliveTime : UInt;
	var keepAliveTimer : Timer;	
	var expireCheckTime : UInt;
	var expireTimeout : UInt;
	var expireTimer : Timer;
	
	function new( groupname  : String,
				  keepAliveTime : UInt = 120000,
				  expireTimeout : UInt = 300000, expireCheckTime : UInt = 10000 ) {
		super();
		this.groupname = groupname;
		this.keepAliveTime = keepAliveTime;
		this.expireTimeout = expireTimeout;
		this.expireCheckTime = expireCheckTime;
		cleanup();
	}
	
	inline function getNumPeers() : UInt {
		return Lambda.count( peers );
	}
	
	function netStatus( e : NetStatusEvent ) {
		#if DEBUG_FNET
		trace( e.info.code, "debug" );
		#end
		switch( e.info.code ) {
		case 'NetGroup.Connect.Success' :
			if( !connected ) {
				connected = true;
				me.address = ng.convertPeerIDToGroupAddress( nc.nearID );
				dispatchEvent( new GroupEvent( GroupEvent.CONNECT ) );
			}
		case 'NetGroup.Neighbor.Connect' :
			if( !neighboured ) {
				neighboured = true;
				announceSelf();
				keepAliveTimer = new Timer( keepAliveTime );
				keepAliveTimer.run = announceSelf;
				expireTimer = new Timer( expireCheckTime );
				expireTimer.run = expirePeers;
				requestUsers( e.info.neighbor );
			}
		case 'NetGroup.Neighbor.Disconnect' :
			var p = peers.get( e.info.peerID );
			if( p != null ) removePeer( p );
		case 'NetGroup.Posting.Notify' :
			var m = e.info.message;
			if( m.id != null &&  m.name != null ) {
				updatePeer( m );
			}
		case 'NetGroup.SendTo.Notify' :
			var i = e.info;
			if( i.message.destination == me.address ) {
				#if DEBUG_FNET
				trace( "ListRoutingObject:"+Std.string(i.message.type).toUpperCase() );
				#end
				switch( i.message.type ) {
				case ListRouting.REQUEST :
					var r = new ListRouting( ListRouting.RESPONSE );
					r.destination = i.message.sender;
					r.time = Std.int( Lib.getTimer() );
					//r.peers = createPeerList();
					r.peers = {};
					Reflect.setField( r.peers, me.id, me );
					for( p in peers ) {
						Reflect.setField( r.peers, p.id, p );
						//attachPeerListObject( r.peers, p );
					}
					//attachPeerListObject( r.peers, me );
					//TODO (custom) data callback here
				//	if( listTimestamp != null
					//trace( Std.parseFloat(i.message.time) +" ::::: "+ (Lib.getTimer()) );
					if( Std.parseFloat(i.message.time) < Lib.getTimer() )
						//r.data = onDataRequest( i.message.id );
						r.data = onDataRequest();
	//				}
					ng.sendToNearest( r, r.destination );
				case ListRouting.RESPONSE :
					var peerlist : Dynamic = i.message.peers;
					var neighborsTime = Std.parseInt( i.message.time );
					var neighborsAge = 0.0;
					for( id in Reflect.fields( peerlist ) ) {
						var p : Dynamic =  Reflect.field( peerlist, id );
						neighborsAge = neighborsTime - p.stamp + 1000;
						if( peers.exists( id ) ) {
							var peer = peers.get(id);
							var localAge = Lib.getTimer() - peer.stamp;
							trace("localAgelocalAge "+neighborsAge +" : "+ localAge);
							if( neighborsAge < localAge ) {
								peer.stamp = Lib.getTimer() - neighborsAge;
							}
						} else {
							p.id = id;
							var npeer = addPeer( p );
							npeer.stamp = Lib.getTimer()-neighborsAge; //?
						}
					}
					if( !listRecieved ) {
//						listTimestamp = Lib.getTimer();
						var m : Dynamic = i.message;
						dispatchEvent( new PeerEvent( PeerEvent.LIST, m.sender, m.data ) );
					}
				}
			} else if( !i.fromLocal ) {
				trace( "sendToNearest ","info");
				ng.sendToNearest( i.message, i.message.destination );
			}
		}
	}
	
	function announceSelf() {
		var id = ng.post( {
			seq : postSequence++,
			id : me.id,
			name : me.name
		});
		me.stamp = Lib.getTimer();
	}
	
	function requestUsers( peer : String ) {
		var r = new ListRouting();
		r.destination = peer;
		r.time = Std.int( Lib.getTimer() );
		r.sender = me.address;
		ng.sendToNearest( r, r.destination );
	}
	
	function updatePeer( p : Dynamic ) {
		if( !peers.exists( p.id ) ) {
			addPeer( p );
		} else {
			peers.get( p.id ).stamp = Lib.getTimer();
		}
	}
	
	function addPeer( p : Dynamic ) : Peer {
		var peer = createPeer();
		peer.id = p.id;
		peer.name = p.name;
		peer.stamp = Lib.getTimer();
		peers.set( peer.id, peer );
		dispatchEvent( new PeerEvent( PeerEvent.CONNECT, peer ) );
		return peer;
	}
	
	function removePeer( p : Peer ) {
		peers.remove( p.id );
		if( numPeers == 0 ) {
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
		dispatchEvent( new PeerEvent( PeerEvent.DISCONNECT, p ) );
	}
	
	function createPeer() : Peer {
		return new Peer();
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
				trace( "Peer expired ["+age+":"+expireTimeout+"]", "warn" );
				#end
				removePeer( p );
			} /* else if( age > idleTimeout ) {
				//TODO
				//onPeerIdle();//onPeerStatus();
			}
			*/
		}
	}
	
	function setupGroup() {
		var g = new GroupSpecifier( groupname );
		g.postingEnabled = g.routingEnabled = g.serverChannelEnabled = true;
		ng = new NetGroup( nc, g.groupspecWithAuthorizations() );
		ng.addEventListener( NetStatusEvent.NET_STATUS, netStatus, false, 0, true );
	}
	
	function cleanup() {
		connected = neighboured = listRecieved = false;
		postSequence = 0;
		peers = new Hash();
		me = new Peer();
	}
	
}
