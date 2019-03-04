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

BluetoothCharacteristic getCharacteristic(String four) {
  return BluetoothCharacteristic(
      uuid: Guid("0000$four-0000-1000-8000-00805F9B34FB"),
      serviceUuid: Guid("0000308E-0000-1000-8000-00805F9B34FB"),
      descriptors: [],
      properties: CharacteristicProperties(write: true, notify: true));
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
    _poolInfo.togglePump = () {
      var pumpOn = _poolInfo.pumpOn ? 0 : 1;
      // Optimistically Update
      _poolInfo.pumpOn = !_poolInfo.pumpOn;
      _writeCharacteristic(getCharacteristic("8272"), [pumpOn]);
    };

    _poolInfo.toggleHeater = () {
      var heaterOn = _poolInfo.heaterOn ? 0 : 1;
      // Optimistically Update
      _poolInfo.heaterOn = !_poolInfo.heaterOn;
      _writeCharacteristic(getCharacteristic("8273"), [heaterOn]);
    };

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
          });
          var poolService = services.firstWhere(
              (s) => s.uuid == Guid("0000308e-0000-1000-8000-00805f9b34fb"));
          poolService?.characteristics?.forEach((c) {
            device.readCharacteristic(c).then((value) {
              if (c.uuid == Guid("00008270-0000-1000-8000-00805f9b34fb")) {
                setState(() {
                  _poolInfo.waterTemp = value[0];
                });
              } else if (c.uuid ==
                  Guid("00008271-0000-1000-8000-00805f9b34fb")) {
                setState(() {
                  _poolInfo.airTemp = value[0];
                });
              } else if (c.uuid ==
                  Guid("00008272-0000-1000-8000-00805f9b34fb")) {
                setState(() {
                  _poolInfo.pumpOn = value[0] == 1;
                });
              } else if (c.uuid ==
                  Guid("00008273-0000-1000-8000-00805f9b34fb")) {
                setState(() {
                  _poolInfo.heaterOn = value[0] == 1;
                });
              }
            });
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

  _writeCharacteristic(BluetoothCharacteristic c, List<int> values) async {
    await device.writeCharacteristic(c, values,
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
        if (c.uuid == Guid("00008270-0000-1000-8000-00805f9b34fb")) {
          setState(() {
            _poolInfo.waterTemp = d[0];
          });
        } else if (c.uuid == Guid("00008271-0000-1000-8000-00805f9b34fb")) {
          setState(() {
            _poolInfo.airTemp = d[0];
          });
        } else if (c.uuid == Guid("00008272-0000-1000-8000-00805f9b34fb")) {
          setState(() {
            _poolInfo.pumpOn = d[0] == 1;
          });
        } else if (c.uuid == Guid("00008273-0000-1000-8000-00805f9b34fb")) {
          setState(() {
            _poolInfo.heaterOn = d[0] == 1;
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
        floatingActionButton: _buildScanningButton());
  }

  @override
  Widget build(BuildContext context) {
    switch (deviceState) {
      case BluetoothDeviceState.connected:
        {
          if (_poolInfo.isLoading()) {
            return _loading(context);
          }

          return PoolController(
            poolInfo: _poolInfo,
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
