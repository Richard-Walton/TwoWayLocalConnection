package com.dubitplatform.localConnection
{
	import flash.errors.IllegalOperationError;
	import flash.utils.flash_proxy;
	
	import mx.rpc.AsyncToken;
	import mx.utils.UIDUtil;
	
	use namespace flash_proxy;
	
	internal class RemoteClientProxy extends ClientProxy
	{		
		public function RemoteClientProxy(localConnectionService:LocalConnectionService, messages:Object)
		{
			super(localConnectionService, messages);
		}
		
		override flash_proxy function callProperty(name:*, ...parameters) : *
		{
			if(!localConnectionService.connected) throw new IllegalOperationError("LocalConnectionService is not yet connected");
			
			var connectionManager:LocalConnectionMananger = localConnectionService.connectionManager;
			
			var token:AsyncToken = new AsyncToken(new LocalConnectionMessage(UIDUtil.createUID(), name, parameters));
			
			messages[token.message.messageId] = token;
			
			connectionManager.outboundConnection.send(
				connectionManager.outboundConnectionName, name, token.message)
			
			return token;
		}
	}
}