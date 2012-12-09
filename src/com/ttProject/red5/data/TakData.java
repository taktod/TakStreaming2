package com.ttProject.red5.data;

import java.nio.ByteBuffer;

public class TakData {
	private int index;
	private ByteBuffer data;
	public TakData(int index, ByteBuffer rawData) {
		this.index = index;
		this.data = rawData;
	}
	public int getIndex() {
		return index;
	}
	public byte[] getData() {
		return data.array();
	}
	@Override
	public String toString() {
		return index + ":" + data.capacity();
	}
}
