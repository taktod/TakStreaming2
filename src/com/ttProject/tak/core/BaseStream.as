package com.ttProject.tak.core
{
	import com.ttProject.info.Logger;
	
	import flash.utils.ByteArray;

	/**
	 * takStreamの基礎動作を実施します。
	 * 
	 * とりあえずbyteArrayについてメモ
	 * writeをつかえば書き込み可能。
	 * positionの位置は、wruteもreadも影響をうける。
	 * 00 01 02 03 04 05 06
	 * position0でreadIntを実行すると
	 * 00 01 02 03が取得できる。
	 * position0でwriteInt(5)を実行すると
	 * 00 00 00 05 04 05 06になる。
	 * 
	 */
	public class BaseStream extends TakStream {
		// 拡張データ
		private var _crc:int; // 動作のCRC値、ずれるデータがきたときには再生できない。
		protected function get crc():int {return _crc;}

		// headerの中身は
		private var flhData:ByteArray = null; // header情報
		// flmListの中身は
		// flmList["index"] = {size: data:}としておく。
		private var flmList:Object = {}; // mediaデータ情報

		// 処理中のindex番号
		private var index:int; // 再生index番号

		public function BaseStream() {
			super();
		}
		/**
		 * flhデータを設定します。
		 */
		public function appendFlhData(data:ByteArray):void {
			// headerデータ
			setup(); // headerをうけとったら、クリアする必要がある。
			// これがきた場合は再度setupし直す必要がある。
			_crc = data.readInt(); // crc取得
			var header:ByteArray = new ByteArray();
			data.readBytes(header); // flvのheader情報を取得します。
			appendHeaderBytes(header); // flvのheader情報を書き込ませる。
			// 元に戻しておく。
			data.position = 0; // 元のデータは元にもどしておく。
			flhData = data; // 保存
			Logger.info("flhデータを追記します。");
		}
		/**
		 * flmデータを設定します。
		 * totalsize crc num flvtag1 flvtag2 ...
		 * chunkデータをそのまま追記していきます。
		 */
		public function appendFlmData(data:ByteArray, resetFlg:Boolean = false):Boolean {
			// mediaデータ
			var position:uint = 0;
			var result:Boolean = false;
			data.position = 8;
			var num:int = data.readInt();
			if(resetFlg) {
				Logger.info("リセットします。" + num);
				resetIndex(num); // リセットするのでindexごと復帰させます。
			}
			// flmListのデータがすでに保持済みの場合は、もっているデータなので再処理しない。
			if(flmList[num] != null) {
				Logger.info("追加しようとしたデータはすでにDL済みです。");
				return false;
			}
			// flvのtagサイズを計算(先頭だけ、12バイトのtotalSize crc num付き)
			var size:int = 12 + (data.readInt() & 0x00FFFFFF) + 11 + 4;
			data.position = 0;
			var fragmentData:ByteArray = new ByteArray();
			data.readBytes(fragmentData, 0, size); // データを読み込み保持する。
			while((result = appendFlmFlagment(fragmentData, num)) == false) {
				position = data.position;
				size = (data.readInt() & 0x00FFFFFF) + 11 + 4;
				data.position = position;
				fragmentData = new ByteArray();
				data.readBytes(fragmentData, 0, size);
			}
			return result;
		}
		/**
		 * flmデータを設定します。
		 * 中途データ用
		 * このデータは順番にくるという保証はない。
		 * 違う番号のデータが先行して転送される可能性もあるので、そこも考慮しておきたい。
		 * @return true:flm完成 false:flm中途
		 */
		public function appendFlmFlagment(data:ByteArray, index:int):Boolean {
			if(flmList[index] == null) {
				var flmNum:int = 0; // 保持要素数
				var lowest:int = -1; // 最小番号
				for(var idx:* in flmList) {
					flmNum ++;
					if(lowest == -1) {
						lowest = idx;
					}
					else if(lowest > idx){
						lowest = idx;
					}
				}
				// 要素数が20をこえたら一番古いデータを消す。
				if(flmNum > 20) {
					delete flmList[lowest];
				}
				// 新規データなのでデータを生成します。
				// 8バイト読み込む
				var totalSize:int = data.readInt() + 12;
				if(_crc != data.readInt()) {
					throw new Error("crcが一致しません。");
				}
				var num:int = data.readInt();
				if(num != index) {
					throw new Error("番号が一致しません。");
				}
				flmList[index] = {"size": totalSize, "data": new ByteArray()};
			}
			// 追記すべきデータ(細かいデータがある場合は追記する)
			if(this.index == index) {
				var rawData:ByteArray = new ByteArray();
				data.readBytes(rawData);
				appendDataBytes(rawData);
			}
			// データの保存 // このdataは共有するべきもの。(子接続とかある場合はこのデータを共有にまわす必要あり)
			data.position = 0;
			var flmData:ByteArray = flmList[index]["data"] as ByteArray;
			flmData.writeBytes(data);
			var result:Boolean = (flmData.length == flmList[index]["size"]);
			if(result) {
				// １つのflmデータが完成した場合
				this.index ++; // 次のindexにすすめる。
				// 次のflmデータの準備が進んでいる場合はそのデータを追記する必要あり。
				insertDownloadedData();
			}
			// しばらくデータがきちんと送信されてこなかったら、動作不良ということでいったん殺す必要があると思う。
			return result;
		}
		/**
		 * 処理index番号をクリアします。
		 */
		public function resetIndex(index:int):void {
			this.index = index;
			flmList = [];
		}
		private function insertDownloadedData():void {
			// ダウンロードができなかったら
			// 現在のindexをつかってflmListに残っているデータを追記していく。
			if(flmList[index] == null) {
				// データがなければ、あとで追加されるのでそっちでやってもらう。
				return;
			}
			// データがある場合は中身があるので、その中途の中身をnetStreamに追記してやる必要あり。
			var chunkData:ByteArray = (flmList[index]["data"] as ByteArray);
			// データを読み込んでいく。
			// サイズを取得
			var totalSize:int = chunkData.readInt();
			// crcを取得
			var crc:int = chunkData.readInt();
			// 番号を取得
			var num:int = chunkData.readInt();
			// 以下の部分はあるだけ読み込み実行させる必要がある。
			while(chunkData.length != chunkData.position) {
				// このあとはflvタグデータなので解析して取得していく。
				var position:uint = chunkData.position;
				var size:int = chunkData.readInt() + 11 + 4;
				// chunkデータを読み込む
				chunkData.position = position;
				var fragmentData:ByteArray = new ByteArray();
				chunkData.readBytes(fragmentData, 0, size);
				appendBytes(fragmentData);
			}
			// すべて取得しきったら、indexを元にもどしておく。
			chunkData.position = 0;
			if(chunkData.length == totalSize) {
				// このデータ処理済みになったので、次のindexの処理をやっとく。
				this.index ++;
				insertDownloadedData();
			}
		}
	}
}
