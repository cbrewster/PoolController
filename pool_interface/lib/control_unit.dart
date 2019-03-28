import 'package:flutter_blue/flutter_blue.dart';
import 'package:pool_interface/pool_state.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

Guid poolServiceGuid = Guid("0000308E-0000-1000-8000-00805F9B34FB");
Guid _waterTempGuid = Guid("00008270-0000-1000-8000-00805F9B34FB");
Guid _airTempGuid = Guid("00008271-0000-1000-8000-00805F9B34FB");
Guid _pumpManualGuid = Guid("00008272-0000-1000-8000-00805F9B34FB");
Guid _heaterManualGuid = Guid("00008273-0000-1000-8000-00805F9B34FB");
Guid _thermostatGuid = Guid("00008274-0000-1000-8000-00805F9B34FB");
Guid _pumpStatusGuid = Guid("00008275-0000-1000-8000-00805F9B34FB");
Guid _heaterStatusGuid = Guid("00008276-0000-1000-8000-00805F9B34FB");
Guid _pumpTimestampGuid = Guid("00008277-0000-1000-8000-00805F9B34FB");
Guid _heaterTimestampGuid = Guid("00008278-0000-1000-8000-00805F9B34FB");
Guid _timeGuid = Guid("00008279-0000-1000-8000-00805F9B34FB");
Guid _pumpOnTimeGuid = Guid("0000827A-0000-1000-8000-00805F9B34FB");
Guid _pumpOffTimeGuid = Guid("0000827B-0000-1000-8000-00805F9B34FB");

class ControlUnit {
  final BluetoothDevice device;
  final PoolState _state = PoolState();
  Timer _updateTimer;

  final Map<Guid, StreamSubscription> _charSubscriptions = {};
  final StreamController<PoolState> _streamController = StreamController();
  final Map<Guid, BluetoothCharacteristic> _characteristics = {};
  bool loading = true;

  Stream<PoolState> poolState() => _streamController.stream;

  _parseTimestamp(List<int> data) {
    final seconds = _fromBytesToInt32(data);
    final dateTime = new DateTime.fromMillisecondsSinceEpoch((seconds) * 1000);
    return dateTime;
  }

  _fromBytesToInt32(List<int> data) {
    final bytes = Int8List.fromList(data);
    final byteData = ByteData.view(bytes.buffer);
    return byteData.getInt32(0, Endian.little);
  }

  ControlUnit({this.device}) {
    _streamController.add(_state);

    device.discoverServices().then((services) {
      var poolService =
          services.firstWhere((service) => service.uuid == poolServiceGuid);
      if (poolService != null) {
        poolService.characteristics.forEach((characteristic) {
          _characteristics[characteristic.uuid] = characteristic;
          // Subscriber to each characteristic.
          if (characteristic.uuid == _waterTempGuid) {
            _subscribe(characteristic, (data) => _state.waterTemp = data[0]);
          } else if (characteristic.uuid == _airTempGuid) {
            _subscribe(characteristic, (data) => _state.airTemp = data[0]);
          } else if (characteristic.uuid == _pumpManualGuid) {
            _subscribe(
                characteristic, (data) => _state.pumpManual = data[0] == 1);
          } else if (characteristic.uuid == _heaterManualGuid) {
            _subscribe(
                characteristic, (data) => _state.heaterManual = data[0] == 1);
          } else if (characteristic.uuid == _thermostatGuid) {
            _subscribe(characteristic, (data) => _state.thermostat = data[0]);
          } else if (characteristic.uuid == _pumpStatusGuid) {
            _subscribe(
                characteristic, (data) => _state.pumpStatus = data[0] == 1);
          } else if (characteristic.uuid == _heaterStatusGuid) {
            _subscribe(
                characteristic, (data) => _state.heaterStatus = data[0] == 1);
          } else if (characteristic.uuid == _pumpTimestampGuid) {
            _subscribe(characteristic,
                (data) => _state.pumpTimestamp = _parseTimestamp(data));
          } else if (characteristic.uuid == _heaterTimestampGuid) {
            _subscribe(characteristic,
                (data) => _state.heaterTimestamp = _parseTimestamp(data));
          } else if (characteristic.uuid == _pumpOnTimeGuid) {
            _subscribe(characteristic,
                (data) => _state.pumpOnTime = _parseTimeOfDay(data));
          } else if (characteristic.uuid == _pumpOffTimeGuid) {
            _subscribe(characteristic,
                (data) => _state.pumpOffTime = _parseTimeOfDay(data));
          }
        });
        _loadInitial();
      }
    });
    _updateTimer = Timer.periodic(
        Duration(seconds: 1), (_) => _streamController.add(_state));
  }

  _getCharacteristic(BluetoothCharacteristic char) async {
    var data;
    while (data == null) {
      data = await device.readCharacteristic(char);
    }
    return data;
  }

  _parseTimeOfDay(List<int> data) {
    return TimeOfDay(hour: data[1], minute: data[0]);
  }

  _loadInitial() async {
    final time = DateTime.now();
    final int seconds = time.millisecondsSinceEpoch ~/ 1000;
    final data = ByteData(4);
    data.setInt32(0, seconds, Endian.little);

    await device.writeCharacteristic(
        _characteristics[_timeGuid], data.buffer.asUint8List().toList(),
        type: CharacteristicWriteType.withResponse);

    var airTempData = await _getCharacteristic(_characteristics[_airTempGuid]);
    var waterTempData =
        await _getCharacteristic(_characteristics[_waterTempGuid]);
    var pumpManualData =
        await _getCharacteristic(_characteristics[_pumpManualGuid]);
    var heaterManualData =
        await _getCharacteristic(_characteristics[_heaterManualGuid]);
    var thermostatData =
        await _getCharacteristic(_characteristics[_thermostatGuid]);
    var pumpStatusData =
        await _getCharacteristic(_characteristics[_pumpStatusGuid]);
    var heaterStatusData =
        await _getCharacteristic(_characteristics[_heaterStatusGuid]);
    var pumpTimestampData =
        await _getCharacteristic(_characteristics[_pumpTimestampGuid]);
    var heaterTimestampData =
        await _getCharacteristic(_characteristics[_heaterTimestampGuid]);
    var pumpOnTimeData =
        await _getCharacteristic(_characteristics[_pumpOnTimeGuid]);
    var pumpOffTimeData =
        await _getCharacteristic(_characteristics[_pumpOffTimeGuid]);

    _state.airTemp = airTempData[0];
    _state.waterTemp = waterTempData[0];
    _state.pumpManual = pumpManualData[0] == 1;
    _state.heaterManual = heaterManualData[0] == 1;
    _state.thermostat = thermostatData[0];
    _state.pumpStatus = pumpStatusData[0] == 1;
    _state.heaterStatus = heaterStatusData[0] == 1;
    _state.pumpTimestamp = _parseTimestamp(pumpTimestampData);
    _state.heaterTimestamp = _parseTimestamp(heaterTimestampData);
    _state.pumpOnTime = _parseTimeOfDay(pumpOnTimeData);
    _state.pumpOffTime = _parseTimeOfDay(pumpOffTimeData);

    _streamController.add(_state);

    loading = false;
  }

  _subscribe(BluetoothCharacteristic characteristic,
      void onData(List<int> data)) async {
    // Make sure characteristic is set to notify.
    device.setNotifyValue(characteristic, true);

    // Subscribe for subsequent values
    _charSubscriptions[characteristic.uuid] =
        device.onValueChanged(characteristic).listen((data) {
      onData(data);
      _streamController.add(_state);
    });
  }

  void togglePump() {
    _state.pumpManual = !_state.pumpManual;

    device.writeCharacteristic(
        _characteristics[_pumpManualGuid], [_state.pumpManual ? 1 : 0],
        type: CharacteristicWriteType.withResponse);
    _streamController.add(_state);
  }

  void toggleHeater() {
    _state.heaterManual = !_state.heaterManual;
    device.writeCharacteristic(
        _characteristics[_heaterManualGuid], [_state.heaterManual ? 1 : 0],
        type: CharacteristicWriteType.withResponse);
    _streamController.add(_state);
  }

  void decreaseThermostat() {
    _state.thermostat = max(_state.thermostat - 1, 60);
    device.writeCharacteristic(
        _characteristics[_thermostatGuid], [_state.thermostat],
        type: CharacteristicWriteType.withResponse);
    _streamController.add(_state);
  }

  void increaseThermostat() {
    _state.thermostat = min(_state.thermostat + 1, 80);
    device.writeCharacteristic(
        _characteristics[_thermostatGuid], [_state.thermostat],
        type: CharacteristicWriteType.withResponse);
    _streamController.add(_state);
  }

  dispose() {
    _charSubscriptions.forEach((uuid, sub) => sub.cancel());
    _charSubscriptions.clear();
    _streamController.close();
    _updateTimer.cancel();
  }
}
