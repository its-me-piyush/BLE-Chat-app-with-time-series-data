import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:poc_ble_timeseries_data/models/time_series_data_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimeSeriesDataProvider extends ChangeNotifier {
  final List<TimeSeriesDataModel> _list = [];

  List<TimeSeriesDataModel> get data {
    return [..._list];
  }

  Future<void> storeData(String? jsonData) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    if (jsonData != null) {
      debugPrint("[INFO] jsonData to be stored: $jsonData");
      List<TimeSeriesDataModel> oldDataList = [];
      if (prefs.containsKey("jsonData")) {
        String? oldData = prefs.getString("jsonData");
        var oldDataListData = json.decode(oldData!) as List<dynamic>;
        for (var element in oldDataListData) {
          oldDataList.add(TimeSeriesDataModel.fromJson(element));
        }
      }
      TimeSeriesDataModel newData =
          TimeSeriesDataModel.fromJson(json.decode(jsonData));
      oldDataList.add(newData);
      await prefs.setString('jsonData', json.encode(oldDataList));
      debugPrint(
          "[INFO] after saving it in local: ${json.encode(oldDataList)}");
      notifyListeners();
    }

    // notifyListeners();
  }

  Future<void> dummySendData() async {
    Map<String, dynamic> data = {
      "instantaneousPower": {
        "value": generateRandomInstantaneousPower(),
        "timestamp": DateTime.now().millisecondsSinceEpoch
      },
      "batteryChargeLevel": {
        "value": generateRandomBatteryChargeLevel(),
        "timestamp": DateTime.now().millisecondsSinceEpoch
      },
      "batteryTemperature": {
        "value": generateRandomBatteryTemperature(),
        "timestamp": DateTime.now().millisecondsSinceEpoch
      }
    };
    await storeData(json.encode(data));
  }

  Future<void> deleteStoredData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    prefs.clear();
    _list.clear();
    debugPrint("[INFO] DELETED ALL DATA");
    debugPrint("${prefs.containsKey("jsonData")}");

    notifyListeners();
  }

  Future<List<TimeSeriesDataModel>> getData() async {
    debugPrint("[INFO] GET DATA");
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString("jsonData");
    List<TimeSeriesDataModel> oldData = [];
    if (data != null) {
      _list.clear();
      var temp = json.decode(data) as List<dynamic>;
      for (var element in temp) {
        oldData.add(TimeSeriesDataModel.fromJson(element));
      }

      _list.addAll(oldData);
    }
    debugPrint("[INFO] IN get data: $_list");
    return _list;
  }

  double generateRandomInstantaneousPower() {
    final Random random = Random();
    final double voltage = random.nextDouble() * 100;
    final double current = random.nextDouble() * 10;
    final double power = voltage * current;
    return power;
  }

  double generateRandomBatteryChargeLevel() {
    final Random random = Random();
    return (random.nextInt(101)) / 100.0;
  }

  double generateRandomBatteryTemperature() {
    final Random random = Random();
    return random.nextDouble() * 70 - 20;
  }

  String sendData() {
    Map<String, dynamic> data = {
      "instantaneousPower": {
        "value": generateRandomInstantaneousPower(),
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      },
      "batteryChargeLevel": {
        "value": generateRandomBatteryChargeLevel(),
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      },
      "batteryTemperature": {
        "value": generateRandomBatteryTemperature(),
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      }
    };

    return json.encode(data);
  }
}
