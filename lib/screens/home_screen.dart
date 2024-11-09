import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:poc_ble_timeseries_data/models/time_series_data_model.dart';

import 'package:poc_ble_timeseries_data/providers/time_series_data_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = "Dummy Data";
  final Strategy strategy = Strategy.P2P_STAR;
  Map<String, ConnectionInfo> endpointMap = {};

  bool _allPermissions = false;
  bool _checkingPermissions = false;
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  bool _stopSharing = false;
  bool _isSendingData = false;

  void _shareData() {
    setState(() {
      _isSendingData = true;
      _stopSharing = false;
    });
    Timer timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      endpointMap.forEach((key, value) {
        // String a = Random().nextInt(100).toString();

        String jsonData = TimeSeriesDataProvider().sendData();
        List<int> utfData = utf8.encode(jsonData);
        Nearby().sendBytesPayload(key, Uint8List.fromList(utfData));
      });
      if (_stopSharing) {
        timer.cancel();
        _isSendingData = false;
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          "Sending data every 3 seconds",
        ),
        duration: const Duration(days: 365),
        action: SnackBarAction(
          label: 'Stop',
          onPressed: () {
            setState(() {
              _stopSharing = true;
              _isSendingData = false;
              timer.cancel();
              ScaffoldMessenger.of(context).clearSnackBars();
            });
          },
        ),
      ),
    );
  }

  void showSnackbar(dynamic a) {
    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    //   content: Text(a.toString()),
    // ));
  }

  void onConnectionInit(String id, ConnectionInfo info) {
    showModalBottomSheet(
      context: context,
      builder: (builder) {
        TimeSeriesDataProvider provider =
            Provider.of<TimeSeriesDataProvider>(context, listen: false);
        return Center(
          child: Column(
            children: <Widget>[
              Text("id: $id"),
              Text("Token: ${info.authenticationToken}"),
              Text("Name${info.endpointName}"),
              Text("Incoming: ${info.isIncomingConnection}"),
              ElevatedButton(
                child: const Text("Accept Connection"),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    endpointMap[id] = info;
                  });
                  Nearby().acceptConnection(
                    id,
                    onPayLoadRecieved: (endid, payload) async {
                      if (payload.type == PayloadType.BYTES) {
                        String str = String.fromCharCodes(payload.bytes!);
                        showSnackbar("$endid: $str");

                        try {
                          await provider.storeData(str);
                          showSnackbar('[INFO] Data Recieved!');
                        } catch (e) {
                          showSnackbar('Error in recieved data: $e');
                        }
                      }
                    },
                    onPayloadTransferUpdate: (endid, payloadTransferUpdate) {
                      if (payloadTransferUpdate.status ==
                          PayloadStatus.IN_PROGRESS) {
                        showSnackbar(
                            "Payload Transfer Update - bite Transfered: ${payloadTransferUpdate.bytesTransferred} ");
                      } else if (payloadTransferUpdate.status ==
                          PayloadStatus.FAILURE) {
                        showSnackbar("$endid: FAILED to transfer file");
                      } else if (payloadTransferUpdate.status ==
                          PayloadStatus.SUCCESS) {
                        showSnackbar(
                            "$endid success, total bytes = ${payloadTransferUpdate.totalBytes}");
                      }
                    },
                  );
                },
              ),
              ElevatedButton(
                child: const Text("Reject Connection"),
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await Nearby().rejectConnection(id);
                  } catch (e) {
                    showSnackbar(e);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _startAdvertising() async {
    try {
      bool a = await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: onConnectionInit,
        onConnectionResult: (id, status) {
          showSnackbar(status);
        },
        onDisconnected: (id) {
          showSnackbar(
              "Disconnected: ${endpointMap[id]!.endpointName}, id $id");
          setState(() {
            endpointMap.remove(id);
          });
        },
      );

      setState(() {
        _isAdvertising = true;
      });
      showSnackbar("ADVERTISING: $a");
    } catch (exception) {
      showSnackbar(exception);
    }
  }

  void _stopAdvertising() async {
    await Nearby().stopAdvertising();
    setState(() {
      _isAdvertising = false;
    });
    showSnackbar("Stopped Advertising");
  }

  void _checkUserPermissions() async {
    setState(() {
      _checkingPermissions = true;
    });

    List<Permission> permissionsToCheck = [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ];

    for (var permission in permissionsToCheck) {
      if (await permission.isDenied) {
        await permission.request();
      }
    }

    if (await Permission.locationWhenInUse.isGranted) {
      await Permission.nearbyWifiDevices.request();
      await Permission.storage.request();
    }

    List<Future<bool>> permissionChecks =
        permissionsToCheck.map((permission) => permission.isGranted).toList();

    bool allPermissionsGranted =
        (await Future.wait(permissionChecks)).every((result) => result);

    setState(() {
      _allPermissions = allPermissionsGranted;
    });

    setState(() {
      _checkingPermissions = false;
    });
  }

  void _startDiscovery() async {
    try {
      bool a = await Nearby().startDiscovery(
        userName,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          // show sheet automatically to request connection
          showModalBottomSheet(
            context: context,
            builder: (builder) {
              return Center(
                child: Column(
                  children: <Widget>[
                    Text("id: $id"),
                    Text("Name: $name"),
                    Text("ServiceId: $serviceId"),
                    ElevatedButton(
                      child: const Text("Request Connection"),
                      onPressed: () {
                        Navigator.pop(context);
                        Nearby().requestConnection(
                          userName,
                          id,
                          onConnectionInitiated: (id, info) {
                            onConnectionInit(id, info);
                          },
                          onConnectionResult: (id, status) {
                            showSnackbar(status);
                          },
                          onDisconnected: (id) {
                            setState(() {
                              endpointMap.remove(id);
                            });
                            showSnackbar(
                                "Disconnected from: ${endpointMap[id]!.endpointName}, id $id");
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        onEndpointLost: (id) {
          showSnackbar(
              "Lost discovered Endpoint: ${endpointMap[id]?.endpointName}, id $id");
        },
      );
      showSnackbar("DISCOVERING: $a");
      setState(() {
        _isDiscovering = true;
      });
    } catch (e) {
      showSnackbar(e);
    }
  }

  void _stopDiscovery() async {
    await Nearby().stopDiscovery();
    setState(() {
      _isDiscovering = false;
    });
    showSnackbar("Stopped Discovery");
  }

  void _stopAllEndpoints() async {
    await Nearby().stopAllEndpoints();
    setState(() {
      endpointMap.clear();
    });
    showSnackbar("All Devices Disconnected!");
  }

  @override
  void initState() {
    super.initState();
    _checkUserPermissions();
  }

  @override
  Widget build(BuildContext context) {
    TimeSeriesDataProvider timeSeriesDataProvider =
        Provider.of<TimeSeriesDataProvider>(context, listen: false);
    return _checkingPermissions
        ? const SimpleDialog(
            title: Text("Checking permissions"),
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Please wait..."),
                ],
              ),
            ],
          )
        : Scaffold(
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
              title: const Text("POC - TimeSeries + BLE"),
            ),
            floatingActionButton:
                Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              FloatingActionButton(
                onPressed: timeSeriesDataProvider.deleteStoredData,
                child: const Icon(Icons.delete),
              ),
              const SizedBox(
                height: 10,
              ),
              FloatingActionButton(
                onPressed: timeSeriesDataProvider.dummySendData,
                child: const Icon(Icons.data_object_rounded),
              ),
              const SizedBox(
                height: 10,
              ),
              FloatingActionButton(
                onPressed: () {
                  if (_isSendingData) {
                    setState(() {
                      _stopSharing = true;
                      _isSendingData = false;
                    });
                  }
                },
                backgroundColor:
                    _isSendingData ? Colors.deepPurple : Colors.grey,
                child: const Icon(Icons.stop_screen_share_rounded),
              ),
            ]),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Consumer<TimeSeriesDataProvider>(
                builder: (context, value, child) {
                  debugPrint("[INFO] FROM HOME data: ${value.data.length}");
                  return FutureBuilder(
                    future: value.getData(),
                    builder: (context, snapshot) {
                      var data = snapshot.data;
                      if (data != null) {
                        return SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: SfCartesianChart(
                            primaryXAxis: DateTimeAxis(
                                dateFormat: DateFormat("dd/MM/yyyy HH:mm:ss")),
                            series: <CartesianSeries>[
                              LineSeries<TimeSeriesDataModel, DateTime>(
                                dataSource: data,
                                xValueMapper: (TimeSeriesDataModel data, _) {
                                  return DateTime.fromMillisecondsSinceEpoch(
                                      data.instantaneousPower!.timestamp!);
                                },
                                yValueMapper: (TimeSeriesDataModel data, _) =>
                                    data.instantaneousPower!.value!,
                                name: 'Instantaneous Power',
                                markerSettings:
                                    const MarkerSettings(isVisible: true),
                              ),
                              LineSeries<TimeSeriesDataModel, DateTime>(
                                dataSource: data,
                                xValueMapper: (TimeSeriesDataModel data, _) =>
                                    DateTime.fromMillisecondsSinceEpoch(
                                        data.batteryChargeLevel!.timestamp!),
                                yValueMapper: (TimeSeriesDataModel data, _) =>
                                    data.batteryChargeLevel!.value!,
                                name: 'Battery Charge Level',
                                markerSettings:
                                    const MarkerSettings(isVisible: true),
                              ),
                              LineSeries<TimeSeriesDataModel, DateTime>(
                                dataSource: data,
                                xValueMapper: (TimeSeriesDataModel data, _) =>
                                    DateTime.fromMillisecondsSinceEpoch(
                                        data.batteryTemperature!.timestamp!),
                                yValueMapper: (TimeSeriesDataModel data, _) =>
                                    data.batteryTemperature!.value!,
                                name: 'Battery Temperature',
                                markerSettings:
                                    const MarkerSettings(isVisible: true),
                              ),
                            ],
                            legend: Legend(
                              isVisible: true,
                              overflowMode: LegendItemOverflowMode.wrap,
                            ),
                            trackballBehavior: TrackballBehavior(
                              enable: true,
                              activationMode: ActivationMode.singleTap,
                              lineType: TrackballLineType.vertical,
                              tooltipDisplayMode:
                                  TrackballDisplayMode.groupAllPoints,
                              tooltipSettings:
                                  const InteractiveTooltip(enable: true),
                            ),
                            zoomPanBehavior: ZoomPanBehavior(
                              enablePinching: true,
                              enableDoubleTapZooming: true,
                              enablePanning: false,
                            ),
                          ),
                        );
                        // return Text(data.length.toString());
                      } else {
                        return const Center(
                          child: Text(
                            "No Data!",
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
            bottomNavigationBar: BottomAppBar(
              child: Padding(
                padding: const EdgeInsets.all(0.0),
                child: GridView.count(
                  crossAxisCount: 6,
                  crossAxisSpacing: 0.0,
                  mainAxisSpacing: 0.0,
                  children: [
                    IconButton(
                      onPressed: _allPermissions
                          ? endpointMap.isNotEmpty
                              ? _stopAllEndpoints
                              : null
                          : null,
                      icon: const Icon(Icons.stop_circle_rounded),
                      tooltip: 'Stop All Endpoints',
                      color: _allPermissions
                          ? endpointMap.isNotEmpty
                              ? Colors.orange
                              : Colors.grey
                          : Colors.grey,
                    ),
                    IconButton(
                      onPressed: _allPermissions
                          ? _isDiscovering
                              ? !_isAdvertising
                                  ? _stopDiscovery
                                  : null
                              : null
                          : null,
                      icon: const Icon(Icons.cancel),
                      tooltip: 'Stop Discovery',
                      color: _allPermissions
                          ? _isDiscovering
                              ? !_isAdvertising
                                  ? Colors.blue
                                  : Colors.grey
                              : Colors.grey
                          : Colors.grey,
                    ),
                    IconButton(
                      onPressed: _allPermissions
                          ? !_isAdvertising
                              ? _startDiscovery
                              : null
                          : null,
                      icon: const Icon(Icons.search),
                      tooltip: 'Start Discovery',
                      color: _allPermissions
                          ? !_isAdvertising
                              ? Colors.orange
                              : Colors.grey
                          : Colors.grey,
                    ),
                    IconButton(
                      onPressed: _allPermissions
                          ? endpointMap.isNotEmpty
                              ? _shareData
                              : null
                          : null,
                      icon: const Icon(Icons.send),
                      tooltip: 'Send Data',
                      color: _allPermissions
                          ? endpointMap.isNotEmpty
                              ? Colors.red
                              : Colors.grey
                          : Colors.grey,
                    ),
                    IconButton(
                      onPressed: _allPermissions
                          ? _isAdvertising
                              ? _stopAdvertising
                              : null
                          : null,
                      icon: const Icon(Icons.bluetooth_disabled),
                      tooltip: 'Stop Advertising',
                      color: _allPermissions
                          ? _isAdvertising
                              ? Theme.of(context).colorScheme.inversePrimary
                              : Colors.grey
                          : Colors.grey,
                    ),
                    IconButton(
                      onPressed: _allPermissions
                          ? !_isDiscovering
                              ? _startAdvertising
                              : null
                          : null,
                      icon: const Icon(Icons.bluetooth_searching),
                      tooltip: 'Start Advertising',
                      color: _allPermissions
                          ? !_isDiscovering
                              ? Theme.of(context).colorScheme.inversePrimary
                              : Colors.grey
                          : Colors.grey,
                    )
                  ],
                ),
              ),
            ),
          );
  }
}
