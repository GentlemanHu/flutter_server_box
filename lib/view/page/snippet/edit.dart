import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/server/snippet.dart';
import 'package:toolbox/data/provider/snippet.dart';
import 'package:toolbox/data/res/font_style.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/widget/input.dart';

class SnippetEditPage extends StatefulWidget {
  const SnippetEditPage({Key? key, this.snippet}) : super(key: key);

  final Snippet? snippet;

  @override
  _SnippetEditPageState createState() => _SnippetEditPageState();
}

class _SnippetEditPageState extends State<SnippetEditPage>
    with AfterLayoutMixin {
  final _nameController = TextEditingController();
  final _scriptController = TextEditingController();
  final _scriptNode = FocusNode();

  late SnippetProvider _provider;
  late S _s;

  @override
  void initState() {
    super.initState();
    _provider = locator<SnippetProvider>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_s.edit, style: size18), actions: [
        widget.snippet != null
            ? IconButton(
                onPressed: () {
                  _provider.del(widget.snippet!);
                  Navigator.of(context).pop();
                },
                tooltip: _s.delete,
                icon: const Icon(Icons.delete))
            : const SizedBox()
      ]),
      body: ListView(
        padding: const EdgeInsets.all(13),
        children: [
          TextField(
            controller: _nameController,
            keyboardType: TextInputType.text,
            onSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_scriptNode),
            decoration: buildDecoration(_s.name, icon: Icons.info),
          ),
          TextField(
            controller: _scriptController,
            autocorrect: false,
            focusNode: _scriptNode,
            minLines: 3,
            maxLines: 10,
            keyboardType: TextInputType.text,
            enableSuggestions: false,
            decoration: buildDecoration(_s.snippet, icon: Icons.code),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.send),
        onPressed: () {
          final name = _nameController.text;
          final script = _scriptController.text;
          if (name.isEmpty || script.isEmpty) {
            showSnackBar(context, Text(_s.fieldMustNotEmpty));
            return;
          }
          final snippet = Snippet(name, script);
          if (widget.snippet != null) {
            _provider.update(widget.snippet!, snippet);
          } else {
            _provider.add(snippet);
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    if (widget.snippet != null) {
      _nameController.text = widget.snippet!.name;
      _scriptController.text = widget.snippet!.script;
    }
  }
}
