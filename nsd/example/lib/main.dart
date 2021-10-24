import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:nsd/nsd.dart';
import 'package:nsd_example/logging.dart';
import 'package:provider/provider.dart';

const String serviceType = '_http._tcp';
const utf8encoder = Utf8Encoder();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  final nsd = NsdPlatform.instance;

  final discoveries = <Discovery>[];
  final registrations = <Registration>[];

  var _nextPort = 56360;

  int get nextPort => _nextPort++; // TODO ensure ports are not taken

  MyAppState();

  Future<void> addDiscovery() async {
    final discovery = await nsd.startDiscovery(serviceType).catchError((error) {
      logError(this, error);
    });

    setState(() {
      discoveries.add(discovery);
    });
  }

  Future<void> dismissDiscovery(Discovery discovery) async {
    setState(() {
      /// remove fast, without confirmation, to avoid "onDismissed" error.
      discoveries.remove(discovery);
    });

    await nsd.stopDiscovery(discovery).catchError((error) {
      logError(this, error);
    });
  }

  Future<void> addRegistration() async {
    final serviceInfo = ServiceInfo(
        name: 'Some Service',
        type: serviceType,
        port: nextPort,
        txt: createTxt());

    final registration = await nsd.register(serviceInfo).catchError((error) {
      logError(this, error);
    });

    setState(() {
      registrations.add(registration);
    });
  }

  Future<void> dismissRegistration(Registration registration) async {
    setState(() {
      /// remove fast, without confirmation, to avoid "onDismissed" error.
      registrations.remove(registration);
    });

    await nsd.unregister(registration).catchError((error) {
      logError(this, error);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: SpeedDial(
          icon: Icons.add,
          spacing: 10,
          spaceBetweenChildren: 5,
          children: [
            SpeedDialChild(
              elevation: 2,
              child: const Icon(Icons.wifi_tethering),
              label: 'Register Service',
              onTap: () async => addRegistration(),
            ),
            SpeedDialChild(
              elevation: 2,
              child: const Icon(Icons.wifi_outlined),
              label: 'Start Discovery',
              onTap: () async => addDiscovery(),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                controller: ScrollController(),
                itemBuilder: buildDiscovery,
                itemCount: discoveries.length,
              ),
            ),
            const Divider(
              height: 20,
              thickness: 4,
              indent: 0,
              endIndent: 0,
              color: Colors.blue,
            ),
            Expanded(
              child: ListView.builder(
                controller: ScrollController(),
                itemBuilder: buildRegistration,
                itemCount: registrations.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDiscovery(context, index) {
    final discovery = discoveries.elementAt(index);
    return Dismissible(
        key: ValueKey(discovery.id),
        onDismissed: (_) async => dismissDiscovery(discovery),
        child: DiscoveryWidget(discovery));
  }

  Widget buildRegistration(context, index) {
    final registration = registrations.elementAt(index);
    return Dismissible(
        key: ValueKey(registration.id),
        onDismissed: (_) async => dismissRegistration(registration),
        child: RegistrationWidget(registration));
  }
}

class DiscoveryWidget extends StatefulWidget {
  final Discovery discovery;

  DiscoveryWidget(this.discovery) : super(key: ValueKey(discovery.id));

  @override
  State createState() => DiscoveryState();
}

class DiscoveryState extends State<DiscoveryWidget> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ListTile(
              leading: const Icon(Icons.wifi_outlined),
              title: Text('Discovery ${shorten(widget.discovery.id)}')),
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: ChangeNotifierProvider.value(
                value: widget.discovery,
                child: Consumer<Discovery>(builder: buildDataTable),
              )),
          const SizedBox(
            height: 16,
          ),
        ],
      ),
    );
  }

  Widget buildDataTable(
      BuildContext context, Discovery discovery, Widget? child) {
    return DataTable(
      headingRowHeight: 24,
      dataRowHeight: 24,
      dataTextStyle: const TextStyle(color: Colors.black, fontSize: 12),
      columnSpacing: 8,
      horizontalMargin: 0,
      headingTextStyle: const TextStyle(
          color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600),
      columns: <DataColumn>[
        buildDataColumn('Name'),
        buildDataColumn('Type'),
        buildDataColumn('Host'),
        buildDataColumn('Port'),
      ],
      rows: buildDataRows(discovery),
    );
  }

  DataColumn buildDataColumn(String name) {
    return DataColumn(
      label: Text(
        name,
      ),
    );
  }

  List<DataRow> buildDataRows(Discovery discovery) {
    return discovery.serviceInfos
        .map((e) => DataRow(
              cells: <DataCell>[
                DataCell(Text(e.name ?? 'unknown')),
                DataCell(Text(e.type ?? 'unknown')),
                DataCell(Text(e.host ?? 'unknown')),
                DataCell(Text(e.port != null ? '${e.port}' : 'unknown'))
              ],
            ))
        .toList();
  }
}

class RegistrationWidget extends StatelessWidget {
  final Registration registration;

  RegistrationWidget(this.registration) : super(key: ValueKey(registration.id));

  @override
  Widget build(BuildContext context) {
    final serviceInfo = registration.serviceInfo;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.wifi_tethering),
            title: Text('Registration ${shorten(registration.id)}'),
            subtitle: Text(
              'Name: ${serviceInfo.name} ▪️ '
              'Type: ${serviceInfo.type} ▪️ '
              'Host: ${serviceInfo.host} ▪️ '
              'Port: ${serviceInfo.port}',
              style: const TextStyle(color: Colors.black, fontSize: 12),
            ),
          ),
          const SizedBox(
            height: 8,
          ),
        ],
      ),
    );
  }
}

/// Shortens the id for display on-screen.
String shorten(String? id) {
  return id?.toString().substring(0, 4) ?? 'unknown';
}

/// Creates a txt attribute object that showcases the most common use cases.
Map<String, Uint8List?> createTxt() {
  return <String, Uint8List?>{
    'attribute-a': utf8encoder.convert('Löwe'),
    'attribute-b': Uint8List(0),
    'attribute-c': null,
    'attribute-d': Uint8List.fromList([0, 1, 2, 3])
  };
}
