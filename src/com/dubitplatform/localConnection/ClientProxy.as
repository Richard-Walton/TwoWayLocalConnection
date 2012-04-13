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
	
	use namespace flash_proxy;
	use namespace mx_internal;
	
	internal class ClientProxy extends Proxy
	{	
		private static const FUNCTION_CALL_METHOD:String = "functionCall";
		private static const FUNCTION_RETURN_METHOD:String = "functionReturn";
		private static const NOTIFY_ALIVE_METHOD:String = "notifyAlive";
		
		private static const KEEP_ALIVE_INTERVAL:int = 1000;
		private static const TIMEOUT_CHECK_INTERVAL:int = 5000;
		private static const TIMEOUT:int = 1000;
		
		private var lastAliveTime:int = -1;
		
		private var sentMessageTokens:Object;
		private var messageHandlers:Object;
		
		private var localConnectionService:LocalConnectionService;
		
		public function ClientProxy(localConnectionService:LocalConnectionService)
		{
			registerClassAlias(getQualifiedClassName(FunctionCallMessage), FunctionCallMessage);
			
			this.localConnectionService = localConnectionService;
			
			sentMessageTokens = {};
			
			messageHandlers = {};
			messageHandlers[FUNCTION_CALL_METHOD] = handleFunctionCall;
			messageHandlers[FUNCTION_RETURN_METHOD] = handleFunctionReturn;		
			messageHandlers[NOTIFY_ALIVE_METHOD] = handleNotifyAlive;
			
			var timeoutIntervalID:uint = 0;
			var sendAliveIntervalID:uint = 0;
			
			localConnectionService.addEventListener(StatusEvent.STATUS, function(e:StatusEvent) : void
			{
				if(localConnectionService.status == LocalConnectionService.WAITING_FOR_REMOTE_CLIENT)
				{
					timeoutIntervalID = setInterval(checkForTimeouts, TIMEOUT_CHECK_INTERVAL);
					sendAliveIntervalID = setInterval(sendMessage, KEEP_ALIVE_INTERVAL, NOTIFY_ALIVE_METHOD);
				}
				else if(localConnectionService.status == LocalConnectionService.CLOSING)
				{
					clearInterval(timeoutIntervalID);
					clearInterval(sendAliveIntervalID);
				}
			});			
		}
		
		// incoming messages
		override flash_proxy function getProperty(name:*) : *
		{	
			return messageHandlers[name];
		}
		
		// outgoing messages
		override flash_proxy function callProperty(name:*, ...parameters) : *
		{		
			if(!localConnectionService.connected) throw new IllegalOperationError("LocalConnectionService is not connected");
			
			return sendMessage(FUNCTION_CALL_METHOD, FunctionCallMessage.create(name, parameters));
		}
		
		protected function handleFunctionCall(message:FunctionCallMessage) : void
		{
			var handlerFunction:Function = localConnectionService.localClient[message.functionName];
			
			message.body = handlerFunction.apply(null, message.functionArguments);
				
			sendMessage(FUNCTION_RETURN_METHOD, message, false);
		}
		
		protected function handleFunctionReturn(message:FunctionCallMessage) : void
		{
			var responseHandler:AsyncToken = sentMessageTokens[message.messageId];
			
			if(responseHandler)
			{
				responseHandler.applyResult(ResultEvent.createEvent(message.body, responseHandler, responseHandler.message));
				
				delete sentMessageTokens[message.messageId];
			}
		}
		
		protected function sendMessage(methodName:String, message:IMessage = null, expectResponse:Boolean = true) : AsyncToken
		{			
			var token:AsyncToken = null;
			
			if(message && expectResponse) sentMessageTokens[message.messageId] = token = new AsyncToken(message);
			
			var sendFunctionParams:Array = [localConnectionService.outboundConnectionName, methodName];
			
			if(message) sendFunctionParams.push(message);
			
			localConnectionService.outboundConnection.send.apply(null, sendFunctionParams);
			
			return token;
		}
		
		protected function handleNotifyAlive() : void
		{
			lastAliveTime = getTimer();
			
			if(! localConnectionService.connected) 
			{				
				localConnectionService.updateStatus(LocalConnectionService.CONNECTED);
			}
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
			if(localConnectionService.connected && (currentTime - lastAliveTime) > TIMEOUT)
			{
				localConnectionService.close(true);
			}
		}
	}
}