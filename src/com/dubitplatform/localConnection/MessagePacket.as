package com.dubitplatform.localConnection
{
	import flash.utils.ByteArray;
	
	import mx.messaging.messages.IMessage;

	internal class MessagePacket
	{
		private static const MAX_PACKET_SIZE:int = 39200;
		
		public var messageId:String;
		public var bytes:ByteArray;
		public var totalPackets:int;
		
		public static function createPackets(message:IMessage) : Vector.<MessagePacket>
		{
			var messageBytes:ByteArray = new ByteArray();
			
			messageBytes.writeObject(message);
			messageBytes.position = 0;
			
			var totalPackets:int = Math.ceil(messageBytes.length / MAX_PACKET_SIZE);
			var packets:Vector.<MessagePacket> = new Vector.<MessagePacket>(totalPackets);
			
			for(var i:int = 0; i < totalPackets; i++)
			{
				var packetSize:int = Math.min(MAX_PACKET_SIZE, messageBytes.length - messageBytes.position);
				
				var packetBytes:ByteArray = new ByteArray();
				
				packetBytes.writeBytes(messageBytes, messageBytes.position, packetSize);
				
				packets[i] = MessagePacket.create(message.messageId, packetBytes, totalPackets);
				
				messageBytes.position += packetBytes.length;
			}
			
			messageBytes.clear();
			
			return packets;
		}
		
		private static function create(messageId:String, bytes:ByteArray, totalPackets:int) : MessagePacket
		{
			var messagePacket:MessagePacket = new MessagePacket();
			
			messagePacket.messageId = messageId;
			messagePacket.bytes = bytes;
			messagePacket.totalPackets = totalPackets;
			
			return messagePacket;
		}
	}
}