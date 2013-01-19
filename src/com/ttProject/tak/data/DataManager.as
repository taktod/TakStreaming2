package com.ttProject.tak.data
{
	import com.ttProject.info.Data;
	import com.ttProject.tak.Logger;
	import com.ttProject.tak.core.TakStream;
	import com.ttProject.tak.source.HttpStream;
	import com.ttProject.tak.source.ISourceStream;
	import com.ttProject.tak.supply.ISupplyStream;
	import com.ttProject.tak.supply.P2pSupplyStream;
	
	import flash.events.EventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.ByteArray;
	import flash.utils.Timer;

	/**
	 * データを管理します。
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
			
			// 親のstream(データの再生用のstream)を保持しておく。
			this.stream = stream;
			this.addEventListener(TimerEvent.TIMER, onTimerEvent);
		}
		/**
		 * 動作を開始する
		 */
		override public function start():void {
			playedIndex = -1;
			this.stream.close();
			var stream:ISourceStream = null;
			// sourceコネクションから接続する相手を決めなくてはいけない。
			// とりあえず、rtmpがある場合はそちらにつなげる。
			stream = source.getSource("rtmp");
			if(stream == null) {
				Logger.info("rtmpはないよ");
			}
			else {
				Logger.info("rtmpのtakStream開始処理はまだつくってないっす。");
//				stream.start(-1);
			}
			// rtmpがなくて、httpがある場合はそっちにつなげる。
			stream = source.getSource("http");
			if(stream == null) {
				Logger.info("httpもないよ");
			}
			else {
				stream.start(-1);
				stream.target = true; // メインダウンロードに指定しておく。
			}
			// p2pの接続の構築手配しておく。
			try {
				rtmfp.stopConnection();
				rtmfp.startConnection();
			}
			catch(e:Error) {
				Logger.error("error:" + e.message);
			}

			// シグナル用のタイマーをスタートさせておく。
			super.start();
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
			if(name == "rtmfp") {
				// rtmfpの接続がきました。
				Logger.info("あたらしい接続がきました。rtmfp");
				// いままでつかっていたストリームは破棄する。
				source.getSource("http").stop();
				// TODO rtmpのことも考慮しておく
			}
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
				return;
			}
			// あたらしいデータなのでflmListに登録しておく。
			flmList.add(flm);
			// supplyStream(この時点で孫以下におくって問題ないので、送っておく。)
			supply.flm(flh, flm);

			if(playedIndex == -1) {
				// 開始前の場合、ここから開始する。
				playedIndex = flm.index;
				stream.appendDataBytes(flm.getData());
			}
			else {
				// インデックスが設置済みの場合
				if(flm.index == playedIndex + 1) { // 今回得たデータが欲しかったデータ
					stream.appendDataBytes(flm.getData());
					// 次のデータがあるか確認して存在できているなら、次のデータも流す。
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
			}
		}
		/**
		 * flhDataを受け入れる処理
		 */
		public function setFlhData(data:ByteArray):void {
			// 初期化
			flmList = new FlmDataHolder();
			playedIndex = -1;
			// 解析
			flh = new FlhData(data);
			// takStream
			stream.setup();
			stream.appendHeaderBytes(flh.getData());
			// supplyStream(p2pへの通信では、headerがきたことは通知する必要がある。 )
			supply.flh(flh);
		}
		/**
		 * 接続時の始めのflhデータを受け入れる動作(rtmfpのみ)
		 */
		public function setInitFlhData(data:ByteArray):void {
			// flhデータが存在していない場合のみ、初期化しておく。
			if(flh == null || stream.bufferLength < 0.5) {
				Logger.info("再セットアップします。");
				// 初期化
				flmList = new FlmDataHolder();
				playedIndex = -1;
				// 解析
				flh = new FlhData(data);
				// takStream処理
				stream.setup();
				stream.appendHeaderBytes(flh.getData());
			}
		}
		/**
		 * タイマー処理
		 */
		private function onTimerEvent(event:TimerEvent):void {
			// GUI処理だが、いまだけここにいれておく。
			var length:Number = stream.bufferLength;
			if(length == -1 || length > 1) {
				// 開始前もしくはデータがまだのこっている場合は、追記読み込み補助は実施しない
				return;
			}
			// データの補完を手配してみる。
			var httpStream:HttpStream = source.getSource("http") as HttpStream;
			if(httpStream == null) {
				// 補完可能なストリームが存在しない。
				start();
				return;
			}
			// データを補完依頼してみる。
			httpStream.spot(playedIndex + 1);
		}
	}
}

import com.ttProject.tak.Logger;
import com.ttProject.tak.data.DataManager;
import com.ttProject.tak.data.RtmfpConnection;
import com.ttProject.tak.source.ISourceStream;
import com.ttProject.tak.supply.ISupplyStream;

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
			min = -1;
			for(key in _data) {
				count ++;
				if(min == -1 || min > key) {
					min = key;
				}
			}
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
	private var source:Object;
	/**
	 * コンストラクタ
	 */
	public function SourceHolder() {
		source = {};
	}
	/**
	 * 
	 */
	public function addSource(name:String, stream:ISourceStream):void {
		source[name] = stream;
	}
	/**
	 * 
	 */
	public function getSource(name:String):ISourceStream {
		return source[name];
	}
}

/**
 * データを他のユーザーに送る接続保持
 * こっちはきっちりと管理しなければならない。
 */
class SupplyHolder {
	private var supply:Array;
	public function SupplyHolder() {
		supply = [];
	}
	public function addSupply(stream:ISupplyStream):void {
		supply.push(stream);
	}
	/**
	 * flmデータを送信手配する
	 */
	public function flm(flh:FlhData, flm:FlmData):void {
		var deleteTarget:Array = [];
		var i:int;
		for(i = 0;i < supply.length;i ++) {
			var stream:ISupplyStream = supply[i];
			// 接続しているか確認
			if(!stream.connected) {
				// 切断しているので破棄queueに追加
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
			supply.splice(deleteTarget[i], 1);
		}
	}
	/**
	 * flhデータを送信手配する。
	 */
	public function flh(flh:FlhData):void {
		var deleteTarget:Array = [];
		var i:int;
		for(i = 0;i < supply.length;i ++) {
			var stream:ISupplyStream = supply[i];
			// 接続確認
			if(!stream.connected) {
				// 切断しているデータがあれば破棄手配
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
			supply.splice(deleteTarget[i], 1);
		}
	}
}

/**
 * rtmfpのコネクション保持
 */
class RtmfpHolder {
	private var rtmfp:Object;
	private var dataManager:DataManager;
	private var startFlg:Boolean;
	/**
	 * コンストラクタ
	 */
	public function RtmfpHolder(dataManager:DataManager) {
		rtmfp = {};
		this.dataManager = dataManager;
	}
	/**
	 * 供給用接続として登録する
	 */
	public function addSupply(url:String, name:String):void {
		var key:String = url + "+" + name;
		if(rtmfp[key] == null) {
			rtmfp[key] = new RtmfpConnection(url, name, dataManager, false, true);
			if(startFlg) {
				(rtmfp[key] as RtmfpConnection).startConnection();
			}
		}
		else {
			var connection:RtmfpConnection = rtmfp[key] as RtmfpConnection;
			connection.supply = true;
		}
	}
	/**
	 * 受信用接続として登録する
	 */
	public function addSource(url:String, name:String):void {
		var key:String = url + "+" + name;
		if(rtmfp[key] == null) {
			rtmfp[key] = new RtmfpConnection(url, name, dataManager, true, false);
			if(startFlg) {
				(rtmfp[key] as RtmfpConnection).startConnection();
			}
		}
		else {
			var connection:RtmfpConnection = rtmfp[key] as RtmfpConnection;
			connection.source = true;
		}
	}
	/**
	 * 接続を開始させる。
	 */
	public function startConnection():void {
		startFlg = true;
		for(var key:* in rtmfp) {
			(rtmfp[key] as RtmfpConnection).startConnection();
		}
	}
	/**
	 * 接続を停止させる。
	 */
	public function stopConnection():void {
		startFlg = false;
		for(var key:* in rtmfp) {
			(rtmfp[key] as RtmfpConnection).closeConnection();
		}
	}
}
