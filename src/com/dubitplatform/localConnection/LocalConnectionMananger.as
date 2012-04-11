package com.dubitplatform.localConnection
{
	import avmplus.getQualifiedClassName;
	
	import flash.net.LocalConnection;
	import flash.net.registerClassAlias;
	import flash.utils.setTimeout;

	public class LocalConnectionMananger
	{
		public static const IDLE:int = 0;
		public static const CONNECTING:int = 1;
		public static const HAND_SHAKE:int = 2;
		public static const CONNECTED:int = 3;
		
		private static const RETRY_CONNECTION_INTERVAL:int = 500;
		
		private var _inboundConnection:LocalConnection;
		private var _outboundConnection:LocalConnection;
		
		private var _inboundConnectionName:String;
		private var _outboundConnectionName:String;
		
		private var _state:int;
		
		public function LocalConnectionMananger(inboundConnection:LocalConnection = null, outboundConnection:LocalConnection = null)
		{
			registerClassAlias(getQualifiedClassName(LocalConnectionMessage), LocalConnectionMessage);
			
			_inboundConnection = inboundConnection || new LocalConnection();
			_outboundConnection = outboundConnection || new LocalConnection();
			
			_inboundConnectionName = null;
			_outboundConnectionName = null;
			
			_state = IDLE;
		}
		
		public function get inboundConnection() : LocalConnection
		{
			return _inboundConnection;
		}

		public function get outboundConnection() : LocalConnection
		{
			return _outboundConnection;
		}
				
		public function get inboundConnectionName() : String
		{
			return _inboundConnectionName;
		}
		
		public function get outboundConnectionName() : String
		{
			return _outboundConnectionName;
		}
		
		public function get state() : int
		{
			return _state;
		}
		
		public function connect(connectionName:String) : void
		{
			if(state != IDLE) return;
			
			_state = CONNECTING;
			
			try
			{
				inboundConnection.connect(_inboundConnectionName = connectionName + "_1");
				_outboundConnectionName = connectionName + "_2";
			}
			catch(e:ArgumentError)
			{
				try
				{
					inboundConnection.connect(_inboundConnectionName = connectionName + "_2");
					_outboundConnectionName = connectionName + "_1";
				}
				catch(e:ArgumentError)
				{
					close();
					
					_state = CONNECTING;
					
					setTimeout(connect, RETRY_CONNECTION_INTERVAL, connectionName);
				}
			}
			
			_state = CONNECTED;
		}
		
		public function close() : void
		{
			if(_state == CONNECTED) inboundConnection.close() 
		
			_state = IDLE;
		}
		
		public function sendOutbound(methodName:String, params:Array) : void
		{
			outboundConnection.send.apply(outboundConnection, [outboundConnectionName, methodName, params]);
		}
	}
}