import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:upay_ver01/camera_page.dart';
import 'package:upay_ver01/charge_page.dart';
import 'package:upay_ver01/main.dart';
import 'package:upay_ver01/payment_page.dart';
import 'package:intl/intl.dart';
import 'package:countup/countup.dart';

class SelectPage extends StatefulWidget {
  const SelectPage({
    super.key,
    required this.userData,
    required this.items,
  });
  final UserData userData;
  final List<ItemData> items;
  @override
  _SelectPageState createState() => _SelectPageState();
}

class _SelectPageState extends State<SelectPage> {
  // List<ItemCard> itemCards = List.generate(5, (index) => ItemCard());
  // List<ItemData> items = List.generate(5, (index) => ItemData());
  bool isBuyButtonEnabled = false;

  final formatter = NumberFormat("#,###");

  @override
  void initState() {
    super.initState();
    // 初期化
    setState(() {
      // isBuyButtonEnabled = true;
      // 今の合計金額とUserDataの残高を比べて決める
      int price = _calculatePrice();
      int balance = widget.userData.balance;
      if (price != 0 && price <= balance) {
        isBuyButtonEnabled = true;
      } else {
        isBuyButtonEnabled = false;
      }
    });
  }

  bool _pressedBack = false;
  void _loadBackPage() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return MyApp();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // final Offset begin = Offset(1.0, 0.0); // 右から左
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

  void _onButtonPressed(int index) {
    if (!_isItemButtonEnabled) return;
    setState(() {
      widget.items[index].tapCount++;
      // isBuyButtonEnabled = true;
      // 今の合計金額とUserDataの残高を比べて決める
      int price = _calculatePrice();
      int balamce = widget.userData.balance;
      if (price <= balamce && price != 0) {
        isBuyButtonEnabled = true;
      } else {
        isBuyButtonEnabled = false;
      }
      _isItemButtonEnabled = false;
    });
    Future.delayed(Duration(milliseconds: 200), () {
      setState(() {
        _isItemButtonEnabled = true;
      });
    });
  }

  void _resetButton() {
    setState(() {
      for (int i = 0; i < widget.items.length; i++) {
        widget.items[i].tapCount = 0;
      }
      isBuyButtonEnabled = false;
    });
  }

  int _calculatePrice() {
    int sum = 0;
    for (int i = 0; i < widget.items.length; i++) {
      sum += widget.items[i].price * widget.items[i].tapCount;
    }
    return sum;
  }

  bool _chargeButtonPressed = false;

  void _onChargeTap() {}

  void _onChargeTapDown(TapDownDetails value) {
    setState(() {
      _chargeButtonPressed = true;
    });
  }

  void _onChargeTapUp(TapUpDetails value) {
    _loadNext();
    setState(() {
      // _buttonPressed = false;
    });
  }

  void _onChargeTapCancel() {
    _loadNext();
    setState(() {
      // _buttonPressed = false;
    });
  }

  void _loadNext() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return ChargePage(
            userData: widget.userData,
            items: widget.items,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final Offset begin = Offset(0.0, 1.0); // 下から上
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

  bool _pressedCancel = false;
  bool _pressedBuy = false;
  bool _isItemButtonEnabled = true;

  void _loadPaymentPage() {
    if (isBuyButtonEnabled) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return PaymentPage(userData: widget.userData, items: widget.items);
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
            // '商品の選択',
            'Product Selection',
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
                      'Top',
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
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              /* Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    /* onTap: _onTap,
                    onTapCancel: _onTapCancel,
                    onTapUp: _onTapUp,
                    onTapDown: _onTapDown, */
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                              // color: Colors.black.withOpacity(0.25),
                              // spreadRadius: 1,
                              // blurRadius: 4,
                              // offset: Offset(0, 4),
                              ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(
                            left: 16, right: 16, top: 4, bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              child: Image.asset(
                                'images/drink.png',
                                // fit: BoxFit.fitHeight,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'drink',
                              style: TextStyle(
                                fontSize: 20,
                                color: context.colors.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 24,
                  ),
                  GestureDetector(
                    /* onTap: _onTap,
                    onTapCancel: _onTapCancel,
                    onTapUp: _onTapUp,
                    onTapDown: _onTapDown, */
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(
                            left: 16, right: 16, top: 4, bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              child: Image.asset(
                                'images/snack.png',
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'snack',
                              style: TextStyle(
                                fontSize: 20,
                                color: context.colors.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 24,
                  ),
                  GestureDetector(
                    /* onTap: _onTap,
                    onTapCancel: _onTapCancel,
                    onTapUp: _onTapUp,
                    onTapDown: _onTapDown, */
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(
                            left: 16, right: 16, top: 4, bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              child: Image.asset(
                                'images/food.png',
                                // fit: BoxFit.fitHeight,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'food',
                              style: TextStyle(
                                fontSize: 20,
                                color: context.colors.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ), */
              Expanded(
                child: SingleChildScrollView(
                  //スクロール
                  scrollDirection: Axis.horizontal, //スクロールの方向、水平
                  padding: const EdgeInsets.all(0),
                  // childAspectRatio: (200 / 300),
                  child: Row(
                    children: List.generate(
                        widget.items.length,
                        (index) => Padding(
                              padding: const EdgeInsets.only(
                                  bottom: 16, top: 8, left: 8, right: 8),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  maximumSize: Size(220, 400),
                                  // minimumSize: Size(0,400),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: widget.items[index].tapCount > 0
                                        ? BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            width: 4)
                                        : BorderSide(
                                            color: Colors.transparent,
                                            width: 0), // アウトラインを追加
                                  ),
                                  backgroundColor:
                                      widget.items[index].tapCount > 0
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                          : Colors.white,
                                ),
                                clipBehavior:
                                    Clip.antiAliasWithSaveLayer, // 画像を丸角にする
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      height: 12,
                                    ),
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          height: 196,
                                          child: Image.network(
                                            widget.items[index]
                                                .imagePath, // 商品の画像
                                            // fit: BoxFit.fitHeight,
                                          ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: -10,
                                          child: SizedBox(
                                            height: 52,
                                            width: 80,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: widget.items[index]
                                                            .tapCount >
                                                        0
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : Colors
                                                        .transparent, // 背景色を設定
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        16), // 角丸の半径を設定
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '× ${widget.items[index].tapCount.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                    color: widget.items[index]
                                                                .tapCount >
                                                            0
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .onPrimary
                                                        : Colors.transparent,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        /* Positioned(
                                          top: 0,
                                          left: -10,
                                          child: SizedBox(
                                            height: 32,
                                            width: 32,
                                            child: Center(
                                              child: Image.asset(
                                                'images/food.png',
                                                color:context.colors.primary
                                              ),
                                            ),
                                          ),
                                        ), */
                                      ],
                                    ),
                                    SizedBox(
                                      height: 4, // 画像と商品名の間の余白
                                    ),
                                    // 商品名
                                    Container(
                                      width: double.infinity,
                                      // padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment: CrossAxisAlignment
                                            .center, // 縦方向の位置合わせ
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: Image.asset(
                                              _getImagePath(
                                                  widget.items[index].category),
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 4,
                                          ),
                                          Expanded(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                widget.items[index].name,
                                                style: TextStyle(
                                                  // fontWeight: FontWeight.w600,
                                                  fontSize: 24,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 値段
                                    Container(
                                      width: double.infinity,
                                      // padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Center(
                                        child: Text(
                                          '¥${widget.items[index].price.toStringAsFixed(0)}',
                                          style: TextStyle(
                                              // color: Colors.grey,
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 10,
                                    ),
                                  ],
                                ),
                                onPressed: () {
                                  _onButtonPressed(index);
                                },
                              ),
                            )),
                  ),
                ),
              ),
              // SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Card(
                    color: context.colors.secondaryContainer,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SizedBox(
                      width: 550,
                      height: 200,
                      // 残高 チャージ
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SizedBox(
                              width: 420,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  SizedBox(height: 10),
                                  FittedBox(
                                    fit: BoxFit.fitWidth,
                                    child: Text(
                                      '${widget.userData.userName}\'s Balance',
                                      style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer),
                                      textAlign: TextAlign.left,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        '¥',
                                        style: TextStyle(
                                            fontSize: 64,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSecondaryContainer),
                                      ),
                                      Countup(
                                        begin: 0,
                                        end: widget.userData.balance.toDouble(),
                                        duration: Duration(milliseconds: 1000),
                                        separator: ',',
                                        style: TextStyle(
                                            fontSize: 64,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSecondaryContainer),
                                      ),
                                    ],
                                  ),
                                  /* Text(
                                  '¥${formatter.format(widget.userData.balamce)}',
                                  style: TextStyle(
                                      fontSize: 64,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer),
                                  textAlign: TextAlign.left,
                                ), */
                                ],
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: !_chargeButtonPressed ? 4 : 0,
                                  ),
                                  child: GestureDetector(
                                    onTap: _onChargeTap,
                                    onTapUp: _onChargeTapUp,
                                    onTapDown: _onChargeTapDown,
                                    onTapCancel: _onChargeTapCancel,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: !_chargeButtonPressed
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .outlineVariant,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: !_chargeButtonPressed
                                                ? Colors.black.withOpacity(0.25)
                                                : Colors.black.withOpacity(0),
                                            spreadRadius: 1,
                                            blurRadius: 4,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      padding: EdgeInsets.all(24),
                                      child: Icon(
                                        Icons.add_card,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 取り消し・購入
                  SizedBox(
                    height: 200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 取り消し
                        GestureDetector(
                          onTap: () {},
                          onTapDown: (details) {
                            setState(() {
                              _pressedCancel = true;
                            });
                          },
                          onTapUp: (details) {
                            _resetButton();
                            setState(() {
                              _pressedCancel = false;
                            });
                          },
                          onTapCancel: () {
                            _resetButton();
                            setState(() {
                              _pressedCancel = false;
                            });
                          },
                          child: Container(
                            width: 200,
                            height: 80,
                            decoration: BoxDecoration(
                              color: !_pressedCancel
                                  ? context.colors.surfaceContainerLow
                                  : context.colors.error,
                              boxShadow: [
                                BoxShadow(
                                  color: !_pressedCancel
                            ? Colors.black.withOpacity(0.2)
                            : Colors.transparent,
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
                              // '取り消し',
                              'Clear',
                              style: TextStyle(
                                fontSize: 28,
                                color: !_pressedCancel
                                    ? context.colors.error
                                    : context.colors.onError,
                              ),
                            ),
                          ),
                        ),
                        // 購入する
                        GestureDetector(
                          onTap: () {},
                          onTapDown: (details) {
                            setState(() {
                              _pressedBuy = true;
                            });
                          },
                          onTapUp: (details) {
                            _loadPaymentPage();
                            setState(() {
                              // _pressedBuy = false;
                            });
                          },
                          onTapCancel: () {
                            _loadPaymentPage();
                            setState(() {
                              // _pressedBuy = false;
                            });
                          },
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: !_pressedBuy ? 4 : 0,
                            ),
                            child: Container(
                              width: 550,
                              height: 100,
                              decoration: BoxDecoration(
                                color: isBuyButtonEnabled && !_pressedBuy
                                    ? context.colors.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                borderRadius: BorderRadius.circular(
                                    64), // ElevatedButtonのデフォルトの角丸を再現
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 40),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    // '購入する',
                                    'Pay',
                                    style: TextStyle(
                                      fontSize: 28,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                    ),
                                  ),
                                  Text(
                                    '¥${_calculatePrice()}',
                                    style: TextStyle(
                                      fontSize: 36,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ヘルパーメソッド
String _getImagePath(ItemCategory category) {
  switch (category) {
    case ItemCategory.drink:
      return 'images/drink.png';
    case ItemCategory.food:
      return 'images/food.png';
    case ItemCategory.snack:
      return 'images/snack.png';
    default:
      return 'images/dirnk.png'; // デフォルトの画像パス
  }
}
