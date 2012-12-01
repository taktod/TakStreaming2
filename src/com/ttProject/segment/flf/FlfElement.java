package com.ttProject.segment.flf;

/**
 * flfが保持しているエレメント情報?
 * @author taktod
 */
public class FlfElement {
	private String file;
	private String http;
	private String info;
	private int index;
	public FlfElement(String file, String http, float duration, int index) {
		this.file = file;
		this.http = http;
		this.info = "#FLF_DATA:" + duration;
		this.index = index;
	}
	public String getFile() {
		return file;
	}
	public String getHttp() {
		return http;
	}
	public String getInfo() {
		return info;
	}
	public int getIndex() {
		return index;
	}
	public boolean isFirst() {
		return index == 1;
	}
}
