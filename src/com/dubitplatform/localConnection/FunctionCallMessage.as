package com.dubitplatform.localConnection
{
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	
	import mx.messaging.messages.AbstractMessage;

	internal class FunctionCallMessage extends AbstractMessage
	{		
		private static const FUNCTION_NAME:String = "f";
		private static const FUNCTION_ARGUMENTS:String = "a";
		
		public static function create(functionName:String, functionArguments:Array = null) : FunctionCallMessage
		{		
			var body:Object = {};
			
			body[FUNCTION_NAME] = functionName;
			body[FUNCTION_ARGUMENTS] = functionArguments;
			
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
			
			try { return messageBytes.readObject() }
			finally { messageBytes.clear(); }
			
			return null; // Just here to make the compiler work!  There is no way this line will ever be executed.
		}
		
		public function get functionName() : String
		{
			return body[FUNCTION_NAME];
		}
		
		public function get functionArguments() : Array
		{
			return body[FUNCTION_ARGUMENTS];
		}
	}
}