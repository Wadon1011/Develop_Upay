import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:upay_ver01/select_page.dart';
import 'package:upay_ver01/camera_page.dart';
import 'package:intl/intl.dart';
import 'package:upay_ver01/main.dart';
import 'package:flutter/services.dart';
import 'package:gsheets/gsheets.dart';
import 'dart:convert';

class ChargePage extends StatefulWidget {
  const ChargePage({
    super.key,
    required this.userData,
    required this.items,
  });
  final UserData userData;
  final List<ItemData> items;

  @override
  _ChargePageState createState() => _ChargePageState();
}

class _ChargePageState extends State<ChargePage> {
  TextEditingController inputController = TextEditingController();
  bool isButtonEnabled = false;
  int chargeAmount = 0;

  final formatter = NumberFormat("#,###");

  @override
  void dispose() {
    inputController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    inputController.addListener(_addCurrencySymbol);
    inputController.addListener(_validateInput);
  }

  bool _pressedBack = false;
  void _loadBackPage() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return SelectPage(
            userData: widget.userData,
            items: widget.items,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final Offset begin = Offset(0.0, -1.0); // 上から下
          // final Offset begin = Offset(-1.0, 0.0); // 左から右
          final Offset end = Offset.zero;
          final Animatable<Offset> tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: Curves.easeInOut));
          final Animation<Offset> offsetAnimation = animation.drive(tween);
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );
  }

  void _addCurrencySymbol() {
    final text = inputController.text;
    if (text.isNotEmpty && !text.startsWith('¥')) {
      final newText = '¥${text.replaceAll('¥', '')}';
      inputController.value = inputController.value.copyWith(
        text: newText,
        selection: TextSelection.fromPosition(
          TextPosition(offset: newText.length),
        ),
      );
    } else if (text == '¥') {
      inputController.clear();
    }
  }

  void _validateInput() {
    final text = inputController.text.replaceAll('¥', '');
    final isNumeric = double.tryParse(text) != null;
    setState(() {
      isButtonEnabled = isNumeric;
      int? num = int.tryParse(text);
      if (num != null && num < 0) {
        isButtonEnabled = false;
      }
      if (isNumeric) {
        chargeAmount = int.tryParse(text) ?? 0;
      }
    });
  }

  void _addAmount(int amount) {
    final currentText = inputController.text.replaceAll('¥', '');
    final currentAmount = double.tryParse(currentText) ?? 0;
    final newAmount = currentAmount + amount;
    if (newAmount > 10000) {
      return;
    }
    final newText = '¥' + newAmount.toStringAsFixed(0);
    inputController.value = inputController.value.copyWith(
      text: newText,
      selection: TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      ),
    );
    _validateInput();
  }

  bool _pressed500 = false;
  bool _pressed1000 = false;
  bool _pressedCharge = false;

  void _popDialogue() {
    if (isButtonEnabled) {
      showDialog<void>(
          context: context,
          builder: (_) {
            return AlertDialogSample(
              chargeAmount: chargeAmount,
              userData: widget.userData,
              items: widget.items,
            );
          });
    } else {
      null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.colors.surfaceContainerLow,
        appBar: AppBar(
          toolbarHeight: 100, // Set this height
          /* elevation: 3,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black, */
          title: Text(
            // 'チャージ',
            'Top Up',
            style: TextStyle(color: context.colors.primary),
          ),
          centerTitle: true,
          leadingWidth: 280,
          leading: Padding(
            padding: const EdgeInsets.all(24),
            child: GestureDetector(
              onTap: () {},
              onTapDown: (details) {
                setState(() {
                  _pressedBack = true;
                });
              },
              onTapUp: (details) {
                _loadBackPage();
                setState(() {
                  // _pressedBack = false;
                });
              },
              onTapCancel: () {
                _loadBackPage();
                setState(() {
                  // _pressedBack = false;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: !_pressedBack
                      ? context.colors.surfaceContainerLow
                      : context.colors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: !_pressedBack
                          ? Colors.black.withOpacity(0.2)
                          : Colors.transparent,
                      offset: Offset(0, 3), // シャドウの位置（x, y）
                      blurRadius: 6, // ぼかしの半径
                      spreadRadius: 0, // シャドウの広がり
                    ),
                  ],
                  borderRadius: BorderRadius.circular(64),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_back_ios_new,
                      size: 24,
                      color: !_pressedBack
                          ? context.colors.primary
                          : context.colors.onPrimary,
                    ),
                    Text(
                      // '戻る',
                      'Return',
                      style: TextStyle(
                        fontSize: 24,
                        color: !_pressedBack
                            ? context.colors.primary
                            : context.colors.onPrimary,
                      ),
                    ),
                    SizedBox(width: 24),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.person,
                    size: 30,
                  ),
                  SizedBox(width: 10),
                  Text(widget.userData.userName,
                      style: TextStyle(
                        fontSize: 24,
                      )),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(top: 48, left: 72, right: 72),
                child: Container(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          // 上の段
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 残高
                              Padding(
                                padding: const EdgeInsets.only(left: 160),
                                child: Column(
                                  children: [
                                    Text(
                                      // '現在の残高',
                                      'UPay Balance',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '¥${formatter.format(widget.userData.balance)}',
                                      style: TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // チャージ金額
                              Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  SizedBox(
                                    width: 600,
                                    child: TextFormField(
                                      decoration: InputDecoration(
                                        // prefixText: '¥',
                                        // 入力が空のときに「¥」を表示しないために、prefixTextのvisibilityを制御します
                                        prefixStyle: TextStyle(
                                          color: inputController.text.isEmpty
                                              ? Colors.transparent
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                          fontSize: 60,
                                        ),
                                        hintText: '¥0',
                                        hintStyle: const TextStyle(
                                          fontSize: 68,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        counterText: '',
                                      ),
                                      style: TextStyle(
                                        fontSize: 68,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      autofocus: true,
                                      keyboardType: TextInputType.number,
                                      maxLength: 5,
                                      controller: inputController,
                                      textAlign: TextAlign.right,
                                      autocorrect: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 24),
                          // 下の段
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // +500
                              GestureDetector(
                                onTap: () {},
                                onTapDown: (details) {
                                  setState(() {
                                    _pressed500 = true;
                                  });
                                },
                                onTapUp: (details) {
                                  _addAmount(500);
                                  setState(() {
                                    _pressed500 = false;
                                  });
                                },
                                onTapCancel: () {
                                  _addAmount(500);
                                  setState(() {
                                    _pressed500 = false;
                                  });
                                },
                                child: Container(
                                  width: 240,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: !_pressed500
                                        ? context.colors.surfaceContainerLow
                                        : Theme.of(context).colorScheme.primary,
                                    /* border: Border.all(
                                      width: 2,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ), */
                                    boxShadow: [
                                      BoxShadow(
                                        color: !_pressed500
                                            ? Colors.black.withOpacity(0.4)
                                            : Colors.black.withOpacity(0),
                                        offset: Offset(0, 3), // シャドウの位置（x, y）
                                        blurRadius: 6, // ぼかしの半径
                                        spreadRadius: 0, // シャドウの広がり
                                      ),
                                    ],
                                    borderRadius: BorderRadius.circular(
                                        64), // OutlinedButtonのデフォルトの角丸を再現
                                  ),
                                  alignment: Alignment.center, // テキストを中央に配置
                                  child: Text(
                                    '+500',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: !_pressed500
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              // +1000
                              GestureDetector(
                                onTap: () {},
                                onTapDown: (details) {
                                  setState(() {
                                    _pressed1000 = true;
                                  });
                                },
                                onTapUp: (details) {
                                  _addAmount(1000);
                                  setState(() {
                                    _pressed1000 = false;
                                  });
                                },
                                onTapCancel: () {
                                  _addAmount(1000);
                                  setState(() {
                                    _pressed1000 = false;
                                  });
                                },
                                child: Container(
                                  width: 240,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: !_pressed1000
                                        ? context.colors.surfaceContainerLow
                                        : Theme.of(context).colorScheme.primary,
                                    boxShadow: [
                                      BoxShadow(
                                        color: !_pressed1000
                                            ? Colors.black.withOpacity(0.4)
                                            : Colors.black.withOpacity(0),
                                        offset: Offset(0, 3), // シャドウの位置（x, y）
                                        blurRadius: 6, // ぼかしの半径
                                        spreadRadius: 0, // シャドウの広がり
                                      ),
                                    ],
                                    borderRadius: BorderRadius.circular(
                                        64), // OutlinedButtonのデフォルトの角丸を再現
                                  ),
                                  alignment: Alignment.center, // テキストを中央に配置
                                  child: Text(
                                    '+1,000',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: !_pressed1000
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              // チャージする
                              GestureDetector(
                                onTap: () {},
                                onTapDown: (details) {
                                  setState(() {
                                    _pressedCharge = true;
                                  });
                                },
                                onTapUp: (details) {
                                  _popDialogue();
                                  setState(() {
                                    _pressedCharge = false;
                                  });
                                },
                                onTapCancel: () {
                                  _popDialogue();
                                  setState(() {
                                    _pressedCharge = false;
                                  });
                                },
                                child: Container(
                                  width: 600,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: isButtonEnabled && !_pressedCharge
                                        ? context.colors.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .outlineVariant,
                                    borderRadius: BorderRadius.circular(
                                        64), // ElevatedButtonのデフォルトの角丸を再現
                                    boxShadow:
                                        isButtonEnabled && !_pressedCharge
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.25),
                                                  spreadRadius: 1,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ]
                                            : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_card,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                      SizedBox(width: 10), // アイコンとテキストの間のスペース
                                      Text(
                                        // 'チャージする',
                                        'Top Up',
                                        style: TextStyle(
                                          fontSize: 28,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
            /* Expanded(
            flex: 5,
            child: Container(
                // color: Colors.black38,
                ),
          ), */
          ],
        ),
      ),
    );
  }
}

class AlertDialogSample extends StatefulWidget {
  const AlertDialogSample({
    super.key,
    required this.chargeAmount,
    required this.userData,
    required this.items,
  });

  final int chargeAmount;
  final UserData userData;
  final List<ItemData> items;

  @override
  State<AlertDialogSample> createState() => _AlertDialogSampleState();
}

class _AlertDialogSampleState extends State<AlertDialogSample> {
  final formatter = NumberFormat("#,###");

  bool _pressedCancel = false;
  bool _pressedComplete = false;

  bool _isDialogShowing = false;
  void _loadSelectPage() async {
    UserData newData = widget.userData.copyWith();
    newData.balance += widget.chargeAmount;

    // ダイアログが既に表示されている場合は表示しない
    if (!_isDialogShowing) {
      _isDialogShowing = true;
      // ダイアログを呼び出す
      await showLoadingDialog(context: context);
    }

    try {
      // データをロードし、処理が完了するまで待つ
      await topup(newData, widget.chargeAmount);
    } finally {
      // ダイアログを閉じる
      if (_isDialogShowing) {
        Navigator.of(context, rootNavigator: true).pop();
        _isDialogShowing = false;
      }
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return SelectPage(
            userData: newData,
            items: widget.items,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final Offset begin = Offset(0.0, -1.0); // 上から下
          // final Offset begin = Offset(-1.0, 0.0); // 左から右
          final Offset end = Offset.zero;
          final Animatable<Offset> tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: Curves.easeInOut));
          final Animation<Offset> offsetAnimation = animation.drive(tween);
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.secondaryContainer,
      title: SizedBox(
        height: 200,
        child: Image.asset(
          'images/Topup.png',
          fit: BoxFit.fitHeight,
        ),
      ),
      /* Icon(
        Icons.payments_outlined,
        size: 200,
      ), */
      insetPadding: EdgeInsets.all(24),
      content: Container(
        width: 1000,
        height: 120,
        child: Center(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 32,
                // fontWeight: FontWeight.bold,
                color: context.colors.onSecondaryContainer,
              ),
              children: [
                TextSpan(
                  // text: '横のお金入れに ',
                  text: 'Please insert ',
                ),
                TextSpan(
                  text: '¥${formatter.format(widget.chargeAmount)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 40),
                ),
                TextSpan(
                  // text: ' 入れてください\nおつりは計算して回収してください',
                  text:
                      ' into the side money slot.\nCalculate and collect your change.',
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      actions: <Widget>[
        SizedBox(
          width: 300,
          height: 80,
          child: Padding(
            padding: EdgeInsets.only(
              top: !_pressedCancel ? 0 : 4,
            ),
            child: GestureDetector(
              onTap: () {},
              onTapDown: (details) {
                setState(() {
                  _pressedCancel = true;
                });
              },
              onTapUp: (details) {
                Navigator.pop(context);
                setState(() {
                  // _pressedCancel = false;
                });
              },
              onTapCancel: () {
                Navigator.pop(context);
                setState(() {
                  // _pressedCancel = false;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: !_pressedCancel
                      ? context.colors.surface
                      : Theme.of(context)
                          .colorScheme
                          .outlineVariant, // ElevatedButtonのデフォルトの背景色を設定
                  borderRadius:
                      BorderRadius.circular(64), // ElevatedButtonのデフォルトの角丸を再現
                  boxShadow: [
                    BoxShadow(
                      color: !_pressedCancel
                          ? Colors.black.withOpacity(0.25)
                          : Colors.transparent,
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                child: Center(
                  child: Text(
                    // '入力に戻る',
                    'Return to input',
                    style: TextStyle(
                      fontSize: 28,
                      // fontWeight: FontWeight.bold,
                      color: context.colors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 16,
        ),
        SizedBox(
          width: 300,
          height: 80,
          child: Padding(
            padding: EdgeInsets.only(
              top: !_pressedComplete ? 0 : 4,
            ),
            child: GestureDetector(
              onTap: () {},
              onTapDown: (details) {
                setState(() {
                  _pressedComplete = true;
                });
              },
              onTapUp: (details) {
                _loadSelectPage();
                setState(() {
                  // _pressedCancel = false;
                });
              },
              onTapCancel: () {
                _loadSelectPage();
                setState(() {
                  // _pressedCancel = false;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: !_pressedComplete
                      ? context.colors.primary
                      : Theme.of(context)
                          .colorScheme
                          .outlineVariant, // ElevatedButtonのデフォルトの背景色を設定
                  borderRadius:
                      BorderRadius.circular(64), // ElevatedButtonのデフォルトの角丸を再現
                  boxShadow: [
                    BoxShadow(
                      color: !_pressedComplete
                          ? Colors.black.withOpacity(0.25)
                          : Colors.transparent,
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                child: Center(
                  child: Text(
                    // '完了した',
                    'Complete',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: context.colors.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> topup(UserData newData, int amount) async {
  // スプレッドシートの値を読み取る
  // サービスアカウントの認証情報をロード
  final credentials = await rootBundle.loadString('assets/credentials.json');
  final jsonCredentials = jsonDecode(credentials);
  final gsheets = GSheets(jsonCredentials);

  // スプレッドシートIDを指定
  final spreadsheetId = '1c8civD4TDvMohN-gQyOrnODUF-On2ZV8HseyWADFfKw';

  // スプレッドシートを取得
  final ss = await gsheets.spreadsheet(spreadsheetId);

  // シート名を指定してワークシートを取得
  final userDataSheet = ss.worksheetByTitle('UserData');

  // ユーザの情報を更新する
  await userDataSheet?.values.map
      .insertRowByKey(newData.id, newData.toGsheets());

  // チャージ履歴を書きこむ
  if (newData.id == 0) {
    // テストコードでは履歴を残したくない
    return;
  }
  final topupHistorySheet = ss.worksheetByTitle('TopupHistory');

  // 最後の行の位置を見つける
  final allRows = await topupHistorySheet?.values.allRows();
  if (allRows != null) {
    int lastRows = allRows.length + 1;
    TopupHistory newHistory = TopupHistory(
      time: DateTime.now().toString(),
      userID: newData.id,
      amount: amount,
      afterTopup: newData.balance,
    );
    await topupHistorySheet?.values.map
        .insertRow(lastRows, newHistory.toGsheets());
  }
}
