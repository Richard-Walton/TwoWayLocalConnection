package com.dubitplatform.localConnection
{
	import avmplus.getQualifiedClassName;
	
	import flash.events.EventDispatcher;
	import flash.events.StatusEvent;
	import flash.net.LocalConnection;
	import flash.net.registerClassAlias;
	import flash.utils.setTimeout;
	
	[Event(name="status", type="flash.events.StatusEvent")]
	public class LocalConnectionService extends EventDispatcher
	{	
		public static const IDLE:String = "idle";
		public static const CONNECTING:String = "connecting";
		public static const WAITING_FOR_REMOTE_CLIENT:String = "waitingForRemoteClient";
		public static const CONNECTED:String = "connected";
		public static const CLOSING:String = "closing";
		
		private static const RETRY_CONNECTION_INTERVAL:int = 500;
		
		private var _inboundConnection:LocalConnection;
		private var _outboundConnection:LocalConnection;
		
		private var _inboundConnectionName:String;
		private var _outboundConnectionName:String;
		
		private var _status:String;
		
		private var _localClient:Object;
		private var _clientProxy:ClientProxy;
		
		public function LocalConnectionService(localClient:Object = null)
		{			
			registerClassAlias(getQualifiedClassName(FunctionCallMessage), FunctionCallMessage);
			
			_localClient = localClient;
			_clientProxy = new ClientProxy(this);
			
			_inboundConnection = createAndSetupLocalConnection(_clientProxy);			
			_outboundConnection = createAndSetupLocalConnection(_clientProxy);
			
			_inboundConnectionName = null;
			_outboundConnectionName = null;
			
			_status = IDLE;
		}
		
		private function createAndSetupLocalConnection(client:Object) : LocalConnection
		{
			var localConnection:LocalConnection = new LocalConnection();

			localConnection.client = client;
			localConnection.addEventListener(StatusEvent.STATUS, function(e:StatusEvent) : void {});
			
			return localConnection;
		}
		
		internal function get inboundConnection() : LocalConnection
		{
			return _inboundConnection;
		}
		
		internal function get outboundConnection() : LocalConnection
		{
			return _outboundConnection;
		}
		
		internal function get inboundConnectionName() : String
		{
			return _inboundConnectionName;
		}
		
		internal function get outboundConnectionName() : String
		{
			return _outboundConnectionName;
		}
		
		public function get status() : String
		{
			return _status;
		}
		
		/**
		 * @see flash.net.LocalConnection#client()
		 */   
		public function get localClient() : Object
		{
			return _localClient;
		}
		
		public function set localClient(value:Object) : void
		{
			_localClient = value;
		}
		
		public function get remoteClient() : Object
		{
			return _clientProxy;
		}
		
		internal function updateStatus(newStatus:String) : void
		{
			_status = newStatus;
			
			dispatchEvent(new StatusEvent(StatusEvent.STATUS, false, false, status, status));
		}
		
		/**
		 * @see flash.net.LocalConnection#allowDomain()
		 */  
		public function allowDomain(... domains) : void
		{
			inboundConnection.allowDomain.apply(null, domains);
			outboundConnection.allowDomain.apply(null, domains);
		}
		
		/**
		 * @see flash.net.LocalConnection#allowInsecureDomain()
		 */          
		public function allowInsecureDomain(... domains) : void
		{
			inboundConnection.allowInsecureDomain.apply(null, domains);
			outboundConnection.allowInsecureDomain.apply(null, domains);
		}
		
		/**
		 * @see flash.net.LocalConnection#connect()
		 */   
		public function connect(connectionName:String) : void
		{
			if(status != IDLE) return;
			
			updateStatus(CONNECTING);
			
			if(connectionName.charAt(0) != "_") connectionName = "_" + connectionName;
			
			attemptToConnect(connectionName + "_1", connectionName + "_2");
		}
		
		public function get connected() : Boolean
		{
			return status == CONNECTED || status == CLOSING;
		}
		
		/**
		 * @see flash.net.LocalConnection#close()
		 */   
		public function close() : void
		{
			updateStatus(CLOSING);
			
			try { inboundConnection.close() }
			catch(e:ArgumentError) {}
			
			updateStatus(IDLE);
		}
		
		protected function attemptToConnect(connectionA:String, connectionB:String) : void
		{
			if(status != CONNECTING) return;
			
			var successfulConnectionName:String = tryConnectWith(connectionA) || tryConnectWith(connectionB);
			
			if(successfulConnectionName)
			{
				_inboundConnectionName = successfulConnectionName;
				_outboundConnectionName = successfulConnectionName == connectionA ? connectionB : connectionA;
				
				updateStatus(WAITING_FOR_REMOTE_CLIENT);
			}
			else
			{
				setTimeout(attemptToConnect, RETRY_CONNECTION_INTERVAL, connectionA, connectionB);
			}
		}
		
		private function tryConnectWith(connectionName:String) : String
		{	
			try { inboundConnection.connect(connectionName) }
			catch(e:ArgumentError) { connectionName = null }
			
			return connectionName;
		}
	}
}