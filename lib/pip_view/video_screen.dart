import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pip_flutter/pipflutter_player.dart';
import 'package:pip_flutter/pipflutter_player_configuration.dart';
import 'package:pip_flutter/pipflutter_player_controller.dart';
import 'package:pip_flutter/pipflutter_player_controls_configuration.dart';
import 'package:pip_flutter/pipflutter_player_data_source.dart';
import 'package:pip_flutter/pipflutter_player_data_source_type.dart';
import 'package:pip_flutter/pipflutter_player_drm_configuration.dart';
import 'package:pip_flutter/pipflutter_player_event.dart';
import 'package:pip_flutter/pipflutter_player_event_type.dart';
import 'package:pip_flutter/pipflutter_player_video_format.dart';
import 'package:pip_flutter/video_player_platform_interface.dart';

//export
export 'package:pip_flutter/pipflutter_player_data_source_type.dart';
export 'package:pip_flutter/pipflutter_player_video_format.dart';

enum VideoStatus {
  INITIALZED,
  PLAY,
  PAUSE,
  LOADING,
  ERROR,
}

class VideoData {
  String? url;
  VideoStatus? status;
  Duration? durationTotal;
  Duration? position;
  List<DurationRange>? buffered;
  bool? isPIP;
  double? speed;
  double? volume;
  bool? isLoop;
  String? errorDescription;
  bool? isBuffering;
  bool? isBufferUpdate;
  bool? isBufferEnd;
  Size? size;
}

class VideoPlayer extends StatefulWidget {
  final String videoUrl;
  final PipFlutterPlayerDataSourceType type;
  final PipFlutterPlayerVideoFormat videoFormat;
  final bool isAutoPlay;
  final bool isFullScreen;
  final double aspectRatio;
  final bool isLiveStream;
  final Duration? startAt;
  final Widget? loadingWidget;
  final PipFlutterPlayerDrmConfiguration? certificate;
  final Function()? onLoading;
  final Function()? onLoadUpdate;
  final Function()? onLoadDone;
  final Function(void Function()? refresh)? refresh;
  final Function(Future<void> Function()? onPlay)? onPlay;
  final Function(Future<void> Function()? onPause)? onPause;
  final Function(Future<void> Function({double? top, double? left, double? width, double? height})? onRunPIP)? runPIP;
  final Function(Future<void> Function()? onStopPIP)? runStopPIP;
  final Function(bool isPIP)? onPIPChange;
  final Function(Future<void> Function(bool isLoop)? setLopping)? setLopping;
  final Function(Future<void> Function(double speed)? setSpeed)? setSpeed;
  final Function(Future<void> Function(double speed)? setVolume)? setVolume;
  final Function(Future<void> Function(Duration duration)? seekTo)? seekTo;
  final Function(Future<void> Function(bool)? setAutoPIP)? setAutoPIP;
  final Function(dynamic error)? onError;
  final Function(VideoData? videoData)? listenVideoData;
  final PipFlutterPlayerControlsConfiguration? controlsConfiguration;
  final Function()? onFinishVideo;
  final bool isAutoEnterPIP;

  ///cache controller
  final PipFlutterPlayerController? pipController;
  final Function(PipFlutterPlayerController? pipController)? onCreated;
  const VideoPlayer({
    required this.videoUrl,
    this.type = PipFlutterPlayerDataSourceType.network,
    this.certificate,
    this.isAutoPlay = true,
    this.isFullScreen = false,
    this.aspectRatio = 9 / 16,
    this.startAt,
    this.isLiveStream = false,
    this.videoFormat = PipFlutterPlayerVideoFormat.other,
    this.loadingWidget,
    this.onLoading,
    this.onLoadUpdate,
    this.onLoadDone,
    this.onPlay,
    this.onPause,
    this.runPIP,
    this.runStopPIP,
    this.setSpeed,
    this.setVolume,
    this.seekTo,
    this.onError,
    this.listenVideoData,
    this.setLopping,
    this.refresh,
    this.onPIPChange,
    this.controlsConfiguration,
    this.onFinishVideo,
    this.setAutoPIP,
    this.isAutoEnterPIP = false,
    this.onCreated,
    this.pipController,
  });
  @override
  State<VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> with WidgetsBindingObserver {
  PipFlutterPlayerController? controller;
  final VideoData videoData = VideoData();
  final GlobalKey pipFlutterPlayerKey = GlobalKey();
  @override
  void initState() {
    // TODO: implement initState
    _initVideo();
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant VideoPlayer oldWidget) {
    if (oldWidget.videoUrl != widget.videoUrl) {
      _onDispose();
      _initVideo();
    }

    super.didUpdateWidget(oldWidget);
  }

  _initVideo() {
    //init video
    videoData.url = widget.videoUrl;
    if (widget.pipController == null) {
      PipFlutterPlayerConfiguration configuration = PipFlutterPlayerConfiguration(
        aspectRatio: widget.aspectRatio,
        fit: BoxFit.cover,
        autoPlay: widget.isAutoPlay,
        fullScreenByDefault: widget.isFullScreen,
        startAt: widget.startAt,
        deviceOrientationsOnFullScreen: const [DeviceOrientation.portraitUp],
        deviceOrientationsAfterFullScreen: const [DeviceOrientation.portraitUp],
        controlsConfiguration: widget.controlsConfiguration ??
            PipFlutterPlayerControlsConfiguration(
              loadingWidget: widget.loadingWidget ?? const SizedBox.shrink(),
              backgroundColor: Colors.transparent,
            ),
        autoEnterPIP: widget.isAutoEnterPIP,
      );
      PipFlutterPlayerDataSource dataSource = PipFlutterPlayerDataSource(
        widget.type,
        widget.videoUrl,
        videoFormat: widget.videoFormat,
        liveStream: widget.isLiveStream,
        drmConfiguration: widget.certificate,
      );
      controller = PipFlutterPlayerController(
        configuration,
        pipFlutterPlayerDataSource: dataSource,
      );
    } else {
      controller = widget.pipController;
      initDelegate();
      autoPlay();
    }

    controller?.setPipFlutterPlayerGlobalKey(pipFlutterPlayerKey);
    controller?.setControlsEnabled(false);
    setState(() {});

    controller?.addEventsListener(_eventsListener);
  }

  _eventsListener(PipFlutterPlayerEvent event) {
    // print("_eventsListener ${event.pipFlutterPlayerEventType}");

    switch (event.pipFlutterPlayerEventType) {
      case PipFlutterPlayerEventType.initialized:

        ///init delegate
        initDelegate();
        break;
      case PipFlutterPlayerEventType.pipStop:
        // print("PipFlutterPlayerEventType.pipStop");
        widget.onPIPChange?.call(false);
        if (_appLifecycleState == AppLifecycleState.resumed) {
          autoPlay();
        } else {
          pause();
        }
        break;
      case PipFlutterPlayerEventType.pipStart:
        widget.onPIPChange?.call(true);
        // autoPlay();
        break;
      case PipFlutterPlayerEventType.finished:
        widget.onFinishVideo?.call();
        // autoPlay();
        break;
      default:
        break;
    }
  }

  initDelegate() {
    widget.onPlay?.call(controller?.play);
    widget.onPause?.call(controller?.pause);
    widget.seekTo?.call(controller?.seekTo);
    widget.setLopping?.call(controller?.setLooping);
    widget.setSpeed?.call(controller?.setSpeed);
    widget.setVolume?.call(controller?.setVolume);
    widget.runPIP?.call(onRunPIP);
    widget.runStopPIP?.call(runStopPIP);
    widget.setAutoPIP?.call(controller?.setAutoPIP);
    widget.refresh?.call(refresh);
    widget.onCreated?.call(controller);
    controller!.videoPlayerController?.removeListener(_initListenVideo);
    controller!.videoPlayerController?.addListener(_initListenVideo);
  }

  refresh() {
    if (_appLifecycleState == AppLifecycleState.resumed) {
      controller?.videoPlayerController?.refresh();
      if (widget.isLiveStream) {
        controller?.seekTo(Duration(seconds: controller?.videoPlayerController?.value.duration?.inSeconds ?? 0));
      }
    }
  }

  autoPlay() {
    try {
      if (widget.isAutoPlay && _appLifecycleState == AppLifecycleState.resumed) {
        if (controller?.videoPlayerController?.value.isPlaying != true) {
          controller?.play();
        }
      }
    } catch (e) {
      //do nothing
    }
  }

  pause() {
    try {
      controller?.pause();
    } catch (e) {
      //do nothing
    }
  }

  Future<void> onRunPIP({double? top, double? left, double? width, double? height}) async {
    // print("onRunPIP");

    await controller!.enablePictureInPicture(pipFlutterPlayerKey, top: top, left: left, width: width, height: height);
    autoPlay();
  }

  Future<void> runStopPIP() async {
    await controller!.disablePictureInPicture();
    autoPlay();
  }

  void _initListenVideo() {
    var data = controller?.videoPlayerController?.value;
    if (data != null) {
      videoData.buffered = data.buffered;
      videoData.durationTotal = data.duration;
      videoData.position = data.position;
      videoData.isPIP = data.isPip;
      videoData.speed = data.speed;
      videoData.volume = data.volume;
      videoData.isLoop = data.isLooping;
      videoData.isBuffering = data.isBuffering;
      videoData.isBufferUpdate = data.isBufferUpdate;
      videoData.isBufferEnd = data.isBufferEnd;
      videoData.size = data.size;
      if (data.initialized) {
        videoData.status = VideoStatus.INITIALZED;
      }
      if (data.isPlaying) {
        videoData.status = VideoStatus.PLAY;
      } else {
        videoData.status = VideoStatus.PAUSE;
      }
      if (data.isBuffering) {
        videoData.status = VideoStatus.LOADING;
        widget.onLoading?.call();
      }
      if (data.isBufferUpdate) {
        widget.onLoadUpdate?.call();
      }
      if (data.isBufferEnd) {
        widget.onLoadDone?.call();
      }
      if ((data.errorDescription ?? "").isNotEmpty) {
        videoData.status = VideoStatus.ERROR;
        videoData.errorDescription = (data.errorDescription ?? "");
        widget.onError?.call(data.errorDescription);
      }
      widget.listenVideoData?.call(videoData);
      return;
    }
  }

  AppLifecycleState? _appLifecycleState;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      //do your stuff
      stopIfPipExit();
    }
  }

  stopIfPipExit() async {
    await Future.delayed(const Duration(milliseconds: 1000), () {
      if (controller?.videoPlayerController?.value.isPip ?? false) {
        if (Platform.isIOS) {
          runStopPIP();
        }
      }
    });
    autoPlay();
  }

  void _onDispose() {
    widget.onPlay?.call(null);
    widget.onPause?.call(null);
    widget.seekTo?.call(null);
    widget.setLopping?.call(null);
    widget.setSpeed?.call(null);
    widget.setVolume?.call(null);
    widget.runPIP?.call(null);
    widget.runStopPIP?.call(null);
    widget.refresh?.call(null);
    widget.setAutoPIP?.call(null);
    controller?.videoPlayerController?.removeListener(_initListenVideo);
    controller?.removeEventsListener(_eventsListener);
    controller?.dispose();
  }

  @override
  void dispose() {
    _onDispose();

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return controller != null
        ? PipFlutterPlayer(
            controller: controller!,
            key: pipFlutterPlayerKey,
          )
        : (widget.loadingWidget ?? const SizedBox.shrink());
  }
}
