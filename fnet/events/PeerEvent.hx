package fnet.events;

import flash.events.Event;

//TODO class PeerEvent extends GroupEvent {
class PeerEvent extends Event {
	
	public static inline var CONNECT = 'fnet_peer_connnect';
	public static inline var DISCONNECT = 'fnet_peer_disconnnect';
	public static inline var LIST = 'fnet_peer_list';
	
	public var peer : Peer;
	public var data : Dynamic;
	
	public function new( type : String, ?peer : Peer, ?data : Dynamic,
						 bubbles : Bool = false, cancelable : Bool = false ) {
		super( type, bubbles, cancelable );
		this.peer = peer;
		this.data = data;
	}
	
}
