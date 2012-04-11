package com.dubitplatform.localConnection
{
	import flash.events.EventDispatcher;
	
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
		}
		
		public function connect(connectionName:String) : void
		{
			connectionManager.connect(connectionName);
		}
		
		public function get connectionManager() : LocalConnectionMananger
		{
			return _connectionManager;
		}
		
		public function get connected() : Boolean
		{
			return connectionManager.state == LocalConnectionMananger.CONNECTED;
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
			return connected ? _clientProxy : null;
		}
	}
}