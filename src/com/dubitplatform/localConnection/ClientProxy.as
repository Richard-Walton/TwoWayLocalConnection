package com.dubitplatform.localConnection
{
	import flash.errors.IllegalOperationError;
	import flash.utils.Proxy;
	import flash.utils.flash_proxy;
	
	import mx.core.mx_internal;
	import mx.messaging.messages.IMessage;
	import mx.rpc.AsyncToken;
	import mx.rpc.events.ResultEvent;
	
	use namespace flash_proxy;
	
	internal class ClientProxy extends Proxy
	{	
		private static const FUNCTION_CALL_METHOD:String = "functionCall";
		private static const FUNCTION_RETURN_METHOD:String = "functionReturn";
		
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
		}
		
		// incoming messages
		override flash_proxy function getProperty(name:*) : *
		{	
			return messageHandlers[name];
		}
		
		// outgoing messages
		override flash_proxy function callProperty(name:*, ...parameters) : *
		{				
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
				use namespace mx_internal;
				
				responseHandler.applyResult(ResultEvent.createEvent(message.body, responseHandler, responseHandler.message));
			}
		}
		
		protected function sendMessage(methodName:String, message:IMessage, expectResponse:Boolean = true) : AsyncToken
		{
			if(!localConnectionService.connected) throw new IllegalOperationError("LocalConnectionService is not yet connected");
			
			var token:AsyncToken = new AsyncToken(message);		
			var connectionManager:LocalConnectionMananger = localConnectionService.connectionManager;

			connectionManager.outboundConnection.send(connectionManager.outboundConnectionName, methodName, message);
			
			if(expectResponse) sentMessageTokens[message.messageId] = token;
			
			return token;
		}		
	}
}