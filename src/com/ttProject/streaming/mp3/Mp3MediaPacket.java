package com.ttProject.streaming.mp3;

/**
 * mp3の実体パケット
 * @author taktod
 */
public class Mp3MediaPacket extends Mp3Packet {
	/**
	 * コンストラクタ
	 * @param manager
	 */
	public Mp3MediaPacket(Mp3PacketManager manager) {
		super(manager);
	}
	/**
	 * headerパケットであるか？
	 */
	@Override
	public boolean isHeader() {
		return false;
	}
}
