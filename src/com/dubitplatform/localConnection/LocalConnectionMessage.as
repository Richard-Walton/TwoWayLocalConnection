package com.dubitplatform.localConnection
{
	import mx.messaging.messages.AbstractMessage;

	public class LocalConnectionMessage extends AbstractMessage
	{		
		private static const FUNCTION_NAME_HEADER:String = "f";
		private static const FUNCTION_ARGUMENTS_HEADER:String = "a";
		
		public static function create(functionName:String, functionArguments:Array) : LocalConnectionMessage
		{
			var message:LocalConnectionMessage = new LocalConnectionMessage();
			
			message.headers[FUNCTION_NAME_HEADER] = functionName;
			message.headers[FUNCTION_ARGUMENTS_HEADER] = functionArguments;
			
			return message;
		}
		
		public function get functionName() : String
		{
			return headers[FUNCTION_NAME_HEADER];
		}
		
		public function get functionArguments() : Array
		{
			return headers[FUNCTION_ARGUMENTS_HEADER];
		}
	}
}