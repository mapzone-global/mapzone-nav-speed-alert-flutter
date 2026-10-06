import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapzone_nav_speed_alert/mapzone_nav_speed_alert.dart';
import 'package:provider/provider.dart';
import 'package:vietmap_flutter_navigation/models/direction_route.dart';
import 'package:vietmap_flutter_navigation/vietmap_flutter_navigation.dart';

import '../env.dart';
import '../services/route_polyline.dart';
import '../services/vietmap_search.dart';
import '../state/alert_controller.dart';
import '../state/permission_controller.dart';
import '../widgets/bottom_action_bar.dart';
import '../widgets/destination_search_bar.dart';
import '../widgets/map_control_cluster.dart';
import '../widgets/mute_sheet.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/sign_widgets.dart';

/// One map with everything floating on top of it.
///
/// Route-based flow:
///   destination picked → `buildRoute` → `onRouteBuilt(route)`
///   Start → `startNavigation` + `NavSpeedAlert.start(polyline of route)`
///   every progress tick → `NavSpeedAlert.onLocation(snapped position)`
///   navigation reroutes (new `onRouteBuilt`) or the engine reports
///   `onReroute` → alert restarted on the new route
///   Stop / arrival → `NavSpeedAlert.reset`
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  MapNavigationViewController? _controller;
  late final MapOptions _options;

  // 197 Trần Phú, Q5 — the fallback shown before a GPS fix lands.
  static const LatLng _fallbackOrigin = LatLng(10.759222, 106.675902);

  LatLng? _currentLocation;
  LatLng? _destination;
  String? _destinationLabel;

  // The last built route and where it starts (needed to refetch its geometry
  // on iOS, see RoutePolyline). _routeOrigin is the origin of a buildRoute call
  // still in flight; _lastSnapped is the latest position on the driven route.
  DirectionRoute? _route;
  LatLng? _routeOrigin;
  LatLng? _routeFrom;
  LatLng? _lastSnapped;

  // Bumped per alert start and on exit; see _startAlert.
  int _alertGeneration = 0;

  bool _buildingRoute = false;
  bool _navigating = false;
  bool _exiting = false;

  static const String _myLocationAsset = 'assets/markers/current_location.png';
  int? _myLocationMarkerId;

  bool _simulate = true;
  double _speedMultiplier = 1;

  // Speed fed to the engine while simulating, before the multiplier: high
  // enough that a 2× multiplier clears a 50–80 km/h limit. See _onProgress.
  static const double _simBaseSpeedKmh = 45;

  bool get _routeBuilt => _route != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _primePermissions());
    final alert = context.read<AlertController>()
      ..onReroute = _onEngineReroute
      ..addListener(_showSegmentError);
    _alert = alert;
    _options = MapOptions(
      apiKey: Env.vietmapApiKey,
      mapStyle: Env.vietmapMapStyle,
      simulateRoute: _simulate,
      initialLatitude: _fallbackOrigin.latitude,
      initialLongitude: _fallbackOrigin.longitude,
      zoom: 15,
      // The alert SDK provides the safety voice and this example draws its own
      // HUD, so silence the navigation SDK's TTS and banner.
      voiceInstructionsEnabled: false,
      bannerInstructionsEnabled: false,
      language: 'vi',
    );
  }

  late final AlertController _alert;

  @override
  void dispose() {
    _alert
      ..onReroute = null
      ..removeListener(_showSegmentError);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<PermissionController>().refresh();
    }
  }

  // ── Permission ──────────────────────────────────────────────────────────────

  Future<void> _primePermissions() async {
    final perm = context.read<PermissionController>();
    await perm.refresh();
    if (!mounted || !perm.serviceEnabled || perm.needsSettings) return;
    if (!perm.granted) {
      await perm.request();
    } else if (!perm.always) {
      await perm.requestAlways();
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final perm = context.read<PermissionController>();
    await perm.refresh();
    if (!mounted) return false;

    if (!perm.serviceEnabled) {
      _snack('Dịch vụ vị trí đang tắt. Bật Location Services trong Cài đặt.');
      return false;
    }
    if (!perm.granted) {
      if (perm.needsSettings) {
        await _showSettingsDialog();
        return false;
      }
      final granted = await perm.request();
      if (!mounted) return false;
      if (!granted) {
        await _showSettingsDialog();
        return false;
      }
    }
    return true;
  }

  Future<void> _showSettingsDialog() async {
    final perm = context.read<PermissionController>();
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cần quyền vị trí'),
        content: const Text(
          'Ứng dụng cần quyền vị trí để cảnh báo tốc độ. Bật lại trong Cài đặt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Để sau'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Mở Cài đặt'),
          ),
        ],
      ),
    );
    if (open == true) await perm.openSettings();
  }

  // ── Route ───────────────────────────────────────────────────────────────────

  /// Builds a route to the current destination; `onRouteBuilt` takes over.
  Future<bool> _buildRoute(LatLng origin) async {
    setState(() => _buildingRoute = true);
    _routeOrigin = origin;
    _options.simulateRoute = _simulate;
    final built = await _controller?.buildRoute(
      waypoints: [origin, _destination!],
      options: _options,
    );
    if (!mounted) return false;
    if (built != true) {
      setState(() => _buildingRoute = false);
      _snack('Không tạo được tuyến.');
      return false;
    }
    return true;
  }

  void _onRouteBuilt(DirectionRoute route) {
    // Where this route starts: the origin we asked for, or — when the
    // navigation SDK rerouted on its own — the last snapped position.
    _routeFrom =
        _routeOrigin ?? _lastSnapped ?? _currentLocation ?? _fallbackOrigin;
    _routeOrigin = null;
    setState(() {
      _route = route;
      _buildingRoute = false;
    });
    // Built while driving = the navigation SDK (or the engine, via onReroute)
    // replaced the route: follow it with the alert.
    if (_navigating) _startAlert(route);
  }

  Future<void> _startAlert(DirectionRoute route) async {
    // Only the newest request may start the engine: resolving can take a
    // network round-trip (iOS), during which a newer route or Stop may land.
    final generation = ++_alertGeneration;
    final polyline = await RoutePolyline.resolve(
      route,
      origin: _routeFrom ?? _fallbackOrigin,
      destination: _destination!,
    );
    if (!mounted || generation != _alertGeneration || !_navigating) return;
    if (polyline == null) {
      _snack('Không lấy được hình học tuyến cho cảnh báo.');
      return;
    }
    await _alert.startRoute(polyline);
  }

  /// The engine lost the route (a real detour): build a new one from there.
  void _onEngineReroute(RerouteEvent e) {
    if (!_navigating || _destination == null || _buildingRoute) return;
    _snack('Lệch tuyến — đang tạo tuyến mới…');
    _buildRoute(LatLng(e.lat, e.lng));
  }

  void _showSegmentError() {
    final err = _alert.lastError;
    if (err == null) return;
    _alert.clearError();
    _snack('Lỗi tải dữ liệu tuyến (${err.errorCode}): ${err.errorMessage}');
  }

  // ── Start / stop ────────────────────────────────────────────────────────────

  Future<void> _start() async {
    if (_destination == null) return;
    if (!Env.hasAlertCredentials) {
      _snack(
        'Thiếu thông tin xác thực — chạy với --dart-define-from-file=env.json',
      );
      return;
    }
    final configureError = _alert.configureError;
    if (configureError != null) {
      _snack('Không cấu hình được cảnh báo: $configureError');
      return;
    }
    if (!await _ensureLocationPermission()) return;
    if (!mounted) return;
    await _clearMyLocationMarker();

    if (!_routeBuilt) {
      final origin = _currentLocation ?? await _resolveCurrentLocation();
      if (!mounted || !await _buildRoute(origin ?? _fallbackOrigin)) return;
    }

    await _controller?.startNavigation(options: _options);
    if (_simulate) await _controller?.setSpeedMultiplier(_speedMultiplier);
    if (!mounted) return;
    setState(() {
      _buildingRoute = false;
      _navigating = true;
    });
    final route = _route;
    if (route != null) await _startAlert(route);
  }

  Future<void> _onArrival() async {
    await _exitNavigation();
    if (mounted) _snack('Đã đến nơi.');
  }

  Future<void> _exitNavigation() async {
    if (_exiting) return; // arrival + a Stop tap could both land here
    _exiting = true;
    _alertGeneration++; // drop any alert start still resolving its route
    final wasNavigating = _navigating;
    if (_navigating) {
      // Never completes on iOS; see _fireAndForget.
      _fireAndForget(_controller?.finishNavigation());
    }
    await _alert.stopRoute();
    if (!mounted) {
      _exiting = false;
      return;
    }
    setState(() {
      _navigating = false;
      _route = null;
      _lastSnapped = null;
    });
    if (wasNavigating) {
      final here = _currentLocation ?? await _resolveCurrentLocation();
      if (here != null && mounted) {
        _fireAndForget(_controller?.animateCamera(latLng: here, zoom: 16.5));
      }
    }
    _exiting = false;
  }

  // ── Destination ─────────────────────────────────────────────────────────────

  /// Picking a destination builds the route right away, so Start goes straight
  /// into navigation.
  Future<void> _selectDestination(SearchResult r) async {
    final coord = await VietmapSearch.place(r.refId);
    if (coord == null || !mounted) {
      _snack('Không lấy được toạ độ điểm đến.');
      return;
    }
    final dest = LatLng(coord[0], coord[1]);
    await _controller?.clearRoute();
    if (!mounted) return;
    setState(() {
      _destination = dest;
      _destinationLabel = r.display;
      _route = null;
    });
    _fireAndForget(_controller?.animateCamera(latLng: dest, zoom: 15.5));

    final origin = _currentLocation ?? await _resolveCurrentLocation();
    if (!mounted) return;
    await _buildRoute(origin ?? _fallbackOrigin);
  }

  void _clearDestination() {
    setState(() {
      _destination = null;
      _destinationLabel = null;
      _route = null;
    });
    _controller?.clearRoute();
  }

  // ── Location ────────────────────────────────────────────────────────────────

  Future<LatLng?> _resolveCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Dịch vụ vị trí đang tắt.');
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      _currentLocation = latLng;
      return latLng;
    } on TimeoutException {
      _snack('Hết thời gian chờ GPS. Thử lại ngoài trời hoặc dùng mô phỏng.');
      return null;
    } catch (e) {
      _snack('Không lấy được vị trí: $e');
      return null;
    }
  }

  /// Do NOT call `controller.recenter()` while idle: the navigation plugin's
  /// iOS handler force-unwraps a location that is only set during navigation.
  Future<void> _recenter() async {
    if (_navigating) {
      _fireAndForget(_controller?.recenter());
      return;
    }
    if (!await _ensureLocationPermission()) return;
    final here = await _resolveCurrentLocation();
    if (here == null || !mounted) return;
    await _dropMyLocationMarker(here);
    _fireAndForget(_controller?.animateCamera(latLng: here, zoom: 16.5));
  }

  /// Several `MapNavigationViewController` calls (`animateCamera`, `recenter`,
  /// `overview`, `finishNavigation`) never complete their Future on iOS, so
  /// anything that must run afterwards cannot await them.
  void _fireAndForget(Future<void>? future) {
    if (future != null) unawaited(future);
  }

  Future<void> _dropMyLocationMarker(LatLng at) async {
    await _clearMyLocationMarker();
    final added = await _controller?.addImageMarkers([
      NavigationMarker(
        imagePath: _myLocationAsset,
        latLng: at,
        width: 48,
        height: 48,
      ),
    ]);
    if (added != null && added.isNotEmpty) {
      _myLocationMarkerId = added.first.markerId;
    }
  }

  Future<void> _clearMyLocationMarker() async {
    if (_myLocationMarkerId == null) return;
    await _controller?.removeMarkers([_myLocationMarkerId!]);
    _myLocationMarkerId = null;
  }

  void _onProgress(RouteProgressEvent e) {
    // Not every build fires onArrival in simulation; the progress flag does.
    if (e.arrived == true && _navigating) {
      _onArrival();
      return;
    }
    final loc = e.snappedLocation;
    if (!_navigating || loc?.latitude == null || loc?.longitude == null) return;

    final double speedKmh;
    if (_simulate) {
      // Replayed city speeds sit below 30 km/h and never exceed a limit, so
      // feed a fixed base scaled by the multiplier: 45 → 67 → 90 → 135 km/h.
      speedKmh = _simBaseSpeedKmh * _speedMultiplier;
    } else {
      // m/s, and -1 when iOS cannot determine it.
      final ms = loc!.speed?.toDouble() ?? 0;
      speedKmh = ms <= 0 ? 0 : ms * 3.6;
    }

    final here = LatLng(loc!.latitude!.toDouble(), loc.longitude!.toDouble());
    _lastSnapped = here;
    _currentLocation = here;
    _alert.onLocation(
      lat: here.latitude,
      lng: here.longitude,
      bearing: loc.bearing?.toDouble() ?? 0,
      speedKmh: speedKmh,
    );
  }

  // ── Sheets & dialogs ────────────────────────────────────────────────────────

  void _openMuteSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          const FractionallySizedBox(heightFactor: 0.85, child: MuteSheet()),
    );
  }

  Future<void> _openSettings() async {
    final result = await showDialog<SettingsResult>(
      context: context,
      builder: (_) => SettingsDialog(
        vehicle: _alert.vehicle,
        simulate: _simulate,
        speedMultiplier: _speedMultiplier,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _simulate = result.simulate;
      _speedMultiplier = result.speedMultiplier;
    });
    _options.simulateRoute = result.simulate;
    await _alert.applyVehicle(result.vehicle);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Not `context.watch<AlertController>()`: that would rebuild the platform
    // map view on every tick. Engine-driven widgets subscribe on their own.
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          NavigationView(
            mapOptions: _options,
            onMapCreated: (c) => _controller = c,
            onRouteBuilt: _onRouteBuilt,
            onNewRouteSelected: _onRouteBuilt,
            onRouteBuildFailed: (msg) {
              setState(() {
                _route = null;
                _buildingRoute = false;
              });
              _snack('Tạo tuyến thất bại: $msg');
            },
            onRouteProgressChange: _onProgress,
            onArrival: _onArrival,
          ),
          Positioned(top: topInset + 96, left: 12, child: const SignOverlay()),
          if (_navigating)
            Positioned(
              top: topInset + 96,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  SpeedChip(),
                  SizedBox(height: 8),
                  SizedBox(width: 160, child: RestrictionRow()),
                ],
              ),
            ),
          if (!_navigating)
            Positioned(
              top: topInset + 12,
              left: 12,
              right: 12,
              child: DestinationSearchBar(
                destinationLabel: _destinationLabel,
                onSelected: _selectDestination,
                onCleared: _clearDestination,
              ),
            ),
          Positioned(
            right: 16,
            bottom: bottomInset + 96,
            child: MapControlCluster(
              showSettings: !_navigating,
              showOverview: _routeBuilt,
              onSettings: _openSettings,
              onOverview: () => _controller?.overview(),
              onMute: _openMuteSheet,
              onRecenter: _recenter,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 12,
            child: Selector<AlertController, int>(
              selector: (_, c) => c.loadedSegments,
              builder: (_, segments, _) => BottomActionBar(
                running: _navigating,
                busy: _buildingRoute,
                hasDestination: _destination != null,
                statusLine: _destinationLabel ?? 'Đang điều hướng',
                engineReady: segments > 0,
                engineStatus: segments > 0
                    ? 'Đã tải $segments đoạn tuyến'
                    : 'Đang tải dữ liệu tuyến…',
                onStart: _start,
                onStop: _exitNavigation,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
