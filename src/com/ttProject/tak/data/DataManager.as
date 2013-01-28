package com.ttProject.tak.data
{
	import com.ttProject.event.Profile;
	import com.ttProject.tak.Logger;
	import com.ttProject.tak.core.TakStream;
	import com.ttProject.tak.source.HttpStream;
	import com.ttProject.tak.source.ISourceStream;
	import com.ttProject.tak.supply.ISupplyStream;
	import com.ttProject.tak.supply.P2pSupplyStream;
	
	import flash.events.TimerEvent;
	import flash.utils.ByteArray;
	import flash.utils.Timer;

	/**
	 * データを管理します
	 */
	public class DataManager extends Timer {
		// コネクション
		private var source:SourceHolder; // 受信接続
		private var supply:SupplyHolder; // 送信接続
		private var rtmfp:RtmfpHolder; // p2p動作補助

		// メディアデータ
		private var flh:FlhData; // ヘッダーデータ
		private var flmList:FlmDataHolder; // メディアデータ

		private var playedIndex:int; // 動作済みindexデータ保持
		// 元になるtakStreamオブジェクト
		private var stream:TakStream;
		// データソース変更確認時刻保持
		private var lastRestartTime:Number;
		// p2p提供先の数を確認
		public function get supplyCount():int {
			return supply.length;
		}
		// p2p受信元存在確認
		public function get hasP2pSource():Boolean {
			return source.hasP2p;
		}
		public function get hasSource():Boolean {
			return source.hasAny;
		}
		/**
		 * 対象のflmが取得済みであるか確認する。
		 */
		public function checkHasData(index:int):Boolean {
			return flmList.get(index) != null;
		}

		/**
		 * コンストラクタ
		 */
		public function DataManager(stream:TakStream) {
			super(100); // 100ミリ秒単位で動作させておく。
			source = new SourceHolder;
			supply = new SupplyHolder;
			rtmfp  = new RtmfpHolder(this);

			flmList = new FlmDataHolder;
			flh = null; // 始めにflhデータが存在していないはずなので、クリアしておく

			lastRestartTime = -1;

			// 親のstream(データの再生用のstream)を保持しておく。
			this.stream = stream;
			this.addEventListener(TimerEvent.TIMER, onTimerEvent);

			// タイマーとしての動作を開始しておく
			super.start();
		}
		/**
		 * 動作を開始する
		 */
		override public function start():void {
			Logger.info("dataManager.start()");
			// 再生ベースストリームを初期化しておく。
			this.stream.close();
			// 動画開始indexを初期化する。
			playedIndex = -1;
			var stream:ISourceStream = null;
			// rtmpについて調査
/*			stream = source.getSource("rtmp");
			if(stream == null) {
				Logger.info("rtmpはないよ");
			}
			else {
				Logger.info("rtmpのtakStream開始処理はまだつくってないっす。");
			}*/
			// httpについて調査
			stream = source.getSource("http");
			if(stream != null) {
				// httpTakStreamを開始する。
				stream.start(-1);
				this.stream.source = "http";
			}
			// p2pの接続の構築手配しておく。
			try {
				rtmfp.stopConnection();
				rtmfp.startConnection();
			}
			catch(e:Error) {
				Logger.error("error:" + e.message);
			}
		}
		/**
		 * データ元となるurlを追加
		 */
		public function addSource(url:String, name:String):void {
			switch(url.split(":")[0]) {
				case "http":
					addSourceStream("http", new HttpStream(url, this));
					break;
				case "rtmp":
					break;
				case "rtmfp":
					rtmfp.addSource(url, name);
					break;
				default:
					break;
			}
		}
		/**
		 * データ元となるストリームを追加する。
		 */
		public function addSourceStream(name:String, stream:ISourceStream):void {
			source.addSource(name, stream);
		}
		/**
		 * 転送先となるurlを追加
		 */
		public function addSupply(url:String, name:String):void {
			switch(url.split(":")[0]) {
				case "rtmfp":
					rtmfp.addSupply(url, name);
					break;
				default:
					break;
			}
		}
		/**
		 * 供給用のストリームを追加する
		 */
		public function addSupplyStream(stream:ISupplyStream):void {
			supply.addSupply(stream);
		}
		/**
		 * flmDataをうけいれる処理
		 */
		public function setFlmData(data:ByteArray):void {
			// データがそろっている場合は、次の連中にデータを送る必要がある。
			var flm:FlmData = new FlmData(data);
			// DL済みコンテンツ確認
			var oldFlm:FlmData = flmList.get(flm.index);
			if(oldFlm != null) {
				Profile.add("flm", 0, "reget dled data.");
				return;
			}
			// あたらしいデータなのでflmListに登録しておく。
			flmList.add(flm);

			// supplyStream(この時点で孫以下におくって問題ないので、送っておく。)
			supply.flm(flh, flm);

			// 再生indexを確認する。
			if(playedIndex == -1) { // 初動作
				playedIndex = flm.index;
				stream.appendDataBytes(flm.getData());
			}
			else {
				// インデックスが設置済みの場合
				if(flm.index == playedIndex + 1) { // 連番の場合
					stream.appendDataBytes(flm.getData());
					
					// 連番データがすでに受信済みの場合の処置
					playedIndex ++;
					var cachedFlm:FlmData;
					while(true) {
						cachedFlm = flmList.get(playedIndex + 1);
						if(cachedFlm != null) {
							stream.appendDataBytes(cachedFlm.getData());
							playedIndex ++;
						}
						else {
							break;
						}
					}
				}
				else {
					// 連番でもなんでもないが、データが足りなくなっている場合(この処理なくてもtimerで補完されそうだが・・・)
					if(stream.bufferLength < 0.5) {
						Profile.add("flm", 0, "startReliableDLStream by setFlmData");
						Logger.info("dataManager.startReliableDLStream() on setFlmData");
						// のこり時間がなくなってきたので補完するように手配します。
						stream.setup();
						stream.appendHeaderBytes(flh.getData());
						
						// とりあえずhttpStreamで補完を試みる
						startReliableDLStream();
					}
				}
			}
		}
		/**
		 * flhDataを受け入れる処理
		 */
		public function setFlhData(data:ByteArray):void {
			// 解析
			flh = new FlhData(data);
			// rtmfpの提供先に通知
			supply.flh(flh);
			Logger.info("flhがきたので、強制再生成になります。");
			streamSetup();
		}
		/**
		 * 接続時の始めのflhデータを受け入れる動作(rtmfpのみ)
		 */
		public function setInitFlhData(data:ByteArray):void {
			startP2pDLStream();
			// flhデータが存在していない場合のみ、初期化しておく。
			if(flh == null || stream.bufferLength < 0.5) {
				Logger.info("再セットアップします。");
				// 解析
				flh = new FlhData(data);
				streamSetup();
			}
		}
		/**
		 * BaseStreamの初期化補助
		 */
		private function streamSetup():void {
			// 初期化
			flmList = new FlmDataHolder();
			playedIndex = -1;
			stream.setup();
			stream.appendHeaderBytes(flh.getData());
		}
		/**
		 * タイマー処理
		 */
		private function onTimerEvent(event:TimerEvent):void {
			try {
				// 他のオブジェクトのtimer処理を実施させる
				try {
					source.timerEvent();
					supply.timerEvent();
					rtmfp.timerEvent();
				}
				catch(e:Error) {
					Logger.error("他の動作を実行したらエラーでた。:" + e.message);
				}
				// 遅延の確認をして、状態が酷い場合はほぼ確実にデータがとれるストリームで補完してやる
				var length:Number = stream.bufferLength;
				// 開始前の確認(開始前に補完が走ると暴走する)
				if(length == -1 || length > 0.7 || stream.currentFPS == 0) {
					return;
				}
				// 補完動作が多重ではしらないように、補完後１秒は補完を再開しないことにしておく。
				var currentTime:Number = new Date().time;
				if(currentTime < lastRestartTime + 1000) {
					return;
				}
				lastRestartTime = currentTime;

				// データの補完を手配してみる。
				Profile.add("flm", 0, "startReliableDLStream by onTimerEvent");
				Logger.info("dataManager.startReliableDLStream() on onTimerEvent");
				startReliableDLStream();
			}
			catch(e:Error) {
				Logger.error("onTimerEvent(DataManager):" + e.message);
			}
		}
		/**
		 * 信頼できるダウンロードstreamを開始します。
		 */
		private function startReliableDLStream():void {
			// とりあえずp2pは止めます。
			source.disconnectP2pSourceStream();
			var httpStream:HttpStream = source.getSource("http") as HttpStream;
			if(httpStream != null) {
				stream.source = "http";
				httpStream.start(playedIndex);
				return;
			}
			else {
				// p2pしかない場合は、ここであきらめてしまうと、DLがとまりやすくなってしまうので、本当は、ぎりぎりまで我慢する形にした方がいい。
				// なにもない場合はやり直しになります。
				start();
			}
		}
		/**
		 * p2pのダウンロードstreamを開始します。
		 */
		private function startP2pDLStream():void {
			// いままでつかっていたストリームは破棄する。
			var httpStream:ISourceStream = source.getSource("http");
			if(httpStream != null) {
				httpStream.stop();
			}
			// p2pで動作することを宣言する。
			stream.source = "p2p";
		}
	}
}

import com.ttProject.tak.Logger;
import com.ttProject.tak.data.DataManager;
import com.ttProject.tak.data.RtmfpConnection;
import com.ttProject.tak.source.HttpStream;
import com.ttProject.tak.source.ISourceStream;
import com.ttProject.tak.source.P2pSourceStream;
import com.ttProject.tak.supply.ISupplyStream;
import com.ttProject.tak.supply.P2pSupplyStream;

import flash.utils.ByteArray;

/**
 * メディアデータオブジェクト保持クラス
 */
class FlmDataHolder {
	private var _data:Object; // データ保持
	/**
	 * コンストラクタ
	 */
	public function FlmDataHolder() {
		_data = {};
	}
	/**
	 * データを取得する
	 */
	public function get(index:int):FlmData {
		// 指定index番号によるデータの再取得を実施する。
		return _data[index] as FlmData;
	}
	/**
	 * データを設定する。
	 */
	public function add(data:FlmData):void {
		// flmFileの内容を解析して、index番号によるデータの設置を実行しておく。
		_data[data.index] = data;
		// 保持データ数に従ってデータが多すぎる場合はクリアする必要がある。
		var min:int = -1;
		var count:int = 0;
		var key:*;
		for(key in _data) {
			count ++;
			if(min == -1 || min > key) {
				min = key;
			}
		}
		// 保持データが10以上の場合は、古いデータを破棄します。
		if(count > 10) {
			delete _data[min];
		}
	}
}

/**
 * メディアデータ
 */
class FlmData {
	private var _size:int;
	public function get size():int {return _size;}
	private var _crc:int;
	public function get crc():int {return _crc;}
	private var _index:int;
	public function get index():int {return _index;}
	private var _data:ByteArray;
	public function get isComplete():Boolean {return (_size == _data.length - 12);}
	
	/**
	 * コンストラクタ
	 */
	public function FlmData(data:ByteArray) {
		_size	= data.readInt();
		_crc	= data.readInt();
		_index	= data.readInt();
		_data	= data;
	}
	/**
	 * データ追記
	 */
	public function append(data:ByteArray):void {
		// データを追記する。
		_data.position = _data.length;
		_data.writeBytes(data);
	}
	/**
	 * 内部生データ参照(flv部のみ)
	 */
	public function getData():ByteArray {
		var ba:ByteArray = new ByteArray();
		ba.writeBytes(_data, 12, 0);
		ba.position = 0;
		return ba;
	}
	/**
	 * 内部生データ参照(全体)
	 */
	public function getFullData():ByteArray {
		var ba:ByteArray = new ByteArray();
		ba.writeBytes(_data);
		ba.position = 0;
		return ba;
	}
}

/**
 * メディアヘッダーデータ
 */
class FlhData {
	private var _crc:int;
	public function get crc():int {return _crc;}
	private var _data:ByteArray;
	/**
	 * コンストラクタ
	 */
	public function FlhData(data:ByteArray):void {
		_crc = data.readInt();
		_data = data;
	}
	/**
	 * 内部生データ参照(flvのみ)
	 */
	public function getData():ByteArray {
		var ba:ByteArray = new ByteArray();
		ba.writeBytes(_data, 4, 0);
		ba.position = 0;
		return ba;
	}
	/**
	 * 内部生データ参照(全体)
	 */
	public function getFullData():ByteArray {
		var ba:ByteArray = new ByteArray();
		ba.writeBytes(_data);
		ba.position = 0;
		return ba;
	}
}

/**
 * データをうけとる接続保持
 * こっちは参照のみなので正直どうでもよい
 */
class SourceHolder {
	// object["形式"] = "データ"の形で保持させておく。
	// なおp2pだけ複数同時に持てるわけだが・・・どうしよう
	private var _source:Object;
	/**
	 * p2pのストリームがあるかどうか
	 */
	public function get hasP2p():Boolean {
		for(var key:* in _source) {
			if(_source[key] is P2pSourceStream) {
				return true;
			}
		}
		return false;
	}
	public function get hasAny():Boolean {
		for(var key:* in _source) {
			return true;
		}
		return false;
	}
	/**
	 * コンストラクタ
	 */
	public function SourceHolder() {
		_source = {};
	}
	/**
	 * ソースデータの追加
	 */
	public function addSource(name:String, stream:ISourceStream):void {
		_source[name] = stream;
	}
	/**
	 * ソースデータの参照
	 */
	public function getSource(name:String):ISourceStream {
		return _source[name];
	}
	/**
	 * timerの動作
	 */
	public function timerEvent():void {
		for(var key:* in _source) {
			var stream:* = _source[key];
			if(stream is HttpStream) {
				(stream as HttpStream).onTimerDataLoadEvent();
			}
			else if(stream is P2pSourceStream) {
				var p2pSourceStream:P2pSourceStream = (stream as P2pSourceStream);
				if(!p2pSourceStream.connected) {
					// 接続していないと判定された場合は捨てる
					delete _source[key];
				}
				else {
					p2pSourceStream.onTimerEvent();
				}
			}
		}
	}
	/**
	 * p2pのストリームを破棄しておく。
	 */
	public function disconnectP2pSourceStream():void {
		for(var key:* in _source) {
			var stream:* = _source[key];
			if(stream is P2pSourceStream) {
				var p2pSourceStream:P2pSourceStream = (stream as P2pSourceStream);
				p2pSourceStream.stop();
				delete _source[key];
			}
		}
	}
}

/**
 * データを他のユーザーに送る接続保持
 * こっちはきっちりと管理しなければならない。
 */
class SupplyHolder {
	// こちらは単なるArrayで保持
	private var _supply:Array;
	// サイズ参照
	public function get length():int {
		return _supply.length;
	}
	/**
	 * コンストラクタ
	 */
	public function SupplyHolder() {
		_supply = [];
	}
	/**
	 * 提供先の追加
	 */
	public function addSupply(stream:ISupplyStream):void {
		_supply.push(stream);
	}
	/**
	 * timerの動作
	 */
	public function timerEvent():void {
		for(var i:int = 0;i < _supply.length;i ++) {
			(_supply[i] as P2pSupplyStream).onTimerEvent();
		}
	}
	/**
	 * flmデータを送信手配する
	 */
	public function flm(flh:FlhData, flm:FlmData):void {
		var deleteTarget:Array = [];
		var i:int;
		for(i = 0;i < _supply.length;i ++) {
			var stream:ISupplyStream = _supply[i];
			// 接続しているか確認
			if(!stream.connected) {
				deleteTarget.push(i);
			}
			else {
				// header送信済みか確認
				if(!stream.isSendHeader) {
					stream.initFlh(flh.getFullData());
				}
				// データ送信
				stream.flm(flm.getFullData());
			}
		}
		// 存在しなくなったstreamを破棄しておく。
		deleteTarget.reverse();
		for(i = 0;i < deleteTarget.length;i ++) {
			_supply.splice(deleteTarget[i], 1);
		}
	}
	/**
	 * flhデータを送信手配する。
	 */
	public function flh(flh:FlhData):void {
		var deleteTarget:Array = [];
		var i:int;
		for(i = 0;i < _supply.length;i ++) {
			var stream:ISupplyStream = _supply[i];
			// 接続確認
			if(!stream.connected) {
				deleteTarget.push(i);
			}
			else {
				// データ送信
				stream.flh(flh.getFullData());
			}
		}
		// 存在しなくなったstreamを破棄しておく。
		deleteTarget.reverse();
		for(i = 0;i < deleteTarget.length;i ++) {
			_supply.splice(deleteTarget[i], 1);
		}
	}
}

/**
 * rtmfpのコネクション保持
 */
class RtmfpHolder {
	private var _rtmfp:Object;
	private var _dataManager:DataManager;
	private var _startFlg:Boolean;
	/**
	 * コンストラクタ
	 */
	public function RtmfpHolder(dataManager:DataManager) {
		this._rtmfp = {};
		this._dataManager = dataManager;
	}
	/**
	 * 供給用接続として登録する
	 */
	public function addSupply(url:String, name:String):void {
		var key:String = url + "+" + name;
		if(_rtmfp[key] == null) {
			_rtmfp[key] = new RtmfpConnection(url, name, _dataManager, false, true);
			if(_startFlg) {
				(_rtmfp[key] as RtmfpConnection).startConnection();
			}
		}
		else {
			var connection:RtmfpConnection = _rtmfp[key] as RtmfpConnection;
			connection.supply = true;
		}
	}
	/**
	 * 受信用接続として登録する
	 */
	public function addSource(url:String, name:String):void {
		var key:String = url + "+" + name;
		if(_rtmfp[key] == null) {
			_rtmfp[key] = new RtmfpConnection(url, name, _dataManager, true, false);
			if(_startFlg) {
				(_rtmfp[key] as RtmfpConnection).startConnection();
			}
		}
		else {
			var connection:RtmfpConnection = _rtmfp[key] as RtmfpConnection;
			connection.source = true;
		}
	}
	/**
	 * 接続を開始させる。
	 */
	public function startConnection():void {
		_startFlg = true;
		for(var key:* in _rtmfp) {
			(_rtmfp[key] as RtmfpConnection).startConnection();
		}
	}
	/**
	 * 接続を停止させる。
	 */
	public function stopConnection():void {
		_startFlg = false;
		for(var key:* in _rtmfp) {
			(_rtmfp[key] as RtmfpConnection).closeConnection();
		}
	}
	/**
	 * timer動作
	 */
	public function timerEvent():void {
		for(var key:* in _rtmfp) {
			(_rtmfp[key] as RtmfpConnection).onTimerEvent();
		}
	}
}
