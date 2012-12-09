あたらしいバージョンのtakStreamを生成するためのflazr実装

名称:
takStreamFlazr

内容:
taktodが自作したtakStreaming用のsegmentデータを作成するflazr実装。
任意のrtmpサーバーからflazrをDL機能をつかってrtmpデータをダウンロード変換することで
flfFile、flhFile、flmFileを生成します。

ライセンス:
LGPLとします。

作者:
taktod
email poepoemix@hotmail.com
twitter http://twitter.com/taktod/

conf/setting.propertiesに適当にあたいをいれると、適当にデータを生成しますので、専用のプレーヤーで確認してください。

デモ:
http://49.212.39.17/player/TakStreamingPlayer.html

利点:
http経由で小さなsegmentデータを連続でダウンロードすることでストリーミングを実装しています。
AmazonS3等と連携させるといくらでも冗長化できると思います。

今後:
・rtmp実装やrtmfp実装を作成し、必要があれば、自動的に動作をシームレスに切り替えることができるようにしたいと思います。
このシームレスさにより、一時的にrtmpでの配信をhttpに切り替えてサーバーをメンテナンスといったことが柔軟にできます。

・rtmfp実装を利用することで、サーバーと回線のコストを極限まで下げたいとおもっています。

・FlashMediaEncoderやXsplitといった配信ツールから出力したデータもストリームに簡単に載せることができるので
高画質なストリームが楽しめるようにする予定です。

・Flash側のライブラリもとことんまで簡単にすることで、誰でも簡単にplayerを作成できるようにする。

・ユーザーのローカルにあるflvファイルをサーバーを介することなく、ネットワークにながせるようにする。

・変換動作をコントロールすることでdrmも実装する。