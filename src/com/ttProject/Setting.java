package com.ttProject;

import java.io.InputStream;
import java.util.Map;
import java.util.Properties;

import net.arnx.jsonic.JSON;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * とりあえず、jsonファイルあたりでなんとかしておきたいところ。
 * 動画に必要なもの。
 * javaの起動コマンド
 * java -cp test.jar:lib/netty-3.1.5.GA.jar com.ttProject.process.ProcessEntry [port] [key]
 * processに必要な環境変数
 * PATHとLD_LIBRARY_PATHとか？(妙なインストール方法をとっていなければ変更する必要なし。)
 * 変換プログラム指定
 * avconv or ffmpeg
 * 変換コマンド
 * 音声:-acodec libmp3lame -ac 2 -ar 44100 -b:a 96k
 * 映像:-vcodec libx264 -profile:v main -s 320x240 -qmin 10 -qmax 31 -crf 20.0 -level 13...
 * 音声だけ、映像だけというデータもありうるので、片方だけの動作も見越しておいた方がいいはず。
 * 出力ファイルの出す場所。
 * ~/Sites/hls/とか？
 * 
 * 設定を保持するクラス
 * @author taktod
 */
public class Setting {
	private final Logger logger = LoggerFactory.getLogger(Setting.class);
	private final static Setting instance = new Setting();
	private final float duration; // セグメントデータのduration
	private final int limit;
	private final String processCommand;
	private final String path; // 出力パス
	private final String httpPath; // http
	private final String userHome;
	private final Map<String, String> envExtra;
	private Setting() {
		try {
			InputStream is = Setting.class.getResourceAsStream("/setting.properties");
			Properties prop = new Properties();
			prop.load(is);
			userHome = System.getProperty("user.home");
			duration = Float.parseFloat(prop.getProperty("duration"));
			limit = Integer.parseInt(prop.getProperty("limit"));
			path = prop.getProperty("path");
			// process用のコマンドとその出力のデータをいれておく。
			processCommand = "java -cp test.jar:lib/netty-3.1.5.GA.jar com.ttProject.process.ProcessEntry ";
			// processCommandのインスタンスをいくつか準備しておく。
			httpPath = prop.getProperty("httpPath");
			// 拡張環境変数
			envExtra = JSON.decode(prop.getProperty("envExtra"));
		}
		catch (Exception e) {
			logger.error("setting.propertiesが読み込めませんでした。", e);
			throw new RuntimeException("failed to setup setting.");
		}
	}
	/**
	 * インスタンス取得
	 * @return
	 */
	public static synchronized Setting getInstance() {
		return instance;
	}
	public String getProcessCommand() {
		return processCommand;
	}
	public float getDuration() {
		return duration;
	}
	public int getLimit() {
		return limit;
	}
	public String getPath() {
		return path;
	}
	public String getHttpPath() {
		return httpPath;
	}
	public Map<String, String> getEnvExtra() {
		return envExtra;
	}
	public String getUserHome() {
		return userHome;
	}
}
