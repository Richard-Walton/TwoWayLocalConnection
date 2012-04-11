package com.dubitplatform.localConnection
{
	import flash.utils.flash_proxy;
	
	import mx.core.mx_internal;
	import mx.rpc.AsyncToken;
	import mx.rpc.events.ResultEvent;
	
	use namespace flash_proxy;

	internal class LocalClientProxy extends ClientProxy
	{		
		public function LocalClientProxy(localConnectionService:LocalConnectionService, messages:Object)
		{
			super(localConnectionService, messages);
		}
		
		override flash_proxy function getProperty(name:*):*
		{			
			return function(...params) : void { callProperty.apply(null, [name].concat(params)) }
		}
		
		override flash_proxy function callProperty(name:*, ...parameters) : *
		{
			var message:LocalConnectionMessage = parameters[0];
			
			var handlerFunction:Function = localConnectionService.localClient[message.functionName];
			
			if(handlerFunction.length > 0) 
			{
				message.body = handlerFunction.call(localConnectionService.localClient, message.functionArguments);
				
				localConnectionService.connectionManager.outboundConnection.send(
					localConnectionService.connectionManager.outboundConnectionName, "functionResult", message);
			}
			else
			{
				handlerFunction();
				
			}
		}
		
		public function functionResult(message:LocalConnectionMessage) : void
		{
			use namespace mx_internal;

			var asyncToken:AsyncToken = messages[message.messageId];
			
			asyncToken.applyResult(ResultEvent.createEvent(message.body, asyncToken, asyncToken.message));
		}
	}
}