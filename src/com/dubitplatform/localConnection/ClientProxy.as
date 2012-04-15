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
		
		private static const SEND_KEEP_ALIVE_INTERVAL:int = 1000;
		private static const TIMEOUT_CHECK_INTERVAL:int = 5000;
		private static const TIMEOUT:int = 2500;
		
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
			
			var timeoutIntervalID:uint = 0;
			var sendAliveIntervalID:uint = 0;
			
			service.addEventListener(StatusEvent.STATUS, function(e:StatusEvent) : void
			{
				if(e.code == LocalConnectionService.WAITING_FOR_REMOTE_CLIENT)
				{
					timeoutIntervalID = setInterval(checkForTimeouts, TIMEOUT_CHECK_INTERVAL);
					sendAliveIntervalID = setInterval(sendMessage, SEND_KEEP_ALIVE_INTERVAL, FunctionCallMessage.create(NOTIFY_ALIVE_METHOD));
				}
				else if(e.code == LocalConnectionService.CLOSING)
				{
					clearInterval(timeoutIntervalID);
					clearInterval(sendAliveIntervalID);
				}
			});
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
			var returnValue:* = service.localClient[functionName].apply(null, params);
				
			sendMessage(FunctionCallMessage.create(FUNCTION_RETURN_METHOD, [messageId, returnValue]));
		}
		
		protected function handleFunctionReturn(messageId:String, returnValue:Object) : void
		{
			var responseHandler:AsyncToken = sentMessageTokens[messageId];
			
			responseHandler.applyResult(ResultEvent.createEvent(returnValue, responseHandler, responseHandler.message));
				
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
				service.outboundConnection.send(service.outboundConnectionName, "handleMessagePacket", packet);
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
		
		protected function checkForTimeouts() : void
		{
			var currentTime:int = getTimer();

			// Message timeouts
			for each(var token:AsyncToken in sentMessageTokens)
			{
				var message:IMessage = token.message;
				
				if((currentTime - message.timestamp) > TIMEOUT)
				{
					token.applyFault(FaultEvent.createEvent(new Fault("timeout", "timeout"), token, message));
					
					delete sentMessageTokens[message.messageId];
				}
			}
			
			// Connection timeout
			if(service.connected && (currentTime - lastAliveTime) > TIMEOUT)
			{
				service.updateStatus(LocalConnectionService.TIMED_OUT);
				service.connect(service.connectionName); // Attempt to re-connect
			}
		}
	}
}