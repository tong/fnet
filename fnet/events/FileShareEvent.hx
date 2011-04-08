package fnet.events;

import flash.events.Event;

class FileShareEvent extends Event {
	
	public static inline var CONNECT = 'fnet_fileshare_connect';
	public static inline var DISCONNECT = 'fnet_fileshare_connect';
	public static inline var PROGRESS = 'fnet_fileshare_progress';
	public static inline var SENT = 'fnet_fileshare_sent';
	public static inline var RECIEVED = 'fnet_fileshare_recieved';
	public static inline var OFFER = 'fnet_fileshare_offer';
	
	public var info(default,null) : Dynamic;
	
	public function new( type : String, ?info : Dynamic, bubbles : Bool = false, cancelable : Bool = false ) {
		super( type, bubbles, cancelable );
		this.info = info;
	}
	
}
