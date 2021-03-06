package com.ttProject.streaming;

import java.nio.ByteBuffer;
import java.util.List;

/**
 * 
 * @author taktod
 */
public interface IMediaPacketManager {
	/**
	 * データをいれると、書き込みOKになったパケットデータを応答します。
	 * @param buffer
	 * @return データのリスト
	 */
	public List<IMediaPacket> getPackets(ByteBuffer buffer);
	/**
	 * 現在処理中のパケットを応答します。
	 * @return
	 */
	public IMediaPacket getCurrentPacket();
	/**
	 * 拡張子を取得する。
	 * @return
	 */
	public String getExt();
	/**
	 * headerの拡張子を取得する。
	 * @return
	 */
	public String getHeaderExt();
}
