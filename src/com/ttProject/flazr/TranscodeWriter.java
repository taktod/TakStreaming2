package com.ttProject.flazr;

import java.nio.ByteBuffer;
import java.util.List;

import org.jboss.netty.buffer.ChannelBuffer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.flazr.io.flv.AudioTag;
import com.flazr.io.flv.FlvAtom;
import com.flazr.io.flv.VideoTag;
import com.flazr.rtmp.RtmpHeader;
import com.flazr.rtmp.RtmpMessage;
import com.flazr.rtmp.RtmpWriter;
import com.ttProject.Setting;
import com.ttProject.process.ConvertProcessHandler;
import com.ttProject.segment.flf.FlfManager;
import com.ttProject.streaming.IMediaPacket;
import com.ttProject.streaming.flv.FlvMediaPacket;
import com.ttProject.streaming.flv.FlvPacketManager;

/**
 * 変換用のwriter動作
 * FMSしか確認してない。他のサーバーならどうなるか？
 * @author taktod
 */
public class TranscodeWriter implements RtmpWriter {
	private static final Logger logger = LoggerFactory.getLogger(TranscodeWriter.class);

	private final int[]  channelTimes = new int[RtmpHeader.MAX_CHANNEL_ID];
	private final String name;
	private int primaryChannel = -1;

	// コンバートを開始したときの先頭の時刻保持(この時刻分だけデータがずれます。)
	private int startTime = -1; // 出力開始timestamp
	private int playTime = -1; // データ取得開始時刻
	private boolean isPlaying = false;
	
	// コンバート中のコーデック情報を保持しておく。
	private CodecType videoCodec = null;
	private CodecType audioCodec = null;

	// コンバート処理のハンドラー
	private ConvertProcessHandler convertHandler = null;

	// 最終処理時刻(処理がなくなったと判定するのに必要)
	private long lastAccessTime = -1;
	private long lastWriteTime = -1;

	// audioデータのqueue、整列させるのに利用
	private final AtomOrderManager orderManager = new AtomOrderManager();

	// sequenceHeaderがあるコーデック用のデータ
	private final MediaSequenceHeader mediaSequenceHeader = new MediaSequenceHeader();

	private final FlvPacketManager flvPacketManager;
	private int increment = 0;
	private final FlfManager flfManager;

	/**
	 * コンストラクタ
	 * @param name
	 */
	public TranscodeWriter(String name) {
		Setting setting = Setting.getInstance();
		flvPacketManager = new FlvPacketManager();
		flfManager = FlfManager.getInstance(setting.getPath() + name + ".flf");
		this.name = name;
		// 監視スレッドをつくっておいて、２秒間データがこなかったらとまったと判定する。
		Thread t = new Thread(new Runnable() {
			@Override
			public void run() {
				try {
					while(true) {
						if(isPlaying) {
							// 最終アクセスを確認し、最終アクセス時刻から1秒以上たっていたら、ストリームがなんらかの原因でとまったと推測する。
							if(System.currentTimeMillis() - lastAccessTime > 3000) {
								logger.info("アクセスが3秒強ないので、とまったと判定しました。");
								stop();
							}
							if(lastWriteTime != -1 && System.currentTimeMillis() - lastWriteTime > 1500) {
								// メディアの書き込みが1.5秒ないので、何らかの問題が発生したと判定し、止めます。
								stop();
								// コンバート動作を考慮するなら、片側のメディアデータがながれてこなくなったら止めるべき。(ffmpegのコンバートがとまってしまうため。)
							}
						}
						// １秒後に再度判定する。
						Thread.sleep(1000);
					}
				}
				catch (Exception e) {
					logger.error("変換の監視処理で例外発生", e);
				}
			}
		});
		t.setDaemon(true);
		t.start();
	}
	/**
	 * unpublishを検知した場合
	 */
	public void onUnpublish() {
		stop();
	}
	/**
	 * データのダウンロードがおわったときの処理
	 */
	private void stop() {
		logger.info("止めます。");
		startTime = -1;
		playTime = -1;
		isPlaying = false;
		videoCodec = null;
		audioCodec = null;
		orderManager.reset();
		lastAccessTime = -1;
		lastWriteTime = -1;
		// 最終パケットを書き込んでおく必要がある。
		flvPacketManager.reset();
		increment = 0; // インクリメント情報をリセットできるようにしておかないとこまったことになると思われます。
		if(convertHandler != null) {
			convertHandler.close();
			convertHandler = null;
		}
	}
	/**
	 * データのダウンロードがはじまったときの処理
	 */
	private void start(RtmpHeader header) {
		logger.info("始めます。");
		// ファイルの書き込みチャンネルを開いてとりあえず、書き込みテストを実行します。
		try {
			// 特に取得するものでもないと思うのでスルー
			List<IMediaPacket> packets = flvPacketManager.getPackets(FlvAtom.flvHeader().toByteBuffer()); // headerパケットが拾えるかもしれんか・・・
			for(IMediaPacket packet : packets) {
				// 書き込みを実施
				if(packet.isHeader()) {
					Setting setting = Setting.getInstance();
					packet.writeData(setting.getPath() + name + ".flh", false);
					flfManager.setFlhFile(setting.getHttpPath() + name + ".flh");
				}
				else {
					throw new RuntimeException("ここでメディアデータがでてくるはずがないだろう。");
				}
			}
		}
		catch (Exception e) {
			logger.error("パケット生成に失敗", e);
		}
		isPlaying = true;
		startTime = header.getTime();
		// このタイミングでprocessサーバーとかを作成する。
//		convertHandler = new ConvertProcessHandler(audioCodec != CodecType.NONE, videoCodec != CodecType.NONE, name);
//		convertHandler.getFlvDataQueue().putData(FlvAtom.flvHeader());
		// mediaSequenceHeaderがあるコーデックの場合は情報を書き込む
		for(FlvAtom sequenceHeader : mediaSequenceHeader.getData()) {
			write(sequenceHeader);
			sequenceHeader.getData().resetReaderIndex();
		}
		if(videoCodec != CodecType.NONE) {
			// 動画の場合は開始header以前にあるデータは必要ないので、音声queueからデータを削除します。
			orderManager.clearPrestartAtom(header.getTime());
		}
		else {
			// 音声データのみの場合はaudioQueueは必要ないので破棄します。
			orderManager.reset();
		}
	}
	/**
	 * 締め処理
	 */
	@Override
	public void close() {
		stop();
	}
	/**
	 * 書き込み処理(主体)
	 */
	@Override
	public void write(RtmpMessage message) {
		final RtmpHeader header = message.getHeader();
		if(header.isAggregate()) { // aggregate
			int difference = -1;
			final ChannelBuffer in = message.encode();
			while(in.readable()) {
				final FlvAtom flvAtom = new FlvAtom(in);
				final RtmpHeader subHeader = flvAtom.getHeader();
				if(difference == -1) {
					difference = subHeader.getTime() - header.getTime();
				}
				final int absoluteTime = subHeader.getTime();
				channelTimes[primaryChannel] = absoluteTime;
				subHeader.setTime(subHeader.getTime() - difference);
				writeHook(flvAtom);
			}
		}
		else { // meta audio video
			final int channelId = header.getChannelId();
			channelTimes[channelId] = header.getTime();
			if(primaryChannel == -1 && (header.isAudio() || header.isVideo())) {
				primaryChannel = channelId;
			}
			if(header.getSize() <= 2) {
				return;
			}
			writeHook(new FlvAtom(header.getMessageType(), channelTimes[channelId], message.encode()));
		}
	}
	/**
	 * rtmpから取得するデータはtimestampが前後することがあるので、音声パケットがきたらcacheしておき、映像パケットとソートしておく。
	 * 書き込み処理
	 * @param flvAtom
	 */
	private void writeHook(final FlvAtom flvAtom) {
		RtmpHeader header = flvAtom.getHeader();
		ChannelBuffer dataBuffer = flvAtom.getData().duplicate();
		// 音声でも映像でもない、データ量0のパケットは捨てます
		if((!header.isAudio() && !header.isVideo()) || dataBuffer.capacity() == 0) {
			return;
		}
		// 最終アクセス時刻の記録(1秒強アクセスがなければストリームが停止したと判定させる。)
		lastAccessTime = System.currentTimeMillis();
		if(header.isAudio()) {
			executeAudio(flvAtom);
		}
		else {
			executeVideo(flvAtom);
		}
	}
	/**
	 * 書き込み処理最終
	 * @param flvAtom
	 */
	private void write(final FlvAtom flvAtom) {
		try {
			// ここでの書き込みをやめて、queueに登録するようにする。
			ChannelBuffer buffer = flvAtom.write();
			ByteBuffer buf = buffer.toByteBuffer();
			List<IMediaPacket> packets = flvPacketManager.getPackets(buf.duplicate());
			/*
			 * rtmpのストリームデータの場合は設定によっては、音声が抜けるときがあります。
			 * この場合、音声データがこなくなると、そこでコンバートがとまるみたいです。
			 * なので、その場合は、適当な時間間隔で音声データを挿入してやるといい感じになります。
			 * コンバートを考慮するなら、いれておくべきだが、適当な挿入データがみつからないので、とりあえず却下
			 */
			Setting setting = Setting.getInstance();
			for(IMediaPacket packet : packets) {
				if(packet.isHeader()) {
					packet.writeData(setting.getPath() + name + ".flh", false);
					flfManager.setFlhFile(setting.getHttpPath() + name + ".flh");
				}
				else {
					increment ++;
					String targetFile = setting.getPath() + name + "_" + increment + ".flm";
					String targetHttp = setting.getHttpPath() + name + "_" + increment + ".flm";
					((FlvMediaPacket)packet).writeData(targetFile, increment, false);
					flfManager.writeData(targetFile, targetHttp, packet.getDuration(), increment, false);
				}
			}
		}
		catch (Exception e) {
			logger.error("ファイル書き込みに失敗しました。", e);
			System.exit(-1); // 異常終了
		}
	}
	/**
	 * 音声用の処理
	 * @param flvAtom
	 */
	private void executeAudio(final FlvAtom flvAtom) {
		RtmpHeader header = flvAtom.getHeader();
		ChannelBuffer dataBuffer = flvAtom.getData().duplicate();
		boolean sequenceHeader = false;
		// audio
		AudioTag tag = new AudioTag(dataBuffer.readByte());
		// コーデックを確認コーデック状態がかわっていることを確認した場合は、やりなおしにする必要があるので、有無をいわさず処理やり直しにする。
		if(audioCodec == null) {
			audioCodec = CodecType.getCodecType(tag);
		}
		if(audioCodec != CodecType.getCodecType(tag)) {
			stop();
		}
		// シーケンスヘッダ確認
		sequenceHeader = mediaSequenceHeader.isAacMediaSequenceHeader(flvAtom, tag, dataBuffer.readByte());
		// 本処理前の準備
		if(!isPlaying) {
			if(playTime == -1) {
				playTime = header.getTime();
			}
			if(sequenceHeader) {
				return;
			}
			// timestampが0に関しては無視する。
			if(header.getTime() == 0) {
				return;
			}
			// １秒以上たって、videoCodecが決定されない場合は音声のみとして始める
			if(header.getTime() - playTime > 1000 && videoCodec == null) {
				videoCodec = CodecType.NONE;
				mediaSequenceHeader.resetAvcMediaSequenceHeader();
				// 動作を開始する。
				start(header);
			}
			else {
				return;
			}
		}
		else {
			lastWriteTime = System.currentTimeMillis();
		}
		if(videoCodec == CodecType.NONE) {
			// videoCodecが存在しないと判定された場合は、audioデータ単体で次のデータ化してよくなるため、そのまま追記するようにする。
			header.setTime(header.getTime() - startTime);
			write(flvAtom);
		}
		else {
			// videoCodecが存在している場合、もしくは、判定前の場合はaudioAtomはソートしたら利用する可能性があるので、queueにいれて保存しておく。
			orderManager.addAudioAtom(flvAtom);
		}
	}
	/**
	 * 動画用の処理
	 * @param flvAtom
	 */
	private void executeVideo(final FlvAtom flvAtom) {
		RtmpHeader header = flvAtom.getHeader();
		ChannelBuffer dataBuffer = flvAtom.getData().duplicate();
		boolean sequenceHeader = false;
		// video
		VideoTag tag = new VideoTag(dataBuffer.readByte());
		if(videoCodec == null) {
			videoCodec = CodecType.getCodecType(tag);
		}
		if(videoCodec != CodecType.getCodecType(tag)) {
			stop();
		}
		// シーケンスヘッダ確認
		sequenceHeader = mediaSequenceHeader.isAvcMediaSequenceHeader(flvAtom, tag, dataBuffer.readByte());
		// 開始前処理
		if(!isPlaying) {
			// 初メディアデータであるか確認。初だったらplayTimeに現在のタイムスタンプを保持しておく。(ここにいれる理由は、コーデック違いにより、前の処理の部分で書き換えが発生する可能性があるため。)
			if(playTime == -1) {
				playTime = header.getTime();
			}
			if(sequenceHeader) {
				return;
			}
			// timestampが0に関しては無視する。
			if(header.getTime() == 0) {
				// タイムスタンプ0の通常データはとりいそぎ無視する。(FlashMediaServerのaggregateMessage対策)
				return;
			}
			// キーフレームを取得したタイミングでaudioCodecがきまっていない場合はaudioCodecなしとして動作開始してやる。
			if(tag.isKeyFrame() && // キーフレームの時のみ判定したい。
				(audioCodec != null || // audioCodecがきまっている場合
				header.getTime() - playTime > 1000)) { // もしくはaudioCodecはきまっていないが1秒たった場合
				if(audioCodec == null) {
					audioCodec = CodecType.NONE;
					mediaSequenceHeader.resetAacMediaSequenceHeader();
				}
				// 動作を開始する。
				start(header);
			}
			else {
				return;
			}
		}
		// 書き込む
		for(FlvAtom audioAtom : orderManager.getPassedData(header.getTime())) {
			audioAtom.getHeader().setTime(audioAtom.getHeader().getTime() - startTime);
			write(audioAtom);
		}
		// 動画データも書き込む
		header.setTime(header.getTime() - startTime);
		lastWriteTime = System.currentTimeMillis();
		write(flvAtom);
	}
}
