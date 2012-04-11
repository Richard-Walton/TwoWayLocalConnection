package com.dubitplatform.localConnection
{
	import flash.errors.IllegalOperationError;
	import flash.utils.Proxy;
	import flash.utils.flash_proxy;
	
	import mx.core.mx_internal;
	import mx.rpc.AsyncToken;
	import mx.rpc.events.ResultEvent;
	import mx.utils.UIDUtil;
	
	use namespace flash_proxy;
	
	internal class ClientProxy extends Proxy
	{	
		private var localConnectionService:LocalConnectionService;
		private var sentMessageTokens:Object;
		
		public function ClientProxy(localConnectionService:LocalConnectionService)
		{
			this.localConnectionService = localConnectionService;		
			this.sentMessageTokens = {};
		}
		
		// incoming messages
		override flash_proxy function getProperty(name:*) : *
		{			
			return function(...params) : void
			{
				if(params.length == 1 && params[0] is LocalConnectionMessage) receiveMessage(params[0]);
			}
		}
		
		// outgoing messages
		override flash_proxy function callProperty(name:*, ...parameters) : *
		{	
			return sendMessage(new LocalConnectionMessage(name, parameters));
		}
		
		protected function receiveMessage(message:LocalConnectionMessage) : void
		{
			if(! sentMessageTokens.hasOwnProperty(message.messageId)) handleFunctionCall(message);
			else handleFunctionReturn(message);
		}
		
		protected function handleFunctionCall(message:LocalConnectionMessage) : void
		{
			var handlerFunction:Function = localConnectionService.localClient[message.functionName];
			
			if(handlerFunction.length > 0) 
			{
				message.body = handlerFunction.apply(null, message.functionArguments);
				
				sendMessage(message, false);
			}
			else
			{
				handlerFunction();
			}
		}
		
		protected function handleFunctionReturn(message:LocalConnectionMessage) : void
		{
			var responseHandler:AsyncToken = sentMessageTokens[message.messageId];
			
			if(responseHandler)
			{
				use namespace mx_internal;
				
				responseHandler.applyResult(ResultEvent.createEvent(message.body, responseHandler, responseHandler.message));
			}
		}
		
		protected function sendMessage(message:LocalConnectionMessage, expectResponse:Boolean = true) : AsyncToken
		{
			if(!localConnectionService.connected) throw new IllegalOperationError("LocalConnectionService is not yet connected");
			
			var connectionManager:LocalConnectionMananger = localConnectionService.connectionManager;
			
			var token:AsyncToken = new AsyncToken(message);
			
			if(expectResponse) sentMessageTokens[message.messageId] = token;
			
			connectionManager.outboundConnection.send(
				connectionManager.outboundConnectionName, message.functionName, message)
			
			return token;
		}		
	}
}