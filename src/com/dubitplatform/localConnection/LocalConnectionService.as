package com.dubitplatform.localConnection
{
	import flash.events.EventDispatcher;
	import flash.events.StatusEvent;
	
	public class LocalConnectionService extends EventDispatcher
	{		
		private var _localClient:Object;
		private var _clientProxy:ClientProxy;
		private var _connectionManager:LocalConnectionMananger;
		
		public function LocalConnectionService()
		{			
			var messages:Object = {};
			
			_connectionManager = new LocalConnectionMananger();
			_clientProxy = new ClientProxy(this);
			
			connectionManager.inboundConnection.client = _clientProxy
			connectionManager.outboundConnection.client = _clientProxy;
			
			connectionManager.addEventListener(StatusEvent.STATUS, function(e:StatusEvent) : void
			{
				trace(e.code)
			});
		}
		
		public function connect(connectionName:String) : void
		{
			connectionManager.connect(connectionName);
		}
		
		public function close() : void
		{
			if(connected) connectionManager.close();
		}
		
		public function get connectionManager() : LocalConnectionMananger
		{
			return _connectionManager;
		}
		
		public function get connected() : Boolean
		{
			return connectionManager.status == LocalConnectionMananger.CONNECTED
				|| connectionManager.status == LocalConnectionMananger.CLOSING;
		}
		
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
	}
}