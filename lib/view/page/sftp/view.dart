import 'dart:async';
import 'dart:typed_data';

import 'package:after_layout/after_layout.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/numx.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/server/server_connection_state.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/sftp/absolute_path.dart';
import 'package:toolbox/data/model/sftp/download_worker.dart';
import 'package:toolbox/data/model/sftp/browser_status.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/provider/sftp_download.dart';
import 'package:toolbox/data/res/path.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/page/sftp/downloading.dart';
import 'package:toolbox/view/widget/fade_in.dart';
import 'package:toolbox/view/widget/two_line_text.dart';

class SFTPPage extends StatefulWidget {
  final ServerPrivateInfo spi;
  const SFTPPage(this.spi, {Key? key}) : super(key: key);

  @override
  _SFTPPageState createState() => _SFTPPageState();
}

class _SFTPPageState extends State<SFTPPage> with AfterLayoutMixin {
  final SftpBrowserStatus _status = SftpBrowserStatus();

  final ScrollController _scrollController = ScrollController();

  late MediaQueryData _media;
  late S _s;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _s = S.of(context);
  }

  @override
  void initState() {
    super.initState();
    _status.spi = widget.spi;
    _status.selected = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          centerTitle: true,
          title: TwoLineText(up: 'SFTP', down: widget.spi.name),
          actions: [
            IconButton(
              onPressed: (() => showRoundDialog(
                      context,
                      _s.choose,
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                              leading: const Icon(Icons.folder),
                              title: Text(_s.createFolder),
                              onTap: () => mkdir(context)),
                          ListTile(
                              leading: const Icon(Icons.insert_drive_file),
                              title: Text(_s.createFile),
                              onTap: () => newFile(context)),
                        ],
                      ),
                      [
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(_s.close))
                      ])),
              icon: const Icon(Icons.add),
            )
          ]),
      body: _buildFileView(),
    );
  }

  Widget get centerCircleLoading => Center(
        child: Column(
          children: [
            SizedBox(
              height: _media.size.height * 0.4,
            ),
            const CircularProgressIndicator(),
          ],
        ),
      );

  Widget _buildFileView() {
    if (!_status.selected) {
      return ListView(
        children: [
          _buildDestSelector(),
        ],
      );
    }
    final spi = _status.spi;
    final si =
        locator<ServerProvider>().servers.firstWhere((s) => s.info == spi);

    if (_status.client == null ||
        si.connectionState != ServerConnectionState.connected) {
      return centerCircleLoading;
    }

    if (_status.files == null) {
      _status.path = AbsolutePath('/');
      listDir(path: '/');
      return centerCircleLoading;
    } else {
      return RefreshIndicator(
          child: FadeIn(
            key: Key(_status.spi!.name + _status.path!.path),
            child: ListView.builder(
              itemCount: _status.files!.length + 1,
              controller: _scrollController,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildDestSelector();
                }
                final file = _status.files![index - 1];
                final isDir = file.attr.isDirectory;
                return ListTile(
                  leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file),
                  title: Text(file.filename),
                  trailing: Text(
                    DateTime.fromMillisecondsSinceEpoch(
                            (file.attr.modifyTime ?? 0) * 1000)
                        .toString()
                        .replaceFirst('.000', ''),
                    style: const TextStyle(color: Colors.grey),
                  ),
                  subtitle:
                      isDir ? null : Text((file.attr.size ?? 0).convertBytes),
                  onTap: () {
                    if (isDir) {
                      _status.path?.update(file.filename);
                      listDir(path: _status.path?.path);
                    } else {
                      onItemPress(context, file, true);
                    }
                  },
                  onLongPress: () => onItemPress(context, file, false),
                );
              },
            ),
          ),
          onRefresh: () => listDir(path: _status.path?.path));
    }
  }

  void onItemPress(BuildContext context, SftpName file, bool showDownload) {
    showRoundDialog(
        context,
        _s.choose,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: Text(_s.delete),
              onTap: () => delete(context, file),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(_s.rename),
              onTap: () => rename(context, file),
            ),
            showDownload
                ? ListTile(
                    leading: const Icon(Icons.download),
                    title: Text(_s.download),
                    onTap: () => download(context, file),
                  )
                : const SizedBox()
          ],
        ),
        [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_s.cancel))
        ]);
  }

  void download(BuildContext context, SftpName name) {
    showRoundDialog(context, _s.download,
        Text('${_s.dl2Local(name.filename)}\n${_s.keepForeground}'), [
      TextButton(
          onPressed: () => Navigator.of(context).pop(), child: Text(_s.cancel)),
      TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            final prePath = _status.path!.path;
            final remotePath =
                prePath + (prePath.endsWith('/') ? '' : '/') + name.filename;
            final local = '${(await sftpDownloadDir).path}$remotePath';
            locator<SftpDownloadProvider>().add(
                DownloadItem(_status.spi!, remotePath, local));
            Navigator.of(context).pop();
            showRoundDialog(context, _s.goSftpDlPage, const SizedBox(), [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_s.cancel)),
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    AppRoute(const SFTPDownloadingPage(), 'sftp downloading')
                        .go(context);
                  },
                  child: Text(_s.ok))
            ]);
          },
          child: Text(_s.download))
    ]);
  }

  void delete(BuildContext context, SftpName file) {
    Navigator.of(context).pop();
    showRoundDialog(context, _s.attention, Text(_s.sureDelete(file.filename)), [
      TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel')),
      TextButton(
          onPressed: () {
            _status.client!.remove(file.filename);
            Navigator.of(context).pop();
            listDir();
          },
          child: Text(
            _s.delete,
            style: const TextStyle(color: Colors.red),
          )),
    ]);
  }

  void mkdir(BuildContext context) {
    Navigator.of(context).pop();
    final textController = TextEditingController();
    showRoundDialog(
        context,
        _s.createFolder,
        TextField(
          controller: textController,
          decoration: InputDecoration(
            labelText: _s.name,
          ),
        ),
        [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_s.cancel)),
          TextButton(
              onPressed: () {
                if (textController.text == '') {
                  showRoundDialog(
                      context, _s.attention, Text(_s.fieldMustNotEmpty), [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(_s.ok)),
                  ]);
                  return;
                }
                _status.client!
                    .mkdir('${_status.path!.path}/${textController.text}');
                Navigator.of(context).pop();
                listDir();
              },
              child: Text(
                _s.ok,
                style: const TextStyle(color: Colors.red),
              )),
        ]);
  }

  void newFile(BuildContext context) {
    Navigator.of(context).pop();
    final textController = TextEditingController();
    showRoundDialog(
        context,
        _s.createFile,
        TextField(
          controller: textController,
          decoration: InputDecoration(
            labelText: _s.name,
          ),
        ),
        [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_s.cancel)),
          TextButton(
              onPressed: () async {
                if (textController.text == '') {
                  showRoundDialog(
                      context, _s.attention, Text(_s.fieldMustNotEmpty), [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(_s.ok)),
                  ]);
                  return;
                }
                (await _status.client!
                        .open('${_status.path!.path}/${textController.text}'))
                    .writeBytes(Uint8List(0));
                Navigator.of(context).pop();
                listDir();
              },
              child: Text(
                _s.ok,
                style: const TextStyle(color: Colors.red),
              )),
        ]);
  }

  void rename(BuildContext context, SftpName file) {
    Navigator.of(context).pop();
    final textController = TextEditingController();
    showRoundDialog(
        context,
        _s.rename,
        TextField(
          controller: textController,
          decoration: InputDecoration(
            labelText: _s.name,
          ),
        ),
        [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_s.cancel)),
          TextButton(
              onPressed: () async {
                if (textController.text == '') {
                  showRoundDialog(
                      context, _s.attention, Text(_s.fieldMustNotEmpty), [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(_s.ok)),
                  ]);
                  return;
                }
                await _status.client!
                    .rename(file.filename, textController.text);
                Navigator.of(context).pop();
                listDir();
              },
              child: Text(
                _s.rename,
                style: const TextStyle(color: Colors.red),
              )),
        ]);
  }

  Future<void> listDir({String? path}) async {
    if (_status.isBusy) {
      return;
    }
    _status.isBusy = true;
    if (_status.client == null) {
      showSnackBar(context, Text(_s.noClient));
      return;
    }
    try {
      final fs =
          await _status.client!.listdir(path ?? (_status.path?.path ?? '/'));
      fs.sort((a, b) => a.filename.compareTo(b.filename));
      fs.removeAt(0);
      if (mounted) {
        setState(() {
          _status.files = fs;
          _status.isBusy = false;
        });
      }
    } catch (e) {
      await showRoundDialog(context, _s.error, Text(e.toString()), [
        TextButton(
            onPressed: () => Navigator.of(context).pop(), child: Text(_s.ok))
      ]);
      if (_status.path!.undo()) {
        await listDir();
      }
    }
  }

  Widget _buildDestSelector() {
    final str = _status.path?.path;
    return ExpansionTile(
        title: Text(_status.spi?.name ?? _s.chooseDestination),
        subtitle: _status.selected
            ? str!.omitStartStr(style: const TextStyle(color: Colors.grey))
            : null,
        children: locator<ServerProvider>()
            .servers
            .map((e) => _buildDestSelectorItem(e.info))
            .toList());
  }

  Widget _buildDestSelectorItem(ServerPrivateInfo spi) {
    return ListTile(
      title: Text(spi.name),
      subtitle: Text('${spi.user}@${spi.ip}:${spi.port}'),
      onTap: () {
        _status.spi = spi;
        _status.selected = true;
        _status.path = AbsolutePath('/');
        listDir(path: '/');
      },
    );
  }

  Future<void> connect({ServerPrivateInfo? spi}) async {
    final s = () {
      if (spi != null) {
        return spi;
      }
      return widget.spi;
    }();
    final client = await createSSHClient(s);
    if (client == null) {
      showSnackBar(context, Text(_s.noClient));
      return;
    }
    _status.client = await client.sftp();
  }

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) async {
    await connect();
  }
}
