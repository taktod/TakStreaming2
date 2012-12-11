package com.ttProject.info
{
	import spark.components.TextArea;

	public class Logger
	{
		private static var field:TextArea = null;
		public static function setup(field:TextArea):void {
			Logger.field = field;
		}
		public static function info(data:*):void {
			if(field == null) {
				return;
			}
			field.text += data.toString() + "\r\n";
			if(field.text.split("\n").length > 24) {
				field.text = data.toString() + "\r\n";
			}
		}
	}
}