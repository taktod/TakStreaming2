package com.ttProject.tak.http
{
	import com.ttProject.info.Logger;
	import com.ttProject.tak.rtmfp.RtmfpTakStream;
	
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	/**
	 * httpからデータをうけとる動作
	 */
	public class HttpTakStream extends RtmfpTakStream {
		private var loadingFlg:Boolean; // 処理中管理フラグ
		private var flfFile:String; // flfFile(リロードを繰り返すindexデータ)
		private var flhFile:String; // flhFile(更新時に読み込みheaderファイル)
		private var flmFiles:Array; // flfFile内に定義されているflmFileリスト
		private var loadIndex:int;   // flfFile上の先頭index
		private var passedIndex:int; // 最終処理index
		// timer関連
		private var interval:int = 400;
		private var timer:Timer = null;
		public function HttpTakStream(url:String, stream:String, p2p:String, subp2p:String) {
			super(stream, p2p, subp2p);
			this.flfFile = url;
			this.loadingFlg = false;
			this.flmFiles = [];
			this.passedIndex = 0;
		}
		/**
		 * flfFileの中身を解析します。
		 */
		private function analizeFlfFile(data:String):void {
			flmFiles = [];
			var lines:Array = data.split("\n");
			var resetFlg:Boolean = false;
			if(data.length < 20) {
				Logger.info("読み込みトライ");
				Logger.info(data);
			}
			// TODO 先頭が#FLF_EXTであることを確認する。
			for(var i:int = 0;i <lines.length;i ++) {
				var line:String = lines[i];
				switch(line.split(":")[0]) {
					case "#FLF_COUNTER":
						// カウンターを保持しておきます。
						loadIndex = parseInt(line.split(":")[1]);
						break;
					case "#FLF_RESET":
						// 次のデータがリセット前提になっていることがわかる。
						resetFlg = true;
						break;
					case "#FLF_HEADER": // flhFile指定
						resetFlg = false;
						i ++;
						this.flhFile = lines[i];
						break;
					case "#FLF_DATA": // flmFile指定
						i ++;
						this.flmFiles.push({"duration":parseFloat(line.split(":")[1]), "file":lines[i], "resetFlg":resetFlg});
						resetFlg = false;
						break;
				}
			}
		}
		/**
		 * 放送の実施
		 */
		override public function play(... parameters):void {
			close();
			// ターゲットのurlのデータをダウンロードトライします。
			onTimerEvent(null);
			// 読み込みがおわったらタイマーをつくっておいて、イベントを処理させる。
			timer = new Timer(interval);
			timer.addEventListener(TimerEvent.TIMER, onTimerEvent);
			timer.start();
		}
		/**
		 * 閉じる処理
		 */
		override public function close():void {
			if(timer != null) {
				timer.stop();
				timer = null;
				loadingFlg = false;
				this.passedIndex = 0;
			}
			super.close();
		}
		/**
		 * タイマー処理
		 */
		private function onTimerEvent(event:TimerEvent):void {
			if(loadingFlg) { // 別の前のイベントが処理中だったら処理しない。
				return;
			}
			loadingFlg = true;
			// timerイベントの先頭では、flfファイルを読み込む
			downloadText(flfFile, function(data:String):void {
				// 中身を解析する。
				analizeFlfFile(data);
				var needReset:Boolean = false;
				
				// 連続しているデータをうけとっているか確認
				if(passedIndex == 0 || passedIndex + 1 < loadIndex || passedIndex > loadIndex + flmFiles.length) {
					// 2パケット分delayを取らせる
//					passedIndex = loadIndex + flmFiles.length - 2; // 最終indexの２つ前から(2つのファイルを読み込む)
					passedIndex = loadIndex + flmFiles.length - 3; // 最終indexの３つ前から(2つのファイルを読み込む)
					needReset = true;
				}
				// 現在のpassedIndex以降にresetがあるか確認して、そこまでpassedIndexをすすめる。
				var min:int = passedIndex - loadIndex;
				for(var i:int = flmFiles.length - 1;i > min; i --) {
					// resetフラグを感知した場合はそこにポジションを移す必要がある。
					if(flmFiles[i]["resetFlg"]) {
						passedIndex = i + loadIndex - 1;
						needReset = false;
						break;
					}
				}
				// resetする必要があるデータはあって１つなので、フラグがあったら、記録しておく。
				if(needReset) {
					flmFiles[i + 1]["resetFlg"] = true;
				}
				loadSegmentData(); // 読み込み開始
				return;
			});
		}
		/**
		 * セグメントデータの読み込みを実行します。
		 */
		private function loadSegmentData():void {
			// flfファイル上に読み込みたいデータがあるか確認する。
			if(flmFiles[(passedIndex - loadIndex + 1)] == null) {
				loadingFlg = false;
				return;
			}
			// resetFlgが付いているか確認
			if(flmFiles[(passedIndex - loadIndex + 1)]["resetFlg"]) {
				// resetするのでヘッダーデータを更新する。
				downloadBinary(flhFile, function(data:ByteArray):void{
					// TODO 何番のindexでリセットさせるという情報を持つ必要がある。
					appendFlhData(data);
					// メディア実体を読み込む
					loadMediaDetail();
				});
			}
			else {
				// メディア実体を読み込む
				loadMediaDetail();
			}
		}
		/**
		 * flmファイル読み込み部分
		 */
		private function loadMediaDetail():void {
			passedIndex ++;
			var flmFile:Object = flmFiles[passedIndex - loadIndex];
			downloadBinary(flmFile["file"], function(data:ByteArray):void{
				try {
					appendFlmData(data, flmFile["resetFlg"]);
				}
				catch(e:Error) {
					Logger.info("reset:" + e.toString());
				}
				loadSegmentData();
			});
		}
		/**
		 * テキストデータをダウンロードする。
		 */
		private function downloadText(target:String, task:Function):void {
			var loader:URLLoader = new URLLoader;
			loader.dataFormat = URLLoaderDataFormat.TEXT;
			loader.addEventListener(Event.COMPLETE, function(event:Event):void {
				task(loader.data as String);
			});
			download(loader, target);
		}
		/**
		 * バイナリデータをダウンロードする。
		 */
		private function downloadBinary(target:String, task:Function):void {
			var loader:URLLoader = new URLLoader;
			loader.dataFormat = URLLoaderDataFormat.BINARY;
			loader.addEventListener(Event.COMPLETE, function(event:Event):void {
				task(loader.data as ByteArray);
			});
			download(loader, target);
		}
		/**
		 * ダウンロードの共通処理
		 */
		private function download(loader:URLLoader, target:String):void {
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function(event:SecurityErrorEvent):void {
				Logger.info("securityエラー発生");
			});
			loader.addEventListener(IOErrorEvent.IO_ERROR, function(event:IOErrorEvent):void {
				Logger.info("IO_ERRORエラー発生");
			});
			try {
				var request:URLRequest = new URLRequest(target + "?" + (new Date()).getTime());
				loader.load(request);
			}
			catch(e:Error) {
				Logger.info("error on downloadData:" + e.toString());
			}
		}
		override protected function test():void {
			Logger.info("http");
		}
	}
}