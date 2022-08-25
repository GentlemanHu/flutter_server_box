import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/numx.dart';
import 'package:toolbox/data/model/server/net_speed.dart';
import 'package:toolbox/data/model/server/server.dart';
import 'package:toolbox/data/model/server/server_status.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/data/res/font_style.dart';
import 'package:toolbox/data/res/icon/linux_icons.dart';
import 'package:toolbox/data/res/padding.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

class ServerDetailPage extends StatefulWidget {
  const ServerDetailPage(this.id, {Key? key}) : super(key: key);

  final String id;

  @override
  _ServerDetailPageState createState() => _ServerDetailPageState();
}

class _ServerDetailPageState extends State<ServerDetailPage>
    with SingleTickerProviderStateMixin {
  late MediaQueryData _media;
  late S _s;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _s = S.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerProvider>(builder: (_, provider, __) {
      return _buildMainPage(provider.servers
          .firstWhere((e) => '${e.info.ip}:${e.info.port}' == widget.id));
    });
  }

  Widget _buildMainPage(ServerInfo si) {
    return Scaffold(
      appBar: AppBar(
        title: Text(si.info.name, style: size18),
      ),
      body: ListView(
        padding: const EdgeInsets.all(13),
        children: [
          _buildLinuxIcon(si.status.sysVer),
          SizedBox(height: _media.size.height * 0.03),
          _buildUpTimeAndSys(si.status),
          _buildCPUView(si.status),
          _buildDiskView(si.status),
          _buildMemView(si.status),
          _buildNetView(si.status.netSpeed),
          SizedBox(height: _media.padding.bottom),
        ],
      ),
    );
  }

  Widget _buildLinuxIcon(String sysVer) {
    final iconPath = linuxIcons.search(sysVer);
    if (iconPath == null) return const SizedBox();
    return SizedBox(
        height: _media.size.height * 0.15, child: Image.asset(iconPath));
  }

  Widget _buildCPUView(ServerStatus ss) {
    return RoundRectCard(
      Padding(
        padding: roundRectCardPadding,
        child: SizedBox(
          height: 12 * ss.cpu2Status.coresCount + 67,
          child: Column(children: [
            SizedBox(
              height: _media.size.height * 0.02,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${ss.cpu2Status.usedPercent(coreIdx: 0).toInt()}%',
                  style: const TextStyle(fontSize: 27),
                  textScaleFactor: 1.0,
                ),
                Row(
                  children: [
                    _buildCPUTimePercent(ss.cpu2Status.user, 'user'),
                    SizedBox(
                      width: _media.size.width * 0.03,
                    ),
                    _buildCPUTimePercent(ss.cpu2Status.sys, 'sys'),
                    SizedBox(
                      width: _media.size.width * 0.03,
                    ),
                    _buildCPUTimePercent(ss.cpu2Status.iowait, 'io'),
                    SizedBox(
                      width: _media.size.width * 0.03,
                    ),
                    _buildCPUTimePercent(ss.cpu2Status.idle, 'idle')
                  ],
                )
              ],
            ),
            _buildCPUProgress(ss)
          ]),
        ),
      ),
    );
  }

  Widget _buildCPUTimePercent(double percent, String timeType) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${percent.toStringAsFixed(1)}%',
          style: const TextStyle(fontSize: 13),
          textScaleFactor: 1.0,
        ),
        Text(
          timeType,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          textScaleFactor: 1.0,
        ),
      ],
    );
  }

  Widget _buildCPUProgress(ServerStatus ss) {
    return SizedBox(
      height: 12.0 * ss.cpu2Status.coresCount,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 17),
        itemBuilder: (ctx, idx) {
          if (idx == 0) return const SizedBox();
          return Padding(
            padding: const EdgeInsets.all(2),
            child: _buildProgress(ss.cpu2Status.usedPercent(coreIdx: idx)),
          );
        },
        itemCount: ss.cpu2Status.coresCount,
      ),
    );
  }

  Widget _buildProgress(double percent) {
    if (percent > 100) percent = 100;
    final pColor = primaryColor;
    final percentWithinOne = percent / 100;
    return LinearProgressIndicator(
      value: percentWithinOne,
      minHeight: 7,
      backgroundColor: progressColor.resolve(context),
      color: pColor.withOpacity(0.5 + percentWithinOne / 2),
    );
  }

  Widget _buildUpTimeAndSys(ServerStatus ss) {
    return RoundRectCard(Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 17),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(ss.sysVer, style: size11, textScaleFactor: 1.0),
          Text(
            ss.uptime,
            style: size11,
            textScaleFactor: 1.0,
          ),
        ],
      ),
    ));
  }

  Widget _buildMemView(ServerStatus ss) {
    final pColor = primaryColor;
    final used = ss.memory.used / ss.memory.total;
    final width = _media.size.width - 17 * 2 - 17 * 2;
    const mb = 1024;
    return RoundRectCard(Padding(
      padding: roundRectCardPadding,
      child: SizedBox(
        height: 47,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMemExplain((ss.memory.used * mb).convertBytes, pColor),
                _buildMemExplain(
                    (ss.memory.cache * mb).convertBytes, pColor.withAlpha(77)),
                _buildMemExplain(
                    ((ss.memory.total - ss.memory.used) * mb).convertBytes,
                    progressColor.resolve(context))
              ],
            ),
            const SizedBox(
              height: 7,
            ),
            Row(
              children: [
                SizedBox(
                    width: width * used,
                    child: LinearProgressIndicator(
                      value: 1,
                      color: pColor,
                    )),
                SizedBox(
                  width: width * (1 - used),
                  child: LinearProgressIndicator(
                    // memory.total == 1: failed to get mem, now mem = [emptyMemory] which is initial value.
                    value: ss.memory.total == 1
                        ? 0
                        : ss.memory.cache / (ss.memory.total - ss.memory.used),
                    backgroundColor: progressColor.resolve(context),
                    color: pColor.withAlpha(77),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    ));
  }

  Widget _buildMemExplain(String value, Color color) {
    return Row(
      children: [
        Container(
          color: color,
          height: 11,
          width: 11,
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: size11,
          textScaleFactor: 1.0,
          textAlign: TextAlign.center,
        )
      ],
    );
  }

  Widget _buildDiskView(ServerStatus ss) {
    final clone = ss.disk.toList();
    for (var item in ss.disk) {
      if (ignorePath.any((ele) => item.mountLocation.contains(ele))) {
        clone.remove(item);
      }
    }
    return RoundRectCard(SizedBox(
      height: 27 * clone.length + 25,
      child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 17),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: clone.length,
          itemBuilder: (_, idx) {
            final disk = clone[idx];
            return Padding(
              padding: const EdgeInsets.all(3),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${disk.usedPercent}% of ${disk.size}',
                        style: size11,
                        textScaleFactor: 1.0,
                      ),
                      Text(disk.mountPath, style: size11, textScaleFactor: 1.0)
                    ],
                  ),
                  _buildProgress(disk.usedPercent.toDouble())
                ],
              ),
            );
          }),
    ));
  }

  Widget _buildNetView(NetSpeed ns) {
    final children = <Widget>[
      _buildNetSpeedTop(),
      const Divider(
        height: 7,
      )
    ];
    if (ns.devices.isEmpty) {
      children.add(Center(
        child: Text(
          _s.noInterface,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ));
    } else {
      children.addAll(ns.devices.map((e) => _buildNetSpeedItem(ns, e)));
    }

    return RoundRectCard(Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 17),
      child: Column(
        children: children,
      ),
    ));
  }

  Widget _buildNetSpeedTop() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Icon(
            Icons.device_hub,
            size: 17,
          ),
          Icon(Icons.arrow_downward, size: 17),
          Icon(Icons.arrow_upward, size: 17),
        ],
      ),
    );
  }

  Widget _buildNetSpeedItem(NetSpeed ns, String device) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
              width: _media.size.width / 4,
              child: Text(device, style: size11, textScaleFactor: 1.0)),
          SizedBox(
            width: _media.size.width / 4,
            child: Text(ns.speedIn(device: device),
                style: size11,
                textAlign: TextAlign.center,
                textScaleFactor: 1.0),
          ),
          SizedBox(
              width: _media.size.width / 4,
              child: Text(ns.speedOut(device: device),
                  style: size11,
                  textAlign: TextAlign.right,
                  textScaleFactor: 1.0))
        ],
      ),
    );
  }

  static const ignorePath = [
    '/run',
    '/sys',
    '/dev/shm',
    '/snap',
    '/var/lib/docker',
    '/dev/tty'
  ];
}
