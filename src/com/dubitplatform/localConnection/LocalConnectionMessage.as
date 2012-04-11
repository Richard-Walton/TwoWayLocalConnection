package com.dubitplatform.localConnection
{
	import mx.messaging.messages.AbstractMessage;

	public class LocalConnectionMessage extends AbstractMessage
	{		
		public function LocalConnectionMessage(messageId:String = null, functionName:String = null, functionArguments:Array = null)
		{
			this.messageId = messageId;
			this.headers = {
				"fn": functionName,
				"fa": functionArguments
			}
		}
		
		public function get functionName() : String
		{
			return headers["fn"];
		}
		
		public function get functionArguments() : Array
		{
			return headers["fa"];
		}
	}
}