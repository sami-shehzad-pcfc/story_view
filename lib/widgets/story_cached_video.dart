import 'dart:async';
import 'dart:io';

import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../controller/story_controller.dart';
import '../utils.dart';

class VideoLoader {
  String url;

  File? videoFile;

  Map<String, dynamic>? requestHeaders;

  LoadState state = LoadState.loading;

  VideoLoader(this.url, {this.requestHeaders});

  void loadVideo(VoidCallback onComplete) {
    // if (this.videoFile != null) {
    //   this.state = LoadState.success;
    //   onComplete();
    // }

    // final fileStream = DefaultCacheManager().getFileStream(this.url,
    //     headers: this.requestHeaders as Map<String, String>?);

    // fileStream.listen((fileResponse) {
    //   if (fileResponse is FileInfo) {
    //     if (this.videoFile == null) {
    //       this.state = LoadState.success;
    //       this.videoFile = fileResponse.file;
    //       onComplete();
    //     }
    //   }
    // });
    this.state = LoadState.success;
    onComplete();
  }
}

class StoryCacheVideo extends StatefulWidget {
  final StoryController? storyController;
  final VideoLoader videoLoader;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final bool isMuteByDefault;
  final void Function(Duration duration)? onDurationLoaded;

  StoryCacheVideo(
    this.videoLoader, {
    Key? key,
    this.storyController,
    this.loadingWidget,
    this.errorWidget,
    this.isMuteByDefault = true,
    this.onDurationLoaded,
  }) : super(key: key ?? UniqueKey());

  static StoryCacheVideo url(
    String url, {
    StoryController? controller,
    Map<String, dynamic>? requestHeaders,
    Key? key,
    Widget? loadingWidget,
    bool isMuteByDefault = true,
    Widget? errorWidget,
    void Function(Duration duration)? onDurationLoaded,
  }) {
    return StoryCacheVideo(
      VideoLoader(url, requestHeaders: requestHeaders),
      storyController: controller,
      key: key,
      loadingWidget: loadingWidget,
      isMuteByDefault: isMuteByDefault,
      errorWidget: errorWidget,
      onDurationLoaded: onDurationLoaded,
    );
  }

  @override
  State<StatefulWidget> createState() {
    return StoryCacheVideoState();
  }
}

class StoryCacheVideoState extends State<StoryCacheVideo> {
  Future<void>? playerLoader;

  StreamSubscription? _streamSubscription;

  CachedVideoPlayerPlus? playerController;

  @override
  void initState() {
    super.initState();

    playerController = CachedVideoPlayerPlus.networkUrl(
      Uri.parse(widget.videoLoader.url),
      invalidateCacheIfOlderThan: Duration(days: 3),
    );

    widget.videoLoader.loadVideo(() {
      if (widget.videoLoader.state == LoadState.success) {
        widget.storyController!.pause();
        playerController!.initialize().then((v) {
          setState(() {});
          widget.onDurationLoaded
              ?.call(playerController!.controller.value.duration);
          widget.storyController!.play();
          playerController!.controller
              .setVolume(widget.isMuteByDefault ? 0 : 1);

          if (widget.storyController != null) {
            _streamSubscription = widget.storyController!.playbackNotifier
                .listen((playbackState) {
              if (playbackState == PlaybackState.pause) {
                playerController!.controller.pause();
              } else {
                playerController!.controller.play();
              }
            });
          }
        });
      } else {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      height: double.infinity,
      width: double.infinity,
      child: (playerController?.isInitialized ?? false)
          ? VideoContentView(
              videoLoadState: widget.videoLoader.state,
              controller: playerController!.controller,
              loadingWidget: widget.loadingWidget,
              errorWidget: widget.errorWidget,
            )
          : SizedBox(),
    );
  }

  @override
  void dispose() {
    playerController?.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
}

/**
 * @name VideoContentView
 * @description Stateless widget that shows a video player or loading/error widgets based on video loading state.
 */
class VideoContentView extends StatefulWidget {
  final LoadState videoLoadState;
  final VideoPlayerController? controller;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  const VideoContentView({
    Key? key,
    required this.videoLoadState,
    required this.controller,
    this.loadingWidget,
    this.errorWidget,
  }) : super(key: key);

  @override
  State<VideoContentView> createState() => _VideoContentViewState();
}

class _VideoContentViewState extends State<VideoContentView> {
  @override
  Widget build(BuildContext context) {
    if (widget.videoLoadState == LoadState.success &&
        widget.controller != null &&
        widget.controller!.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          AspectRatio(
            aspectRatio: widget.controller!.value.aspectRatio,
            child: VideoPlayer(widget.controller!),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 40,
            right: 20,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (widget.controller!.value.volume == 0) {
                    widget.controller!.setVolume(1);
                  } else {
                    widget.controller!.setVolume(0);
                  }
                });
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: ShapeDecoration(
                  shape: CircleBorder(),
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                child: Icon(
                  widget.controller!.value.volume == 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (widget.videoLoadState == LoadState.loading) {
      return Center(
        child: widget.loadingWidget ??
            const SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
      );
    }

    return Center(
      child: widget.errorWidget ??
          const Text(
            "Media failed to load.",
            style: TextStyle(color: Colors.white),
          ),
    );
  }
}
