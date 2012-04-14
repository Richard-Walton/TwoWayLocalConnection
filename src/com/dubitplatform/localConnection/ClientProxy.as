package com.dubitplatform.localConnection
{
	import flash.errors.IllegalOperationError;
	import flash.events.StatusEvent;
	import flash.net.registerClassAlias;
	import flash.utils.ByteArray;
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
				if(service.status == LocalConnectionService.WAITING_FOR_REMOTE_CLIENT)
				{
					timeoutIntervalID = setInterval(checkForTimeouts, TIMEOUT_CHECK_INTERVAL);
					sendAliveIntervalID = setInterval(sendMessage, SEND_KEEP_ALIVE_INTERVAL, FunctionCallMessage.create(NOTIFY_ALIVE_METHOD));
				}
				else if(service.status == LocalConnectionService.CLOSING)
				{
					clearInterval(timeoutIntervalID);
					clearInterval(sendAliveIntervalID);
				}
			});			
		}
		
		// incoming messages
		override flash_proxy function getProperty(name:*) : *
		{	
			return handleMessagePacket as Function; // cast to stop compiler warning
		}
		
		// outgoing messages
		override flash_proxy function callProperty(name:*, ...parameters) : *
		{		
			if(!service.connected) throw new IllegalOperationError("LocalConnectionService is not connected");
			
			var functionCall:FunctionCallMessage = FunctionCallMessage.create(FUNCTION_CALL_METHOD);
			
			functionCall.functionArguments = [functionCall.messageId, String(name), parameters];
			
			return sendRequest(functionCall);
		}
		
		protected function handleFunctionCall(messageId:String, functionName:String, params:Array) : void
		{
			var handlerFunction:Function = service.localClient[functionName];
			
			var returnValue:* = handlerFunction.apply(null, params);
				
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
				service.outboundConnection.send(service.outboundConnectionName, "_", packet);
			}
		}
		
		private function handleMessagePacket(messagePacket:MessagePacket) : void
		{
			var buffer:ByteArray = messageBuffers[messagePacket.messageId];
			
			if(buffer == null) buffer = messageBuffers[messagePacket.messageId] = new ByteArray();
			
			buffer.writeBytes(messagePacket.bytes);
			
			if(buffer.length == messagePacket.completeMessageSize)
			{
				delete messageBuffers[messagePacket.messageId];
				
				buffer.position = 0;
				
				var functionCallMessage:FunctionCallMessage = buffer.readObject();
				
				buffer.clear();
				
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
				
				var timeSinceMessageSent:int = currentTime - message.timestamp;
				
				if(timeSinceMessageSent > TIMEOUT)
				{					
					token.applyFault(FaultEvent.createEvent(new Fault("timeout", "timeout"), token, message));
					
					delete sentMessageTokens[message.messageId];
				}
			}
			
			// Connection timeout
			if(service.connected && (currentTime - lastAliveTime) > TIMEOUT)
			{
				service.close(true);
			}
		}
	}
}