あたらしいバージョンのtakStreamを再生するためのflash側動作

名称:
takStreamLibrary

内容:
taktodが自作したtakStreamingのデータを再生するためのライブラリ。
デモ用のプレーヤーも添付しています。

ライセンス:
LGPLとします。

作者:
taktod
email poepoemix@hotmail.com
twitter http://twitter.com/taktod/

使い方:
var stream:NetStream = TakStreamingFactory.getStream(接続先URL);でnetStreamオブジェクトを取得します。
var video:Video = TakstreamingFactory.getVideo();で再生されるvideoオブジェクトを取得します。
stream.play(再生名);で再生します。
ほとんとnetStreamやvideoと同じなので非常に簡単に実装できると思います。

接続先URLについて
httpTakStreamingの場合
対象のサーバーのflfファイルを指定します。
デモとして http://49.212.39.17/tak/test.flf を公開しておきます。
play時の再生名は無視されます。

rtmpTakStreamingの場合
対象サーバーのrtmpアドレスを指定します。
play時の再生名は対象サーバーのstreamNameを指定します。

rtmfpの実装等はこれから行う予定。

サーバー側実装に興味ある方は別ブランチを参照してください。
