package fnet.events;

import flash.events.Event;

class GroupEvent extends Event {
	
	public static inline var CONNECT = 'fnet_group_connect';
	public static inline var DISCONNECT = 'fnet_group_disconnect';
	
	public var data : Dynamic;
	
	public function new( type : String, ?data : Dynamic, bubbles : Bool = false, cancelable : Bool = false ) {
		super( type, bubbles, cancelable );
		this.data = data;
	}
	
}
