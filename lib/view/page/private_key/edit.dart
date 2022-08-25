import 'package:after_layout/after_layout.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/server/private_key_info.dart';
import 'package:toolbox/data/provider/private_key.dart';
import 'package:toolbox/data/res/font_style.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/widget/input.dart';

class PrivateKeyEditPage extends StatefulWidget {
  const PrivateKeyEditPage({Key? key, this.info}) : super(key: key);

  final PrivateKeyInfo? info;

  @override
  _PrivateKeyEditPageState createState() => _PrivateKeyEditPageState();
}

class _PrivateKeyEditPageState extends State<PrivateKeyEditPage>
    with AfterLayoutMixin {
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();
  final _pwdController = TextEditingController();
  final _nameNode = FocusNode();
  final _keyNode = FocusNode();
  final _pwdNode = FocusNode();

  late FocusScopeNode _focusScope;

  late PrivateKeyProvider _provider;
  var _loading = const SizedBox();
  late S _s;

  @override
  void initState() {
    super.initState();
    _provider = locator<PrivateKeyProvider>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context);
    _focusScope = FocusScope.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_s.edit, style: size18), actions: [
        widget.info != null
            ? IconButton(
                tooltip: _s.delete,
                onPressed: () {
                  _provider.delInfo(widget.info!);
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.delete))
            : const SizedBox()
      ]),
      body: ListView(
        padding: const EdgeInsets.all(13),
        children: [
          TextField(
            controller: _nameController,
            keyboardType: TextInputType.text,
            focusNode: _nameNode,
            onSubmitted: (_) => _focusScope.requestFocus(_keyNode),
            decoration: buildDecoration(_s.name, icon: Icons.info),
          ),
          TextField(
            controller: _keyController,
            autocorrect: false,
            minLines: 3,
            maxLines: 10,
            keyboardType: TextInputType.text,
            focusNode: _keyNode,
            onSubmitted: (_) => _focusScope.requestFocus(_pwdNode),
            enableSuggestions: false,
            decoration: buildDecoration(_s.privateKey, icon: Icons.vpn_key),
          ),
          TextField(
            controller: _pwdController,
            autocorrect: false,
            keyboardType: TextInputType.text,
            focusNode: _pwdNode,
            obscureText: true,
            decoration: buildDecoration(_s.pwd, icon: Icons.password),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
          _loading
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: _s.save,
        onPressed: () async {
          final name = _nameController.text;
          final key = _keyController.text;
          final pwd = _pwdController.text;
          if (name.isEmpty || key.isEmpty) {
            showSnackBar(context, Text(_s.fieldMustNotEmpty));
            return;
          }
          FocusScope.of(context).unfocus();
          setState(() {
            _loading = const SizedBox(
              height: 50,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          });
          final info = PrivateKeyInfo(name, key, pwd);
          bool haveErr = false;
          try {
            info.privateKey = await compute(decyptPem, [key, pwd]);
          } catch (e) {
            showSnackBar(context, Text(e.toString()));
            haveErr = true;
          } finally {
            setState(() {
              _loading = const SizedBox();
            });
          }
          if (haveErr) return;
          if (widget.info != null) {
            _provider.updateInfo(widget.info!, info);
          } else {
            _provider.addInfo(info);
          }
          Navigator.of(context).pop();
        },
        child: const Icon(Icons.save),
      ),
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    if (widget.info != null) {
      _nameController.text = widget.info!.id;
      _keyController.text = widget.info!.privateKey;
      _pwdController.text = widget.info!.password;
    }
  }
}

/// [args] : [key, pwd]
String decyptPem(List<String> args) {
  /// skip when the key is not encrypted, or will throw exception
  if (!SSHKeyPair.isEncryptedPem(args[0])) return args[0];
  final sshKey = SSHKeyPair.fromPem(args[0], args[1]);
  return sshKey.first.toPem();
}
