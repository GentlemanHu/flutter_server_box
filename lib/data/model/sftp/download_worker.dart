import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:easy_isolate/easy_isolate.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/sftp/download_status.dart';

class DownloadItem {
  DownloadItem(this.spi, this.remotePath, this.localPath);

  final ServerPrivateInfo spi;
  final String remotePath;
  final String localPath;
}

class SftpDownloadWorker {
  SftpDownloadWorker(
      {required this.onNotify, required this.item});

  final Function(Object event) onNotify;
  final DownloadItem item;
  final worker = Worker();

  void dispose() {
    worker.dispose();
  }

  /// Initiate the worker (new thread) and start listen from messages between
  /// the threads
  Future<void> init() async {
    if (worker.isInitialized) worker.dispose();
    await worker.init(
      mainMessageHandler,
      isolateMessageHandler,
      errorHandler: print,
    );
    worker.sendMessage(DownloadItemEvent(item));
  }

  /// Handle the messages coming from the isolate
  void mainMessageHandler(dynamic data, SendPort isolateSendPort) {
    onNotify(data);
  }

  /// Handle the messages coming from the main
  static isolateMessageHandler(
      dynamic data, SendPort mainSendPort, SendErrorFunction sendError) async {
    if (data is DownloadItemEvent) {
      try {
        mainSendPort.send(SftpWorkerStatus.preparing);
        final watch = Stopwatch()..start();
        final item = data.item;
        final spi = item.spi;
        final client = await createSSHClient(spi);
        if (client == null) {
          mainSendPort.send(SftpWorkerStatus.failed);
          return;
        }
        mainSendPort.send(SftpWorkerStatus.sshConnectted);

        final remotePath = item.remotePath;
        final localPath = item.localPath;
        await Directory(localPath.substring(0, item.localPath.lastIndexOf('/')))
            .create(recursive: true);
        final local = File(localPath);
        if (await local.exists()) {
          await local.delete();
        }
        final localFile = local.openWrite(mode: FileMode.append);
        final file = await (await client.sftp()).open(remotePath);
        final size = (await file.stat()).size;
        if (size == null) {
          mainSendPort.send(Exception('can not get file size'));
          return;
        }
        const defaultChunkSize = 1024 * 1024;
        final chunkSize = size > defaultChunkSize ? defaultChunkSize : size;
        mainSendPort.send(size);
        mainSendPort.send(SftpWorkerStatus.downloading);
        for (var i = 0; i < size; i += chunkSize) {
          final fileData = file.read(length: chunkSize);
          await for (var form in fileData) {
            localFile.add(form);
            mainSendPort.send((i + form.length) / size * 100);
          }
        }
        localFile.close();
        mainSendPort.send(watch.elapsed);
        mainSendPort.send(SftpWorkerStatus.finished);
      } catch (e) {
        mainSendPort.send(e);
      }
    }
  }
}

class DownloadItemEvent {
  DownloadItemEvent(this.item);

  final DownloadItem item;
}
