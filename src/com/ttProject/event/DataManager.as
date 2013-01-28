package com.ttProject.event
{
	/**
	 * プロファイル用のデータ保持マネージャー
	 * ぶっちゃけていうとmodel
	 */
	public class DataManager {
		private var eventList:DataList;
		private var changed:Boolean;
		private var interval:int;
		private var calculateResult:Array;
		/**
		 * コンストラクタ
		 */
		public function DataManager() {
			eventList = new DataList();
			changed = true;
			interval = -1;
		}
		/**
		 * データを生成する。
		 */
		public function makeData(type:String, val:int, note:String):int {
			changed = true;
			var data:Data = new Data(type, val, note);
			eventList.push(data);
			if(eventList.length > 10000) {
				eventList.shift();
			}
			return data.id;
		}
		public function updateData(id:int, type:String, val:int, note:String):void {
			changed = true;
			// IDから対象のデータを取得し直す。
			var data:Data = eventList.getData(id);
			if(type != null) {
				data.type = type;
			}
			if(val != -1) {
				data.value = val;
			}
			if(note != null) {
				data.note = note;
			}
		}
		public function getValue(id:int):int {
			changed = true;
			var data:Data = eventList.getData(id);
			if(data != null) {
				return data.value;
			}
			else {
				return 0;
			}
		}
		public function getRawData():String {
			return eventList.toString();
		}
		public function setRawData(data:String):void {
			changed = true;
			var pattern:RegExp = /\[tic:(\d+),type:([^,]+),val:(\d+),note:([^\]]*)\]/gm;
			var matches:Array;
			while((matches = pattern.exec(data)) != null) {
				eventList.push(new Data(matches[2], parseInt(matches[3]), matches[4], matches[1]));
			}
		}
		/**
		 * 内部データを計算する
		 */
		public function calculateData(interval:int):Array {
			if(interval <= 0) {
				throw new Error("負の数で計算はできません。");
			}
			// 前回の検索と判定値が違う場合は計算しなおし
			if(this.interval != interval) {
				changed = true;
			}
			// データの変更があるなら計算する。
			if(changed) {
				// データを検索していって、interval中のvalueの最大値 最小値 平均 合計 要素数をいれていく。
				// 配列にしたい。
				var list:Array = eventList.orglist;
				var result:Array = [];
				var timePos:int = 0;
				var absTime:uint = 0;
				var min:int = -1;
				var max:int = 0;
				var total:int = 0;
				var num:int = 0;
				for(var i:int = 0;i < eventList.length;i ++) {
					var data:Data = list[i] as Data;
					// 時間がどうなっているか確認する
					// このデータの絶対時刻を取得する
					absTime += data.tic;
					while(absTime > timePos + interval) {
						if(min == -1) {
							min = 0;
						}
						result.push({interval:timePos, min:min, max:max, total:total, avg:(num != 0 ? total/num : 0), num:num});
						timePos += interval;
						min = -1;
						max = 0;
						total = 0;
						num = 0;
					}
					if(min > data.value || min == -1) {
						min = data.value;
					}
					if(max < data.value) {
						max = data.value;
					}
					total += data.value;
					num ++;
				}
				result.push({interval:timePos, min:min, max:max, total:total, avg:(num != 0 ? total/num : 0), num:num});
				// objectのarrayにすればよい。
				changed = false;
				calculateResult = result;
			}
			return calculateResult;
		}
	}
}

/**
 * データ保持
 */
class DataList {
	private var list:Array;
	public function get length():uint {
		return list.length;
	}
	public function DataList() {
		list = [];
	}
	public function push(data:Data):uint {
		var num:uint = list.push(data);
		list["v" + data.id] = data;
		return num;
	}
	public function getData(id:int):Data {
		return list["v" + id] as Data;
	}
	public function shift():Data {
		var data:Data = list.shift() as Data;
		delete list["v" + data.id];
		return data;
	}
	public function pop():Data {
		var data:Data = list.pop() as Data;
		delete list["v" + data.id];
		return data;
	}
	public function toString():String {
		return list.toString();
	}
	public function get orglist():Array {
		return list;
	}
}
/**
 * プロファイルデータ
 */
class Data {
	private static var lastTime:Number = -1;
	private static var nextId:int = 0;
	private var _id:int;
	private var _tic:int;
	private var _type:String;
	private var _value:int;
	private var _note:String;
	public function get id():int {
		return _id;
	}
	public function get tic():int {
		return _tic;
	}
	public function get type():String {
		return _type;
	}
	public function set type(val:String):void {
		_type = val;
	}
	public function get value():int {
		return _value;
	}
	public function set value(val:int):void {
		_value = val;
	}
	public function get note():String {
		return _note;
	}
	public function set note(val:String):void {
		_note = val;
	}
	public function Data(type:String, value:int, note:String, tic:int=-1) {
		_id = nextId ++;
		if(tic == -1) {
			if(Data.lastTime == -1) {
				_tic = 0;
				Data.lastTime = new Date().time;
			}
			else {
				var now:Number = new Date().time;
				_tic = now - Data.lastTime;
				Data.lastTime = now;
			}
		}
		else {
			_tic = tic;
		}
		_type = type;
		_value = value;
		_note = note;
	}
	public function toString():String {
		return "\n[tic:" + tic + ",type:" + type + ",val:" + value + ",note:" + note + "]";
	}
}