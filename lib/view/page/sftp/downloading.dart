import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/numx.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/sftp/download_status.dart';
import 'package:toolbox/data/provider/sftp_download.dart';
import 'package:toolbox/data/res/font_style.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/view/widget/center_loading.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

class SFTPDownloadingPage extends StatefulWidget {
  const SFTPDownloadingPage({Key? key}) : super(key: key);

  @override
  _SFTPDownloadingPageState createState() => _SFTPDownloadingPageState();
}

class _SFTPDownloadingPageState extends State<SFTPDownloadingPage> {
  late S _s;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _s.download,
          style: size18,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Consumer<SftpDownloadProvider>(builder: (__, pro, _) {
      if (pro.status.isEmpty) {
        return Center(
          child: Text(_s.sftpNoDownloadTask),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(11),
        itemCount: pro.status.length,
        itemBuilder: (context, index) {
          final status = pro.status[index];
          return _buildItem(status);
        },
      );
    });
  }

  Widget _wrapInCard(SftpDownloadStatus status, String? subtitle,
      {Widget? trailing}) {
    return RoundRectCard(ListTile(
      title: Text(status.fileName),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: grey,
            ),
      trailing: trailing,
    ));
  }

  Widget _buildItem(SftpDownloadStatus status) {
    if (status.error != null) {
      showSnackBar(context, Text(status.error.toString()));
    }
    switch (status.status) {
      case SftpWorkerStatus.finished:
        final time = status.spentTime.toString();
        return _wrapInCard(status,
            '${_s.downloadFinished} ${_s.spentTime(time == 'null' ? _s.unknown : (time.substring(0, time.length - 7)))}',
            trailing: IconButton(
                onPressed: () => shareFiles(context, [status.item.localPath]),
                icon: const Icon(Icons.open_in_new)));
      case SftpWorkerStatus.downloading:
        return _wrapInCard(
            status,
            _s.downloadStatus((status.progress ?? 0.0).toStringAsFixed(2),
                (status.size ?? 0).convertBytes),
            trailing:
                CircularProgressIndicator(value: (status.progress ?? 0) / 100));
      case SftpWorkerStatus.preparing:
        return _wrapInCard(status, _s.sftpDlPrepare, trailing: loadingIcon);
      case SftpWorkerStatus.sshConnectted:
        return _wrapInCard(status, _s.sftpSSHConnected, trailing: loadingIcon);
      default:
        return _wrapInCard(status, _s.unknown,
            trailing: const Icon(
              Icons.error,
              size: 40,
            ));
    }
  }
}
