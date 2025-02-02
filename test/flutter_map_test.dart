import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_map/src/gestures/flutter_map_interactive_viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'test_utils/test_app.dart';

void main() {
  testWidgets('flutter_map', (tester) async {
    final markers = <Marker>[
      Marker(
        width: 80,
        height: 80,
        point: const LatLng(45.5231, -122.6765),
        builder: (_) => const FlutterLogo(),
      ),
      Marker(
        width: 80,
        height: 80,
        point: const LatLng(40, -120), // not visible
        builder: (_) => const FlutterLogo(),
      ),
    ];

    await tester.pumpWidget(TestApp(markers: markers));
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TileLayer), findsOneWidget);
    expect(find.byType(RawImage), findsWidgets);
    expect(find.byType(MarkerLayer), findsWidgets);
    expect(find.byType(FlutterLogo), findsOneWidget);
  });

  testWidgets(
      'FlutterMap - Bottom ViewInsets (e.g. keyboard) do not trigger rebuilds.',
      (tester) async {
    int builds = 0;

    final map = FlutterMap(
      options: const MapOptions(
        initialCenter: LatLng(45.5231, -122.6765),
        initialZoom: 13,
      ),
      children: [
        Builder(
          builder: (context) {
            final _ = MapCamera.of(context);
            builds++;
            return const SizedBox.shrink();
          },
        ),
      ],
    );

    Widget wrapMapInApp({required double bottomInset}) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(
            viewInsets: EdgeInsets.only(bottom: bottomInset),
          ),
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: map,
          ),
        ),
      );
    }

    await tester.pumpWidget(wrapMapInApp(bottomInset: 0));
    expect(find.byType(FlutterMap), findsOneWidget);

    // Emulate a keyboard popping up by putting a non-zero bottom ViewInset.
    await tester.pumpWidget(wrapMapInApp(bottomInset: 100));

    // The map should not have rebuild after the first build.
    expect(builds, equals(1));
  });

  testWidgets('gestures work with no tile layer and transparent background.',
      (tester) async {
    int taps = 0;
    late MapCamera camera;

    final map = MaterialApp(
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        body: FlutterMap(
          options: MapOptions(
            backgroundColor: Colors.transparent,
            maxZoom: 9,
            initialZoom: 10, // Higher than maxZoom.
            onTap: (_, __) {
              taps++;
            },
          ),
          children: [
            Builder(
              builder: (context) {
                camera = MapCamera.of(context);
                return const SizedBox.shrink();
              },
            )
          ],
        ),
      ),
    );

    // Check that taps are still received.
    await tester.pumpWidget(map);
    expect(taps, 0);
    await tester.tap(find.byType(FlutterMap));
    await tester.pumpAndSettle(FlutterMapInteractiveViewerState.doubleTapDelay);
    expect(taps, 1);

    // Store the camera before pinch zooming.
    final cameraBeforePinchZoom = camera;

    // Create two touches.
    final center = tester.getCenter(find.byType(FlutterMap));
    final touch1 = await tester.startGesture(center.translate(-10, 0));
    final touch2 = await tester.startGesture(center.translate(10, 0));

    // Zoom in.
    await touch1.moveBy(const Offset(-100, 0));
    await touch2.moveBy(const Offset(100, 0));
    await tester.pump();

    // Check that the pinch zoom caused the camera to change.
    expect(camera.zoom, isNot(cameraBeforePinchZoom.center));
  });

  testWidgets('MapCamera.of only notifies dependencies when camera changes',
      (tester) async {
    int buildCount = 0;
    final Widget builder = Builder(builder: (BuildContext context) {
      MapCamera.of(context);
      buildCount++;
      return const SizedBox.shrink();
    });

    await tester.pumpWidget(TestRebuildsApp(child: builder));
    expect(buildCount, equals(1));

    await tester.tap(find.widgetWithText(TextButton, 'Change flags'));
    await tester.pumpAndSettle();
    expect(buildCount, equals(1));

    await tester.tap(find.widgetWithText(TextButton, 'Change MapController'));
    await tester.pumpAndSettle();
    expect(buildCount, equals(1));

    await tester.tap(find.widgetWithText(TextButton, 'Change Crs'));
    await tester.pumpAndSettle();
    expect(buildCount, equals(2));
  });

  testWidgets('MapOptions.of only notifies dependencies when options change',
      (tester) async {
    int buildCount = 0;
    final Widget builder = Builder(builder: (BuildContext context) {
      MapOptions.of(context);
      buildCount++;
      return const SizedBox.shrink();
    });

    await tester.pumpWidget(TestRebuildsApp(child: builder));
    expect(buildCount, equals(1));

    await tester.tap(find.widgetWithText(TextButton, 'Change flags'));
    await tester.pumpAndSettle();
    expect(buildCount, equals(2));

    await tester.tap(find.widgetWithText(TextButton, 'Change MapController'));
    await tester.pumpAndSettle();
    expect(buildCount, equals(2));

    await tester.tap(find.widgetWithText(TextButton, 'Change Crs'));
    await tester.pumpAndSettle();
    expect(buildCount, equals(3));
  });

  testWidgets(
      'MapController.of only notifies dependencies when controller changes',
      (tester) async {
    int buildCount = 0;
    final Widget builder = Builder(builder: (BuildContext context) {
      MapController.of(context);
      buildCount++;
      return const SizedBox.shrink();
    });

    await tester.pumpWidget(TestRebuildsApp(child: builder));
    expect(buildCount, equals(1));

    await tester.tap(find.widgetWithText(TextButton, 'Change flags'));
    await tester.pumpAndSettle();
    expect(buildCount, equals(1));

    await tester.tap(find.widgetWithText(TextButton, 'Change MapController'));
    await tester.pumpAndSettle();
    expect(buildCount, equals(2));

    await tester.tap(find.widgetWithText(TextButton, 'Change Crs'));
    await tester.pumpAndSettle();
    expect(buildCount, equals(2));
  });
}

class TestRebuildsApp extends StatefulWidget {
  final Widget child;

  const TestRebuildsApp({
    super.key,
    required this.child,
  });

  @override
  State<TestRebuildsApp> createState() => _TestRebuildsAppState();
}

class _TestRebuildsAppState extends State<TestRebuildsApp> {
  MapController _mapController = MapController();
  Crs _crs = const Epsg3857();
  int _interactiveFlags = InteractiveFlag.all;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            crs: _crs,
            interactionOptions: InteractionOptions(
              flags: _interactiveFlags,
            ),
          ),
          children: [
            widget.child,
            Column(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _interactiveFlags =
                          InteractiveFlag.hasDrag(_interactiveFlags)
                              ? _interactiveFlags & ~InteractiveFlag.drag
                              : InteractiveFlag.all;
                    });
                  },
                  child: const Text('Change flags'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _crs = _crs == const Epsg3857()
                          ? const Epsg4326()
                          : const Epsg3857();
                    });
                  },
                  child: const Text('Change Crs'),
                ),
                TextButton(
                  onPressed: () {
                    _mapController.dispose();
                    setState(() {
                      _mapController = MapController();
                    });
                  },
                  child: const Text('Change MapController'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
