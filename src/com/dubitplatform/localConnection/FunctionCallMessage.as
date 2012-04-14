package com.dubitplatform.localConnection
{
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	
	import mx.messaging.messages.AbstractMessage;

	internal class FunctionCallMessage extends AbstractMessage
	{		
		private static const FUNCTION_NAME_HEADER:String = "f";
		private static const FUNCTION_ARGUMENTS_HEADER:String = "a";
		
		public static function create(functionName:String, functionArguments:Array = null) : FunctionCallMessage
		{		
			var body:Object = {};
			
			body[FUNCTION_NAME_HEADER] = functionName;
			body[FUNCTION_ARGUMENTS_HEADER] = functionArguments;
			
			var message:FunctionCallMessage = new FunctionCallMessage();
			
			message.body = body;
			message.timestamp = getTimer();
			
			return message;
		}
		
		public static function createFromPackets(packets:Vector.<MessagePacket>) : FunctionCallMessage
		{
			var messageBytes:ByteArray = new ByteArray();
			
			for(var i:int = 0; i < packets.length; i++)
			{
				messageBytes.writeBytes(packets[i].bytes);
			}
			
			messageBytes.position = 0;
			
			var functionCallMessage:FunctionCallMessage = messageBytes.readObject();
			
			messageBytes.clear();
			
			return functionCallMessage;
		}
		
		public function get functionName() : String
		{
			return body[FUNCTION_NAME_HEADER];
		}
		
		public function get functionArguments() : Array
		{
			return body[FUNCTION_ARGUMENTS_HEADER];
		}
	}
}