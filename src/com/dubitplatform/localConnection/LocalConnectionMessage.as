package com.dubitplatform.localConnection
{
	import mx.messaging.messages.AbstractMessage;

	public class LocalConnectionMessage extends AbstractMessage
	{		
		private static const FUNCTION_NAME_HEADER:String = "f";
		private static const FUNCTION_ARGUMENTS_HEADER:String = "a";
		
		public function LocalConnectionMessage(functionName:String = null, functionArguments:Array = null)
		{
			headers[FUNCTION_NAME_HEADER] = functionName;
			headers[FUNCTION_ARGUMENTS_HEADER] = functionArguments;
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