package com.ttProject.info
{
	import spark.components.TextArea;

	/**
	 * 仮表示用のロガー
	 */
	public class Logger {
		private var field:TextArea = null;
		public const OFF:int	= 0;
		public const ERROR:int	= 1;
		public const WARN:int	= 2;
		public const INFO:int	= 3;
		public const DEBUG:int	= 4;
		private var level:int	= INFO;
		/**
		 * コンストラクタ
		 */
		public function Logger(field:TextArea) {
			this.field = field;
		}
		public function setLevel(level:int):void {
			this.level = level;
		}
		public function error(msg:String):void {
			write(msg, ERROR);
		}
		public function warn(msg:String):void {
			write(msg, WARN);
		}
		public function info(msg:String):void {
			write(msg, INFO);
		}
		public function debug(msg:String):void {
			write(msg, DEBUG);
		}
		private function write(msg:String, level:int):void {
			if(field == null) {
				return;
			}
			if(this.level >= level) {
				field.text += msg.toString() + "\r\n";
			}
		}
	}
}