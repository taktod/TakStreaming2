package com.ttProject.red5.data;

import java.nio.ByteBuffer;
import java.util.LinkedList;

/**
 * @author taktod
 */
public class DataManager {
	private ByteBuffer header = null;
	private final LinkedList<TakData> data = new LinkedList<TakData>();
	private final int limit = 6;
	public void setHeader(ByteBuffer header) {
		this.header = header;
	}
	public byte[] getHeader() {
		if(header == null) {
			return null;
		}
		return header.array();
	}
	public void addData(TakData newData) {
		data.add(newData);
		while(data.size() > limit) {
			data.poll();
		}
		System.out.println(data);
	}
	public byte[] getData(int index) {
		for(TakData dat : data) {
			if(dat.getIndex() == index) {
				return dat.getData();
			}
		}
		return null;
	}
	public byte[] getLastData() {
		TakData takData = data.get(data.size() - 1);
		if(takData != null) {
			return takData.getData();
		}
		else {
			return null;
		}
	}
}
