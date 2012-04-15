package com.dubitplatform.localConnection
{
	import flash.errors.IllegalOperationError;
	import flash.events.StatusEvent;
	import flash.net.registerClassAlias;
	import flash.utils.Proxy;
	import flash.utils.clearInterval;
	import flash.utils.flash_proxy;
	import flash.utils.getQualifiedClassName;
	import flash.utils.getTimer;
	import flash.utils.setInterval;
	
	import mx.core.mx_internal;
	import mx.messaging.messages.IMessage;
	import mx.rpc.AsyncToken;
	import mx.rpc.Fault;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import mx.utils.UIDUtil;
	
	use namespace flash_proxy;
	use namespace mx_internal;
	
	internal class ClientProxy extends Proxy
	{	
		private static const FUNCTION_CALL_METHOD:String = "functionCall";
		private static const FUNCTION_RETURN_METHOD:String = "functionReturn";
		private static const NOTIFY_ALIVE_METHOD:String = "notifyAlive";
		private static const CONNECTION_MAINTENANCE_INTERVAL:int = 1000;
		private static const TIMEOUT_PERIOD:int = 2500;
		
		private var lastAliveTime:int = -1;
		
		private var sentMessageTokens:Object;
		private var messageBuffers:Object;
		private var messageHandlers:Object;
		
		private var service:LocalConnectionService;
		
		public function ClientProxy(service:LocalConnectionService)
		{
			registerClassAlias(getQualifiedClassName(FunctionCallMessage), FunctionCallMessage);
			registerClassAlias(getQualifiedClassName(MessagePacket), MessagePacket);
			
			this.service = service;
			
			sentMessageTokens = {};
			messageBuffers = {};
			
			messageHandlers = {};
			messageHandlers[FUNCTION_CALL_METHOD] = handleFunctionCall;
			messageHandlers[FUNCTION_RETURN_METHOD] = handleFunctionReturn;		
			messageHandlers[NOTIFY_ALIVE_METHOD] = handleNotifyAlive;
			
			var maintenanceIntervalID:uint = 0;
			
			service.addEventListener(StatusEvent.STATUS, function(e:StatusEvent) : void
			{
				if(e.code == LocalConnectionService.WAITING_FOR_REMOTE_CLIENT)
				{
					maintenanceIntervalID = setInterval(performConnectionMaintenance, CONNECTION_MAINTENANCE_INTERVAL);
				}
				else if(e.code == LocalConnectionService.CLOSING)
				{
					clearInterval(maintenanceIntervalID);
				}
			});
		}
		
		override flash_proxy function getProperty(name:*) : *
		{
			// Forwards on any remote function calls not directly created/handled by ClientProxy to actual client object.
			return service.client[name];
		}
		
		// outgoing messages
		override flash_proxy function callProperty(name:*, ...parameters) : *
		{		
			if(!service.connected) throw new IllegalOperationError("LocalConnectionService is not connected");
			
			var messageId:String = UIDUtil.createUID();
			var messageParms:Array = [messageId, String(name), parameters];
			
			var functionCall:FunctionCallMessage = FunctionCallMessage.create(FUNCTION_CALL_METHOD, messageParms);
		
			functionCall.messageId = messageId;
			
			return sendRequest(functionCall);
		}
		
		protected function handleFunctionCall(messageId:String, functionName:String, params:Array) : void
		{
			var returnValue:* = service.client[functionName].apply(null, params);
				
			sendMessage(FunctionCallMessage.create(FUNCTION_RETURN_METHOD, [messageId, returnValue]));
		}
		
		protected function handleFunctionReturn(messageId:String, returnValue:Object) : void
		{
			var handler:AsyncToken = sentMessageTokens[messageId];
			
			// Message response may no longer have a handler if the message has timed out
			if(handler) handler.applyResult(ResultEvent.createEvent(returnValue, handler, handler.message));
				
			delete sentMessageTokens[messageId];
		}
		
		protected function sendRequest(message:FunctionCallMessage) : AsyncToken
		{			
			sendMessage(message);
			
			return sentMessageTokens[message.messageId] = new AsyncToken(message);
		}
		
		protected function sendMessage(message:FunctionCallMessage) : void
		{				
			for each(var packet:MessagePacket in MessagePacket.createPackets(message))
			{
				service.send(service.outboundConnectionName, "handleMessagePacket", packet);
			}
		}
		
		public function handleMessagePacket(packet:MessagePacket) : void
		{
			var packets:Vector.<MessagePacket> = messageBuffers[packet.messageId];
			
			if(packets == null) packets = messageBuffers[packet.messageId] = new Vector.<MessagePacket>();
			
			packets.push(packet);
			
			if(packets.length == packet.totalPackets)
			{
				delete messageBuffers[packet.messageId];
				
				var functionCallMessage:FunctionCallMessage = FunctionCallMessage.createFromPackets(packets);
				
				messageHandlers[functionCallMessage.functionName].apply(null, functionCallMessage.functionArguments);
			}
		}
		
		protected function handleNotifyAlive() : void
		{
			lastAliveTime = getTimer();
			
			if(! service.connected) service.updateStatus(LocalConnectionService.CONNECTED);
		}
		
		protected function performConnectionMaintenance() : void
		{
			sendMessage(FunctionCallMessage.create(NOTIFY_ALIVE_METHOD)); // Notify the connected client we're still here
			
			checkForTimeouts(); // Make sure the connected client is still there.
		}
		
		protected function checkForTimeouts() : void
		{
			var currentTime:int = getTimer();

			// Message timeouts
			for each(var token:AsyncToken in sentMessageTokens)
			{
				var message:IMessage = token.message;
				
				if((currentTime - message.timestamp) > TIMEOUT_PERIOD)
				{
					token.applyFault(FaultEvent.createEvent(new Fault("timeout", "timeout"), token, message));
					
					delete sentMessageTokens[message.messageId];
				}
			}
			
			// Connection timeout
			if(service.connected && (currentTime - lastAliveTime) > TIMEOUT_PERIOD)
			{
				service.updateStatus(LocalConnectionService.TIMED_OUT);
				service.connect(service.connectionName); // Attempt to re-connect
			}
		}
	}
}