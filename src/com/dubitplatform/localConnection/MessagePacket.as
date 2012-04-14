package com.dubitplatform.localConnection
{
	import flash.utils.ByteArray;
	
	import mx.messaging.messages.IMessage;

	internal class MessagePacket
	{
		private static const MAX_PACKET_SIZE:int = 39200;
		
		public var messageId:String;
		public var bytes:ByteArray;
		public var completeMessageSize:int;
		
		public static function createPackets(message:IMessage) : Vector.<MessagePacket>
		{
			var messageBytes:ByteArray = new ByteArray();
			
			messageBytes.writeObject(message);
			messageBytes.position = 0;
			
			var packets:Vector.<MessagePacket> = new Vector.<MessagePacket>();
			
			while(messageBytes.position != messageBytes.length)
			{
				var packetSize:int = Math.min(MAX_PACKET_SIZE, messageBytes.length - messageBytes.position);
				
				var packetBytes:ByteArray = new ByteArray();
				
				packetBytes.writeBytes(messageBytes, messageBytes.position, packetSize);
				
				packets.push(MessagePacket.create(message.messageId, packetBytes, messageBytes.length));
				
				messageBytes.position += packetBytes.length;
			}
			
			messageBytes.clear();
			
			return packets;
		}
		
		private static function create(messageId:String, bytes:ByteArray, completeMessageSize:int) : MessagePacket
		{
			var messagePacket:MessagePacket = new MessagePacket();
			
			messagePacket.messageId = messageId;
			messagePacket.bytes = bytes;
			messagePacket.completeMessageSize = completeMessageSize;
			
			return messagePacket;
		}
	}
}