package com.dubitplatform.localConnection
{
	import flash.errors.IllegalOperationError;
	import flash.events.StatusEvent;
	import flash.utils.Proxy;
	import flash.utils.clearInterval;
	import flash.utils.flash_proxy;
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
		private static const NOTIFY_ALIVE:String = "notifyAlive";
		
		private static const KEEP_ALIVE_INTERVAL:int = 1000;
		private static const TIMEOUT_CHECK_INTERVAL:int = 5000;
		private static const TIMEOUT:int = 1000;
		
		private var lastAliveTime:int = -1;
		
		private var messageHandlers:Object;
		
		private var localConnectionService:LocalConnectionService;
		private var sentMessageTokens:Object;
		
		public function ClientProxy(localConnectionService:LocalConnectionService)
		{
			this.localConnectionService = localConnectionService;
			
			sentMessageTokens = {};
			
			messageHandlers = {};
			messageHandlers[FUNCTION_CALL_METHOD] = handleFunctionCall;
			messageHandlers[FUNCTION_RETURN_METHOD] = handleFunctionReturn;		
			messageHandlers[NOTIFY_ALIVE] = handleNotifyAlive;
			
			var timeoutIntervalID:uint = 0;
			var sendAliveIntervalID:uint = 0;
			
			var connectionManager:LocalConnectionMananger = localConnectionService.connectionManager;
			
			connectionManager.addEventListener(StatusEvent.STATUS, function(e:StatusEvent) : void
			{
				if(connectionManager.status == LocalConnectionMananger.WAITING_FOR_REMOTE_CLIENT)
				{
					timeoutIntervalID = setInterval(checkForTimeouts, TIMEOUT_CHECK_INTERVAL);
					sendAliveIntervalID = setInterval(sendMessage, KEEP_ALIVE_INTERVAL, NOTIFY_ALIVE);
				}
				else if(connectionManager.status == LocalConnectionMananger.CLOSING)
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
			if(!localConnectionService.connected) throw new IllegalOperationError("LocalConnectionService is not yet connected");
			
			return sendMessage(FUNCTION_CALL_METHOD, LocalConnectionMessage.create(name, parameters));
		}
		
		protected function handleFunctionCall(message:LocalConnectionMessage) : void
		{
			var handlerFunction:Function = localConnectionService.localClient[message.functionName];
			
			if(handlerFunction.length > 0) 
			{
				message.body = handlerFunction.apply(null, message.functionArguments);
				
				sendMessage(FUNCTION_RETURN_METHOD, message, false);
			}
			else
			{
				handlerFunction();
			}
		}
		
		protected function handleFunctionReturn(message:IMessage) : void
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

			var connectionManager:LocalConnectionMananger = localConnectionService.connectionManager;
			
			connectionManager.outboundConnection.send(connectionManager.outboundConnectionName, methodName, message);
			
			return token;
		}
		
		protected function handleNotifyAlive(values:Array) : void
		{
			lastAliveTime = getTimer();
			
			if(! localConnectionService.connected) 
			{				
				localConnectionService.connectionManager.updateStatus(LocalConnectionMananger.CONNECTED);
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
				localConnectionService.close();
			}
		}
	}
}