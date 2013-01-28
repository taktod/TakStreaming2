package com.ttProject.tak.source
{
	import com.ttProject.event.Profile;
	import com.ttProject.tak.Logger;
	import com.ttProject.tak.data.DataManager;
	
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;

	/**
	 * http経由でデータをダウンロードします。
	 * 対象はflf flh flmの３ファイル
	 * 
	 * やることは２つ
	 * 連番ダウンロード
	 * ・flfファイルをダウンロード後、flh、flmファイルをダウンロードすることでストリーミングをさせる。
	 * スポットダウンロード(今回はこれを追加する必要がある。)
	 * ・目標のファイルが存在するかflfファイルをダウンロードして調べる。
	 * 存在している場合はそれをダウンロードする。
	 */
	public class HttpStream implements ISourceStream {
		private var isSequence:Boolean; // シーケンスモードかどうか？
		private var targetIndex:int; // 処理対象indexデータ保持
		private var isLoadMedia:Boolean; // 今回のflfダウンロードでmediaをロードしたかどうか

		// データの管理はサブクラスにさせる。
		private var flfFile:String; // 処理用flfファイル設定
		private var flhFile:String; // flhFile(更新時に読み込みheaderファイル)
		private var flmList:FlmList;
		
		private var passedIndex:int; // 最終処理index
		private var _target:Boolean;
		public function get isTarget():Boolean {
			return _target;
		}
		public function set target(val:Boolean):void {
			_target = val;
		}

		private var dataManager:DataManager;
		private var inTask:Boolean; // タスク中の場合はtrue
		private var lastDlTime:Number;
		/**
		 * コンストラクタ
		 */
		public function HttpStream(url:String, dataManager:DataManager) {
			this._target = false;
			this.flfFile = url;
			this.flmList = new FlmList();
			this.passedIndex = 0;
			this.dataManager = dataManager;
			this.inTask = true;
		}
		/**
		 * 動作を停止させます。
		 */
		public function stop():void {
			isSequence = false;
			// すでに実行しているダウンロードをキャンセルできるならしたほうがよい(たぶんできないし、できてもタスク管理が面倒になりそう)
		}
		/**
		 * ダウンロードを開始する
		 * startIndexで指定したindexからシーケンスダウンロードをすすめたいときのやりかた。
		 */
		public function start(... parameter):void {
			stop(); // いったん停止してから開始します。
			// 開始indexデータを参照
			var startIndex:int = parameter[0];
			isSequence  = true; // 連番DLモード
			targetIndex = startIndex; // 処理すべきindex記録
			if(startIndex == -1) { // 新規DLの場合
				passedIndex = -1; // 処理済みindex保持
			}
			this.inTask = true; // タスク中に切り替える
			this.lastDlTime = new Date().time; // 最終処理時刻を現在時刻にしておく。
			// flfのDLから開始
			downloadText(flfFile, function(data:String):void {
				analizeFlfFile(data);

				// 開始処理を実施する。
				if(targetIndex != -1) {
					// indexが固定されている場合はそのindexがデータにあるか確認する。
					var flmObject:FlmObject = flmList.get(targetIndex);
					if(flmObject != null) { // データがあった場合
						// データがある場合はそのデータからデータをダウンロードするようにする。
						// flfファイル上でのダウンロード開始indexがどこであるか管理する必要がある。(ただしくシーケンスダウンロードするために必要。)
						passedIndex = flmList.getAbsPos(targetIndex);
					}
					else {
						passedIndex = -1;
					}
				}
				if(passedIndex == -1) {
					// 開始位置が決定しないので、flmListからデフォルトの開始位置をもらう。
					passedIndex = flmList.getDefaultStartAbsPos();
				}
				Logger.info("passedIndex:" + passedIndex);
				if(startIndex != -1) {
					loadSegment(); // 中途indexから再開する場合は、そのままflmデータにうつる
				}
				else { // 初期DLの場合はflhからやりなおす
					downloadBinary(flhFile, function(data:ByteArray):void {
						Logger.info("初期DL開始なのでflhを手始めにDLします。");
						dataManager.setFlhData(data);
						loadSegment();
					});
				}
			});
		}
		/**
		 * タイマーで動作するデータのダウンロード処理
		 */
		public function onTimerDataLoadEvent():void {
			// task処理中もしくは連番DLでない場合は処理しない
			if(inTask || !isSequence) {
				return;
			}
			// 最終DLからある程度経ってから次のどうさにもっていきます。
			// 数値をあげるとDLすべき回数はへるけど、リアルタイム性が犠牲になります。
			if(lastDlTime + 500 > new Date().time) {
				return;
			}
			lastDlTime = new Date().time;
			
			inTask = true; // タスク中に変更する。
			// とりあえずflfの確認からはじめる
			downloadText(flfFile, function(data:String):void {
				analizeFlfFile(data);
				loadSegment();
			});
		}
		/**
		 * 内部の個々のセグメントをダウンロードしていきます。
		 */
		private function loadSegment():void {
			// 次のデータをDLしようとする。
			var flmObject:FlmObject = flmList.getAbs(passedIndex);
			if(flmObject == null) {
				inTask = false;
			}
			else {
				isLoadMedia = true;
				// 普通にDLできる場合はDLする
				if(flmObject.resetFlg) {
					// headerからDLやり直す必要あり。
					downloadBinary(flhFile, function(data:ByteArray):void {
						Logger.info("中途でresetFlgがあったのでflhをダウンロードします。");
						// flhデータを取得することができたので、次の段階にすすむ。
						dataManager.setFlhData(data);
						if(dataManager.checkHasData(flmObject.index)) {
							// すでに対象のデータは保持済み(メインストリームでも発生する可能性があるっぽい。)
							passedIndex = flmList.getAbsPos(flmObject.index) + 1;
							loadSegment();
							return;
						}
						downloadBinary(flmObject.file, function(data:ByteArray):void {
							passedIndex = flmList.getAbsPos(flmObject.index) + 1;
							dataManager.setFlmData(data);
							loadSegment();
						});
					});
				}
				else {
					if(dataManager.checkHasData(flmObject.index)) {
						// すでに対象のデータは保持済み(メインストリームでも発生する可能性があるっぽい。)
//						Logger.info("保持済みのデータのDLを実行しようとした");
						passedIndex = flmList.getAbsPos(flmObject.index) + 1;
						loadSegment();
						return;
					}
					downloadBinary(flmObject.file, function(data:ByteArray):void {
						dataManager.setFlmData(data);
						passedIndex = flmList.getAbsPos(flmObject.index) + 1;
						loadSegment();
					});
				}
			}
		}
		/**
		 * 特定のindexのデータをダウンロードして補完する。
		 * /
		public function spot(index:int):void {
			if(inTask) {
				// 別件でhttpStreamが起動中なら、動作させない。
				return;
			}
			inTask = true;
			isSequence = false;
			targetIndex = index;
			// 特定のindexのみダウンロードします。
			// すでにDL済みのデータ内にあるか確認
			var flmObject:FlmObject = flmList.get(index);
			if(flmObject != null) {
				// ダウンロードして、おくっておく。
				downloadBinary(flmObject.file, function(data:ByteArray):void {
					dataManager.setFlmData(data);
					inTask = false;
				});
			}
			else {
				// flfファイルをダウンロードする。
				downloadText(flfFile, function(data:String):void {
					// 解析しておく
					analizeFlfFile(data);
					// リスト上に目的のindexがあればダウンロードする。
					flmObject = flmList.get(index);
					if(flmObject != null) {
						downloadBinary(flmObject.file, function(data:ByteArray):void {
							dataManager.setFlmData(data);
							inTask = false;
						});
					}
					else {
						// flfからデータが取得できなかった場合はどうしようもないのでやり直して再生する方向にもっていく。
						Logger.info("flfのデータ取得失敗しました。");
//						dataManager.start();
					}
				});
			}
		}
		/**
		 * flhファイルのデータを取得する動作
		 * 外部からflhデータのみ欲しいときに呼び出される動作です。
		 * (未実装)
		 * /
		public function header():void {
			// 現行のflhデータを調べて、取得する。
			// とりあえず最新のデータが欲しいので、強制取得にしておく。
			downloadText(flfFile, function(data:String):void {
				analizeFlfFile(data);
				if(flhFile != null) {
					// データがあるので、ダウンロードしてDataManagerに送り込んでおく。
				}
			});
		}
		/**
		 * flfFileの中身を解析します。
		 */
		private function analizeFlfFile(data:String):void {
			this.isLoadMedia = false;
			var lines:Array = data.split("\n");
			var resetFlg:Boolean = false;
			for(var i:int = 0;i <lines.length;i ++) {
				var line:String = lines[i];
				switch(line.split(":")[0]) {
					case "#FLF_EXT":
						// flfデータである。
						flmList = new FlmList();
						break;
					case "#FLF_COUNTER":
						// カウンターを保持しておきます。
						flmList.setCounter(parseInt(line.split(":")[1]));
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
						this.flmList.add(new FlmObject(parseFloat(line.split(":")[1]), lines[i], resetFlg));
						resetFlg = false;
						break;
				}
			}
		}
		/**
		 * テキストデータをダウンロードする。
		 */
		private function downloadText(target:String, task:Function):void {
			var loader:URLLoader = new URLLoader;
			loader.dataFormat = URLLoaderDataFormat.TEXT;
			var id:int = Profile.add("dlText", new Date().time, target);
			loader.addEventListener(Event.COMPLETE, function(event:Event):void {
				Profile.update(id, null, (new Date().time - Profile.getValue(id)), null);
				task(loader.data as String);
			});
			download(loader, target, id);
		}
		/**
		 * バイナリデータをダウンロードする。
		 */
		private function downloadBinary(target:String, task:Function):void {
			var loader:URLLoader = new URLLoader;
			loader.dataFormat = URLLoaderDataFormat.BINARY;
			var id:int = Profile.add("dlBinary", new Date().time, target);
			loader.addEventListener(Event.COMPLETE, function(event:Event):void {
				Profile.update(id, null, (new Date().time - Profile.getValue(id)), null);
				task(loader.data as ByteArray);
			});
			download(loader, target, id);
		}
		/**
		 * ダウンロードの共通処理
		 */
		private function download(loader:URLLoader, target:String, id:int):void {
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function(event:SecurityErrorEvent):void {
				Logger.info("securityエラー発生");
				Profile.update(id, "dlSecurityFailed", (new Date().time - Profile.getValue(id), null));
				inTask = false;
			});
			loader.addEventListener(IOErrorEvent.IO_ERROR, function(event:IOErrorEvent):void {
				Logger.info("IO_ERRORエラー発生");
				Profile.update(id, "dlIOFailed", (new Date().time - Profile.getValue(id), null));
				inTask = false;
			});
			try {
				var request:URLRequest = new URLRequest(target + "?" + (new Date()).getTime());
				loader.load(request);
			}
			catch(e:Error) {
				Logger.info("error on downloadData:" + e.toString());
			}
		}
		public function hashCode():String {
			return "http:";
		}
	}
}
import com.ttProject.tak.Logger;

/**
 * 現在flfファイルに記述されているflmDataリスト
 */
class FlmList {
	private var list:Object;
	private var flfCounter:int;
	private var startIndex:int;
	private var endIndex:int;
	/**
	 * コンストラクタ
	 */
	public function FlmList() {
		list = {};
	}
	/**
	 * flmデータの追加処理
	 */
	public function add(object:FlmObject):void {
		// ここは範囲計算ではなく、確実に順番にデータがきていると考えた方がよさそう。(中途でflipする可能性も考えておく。)
		/*
		counter:30135
		1935 30135
		1936 30136
		1937 30137
		1 30138
		2 30139
		3 30140
		4 30141
		1 30142
		2 30143
		3 30144
		というデータがある場合は1〜3の3データのみもっていると解釈すべき。
		かならず1からになるとも限らないところがポイント
		*/
		if(object.resetFlg || startIndex == -1) {
			// flfCounterの位置をずらしておく。
			if(endIndex != -1) {
				// flfのカウンターをリセットするのは、endIndexが-1でない状態で入れ替えがあった場合
				flfCounter = getAbsPos(endIndex) + 1;
			}
			// データがいれかわる場合は・・・
			// シーケンスのスタート位置もずらしておく必要あり。
			startIndex = object.index;
			endIndex = object.index;
			list = {};
		}
		if(endIndex < object.index || endIndex == -1) {
			endIndex = object.index;
		}
		list[object.index] = object;
	}
	/**
	 * flmデータの参照処理
	 */
	public function get(index:int):FlmObject {
		return list[index] as FlmObject;
	}
	/**
	 * flfファイル内でのカウンター番号を設定しておく。
	 */
	public function setCounter(counter:int):void {
		flfCounter = counter;
		startIndex = -1;
		endIndex = -1;
	}
	/**
	 * flfファイル上の絶対位置からデータを抜き出す。
	 * flfCounter = 391212
	 * index = 391213
	 * startIndex = 2270
	 * startIndex + index - flfCounter;
	 */
	public function getAbs(absIndex:int):FlmObject {
		return list[(absIndex + startIndex - flfCounter)] as FlmObject;
	}
	/**
	 * flfファイル上の絶対位置を計算する。
	 * flfCounter = 391212
	 * index = 2271
	 * startIndex = 2270
	 * 2271 -> 391213を求める。
	 * index - startIndex + flfCounter;
	 */
	public function getAbsPos(index:int):int {
		return (index - startIndex + flfCounter);
	}
	/**
	 * 開始する場合に推奨される開始位置の取得
	 */
	public function getDefaultStartAbsPos():int {
		return getAbsPos(getDefaultStartPos());
	}
	/**
	 * 開始する場合に推奨される開始位置の取得
	 */
	public function getDefaultStartPos():int {
		var index:int = endIndex; // 適当な開始位置を指定する。
		if(index < startIndex) {
			index = startIndex;
		}
		return index;
	}
	/**
	 * flfデータがすすみすぎているか確認する。
	 * flfデータが先にすすんでいる場合は待機しても、続きのデータが絶対にこないのではじめからやり直す必要がある。
	 * 最終インデックスを計算して最終インデックスの場合は待つ必要なし。
	 * 最終インデックスでない場合は、やりなおし
	 */
	public function checkNeedRestart(absIndex:int):Boolean {
		// リロードされると暴走するか？
		return absIndex < flfCounter;
	}
	/**
	 * 内部情報を確認
	 * toStringを実装すれば必要ないか？
	 */
	public function checkInfo(absIndex:int):void {
		Logger.info("checkNeedRestart:" + absIndex + ":" + flfCounter);
	}
	/**
	 * 文字列化するためのサポート関数
	 */
	public function toString():String {
		var data:String = "" + flfCounter;
		var i:int = 0;
		for(var key:String in list) {
			data += ":" + list[key] + "\n";
			i ++;
		}
		return data;
	}
}

/**
 * 個々のflmデータ
 */
class FlmObject {
	// 各パラメーターはコンストラクタで設定してしまうので、参照のみ許可しておく。
	private var _duration:Number;
	public function get duration():Number {return _duration;}
	private var _file:String;
	public function get file():String {return _file;}
	private var _resetFlg:Boolean;
	public function get resetFlg():Boolean {return _resetFlg;}
	private var _index:int;
	public function get index():int {return _index;}

	/**
	 * コンストラクタ
	 */
	public function FlmObject(duration:Number, file:String, resetFlg:Boolean = false) {
		this._file = file;
		this._duration = duration;
		this._resetFlg = resetFlg;
		var pattern:RegExp = /(\d+)\.flm$/;
		var obj:Object = pattern.exec(file);
		this._index = parseInt(obj[1]);
	}
	/**
	 * 文字列化
	 */
	public function toString():String {
		return "{i:" + index + " d:" + duration + " f:" + file + " r:" + resetFlg + "}\n";
	}
}
