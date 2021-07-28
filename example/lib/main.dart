import 'package:example/video.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:grey_page_media_player/grey_page_media_player.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Grey Page Media Player example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isInitialising = true;
  String errorThrownWhileInitialising = '';

  final mediaPlayer = MediaPlayer.makeInstance();

  String get playbackPosition =>
      '${mediaPlayer.seekPosition}/${mediaPlayer.videoDuration}';

  @override
  void initState() {
    super.initState();

    makeTestVideo().then((videoReader) async {
      await mediaPlayer.initialiseWith(videoReader);
      setState(() {
        isInitialising = false;
      });
    }).onError((error, stackTrace) {
      setState(() {
        errorThrownWhileInitialising = '$error\n$stackTrace';
      });
    });
  }

  @override
  void dispose() {
    mediaPlayer.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: isInitialising
          ? Column(
              children: [
                Text('Is Initialising'),
                Text(
                  errorThrownWhileInitialising,
                  style: TextStyle(color: Colors.red),
                )
              ],
            )
          : Column(
              children: [
                Text(playbackPosition),
                Text(mediaPlayer.state.toString()),
                Divider(
                  height: 10,
                  thickness: 0,
                ),
                MediaPlayerView(
                  initialisedMediaPlayer: mediaPlayer,
                  size: Size(MediaQuery.of(context).size.width,
                      MediaQuery.of(context).size.height * .7),
                  onPostRender: () {
                    // To show the latest playback position and media player state.
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      setState(() {});
                    });
                  },
                ),
                Divider(
                  height: 10,
                  thickness: 0,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.play_arrow),
                      onPressed: mediaPlayer.play,
                    ),
                    IconButton(
                      icon: Icon(Icons.pause),
                      onPressed: mediaPlayer.pause,
                    ),
                    IconButton(
                      icon: Icon(Icons.stop),
                      onPressed: mediaPlayer.stop,
                    ),
                    IconButton(
                      icon: Icon(Icons.replay),
                      onPressed: mediaPlayer.replay,
                    ),
                  ],
                )
              ],
            ),
    );
  }
}
