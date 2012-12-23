package com.ttProject.tak.rtmfp
{
	import com.ttProject.info.Logger;
	
	import flash.events.NetStatusEvent;
	import flash.net.NetConnection;
	import flash.net.NetStream;

	public class RecvConnection {
		private static var recvStream:NetStream; // 受信用
		private static var sendStream:NetStream; // 送信用
		private var name:String;
		private var nodeId:String;
		public function RecvConnection(name:String, nodeId:String, nc:NetConnection) {
			if(recvStream != null) {
				recvStream.close();
			}
			this.name = name;
			this.nodeId = nodeId;
			recvStream = new NetStream(nc, nodeId); // 接続先node指定
			recvStream.addEventListener(NetStatusEvent.NET_STATUS, onNetStreamEvent);
			recvStream.client = new Object();
			recvStream.client.flhData = flhData;
			recvStream.client.flmData = flmData;
			recvStream.client.sourceNode = sourceNode;
			recvStream.play(name);

			sendStream = new NetStream(nc, NetStream.DIRECT_CONNECTIONS);
			sendStream.addEventListener(NetStatusEvent.NET_STATUS, function(event:NetStatusEvent):void {
			});
			sendStream.publish(nodeId); // 自分のnearIDを元に接続できるようにしておく
		}
		private function onNetStreamEvent(event:NetStatusEvent):void {
			
		}
		private function flhData(data:*):void {
			
		}
		private function flmData(data:*):void {
			
		}
		private function sourceNode(data:*):void {
			Logger.info(data);
		}
	}
}