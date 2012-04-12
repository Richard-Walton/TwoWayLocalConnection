package com.dubitplatform.localConnection
{
	import avmplus.getQualifiedClassName;
	
	import flash.events.EventDispatcher;
	import flash.events.StatusEvent;
	import flash.net.LocalConnection;
	import flash.net.registerClassAlias;
	import flash.utils.setTimeout;

	[Event(name="status", type="flash.events.StatusEvent")]
	public class LocalConnectionMananger extends EventDispatcher
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
		
		public function LocalConnectionMananger(inboundConnection:LocalConnection = null, outboundConnection:LocalConnection = null)
		{
			registerClassAlias(getQualifiedClassName(LocalConnectionMessage), LocalConnectionMessage);
			
			_inboundConnection = inboundConnection || new LocalConnection();
			_outboundConnection = outboundConnection || new LocalConnection();
			
			var errorEventSwallower:Function = function(e:StatusEvent) : void {}
			
			_inboundConnection.addEventListener(StatusEvent.STATUS, errorEventSwallower);
			_outboundConnection.addEventListener(StatusEvent.STATUS, errorEventSwallower);
			
			_inboundConnectionName = null;
			_outboundConnectionName = null;
			
			_status = IDLE;
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
		
		public function get status() : String
		{
			return _status;
		}
		
		internal function updateStatus(newStatus:String) : void
		{
			_status = newStatus;
			
			dispatchEvent(new StatusEvent(StatusEvent.STATUS, false, false, status, status));
		}
		
		public function connect(connectionName:String) : void
		{
			if(status != IDLE) return;
			
			updateStatus(CONNECTING);
			
			attemptToConnect(connectionName);
		}
		
		protected function attemptToConnect(connectionName:String) : void
		{
			if(status != CONNECTING) return;
			
			_inboundConnectionName = _outboundConnectionName = null;
			
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
					setTimeout(attemptToConnect, RETRY_CONNECTION_INTERVAL, connectionName);
				}
			}
			
			if(inboundConnectionName && outboundConnectionName)
			{
				updateStatus(WAITING_FOR_REMOTE_CLIENT);
			}
		}
		
		public function close() : void
		{
			updateStatus(CLOSING);
			
			try
			{
				inboundConnection.close()
			}
			catch(e:ArgumentError)
			{
				
			}
		
			updateStatus(IDLE);
		}
	}
}