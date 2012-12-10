package com.ttProject.red5;

import java.io.File;
import java.nio.ByteBuffer;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.apache.mina.core.buffer.IoBuffer;
import org.red5.io.ITag;
import org.red5.io.flv.FLVHeader;
import org.red5.io.flv.impl.Tag;
import org.red5.io.utils.IOUtils;
import org.red5.server.api.IConnection;
import org.red5.server.api.service.IServiceCapableConnection;
import org.red5.server.api.stream.IBroadcastStream;
import org.red5.server.api.stream.IStreamListener;
import org.red5.server.api.stream.IStreamPacket;
import org.red5.server.net.rtmp.event.IRTMPEvent;
import org.red5.server.stream.IStreamData;

import com.ttProject.red5.data.DataManager;
import com.ttProject.red5.data.TakData;
import com.ttProject.red5.ex.TakApplicationAdapter;
import com.ttProject.segment.flf.FlfManager;
import com.ttProject.streaming.IMediaPacket;
import com.ttProject.streaming.flv.FlvHeaderPacket;
import com.ttProject.streaming.flv.FlvMediaPacket;
import com.ttProject.streaming.flv.FlvPacketManager;

/**
 * rtmpのストリームを監視して、takStreamの命令に変換して応答するプログラム
 * とりあえずデータ生成までは、できるようになった。
 * あとは応答をきちんとつくっていくだけ。
 * ByteBufferのリストとして、flhファイルデータの保持と、flmファイルデータ20個の保持が必要。
 * @author taktod
 */
public class RtmpStreamObserver implements IStreamListener {
	// 開始timestamp
	private int startTime = -1;
	private int playTime = -1;
	private boolean isPlaying = false;
	// コーデック情報
	private CodecType audioCodec = null;
	private CodecType videoCodec = null;
	// audioデータorder用マネージャー
	private final TagOrderManager orderManager = new TagOrderManager();
	// sequenceHeader
	private final MediaSequenceHeader mediaSequenceHeader = new MediaSequenceHeader();

	private final FlvPacketManager flvPacketManager;
	private int counter = 0;
	private final DataManager manager;
	private final FlfManager flfManager;
	private final String httpPath;
	private final String filePath;

	// いなくなったらきちんと消えるようにweakHashMapにしとく。
	private Set<IServiceCapableConnection> connSet = new HashSet<IServiceCapableConnection>();
	public void removeConn(IConnection conn) {
		connSet.remove(conn);
	}
	/**
	 * コンストラクタ
	 * @param name
	 */
	public RtmpStreamObserver(String name) {
		FlfManager manager = null;
		flvPacketManager = new FlvPacketManager();
		this.manager = new DataManager();
		String file = TakApplicationAdapter.getFilePath();
		String http = TakApplicationAdapter.getHttpPath();
		if(file != null && http != null) {
			try {
				// ファイルのパスが有効であるか確認する必要がある。
				File f = new File(file);
				// 相対パスで書かれているか絶対パスで書かれているか？
				if(file.startsWith(f.getAbsolutePath())) { // 絶対パス
					f = new File(file + "/" + name);
				}
				else { // 相対パス
					f = new File("webapps/" + file + "/" + name);
				}
				// ディレクトリをつくる。
				f.getParentFile().mkdirs();
				file = f.getAbsolutePath();
				// httpは絶対パスというものが存在しない。
				if(http.endsWith("/")) {
					http = http.substring(0, http.length() - 1);
				}
				if(name.startsWith("/")) {
					name = name.substring(1);
				}
				if(name.endsWith("/")) {
					name = name.substring(0, name.length() - 1);
				}
				http = http + "/" + name;
				manager = FlfManager.getInstance(file + ".flf");
			}
			catch (Exception e) {
				e.printStackTrace();
				manager = null;
			}
		}
		else {
			manager = null;
		}
		filePath = file;
		httpPath = http;
		flfManager = manager;
	}
	public void addStreamClient(IServiceCapableConnection sconn) {
		connSet.add(sconn);
		byte[] data = manager.getHeader();
		if(data != null) {
			sconn.invoke("takHeader", new Object[]{data});
			data = manager.getLastData();
			if(data != null) {
				sconn.invoke("takData", new Object[]{data});
			}
		}
	}
	private void sendHeader() {
		byte[] data = manager.getHeader();
		if(data == null) {
			return;
		}
		synchronized(connSet) {
			for(IServiceCapableConnection sconn : connSet) {
				sconn.invoke("takHeader", new Object[]{data});
			}
		}
	}
	private void sendData(byte[] data) {
		synchronized(connSet) {
			for(IServiceCapableConnection sconn : connSet) {
				sconn.invoke("takData", new Object[]{data});
			}
			System.out.println(connSet);
		}
	}
	/**
	 * パケットを受け取ったときの処理
	 */
	@Override
	public void packetReceived(IBroadcastStream stream,
			IStreamPacket packet) {
		if(!(packet instanceof IRTMPEvent) || !(packet instanceof IStreamData<?>)) {
			// パケット
			return;
		}
		IRTMPEvent rtmpEvent = (IRTMPEvent)packet;
		// takFlazrのTranscodeWrite.writeHookに相当する処理
		analizeRtmpEventHook(rtmpEvent);
	}
	public void stop() {
		System.out.println("止めます。");
		startTime = -1;
		playTime = -1;
		isPlaying = false;
		videoCodec = null;
		audioCodec = null;
		orderManager.reset();
		flvPacketManager.reset();
		counter = 0;
	}
	private void start(ITag tag) {
		System.out.println("始めます。");
		try {
			FLVHeader header = new FLVHeader();
			header.setFlagAudio(audioCodec != CodecType.NONE);
			header.setFlagVideo(videoCodec != CodecType.NONE);
			ByteBuffer buffer = ByteBuffer.allocate(13);
			header.write(buffer);
			List<IMediaPacket> packets = flvPacketManager.getPackets(buffer);
			for(IMediaPacket packet : packets) {
				if(packet.isHeader()) {
					manager.setHeader(((FlvHeaderPacket)packet).getBufferData());
					sendHeader();
					if(flfManager != null) {
						packet.writeData(filePath + ".flh", false);
						flfManager.setFlhFile(httpPath + ".flh");
					}
				}
				else {
					throw new RuntimeException("headerデータでないパケットができてしまいました？");
				}
			}
		}
		catch (Exception e) {
			e.printStackTrace();
		}
		isPlaying = true;
		startTime = tag.getTimestamp();
		for(ITag sequenceHeader : mediaSequenceHeader.getData()) {
			// 書き込む
			write(sequenceHeader);
			sequenceHeader.getBody().rewind();
		}
		if(videoCodec != CodecType.NONE) {
			orderManager.clearPrestartTag(tag.getTimestamp());
		}
		else {
			orderManager.reset();
		}
	}
	private void analizeRtmpEventHook(IRTMPEvent rtmpEvent) {
		// 音声でも映像でもない、データ量0のデータは捨てます。
		byte dataType = rtmpEvent.getDataType();
		if((dataType != ITag.TYPE_AUDIO && dataType != ITag.TYPE_VIDEO)
				|| rtmpEvent.getHeader().getSize() == 0) {
			return;
		}
		ITag tag = new Tag();
		tag.setDataType(rtmpEvent.getDataType());
		tag.setTimestamp(rtmpEvent.getTimestamp());
		IoBuffer data = ((IStreamData<?>) rtmpEvent).getData().asReadOnlyBuffer();
		tag.setBodySize(data.limit());
		tag.setBody(data);
		if(dataType == ITag.TYPE_AUDIO) {
			executeAudio(tag);
		}
		else {
			executeVideo(tag);
		}
	}
	private void write(final ITag tag) {
		try {
			ByteBuffer tagBuffer = null;
			int bodySize = tag.getBodySize();
			if(bodySize == 0) {
				return; // bodySizeがない場合は処理しない。
			}
			int totalTagSize = 11 + bodySize + 4;
			tagBuffer = ByteBuffer.allocate(totalTagSize);
			IOUtils.writeUnsignedByte(tagBuffer, tag.getDataType());
			IOUtils.writeMediumInt(tagBuffer, bodySize);
			IOUtils.writeExtendedMediumInt(tagBuffer, tag.getTimestamp());
			IOUtils.writeMediumInt(tagBuffer, 0);
			
			tagBuffer.put(tag.getBody().buf());
			tagBuffer.putInt(11 + bodySize);
			tagBuffer.flip();
			
			List<IMediaPacket> packets = flvPacketManager.getPackets(tagBuffer);
			for(IMediaPacket packet : packets) {
				if(packet.isHeader()) {
					manager.setHeader(((FlvHeaderPacket)packet).getBufferData());
					sendHeader();
					if(flfManager != null) {
						packet.writeData(filePath + ".flh", false);
						flfManager.setFlhFile(httpPath + ".flh");
					}
				}
				else {
					counter ++;
					ByteBuffer bufferData = ((FlvMediaPacket)packet).getBufferData(counter);
					TakData takData = new TakData(counter, bufferData);
					manager.addData(takData);
					sendData(bufferData.array());
					if(flfManager != null) {
						String targetFile = filePath + "_" + counter + ".flm";
						String targetHttp = httpPath + "_" + counter + ".flm";
						((FlvMediaPacket)packet).writeData(targetFile, counter, false);
						flfManager.writeData(targetFile, targetHttp, packet.getDuration(), counter, false);
					}
				}
			}
		}
		catch (Exception e) {
			System.out.println("ファイル取得に失敗しました。");
			e.printStackTrace();
			System.exit(-1);
		}
	}
	private void executeAudio(final ITag tag) {
		CodecType codec = CodecType.getAudioCodecType(tag.getBody().get());
		boolean sequenceHeader = false;
		// コーデック情報を確認(コーデックがかわっている場合はいったんとめてやり直す。)
		if(audioCodec == null) {
			System.out.println("codecを認識しました。" + codec);
			audioCodec = codec;
		}
		if(audioCodec != codec) {
			// コーデックが一致しない。
			stop();
		}
		// シーケンスヘッダがある場合は保持しておく。
		sequenceHeader = mediaSequenceHeader.isAacMediaSequenceHeader(tag, codec, tag.getBody().get());
		tag.getBody().rewind();
		// 開始前の状態だったら管理する必要がある。
		if(!isPlaying) {
			if(playTime == -1) {
				playTime = tag.getTimestamp();
			}
			if(sequenceHeader) {
				return;
			}
			// timestampが0の場合は捨てる。(ここから始める理由はないと思う。)
			if(tag.getTimestamp() == 0) {
				return;
			}
			// 1秒たって、videoCodecが未決定の場合は音声のみとして始める。
			if(tag.getTimestamp() - playTime > 1000 && videoCodec == null) {
				videoCodec = CodecType.NONE;
				mediaSequenceHeader.resetAvcMediaSequenceHeader();
				// 開始する。
				start(tag);
			}
			else {
				return;
			}
		}
		if(videoCodec == CodecType.NONE) {
			// 音声のみの場合はこのまま処理にまわす。
			tag.setTimestamp(tag.getTimestamp() - startTime);
			// 書き込み
			write(tag);
		}
		else {
			// 映像もある場合は、orderManagerにいれておく。(整列させてきちんとしたflvを目指す。)
			orderManager.addAudioTag(tag);
		}
	}
	private void executeVideo(final ITag tag) {
		byte signByte = tag.getBody().get();
		CodecType codec = CodecType.getVideoCodecType(signByte);
		boolean sequenceHeader = false;
		if(videoCodec == null) {
			System.out.println("codecを認識しました。" + codec);
			videoCodec = codec;
		}
		if(videoCodec != codec) {
			stop();
		}
		sequenceHeader = mediaSequenceHeader.isAvcMediaSequenceHeader(tag, codec, tag.getBody().get());
		tag.getBody().rewind();
		if(!isPlaying) {
			if(playTime == -1) {
				playTime = tag.getTimestamp();
			}
			if(sequenceHeader) {
				return;
			}
			if(tag.getTimestamp() == 0) {
				return;
			}
			if((signByte & 0xF0) == 0x10 && // キーフレームである。
				(audioCodec != null || // audioCodecが決定済み
				tag.getTimestamp() - playTime > 1000)) { // もしくは1秒経過した。
				if(audioCodec == null) {
					audioCodec = CodecType.NONE;
					mediaSequenceHeader.resetAacMediaSequenceHeader();
				}
				// 動作を開始する。
				start(tag);
			}
			else {
				return;
			}
		}
		if((signByte & 0xF0) == 0x30) {
			// disposable inner frameはすてておく。
			return;
		}
		// 書き込む
		for(ITag audioTag : orderManager.getPassedData(tag.getTimestamp())) {
			audioTag.setTimestamp(audioTag.getTimestamp() - startTime);
			// 書き込む
			write(audioTag);
		}
		tag.setTimestamp(tag.getTimestamp() - startTime);
		// 書き込む
		write(tag);
	}
	public static void main(String[] args) {
		ByteBuffer buffer = ByteBuffer.allocate(8);
		buffer.putInt(1);
		buffer.putInt(2);
		buffer.flip();
		System.out.println(buffer.getInt());
		System.out.println(buffer.getInt());
		buffer.flip();
		System.out.println(buffer.getInt());
		System.out.println(buffer.getInt());
	}
}
