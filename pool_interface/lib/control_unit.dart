import 'package:flutter_blue/flutter_blue.dart';
import 'package:pool_interface/pool_state.dart';
import 'dart:async';
import 'dart:math';

Guid poolServiceGuid = Guid("0000308E-0000-1000-8000-00805F9B34FB");
Guid _waterTempGuid = Guid("00008270-0000-1000-8000-00805F9B34FB");
Guid _airTempGuid = Guid("00008271-0000-1000-8000-00805F9B34FB");
Guid _pumpOnGuid = Guid("00008272-0000-1000-8000-00805F9B34FB");
Guid _heaterOnGuid = Guid("00008273-0000-1000-8000-00805F9B34FB");
Guid _thermostatGuid = Guid("00008274-0000-1000-8000-00805F9B34FB");

class ControlUnit {
  final BluetoothDevice device;
  final PoolState _state = PoolState();

  final Map<Guid, StreamSubscription> _charSubscriptions = {};
  final StreamController<PoolState> _streamController = StreamController();
  final Map<Guid, BluetoothCharacteristic> _characteristics = {};

  Stream<PoolState> poolState() => _streamController.stream;

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
          } else if (characteristic.uuid == _pumpOnGuid) {
            _subscribe(characteristic, (data) => _state.pumpOn = data[0] == 1);
          } else if (characteristic.uuid == _heaterOnGuid) {
            _subscribe(
                characteristic, (data) => _state.heaterOn = data[0] == 1);
          } else if (characteristic.uuid == _thermostatGuid) {
            _subscribe(characteristic, (data) => _state.thermostat = data[0]);
          }
        });
      }
    });
  }

  _subscribe(
      BluetoothCharacteristic characteristic, void onData(List<int> data)) async {
    // Get initial value.
    await data = device.readCharacteristic(characteristic);

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
    _state.pumpOn = !_state.pumpOn;

    device.writeCharacteristic(
        _characteristics[_pumpOnGuid], [_state.pumpOn ? 1 : 0],
        type: CharacteristicWriteType.withResponse);
    _streamController.add(_state);
  }

  void toggleHeater() {
    _state.heaterOn = !_state.heaterOn;
    device.writeCharacteristic(
        _characteristics[_heaterOnGuid], [_state.heaterOn ? 1 : 0],
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
  }
}
