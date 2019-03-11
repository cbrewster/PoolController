import 'package:flutter/material.dart';

class PoolState {
  PoolState();

  int waterTemp;
  int airTemp;
  int thermostat;
  bool pumpOn;
  bool heaterOn;

  bool isLoading() {
    return waterTemp == null ||
        airTemp == null ||
        pumpOn == null ||
        heaterOn == null ||
        thermostat == null;
  }
}
