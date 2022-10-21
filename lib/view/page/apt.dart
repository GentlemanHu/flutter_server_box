import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/apt/upgrade_pkg_info.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/provider/apt.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/font_style.dart';
import 'package:toolbox/data/res/url.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/widget/center_loading.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';
import 'package:toolbox/view/widget/two_line_text.dart';
import 'package:toolbox/view/widget/url_text.dart';

class AptManagePage extends StatefulWidget {
  const AptManagePage(this.spi, {Key? key}) : super(key: key);

  final ServerPrivateInfo spi;

  @override
  _AptManagePageState createState() => _AptManagePageState();
}

class _AptManagePageState extends State<AptManagePage>
    with SingleTickerProviderStateMixin, AfterLayoutMixin {
  late MediaQueryData _media;
  final _scrollController = ScrollController();
  final _scrollControllerUpdate = ScrollController();
  final _textController = TextEditingController();
  final _aptProvider = locator<AptProvider>();
  late S _s;
  SSHClient? client;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _s = S.of(context);
  }

  @override
  void dispose() {
    super.dispose();
    locator<AptProvider>().clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: TwoLineText(up: 'Apt', down: widget.spi.name),
      ),
      body: Consumer<AptProvider>(builder: (_, apt, __) {
        if (apt.error != null) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error,
                color: Colors.redAccent,
                size: 37,
              ),
              const SizedBox(
                height: 37,
              ),
              SizedBox(
                height: _media.size.height * 0.4,
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: RoundRectCard(
                    SingleChildScrollView(
                        padding: const EdgeInsets.all(17),
                        child: Text(
                          apt.error!,
                          textAlign: TextAlign.center,
                        )),
                  ),
                ),
              ),
            ],
          );
        }
        if (apt.updateLog == null && apt.upgradeable == null) {
          return centerLoading;
        }
        if (apt.updateLog != null && apt.upgradeable == null) {
          return SizedBox(
              height: _media.size.height -
                  _media.padding.top -
                  _media.padding.bottom,
              child: ConstrainedBox(
                constraints: const BoxConstraints.expand(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  controller: _scrollControllerUpdate,
                  child: Text(apt.updateLog!),
                ),
              ));
        }
        return ListView(
          padding: const EdgeInsets.all(13),
          children: [
            Padding(
              padding: const EdgeInsets.all(17),
              child: UrlText(
                text:
                    '${_s.experimentalFeature}\n${_s.reportBugsOnGithubIssue(issueUrl)}',
                replace: 'Github Issue',
                textAlign: TextAlign.center,
              ),
            ),
            _buildUpdatePanel(apt)
          ].map((e) => RoundRectCard(e)).toList(),
        );
      }),
    );
  }

  Widget _buildUpdatePanel(AptProvider apt) {
    if (apt.upgradeable!.isEmpty) {
      return ListTile(
        title: Text(
          _s.noUpdateAvailable,
          textAlign: TextAlign.center,
        ),
        subtitle: const Text('>_<', textAlign: TextAlign.center),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExpansionTile(
          title: Text(_s.foundNUpdate(apt.upgradeable!.length)),
          subtitle: Text(
            apt.upgradeable!.map((e) => e.package).join(', '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: grey,
          ),
          children: apt.upgradeLog == null
              ? [
                  TextButton(
                      child: Text(_s.updateAll),
                      onPressed: () {
                        apt.upgrade();
                      }),
                  SizedBox(
                    height: _media.size.height * 0.73,
                    child: ListView(
                        controller: _scrollController,
                        children: apt.upgradeable!
                            .map((e) => _buildUpdateItem(e, apt))
                            .toList()),
                  )
                ]
              : [
                  SizedBox(
                      height: _media.size.height * 0.7,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints.expand(),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(18),
                          controller: _scrollController,
                          child: Text(apt.upgradeLog!),
                        ),
                      ))
                ],
        )
      ],
    );
  }

  Widget _buildUpdateItem(UpgradePkgInfo info, AptProvider apt) {
    return ListTile(
      title: Text(info.package),
      subtitle: Text(
        '${info.nowVersion} -> ${info.newVersion}',
        style: grey,
      ),
    );
  }

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    final si = locator<ServerProvider>()
        .servers
        .firstWhere((element) => element.info == widget.spi);

    // ignore: prefer_function_declarations_over_variables
    Function onSubmitted = () {
      if (_textController.text == '') {
        showRoundDialog(context, _s.attention, Text(_s.fieldMustNotEmpty), [
          TextButton(
              onPressed: () => Navigator.of(context).pop(), child: Text(_s.ok)),
        ]);
        return;
      }
      Navigator.of(context).pop();
    };

    // ignore: prefer_function_declarations_over_variables
    PwdRequestFunc onPwdRequest = (triedTimes, user) async {
      if (!mounted) return '';
      await showRoundDialog(
          context,
          triedTimes == 3 ? _s.lastTry : (user ?? _s.unknown),
          TextField(
            controller: _textController,
            keyboardType: TextInputType.visiblePassword,
            obscureText: true,
            onSubmitted: (_) => onSubmitted(),
            decoration: InputDecoration(
              labelText: _s.pwd,
            ),
          ),
          [
            TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: Text(_s.cancel)),
            TextButton(
                onPressed: () => onSubmitted(),
                child: Text(
                  _s.ok,
                  style: const TextStyle(color: Colors.red),
                )),
          ]);
      return _textController.text.trim();
    };
    client = await createSSHClient(widget.spi);
    if (client == null) {
      showSnackBar(context, Text(_s.noClient));
      Navigator.of(context).pop();
      return;
    }
    _aptProvider.init(
        client!,
        si.status.sysVer.dist,
        () => _scrollController
            .jumpTo(_scrollController.position.maxScrollExtent),
        () => _scrollControllerUpdate
            .jumpTo(_scrollControllerUpdate.positions.last.maxScrollExtent),
        onPwdRequest);
    _aptProvider.refreshInstalled();
  }
}
