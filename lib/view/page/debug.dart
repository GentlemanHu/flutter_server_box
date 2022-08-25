import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/data/provider/debug.dart';

class DebugPage extends StatelessWidget {
  const DebugPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('App log'), backgroundColor: Colors.black),
      body: _buildTerminal(context),
      backgroundColor: Colors.black,
    );
  }

  Widget _buildTerminal(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.black,
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'monospace',
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        child: SingleChildScrollView(
          child: Consumer<DebugProvider>(builder: (_, debug, __) {
            return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: debug.widgets);
          }),
        ),
      ),
    );
  }
}
