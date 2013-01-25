package com.ttProject.info
{
	import com.ttProject.tak.core.TakStream;
	
	import flash.net.NetStream;
	
	import mx.controls.DataGrid;

	/**
	 * dataGridにデータを表示するための処理
	 */
	public class Data
	{
		private static var dataGrid:DataGrid;
		/**
		 * セットアップ
		 */
		public static function setup(dataGuid:DataGrid):void {
			Data.dataGrid = dataGuid;
		}
		/**
		 * 表示更新
		 */
		public static function update(ns:NetStream):void {
			if(ns == null) {
				dataGrid.dataProvider = [
					{"name":"bufferLength", "value":"-"},
					{"name":"bufferTime",   "value":"-"},
					{"name":"bytesLoaded",  "value":"-"},
					{"name":"fps",          "value":"-"},
					{"name":"volume",       "value":"-"},
					{"name":"time",         "value":"-"},
					{"name":"delay",        "value":"-"},
					{"name":"audioCodec",   "value":"-"},
					{"name":"videoCodec",   "value":"-"},
					{"name":"source",       "value":"-"}
				];
			}
			else {
				dataGrid.dataProvider = [
					{"name":"bufferLength", "value":ns.bufferLength.toString()},
					{"name":"bufferTime",   "value":ns.bufferTime},
					{"name":"bytesLoaded",  "value":ns.bytesLoaded},
					{"name":"fps",          "value":ns.currentFPS},
					{"name":"volume",       "value":ns.soundTransform.volume},
					{"name":"time",         "value":ns.time},
					{"name":"delay",        "value":ns.liveDelay},
					{"name":"audioCodec",   "value":ns.audioCodec},
					{"name":"videoCodec",   "value":ns.videoCodec},
					{"name":"source",       "value":(ns as TakStream).source}
				];
			}
		}
	}
}