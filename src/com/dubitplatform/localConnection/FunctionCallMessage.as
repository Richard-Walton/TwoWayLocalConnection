package com.dubitplatform.localConnection
{
	import flash.utils.getTimer;
	
	import mx.messaging.messages.AbstractMessage;

	internal class FunctionCallMessage extends AbstractMessage
	{		
		private static const FUNCTION_NAME_HEADER:String = "f";
		private static const FUNCTION_ARGUMENTS_HEADER:String = "a";
		
		public static function create(functionName:String, functionArguments:Array) : FunctionCallMessage
		{
			var message:FunctionCallMessage = new FunctionCallMessage();
			
			message.headers[FUNCTION_NAME_HEADER] = functionName;
			message.headers[FUNCTION_ARGUMENTS_HEADER] = functionArguments;
			message.timestamp = getTimer();
			
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