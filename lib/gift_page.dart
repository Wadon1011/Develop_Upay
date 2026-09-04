import 'package:flutter/material.dart';
import 'package:upay_ver01/main.dart';
import 'package:upay_ver01/select_page.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:gsheets/gsheets.dart';
import 'package:upay_ver01/encryption_helper.dart';
import 'package:gsheets/gsheets.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class GiftPage extends StatefulWidget {
  const GiftPage({
    super.key,
    required this.userData,
    required this.items,
  });
  final UserData userData;
  final List<ItemData> items;
  @override
  State<GiftPage> createState() => _GiftPageState();
}

class _GiftPageState extends State<GiftPage>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }

  bool _pressedBack = false;
  void _loadBackPage() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return MyApp();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final Offset begin = Offset(-1.0, 0.0); // 左から右
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

// 次のシーンの読み出しはこの関数が行う
// もしユーザのGiftAmountが0より大きければgift_page.dartを読み込む、0以下であれば今まで通りselect_page.dart
  void _loadNextPage(UserData loadUserData, List<ItemData> items) {
    if (loadUserData.giftAmount > 0) {
      // gift_page.dart
    } else {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return SelectPage(
              userData: loadUserData,
              items: items,
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final Offset begin = Offset(1.0, 0.0); // 右から左
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
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        // backgroundColor: Color(0xFFFAFAFA),
        backgroundColor: context.colors.tertiaryContainer,
        appBar: AppBar(
          toolbarHeight: 100, // Set this height
          /* elevation: 3,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black, */
          title: Text(
            // 'ギフトカード',
            'Gift Card',
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
                  color: !_pressedBack ? Colors.white : Colors.black,
                  border: Border.all(
                    width: 2,
                    color: !_pressedBack ? Colors.black : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(64),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_back_ios_new,
                      size: 24,
                      color: !_pressedBack ? Colors.black : Colors.white,
                    ),
                    Text(
                      // '戻る',
                      'Top',
                      style: TextStyle(
                        fontSize: 24,
                        color: !_pressedBack ? Colors.black : Colors.white,
                      ),
                    ),
                    SizedBox(width: 24),
                  ],
                ),
              ),
            ),
          ),
          actions: <Widget>[],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                Container(
                  height: constraints.maxHeight * 0.7,
                  child: Center(
                      child: GiftCard(
                          userData: widget.userData, items: widget.items)),
                ),
                Container(
                  height: constraints.maxHeight * 0.3,
                  alignment: Alignment.topCenter,
                  child:
                      BuyButton(userData: widget.userData, items: widget.items),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class GiftCard extends StatelessWidget {
  const GiftCard({
    super.key,
    required this.userData,
    required this.items,
  });
  final UserData userData;
  final List<ItemData> items;
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
      ),
      child: Container(
        padding: EdgeInsets.all(40),
        width: 800,
        height: 350,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  Text(
                    'UPay gift card',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 90),
                  Text(
                    '¥${userData.giftAmount}',
                    style: TextStyle(
                      fontSize: 54,
                      color: context.colors.tertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Image.asset(
              'images/UPay_Icon.png',
              fit: BoxFit.fitHeight,
            ),
          ],
        ),
      ),
    );
  }
}

class BuyButton extends StatefulWidget {
  const BuyButton({
    super.key,
    required this.userData,
    required this.items,
  });
  final UserData userData;
  final List<ItemData> items;
  @override
  _BuyButtonState createState() => _BuyButtonState();
}

class _BuyButtonState extends State<BuyButton> {
  bool isBuyButtonEnabled = true;
  bool _pressedBuy = false;

  void _loadSelectPage() async {
    bool _isDialogShowing = false;
    // 商品選択ページへの遷移をここに追加
    print('Navigating to payment page...');
    UserData newUserData = widget.userData.copyWith();
    newUserData.balance += widget.userData.giftAmount;
    newUserData.giftAmount = 0;

    // ダイアログが既に表示されている場合は表示しない
    if (!_isDialogShowing) {
      _isDialogShowing = true;
      // ダイアログを呼び出す
      await showLoadingDialog(context: context);
    }

    try {
      // データをロードし、処理が完了するまで待つ
      await charge(newUserData);
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
            userData: newUserData,
            items: widget.items,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // final Offset begin = Offset(0.0, -1.0); // 上から下
          final Offset begin = Offset(1.0, 0.0); // 右から左
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

  Future<void> charge(UserData newUserData) async {
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
        .insertRowByKey(newUserData.id, newUserData.toGsheets());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      onTapDown: (details) {
        setState(() {
          _pressedBuy = true;
        });
      },
      onTapUp: (details) {
        _loadSelectPage();
        setState(() {
          _pressedBuy = false;
        });
      },
      onTapCancel: () {
        _loadSelectPage();
        setState(() {
          _pressedBuy = false;
        });
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: !_pressedBuy ? 4 : 0,
        ),
        child: Container(
          width: 800,
          height: 100,
          decoration: BoxDecoration(
            color: isBuyButtonEnabled && !_pressedBuy
                ? context.colors.tertiary
                : context.colors.outlineVariant,
            borderRadius: BorderRadius.circular(64),
            boxShadow: isBuyButtonEnabled && !_pressedBuy
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Receive Gift Card!!',
                style: TextStyle(
                  fontSize: 36,
                  color: context.colors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
