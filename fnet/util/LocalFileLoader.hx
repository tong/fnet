package fnet.util;

import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.events.StatusEvent;
import flash.events.SecurityErrorEvent;
import flash.net.FileReference;
import flash.utils.ByteArray;

class LocalFileLoader extends EventDispatcher {
	
	public var data(getData,null) : ByteArray;
	
	var fr : FileReference;
	
	public function new() {
		super();
	}
	
	function getData() : ByteArray {
		if( fr == null ) return null;
		return fr.data;
	}
	
	public function browse() {
		fr = new FileReference();
		fr.addEventListener( Event.SELECT, selectHandler );
		fr.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
		fr.addEventListener( ProgressEvent.PROGRESS, progressHandler );
		fr.addEventListener( SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler );
		fr.addEventListener( Event.COMPLETE, completeHandler );
		fr.browse();
	}
	
	function selectHandler( e : Event ) {
		fr.load();
	}
	
	function ioErrorHandler( e : IOErrorEvent ) {
		fireStatusEvent( e.type );
	}
	
	function securityErrorHandler( e : SecurityErrorEvent ) {
		fireStatusEvent( e.type );
	}
	
	function progressHandler( e : ProgressEvent ) {
		fireStatusEvent( e.type );
	}
	
	function completeHandler( e : Event ) {
		dispatchEvent( new Event( Event.COMPLETE ) );
	}
	
	function fireStatusEvent( t : String ) {
		dispatchEvent( new StatusEvent( StatusEvent.STATUS, false, false, 'status', t ) );
	}
	
}
