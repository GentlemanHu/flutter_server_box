import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/uint8list.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/server/ping_result.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/data/res/font_style.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/widget/input.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

class PingPage extends StatefulWidget {
  const PingPage({Key? key}) : super(key: key);

  @override
  _PingPageState createState() => _PingPageState();
}

class _PingPageState extends State<PingPage>
    with AutomaticKeepAliveClientMixin {
  late TextEditingController _textEditingController;
  late MediaQueryData _media;
  final List<PingResult> _results = [];
  final _serverProvider = locator<ServerProvider>();
  late S _s;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController(text: '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _s = S.of(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: GestureDetector(
        child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Column(children: [
              const SizedBox(height: 13),
              buildInput(context, _textEditingController,
                  maxLines: 1, onSubmitted: (_) => doPing()),
              _buildControl(),
              SizedBox(
                width: double.infinity,
                height: _media.size.height * 0.6,
                child: ListView.builder(
                    controller: ScrollController(),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return _buildResultItem(result);
                    }),
              ),
            ])),
        onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
      ),
    );
  }

  Widget _buildResultItem(PingResult result) {
    final unknown = _s.unknown;
    final ms = _s.ms;
    return RoundRectCard(ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 7, horizontal: 17),
      title: Text(result.serverName,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
      subtitle: Text(
        _buildPingSummary(result, unknown, ms),
        style: size11,
      ),
      trailing: Text(
          '${_s.pingAvg}${result.statistic?.avg?.toStringAsFixed(2) ?? _s.unknown} $ms',
          style: TextStyle(fontSize: 14, color: primaryColor)),
    ));
  }

  String _buildPingSummary(PingResult result, String unknown, String ms) {
    final ip = result.ip ?? unknown;
    if (result.results == null || result.results!.isEmpty) {
      return '$ip - ${_s.noResult}';
    }
    final ttl = result.results?.first.ttl ?? unknown;
    final loss = result.statistic?.loss ?? unknown;
    final min = result.statistic?.min ?? unknown;
    final max = result.statistic?.max ?? unknown;
    return '$ip\n${_s.ttl}: $ttl, ${_s.loss}: $loss%\n${_s.min}: $min $ms, ${_s.max}: $max $ms';
  }

  Future<void> doPing() async {
    _results.clear();
    final target = _textEditingController.text.trim();
    if (target.isEmpty) {
      showSnackBar(context, Text(_s.pingInputIP));
      return;
    }

    if (_serverProvider.servers.isEmpty) {
      showSnackBar(context, Text(_s.pingNoServer));
      return;
    }

    await Future.wait(_serverProvider.servers.map((e) async {
      final client = await createSSHClient(e.info);
      if (client == null) {
        return;
      }
      final result = await client.run('ping -c 3 $target').string;
      _results.add(PingResult.parse(e.info.name, result));
      setState(() {});
    }));
  }

  Widget _buildControl() {
    return SizedBox(
      height: 57,
      child: RoundRectCard(
        InkWell(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(
                style: ButtonStyle(
                    foregroundColor: MaterialStateProperty.all(primaryColor)),
                child: Row(
                  children: [
                    const Icon(Icons.delete),
                    const SizedBox(
                      width: 7,
                    ),
                    Text(_s.clear)
                  ],
                ),
                onPressed: () {
                  _results.clear();
                  setState(() {});
                },
              ),
              TextButton(
                style: ButtonStyle(
                    foregroundColor: MaterialStateProperty.all(primaryColor)),
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow),
                    const SizedBox(
                      width: 7,
                    ),
                    Text(_s.start)
                  ],
                ),
                onPressed: () {
                  try {
                    doPing();
                  } catch (e) {
                    showSnackBar(context, Text('Error: \n$e'));
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
