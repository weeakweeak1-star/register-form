import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverLocationModal extends StatefulWidget {
  final String driverId;
  final String driverName;

  const DriverLocationModal({super.key, required this.driverId, required this.driverName});

  @override
  State<DriverLocationModal> createState() => _DriverLocationModalState();
}

class _DriverLocationModalState extends State<DriverLocationModal> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  LatLng? _currentLocation;
  bool _isOnline = false;
  GoogleMapController? _mapController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInitialLocation();
    _subscribeToLocation();
  }

  Future<void> _fetchInitialLocation() async {
    try {
      final data = await _supabase
          .from('driver_online_status')
          .select()
          .eq('driver_id', widget.driverId)
          .maybeSingle();
      
      if (data != null && data['current_lat'] != null && data['current_lng'] != null) {
        setState(() {
          _currentLocation = LatLng(data['current_lat'] as double, data['current_lng'] as double);
          _isOnline = data['is_online'] ?? false;
          _isLoading = false;
        });
        _moveCamera();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching location: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _subscribeToLocation() {
    _channel = _supabase.channel('public:driver_online_status:driver_id=eq.${widget.driverId}');
    
    _channel!.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(
        event: 'UPDATE',
        schema: 'public',
        table: 'driver_online_status',
        filter: 'driver_id=eq.${widget.driverId}',
      ),
      (payload, [ref]) {
        final newRecord = payload['new'];
        if (newRecord != null && newRecord['current_lat'] != null && newRecord['current_lng'] != null) {
          setState(() {
            _currentLocation = LatLng(newRecord['current_lat'] as double, newRecord['current_lng'] as double);
            _isOnline = newRecord['is_online'] ?? false;
          });
          _moveCamera();
        }
      },
    ).subscribe();
  }

  void _moveCamera() {
    if (_mapController != null && _currentLocation != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(_currentLocation!));
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الموقع الحي: ${widget.driverName}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isOnline ? Colors.green[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(_isOnline ? 'متصل الآن' : 'غير متصل', 
                        style: TextStyle(color: _isOnline ? Colors.green[800] : Colors.grey[800], fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _currentLocation == null
                  ? const Center(child: Text('لا توجد بيانات لموقع هذا الكابتن حالياً.', style: TextStyle(fontSize: 16)))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(target: _currentLocation!, zoom: 15),
                        onMapCreated: (controller) => _mapController = controller,
                        markers: {
                          Marker(
                            markerId: const MarkerId('driver_marker'),
                            position: _currentLocation!,
                            infoWindow: InfoWindow(title: widget.driverName),
                          ),
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
