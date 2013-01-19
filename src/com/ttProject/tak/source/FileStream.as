package com.ttProject.tak.source
{
	/**
	 * パソコン上にあるflvファイルをベースにしたストリーム
	 * (未作成)
	 */
	public class FileStream implements ISourceStream {
		
		private var _target:Boolean;
		public function get isTarget():Boolean {
			return _target;
		}
		public function set target(val:Boolean):void {
			_target = val;
		}

		public function FileStream() {
			this._target = false;
		}
		public function hashCode():String {
			return "file:";
		}
		public function start(...parameter):void {
			
		}
	}
}