import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:pool_interface/dashboard.dart';
import 'package:pool_interface/control_unit.dart';
import 'dart:async';

class Bluetooth extends StatefulWidget {
  Bluetooth({Key key, this.title}) : super(key: key);

  final String title;

  @override
  State<StatefulWidget> createState() => _BluetoothState();
}

BluetoothCharacteristic getCharacteristic(Guid charGuid, Guid serviceGuid) {
  return BluetoothCharacteristic(
      uuid: charGuid,
      serviceUuid: serviceGuid,
      descriptors: [],
      properties: null);
}

class _BluetoothState extends State<Bluetooth> {
  FlutterBlue _flutterBlue = FlutterBlue.instance;

  // Scanning
  StreamSubscription _scanSubscription;
  Map<DeviceIdentifier, ScanResult> scanResults = new Map();
  bool isScanning = false;

  // State
  StreamSubscription _stateSubscription;
  BluetoothState state = BluetoothState.unknown;

  // Device
  BluetoothDevice device;
  bool get isConnected => (device != null);
  StreamSubscription deviceConnection;
  StreamSubscription deviceStateSubscription;
  List<BluetoothService> services = new List();
  BluetoothDeviceState deviceState = BluetoothDeviceState.disconnected;

  // Pool Controller
  ControlUnit _controlUnit;

  @override
  void initState() {
    super.initState();

    _flutterBlue.setLogLevel(LogLevel.critical);

    _flutterBlue.state.then((s) {
      setState(() {
        state = s;
      });
    });

    _stateSubscription = _flutterBlue.onStateChanged().listen((s) {
      setState(() {
        state = s;
      });
    });

    _startScan();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _stateSubscription = null;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    deviceConnection?.cancel();
    deviceConnection = null;
    super.dispose();
  }

  _startScan() {
    _scanSubscription = _flutterBlue.scan(
        timeout: const Duration(seconds: 5),
        withServices: [poolServiceGuid]).listen((scanResult) {
      setState(() {
        scanResults[scanResult.device.id] = scanResult;
      });
    }, onDone: _stopScan());

    setState(() {
      isScanning = true;
    });
  }

  _stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    setState(() {
      isScanning = false;
    });
  }

  _connect(BluetoothDevice d) async {
    device = d;
    deviceConnection = _flutterBlue
        .connect(device, timeout: const Duration(seconds: 5))
        .listen(null, onDone: _disconnect);

    device.state.then((s) {
      setState(() {
        deviceState = s;
      });
    });

    deviceStateSubscription = device.onStateChanged().listen((s) {
      setState(() {
        deviceState = s;
      });
      if (s == BluetoothDeviceState.disconnected) {
        setState(() {
          _controlUnit?.dispose();
          _controlUnit = null;
        });
      }
      if (s == BluetoothDeviceState.connected) {
        _controlUnit = ControlUnit(device: device);
      }
    });
  }

  _disconnect() {
    deviceStateSubscription?.cancel();
    deviceStateSubscription = null;
    deviceConnection?.cancel();
    deviceConnection = null;
    setState(() {
      _controlUnit?.dispose();
      _controlUnit = null;
      deviceState = BluetoothDeviceState.disconnected;
      device = null;
    });
  }

  _buildScanningButton() {
    if (isConnected || state != BluetoothState.on) {
      return null;
    }
    if (isScanning) {
      return new FloatingActionButton(
        child: new Icon(Icons.stop),
        onPressed: _stopScan,
        backgroundColor: Colors.red,
      );
    } else {
      return new FloatingActionButton(
        child: new Icon(Icons.search),
        onPressed: _startScan,
      );
    }
  }

  Widget _loading(BuildContext context) {
    return Scaffold(
        appBar: new AppBar(
          title: Text(widget.title),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ));
  }

  Widget _search(BuildContext context) {
    return Scaffold(
        appBar: new AppBar(
          title: Text("Search For Pool Controller"),
        ),
        body: ListView(
          children: scanResults.values.map((result) {
            return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(result.device.name.isEmpty
                      ? "Unamed"
                      : result.device.name),
                  RaisedButton(
                    child: Text("Connect"),
                    onPressed: () {
                      _connect(result.device);
                    },
                  )
                ]);
          }).toList(),
        ),
        floatingActionButton: _buildScanningButton());
  }

  @override
  Widget build(BuildContext context) {
    switch (deviceState) {
      case BluetoothDeviceState.connected:
        {
          if (_controlUnit == null) {
            return _loading(context);
          }
          return Dashboard(
            controlUnit: _controlUnit,
            disconnect: () => _disconnect(),
          );
        }
      case BluetoothDeviceState.connecting:
        {
          return _loading(context);
        }

      default:
        {
          return _search(context);
        }
    }
  }
}
