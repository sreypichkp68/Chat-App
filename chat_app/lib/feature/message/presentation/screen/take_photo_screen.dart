import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TakePhotoScreen extends StatefulWidget {
  const TakePhotoScreen({super.key});

  @override
  State<TakePhotoScreen> createState() => _TakePhotoScreenState();
}

class _TakePhotoScreenState extends State<TakePhotoScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _index = 0;
  int _generation = 0;
  bool _busy = false;
  bool _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  Future<void> _open() async {
    final generation = ++_generation;
    final old = _controller;
    setState(() {
      _controller = null;
      _error = null;
      _opening = true;
    });
    CameraController? next;
    try {
      await old?.dispose();
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (!mounted || generation != _generation) return;
      if (_cameras.isEmpty)
        throw CameraException('NoCamera', 'No camera is available.');
      next = CameraController(
        _cameras[_index],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await next.initialize();
      if (!mounted || generation != _generation) {
        await next.dispose();
        return;
      }
      setState(() {
        _controller = next;
        _opening = false;
      });
    } catch (error, stack) {
      debugPrint('Camera initialization failed: $error\n$stack');
      await next?.dispose();
      if (mounted && generation == _generation) {
        setState(() {
          _opening = false;
          _error = switch (error) {
            MissingPluginException() =>
              'Camera setup requires a full app rebuild. Stop the app and run it again.',
            PlatformException(code: 'channel-error') =>
              'Camera setup requires a full app rebuild. Stop the app and run it again.',
            CameraException(code: 'CameraAccessDenied') =>
              'Camera access is denied. Allow camera access in your phone settings, then retry.',
            CameraException(code: 'CameraAccessDeniedWithoutPrompt') =>
              'Allow camera access in your phone settings, then retry.',
            CameraException(code: 'NoCamera') =>
              'No camera is available on this device.',
            _ =>
              'Could not start the camera. Close other apps using the camera and retry.',
          };
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _generation++;
      final controller = _controller;
      setState(() => _controller = null);
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _open();
    }
  }

  Future<void> _take() async {
    final controller = _controller;
    if (controller == null || _busy) return;
    setState(() => _busy = true);
    try {
      final photo = await controller.takePicture();
      if (mounted) Navigator.of(context).pop(photo.path);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not take photo. Please try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back'),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
        title: const Text('Take photo'),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              tooltip: 'Switch camera',
              onPressed: _busy || _opening
                  ? null
                  : () {
                      _index = (_index + 1) % _cameras.length;
                      _open();
                    },
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
        ],
      ),
      body: Center(
        child: controller != null && controller.value.isInitialized
            ? CameraPreview(controller)
            : _error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    TextButton(onPressed: _open, child: const Text('Retry')),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton.icon(
            onPressed: controller == null || _busy ? null : _take,
            icon: const Icon(Icons.camera_alt),
            label: Text(_busy ? 'Taking photo...' : 'Take photo'),
          ),
        ),
      ),
    );
  }
}
