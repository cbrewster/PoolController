import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:pool_interface/controller.dart';
import 'dart:async';

class Search extends StatefulWidget {
  Search({Key key, this.title}) : super(key: key);

  final String title;

  @override
  State<StatefulWidget> createState() => _SearchState();
}

abstract class CharacteristicCallback {
  void callback(List<int> data);
}

class _SearchState extends State<Search> {
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
  Map<Guid, StreamSubscription> valueChangedSubscriptions = {};
  BluetoothDeviceState deviceState = BluetoothDeviceState.disconnected;

  // Pool Info
  PoolInfo _poolInfo = PoolInfo();

  @override
  void initState() {
    super.initState();
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
        withServices: [
          new Guid('0000308E-0000-1000-8000-00805F9B34FB')
        ]).listen((scanResult) {
      print('localName: ${scanResult.advertisementData.localName}');
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
      if (s == BluetoothDeviceState.connected) {
        device.discoverServices().then((s) {
          setState(() {
            services = s;
            services.forEach((s) {
              print("Char ${s.characteristics.map((c) {
                return c.uuid;
              })}");
            });
          });
          var poolService = services.firstWhere(
              (s) => s.uuid == Guid("0000308e-0000-1000-8000-00805f9b34fb"));
          poolService?.characteristics?.forEach((c) {
            _setNotification(c);
          });
        });
      }
    });
  }

  _disconnect() {
    valueChangedSubscriptions.forEach((uuid, sub) => sub.cancel());
    valueChangedSubscriptions.clear();
    deviceStateSubscription?.cancel();
    deviceStateSubscription = null;
    deviceConnection?.cancel();
    deviceConnection = null;
    setState(() {
      device = null;
    });
  }

  _readCharacteristic(BluetoothCharacteristic c) async {
    await device.readCharacteristic(c);
    setState(() {});
  }

  _writeCharacteristic(BluetoothCharacteristic c) async {
    await device.writeCharacteristic(c, [0x12, 0x34],
        type: CharacteristicWriteType.withResponse);
    setState(() {});
  }

  _readDescriptor(BluetoothDescriptor d) async {
    await device.readDescriptor(d);
    setState(() {});
  }

  _writeDescriptor(BluetoothDescriptor d) async {
    await device.writeDescriptor(d, [0x12, 0x34]);
    setState(() {});
  }

  _setNotification(BluetoothCharacteristic c) async {
    if (c.isNotifying) {
      await device.setNotifyValue(c, false);
      valueChangedSubscriptions[c.uuid]?.cancel();
      valueChangedSubscriptions.remove(c.uuid);
    } else {
      await device.setNotifyValue(c, true);

      final sub = device.onValueChanged(c).listen((d) {
        setState(() {
          print("Update: $d");
        });
        if (c.uuid == Guid("00008270-0000-1000-8000-00805f9b34fb")) {
          setState(() {
            _poolInfo.waterTemp = d[1];
          });
        }
      });

      valueChangedSubscriptions[c.uuid] = sub;
    }

    setState(() {});
  }

  _refreshDeviceState(BluetoothDevice d) async {
    var state = await d.state;
    setState(() {
      deviceState = state;
      print('State refreshed: $deviceState');
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

  @override
  Widget build(BuildContext context) {
    return isConnected
        ? PoolController(
            poolInfo: _poolInfo,
          )
        : Scaffold(
            appBar: new AppBar(
              title: Text(widget.title),
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
            floatingActionButton: FloatingActionButton(
              child: Icon(Icons.search),
              onPressed: () {
                _startScan();
              },
            ),
          );
  }
}
