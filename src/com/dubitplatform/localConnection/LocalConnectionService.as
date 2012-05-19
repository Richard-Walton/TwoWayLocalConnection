package com.dubitplatform.localConnection
{
	import flash.events.StatusEvent;
	import flash.net.LocalConnection;
	import flash.utils.setTimeout;
	
	/**
	 * The LocalConnectionServce allows two connected clients to make asynchronous function calls upon each other.
	 * 
	 * To make a call to the remote client use the <i>remoteClient</i> object.  Any call made on the remote client 
	 * object send a message to the connected client and return an AsyncToken.  When the remote client sends its response
	 * the token will be notified.
	 * 
	 * @author richard.walton@dubitlimited.com
	 */
	public class LocalConnectionService extends LocalConnection
	{	
		public static const IDLE:String = "idle";
		public static const CONNECTING:String = "connecting";
		public static const WAITING_FOR_REMOTE_CLIENT:String = "waitingForRemoteClient";
		public static const CONNECTED:String = "connected";
		public static const TIMED_OUT:String = "timedOut";
		public static const CLOSING:String = "closing";
		
		private static const RETRY_CONNECTION_INTERVAL:int = 500;
		
		private var _connectionName:String;
		private var _outboundConnectionName:String;
		
		private var _status:String;
		
		private var _localClient:Object;
		
		public function LocalConnectionService(localClient:Object = null)
		{						
			this.client = localClient;
			super.client = new ClientProxy(this);
			
			addEventListener(StatusEvent.STATUS, function(e:StatusEvent) : void
			{
				if(e.code == null) e.stopImmediatePropagation();
			});
			
			_status = IDLE;
		}
		
		/**
		 * @inhericDoc
		 */   
		override public function connect(connectionName:String) : void
		{
			if(status != IDLE) close();

			updateStatus(CONNECTING);
			
			_connectionName = connectionName;
			
			attemptToConnect(connectionName + "_1", connectionName + "_2");
		}
		
		public function get connectionName() : String
		{
			return _connectionName;
		}
		
		public function get outboundConnectionName() : String
		{
			return _outboundConnectionName;
		}
		
		public function get connected() : Boolean
		{
			return status == CONNECTED || status == CLOSING;
		}
		
		/**
		 * @inhericDoc
		 */   
		override public function close() : void
		{
			updateStatus(CLOSING);
			
			try { super.close() }
			catch(e:ArgumentError) {}
						
			_connectionName = _outboundConnectionName = null;
			
			updateStatus(IDLE);
		}
		
		[Bindable]
		override public function get client() : Object
		{
			return _localClient;
		}
		
		override public function set client(value:Object) : void
		{
			_localClient = value;
		}
		
		public function get remoteClient() : Object
		{
			return super.client;
		}
		
		public function get status() : String
		{
			return _status;
		}
		
		internal function updateStatus(newStatus:String) : void
		{
			_status = newStatus;
			
			dispatchEvent(new StatusEvent(StatusEvent.STATUS, false, false, status, StatusEvent.STATUS));
		}
		
		private function attemptToConnect(connectionA:String, connectionB:String) : void
		{
			if(status != CONNECTING) return;
			
			var inboundConnectionName:String = tryConnectWith(connectionA) || tryConnectWith(connectionB);
			
			if(inboundConnectionName)
			{
				_outboundConnectionName = inboundConnectionName == connectionA ? connectionB : connectionA;
				
				updateStatus(WAITING_FOR_REMOTE_CLIENT);	
			}
			else
			{
				setTimeout(attemptToConnect, RETRY_CONNECTION_INTERVAL, connectionA, connectionB);
			}
		}
		
		private function tryConnectWith(connectionName:String) : String
		{				
			try { super.connect(connectionName) }
			catch(e:ArgumentError) { connectionName = null }
			
			return connectionName;
		}
	}
}