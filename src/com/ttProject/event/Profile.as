package com.ttProject.event
{
	import flash.desktop.Clipboard;
	import flash.desktop.ClipboardFormats;

	/**
	 * Flexのイベントをプロファイルして、どうなっているか確認するための動作
	 */
	public class Profile {
		private static var dataManager:DataManager = new DataManager();
		public static var saveProfile:Boolean = true;
		/**
		 * プロファイルイベントを加える
		 */
		public static function add(type:String, val:int, note:String=""):int {
			if(!saveProfile) {
				return 1;
			}
			return dataManager.makeData(type, val, note);
		}
		public static function getValue(id:int):int {
			if(!saveProfile) {
				return 1;
			}
			return dataManager.getValue(id);
		}
		/**
		 * プロファイルデータを更新する
		 */
		public static function update(id:int, type:String, val:int, note:String=""):void {
			if(!saveProfile) {
				return;
			}
			dataManager.updateData(id, type, val, note);
		}
		public static function getData():String {
			if(!saveProfile) {
				return null;
			}
			return dataManager.getRawData();
		}
		public static function copyToClipBoard():void {
			if(!saveProfile) {
				return;
			}
			var clipboard:Clipboard = Clipboard.generalClipboard;
			clipboard.setData(ClipboardFormats.TEXT_FORMAT, dataManager.getRawData());
		}
		public static function setData(data:String):void {
			if(!saveProfile) {
				return;
			}
			dataManager.setRawData(data);
		}
		public static function getAnalizeData(interval:int):Array {
			if(!saveProfile) {
				return [];
			}
			return dataManager.calculateData(interval);
		}
	}
}