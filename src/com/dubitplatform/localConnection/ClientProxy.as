package com.dubitplatform.localConnection
{
	import flash.utils.Proxy;
	import flash.utils.flash_proxy;
	
	use namespace flash_proxy;
	
	public class ClientProxy extends Proxy
	{
		private var _localConnectionService:LocalConnectionService;
		private var _messages:Object;
		
		public function ClientProxy(localConnectionService:LocalConnectionService, messages:Object)
		{
			_localConnectionService = localConnectionService;
			_messages = messages;
		}
		
		public function get localConnectionService() : LocalConnectionService
		{
			return _localConnectionService;
		}
		
		public function get messages() : Object
		{
			return _messages;
		}
	}
}