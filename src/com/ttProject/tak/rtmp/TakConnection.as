package com.ttProject.tak.rtmp
{
	import com.ttProject.info.Logger;
	
	import flash.net.NetConnection;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.getQualifiedClassName;
	
	/**
	 * 独自命令を処理させるためのrtmp用コネクション
	 */
	public class TakConnection extends NetConnection {
		private var _ts:RtmpTakStream3;
		/**
		 * コンストラクタ
		 */
		public function TakConnection(stream:RtmpTakStream3) {
			super();
			_ts = stream;
		}
		/**
		 * flhデータ
		 */
		public function takHeader(data:*):void {
			var ba:ByteArray = makeByteArray(data);
			_ts.headerData(ba);
		}
		/**
		 * flmデータ
		 */
		public function takData(data:*):void {
			var ba:ByteArray = makeByteArray(data);
			_ts.bodyData(ba);
		}
		/**
		 * 要素パケットデータ
		 * (未使用)
		 */
		public function takRawData(index:int, data:*):void {
			Logger.info("rawDataうけとった");
		}
		/**
		 * 受け取ったデータをByteArrayに変換します。
		 */
		private function makeByteArray(data:Array):ByteArray {
			var ba:ByteArray = new ByteArray;
			ba.endian = Endian.BIG_ENDIAN;
			for(var i:int = 0;i < data.length;i ++) {
				ba.writeByte(data[i]);
			}
			ba.position = 0;
			return ba;
		}
	}
}