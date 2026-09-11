import 'package:upay_ver01/gas_api.dart';
import 'package:flutter/material.dart';
import 'package:upay_ver01/main.dart';
import 'package:upay_ver01/select_page.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/animation.dart';
import 'package:audioplayers/audioplayers.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({
    super.key,
    required this.userData,
    required this.items,
  });
  final UserData userData;
  final List<ItemData> items;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _scaleAnimation;
  late Timer timer;
  OverlayEntry? _checkmarkOverlayEntry;
  OverlayEntry? _whiteOutOverlayEntry;
  late AnimationController _whiteOutController;
  late AudioPlayer audioPlayer;

  List<ItemData> boughtItems = [];

  @override
  void initState() {
    super.initState();
    _initializeAudioPlayer();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      // Navigator.of(context).push(
      //   blackOut(const MyApp()),
      // );
    });
    for (int i = 0; i < widget.items.length; i++) {
      if (widget.items[i].tapCount > 0) {
        boughtItems.add(widget.items[i]);
      }
    }
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    /* _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    ); */

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _offsetAnimation =
        Tween<Offset>(begin: Offset(0, 1), end: Offset(0, -0.1)).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.8, curve: Curves.elasticOut), // 最初の0.5秒でスケールアップ
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.forward) {
        // スケールアップ開始と同時にオーディオを再生
        if (widget.userData.totalAmount < 10000) {
          playSound('sounds/upay_sound.wav');
        } else if (widget.userData.totalAmount < 20000) {
          // ゴールド会員はゴージャスな効果音
          playSound('sounds/upay_sound_gold.wav');
        } else if (widget.userData.totalAmount < 30000) {
          // 2万円以上の方には更なる効果音
          playSound('sounds/upay_sound_two.wav');
        }
      }
    });

    _whiteOutController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  void _cancelTimer() {
    if (timer != null) {
      timer.cancel();
    }
  }

  void _initializeAudioPlayer() {
    audioPlayer = AudioPlayer();
    // 必要に応じてここで他の初期化コードを追加
  }

// チェックマークアニメーションをオーバーレイで表示する関数
  Future<void> showCheckmarkOverlay(BuildContext context) async {
    _checkmarkOverlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Container(
            color: Colors.white.withOpacity(0.5),
          ),
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: SizedBox(
                height: 400,
                child: Image.asset(
                  'images/UPay_Icon.png',
                  fit: BoxFit.fitHeight,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_checkmarkOverlayEntry!);
    await _controller.forward();

    // 0.1秒の遅延を追加
    await Future.delayed(Duration(microseconds: 100));
    // アニメーションが終了したらオーバーレイを削除
    // overlayEntry.remove();
    // _controller.reset();

    // await Future.delayed(Duration(seconds: 1));
    // overlayEntry.remove();
  }

  void playSound(String path) async {
    try {
      await audioPlayer.setSourceAsset(path);
      await audioPlayer.resume();
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // ホワイトアウトのオーバーレイを追加する関数
  Future<void> showWhiteOutOverlay(BuildContext context) async {
    print('ホワイトアウトのオーバーレイを追加');
    final Animation<double> animation = CurvedAnimation(
      parent: _whiteOutController,
      curve: Curves.easeInOut,
    );

    _whiteOutOverlayEntry = OverlayEntry(
      builder: (context) => FadeTransition(
        opacity: animation,
        child: Container(
          color: Colors.white,
        ),
      ),
    );

    Overlay.of(context).insert(_whiteOutOverlayEntry!);
    await _whiteOutController.forward();
    await Future.delayed(Duration(milliseconds: 500));
    // チェックマークのオーバーレイを削除
    print('チェックマークのオーバーレイを削除');
    _checkmarkOverlayEntry?.remove();
    _checkmarkOverlayEntry = null;
  }

  Future<void> navigateWithWhiteOut(BuildContext context, Widget screen) async {
    await showWhiteOutOverlay(context); // ホワイトアウトのオーバーレイを表示
    _whiteOutOverlayEntry?.remove();
    _whiteOutOverlayEntry = null;
    Navigator.of(context)
        .push(PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionDuration: Duration(seconds: 0), // 即時遷移
    ))
        .then((_) async {
      // 新しいシーンが表示された後、ホワイトアウトのオーバーレイをフェードアウト
      // もう呼び出されないのであきらめる
      /* print('ホワイトアウトのオーバーレイをフェードアウト');
      await _whiteOutController.reverse();
      _whiteOutOverlayEntry?.remove();
      _whiteOutOverlayEntry = null; */
    });
  }
  /* Future<void> showWhiteOutOverlay(BuildContext context) async {
    final AnimationController controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    final Animation<double> animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    );

    _whiteOutOverlayEntry = OverlayEntry(
      builder: (context) => FadeTransition(
        opacity: animation,
        child: Container(
          color: Colors.white,
        ),
      ),
    );

    Overlay.of(context).insert(_whiteOutOverlayEntry!);
    await controller.forward();
    // チェックマークのオーバーレイを削除
    _checkmarkOverlayEntry?.remove();
    _checkmarkOverlayEntry = null;
    controller.dispose();
  } */

  final formatter = NumberFormat("#,###");

  bool _pressedBack = false;
  void _loadBackPage() {
    _cancelTimer();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return SelectPage(
            userData: widget.userData,
            items: widget.items,
          );
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

  String _purchaseOrder() {
    String str = '';
    // widgetのitemsから求める
    // ｺｶ･ｺｰﾗ 1本
    // ｺｶ･ｺｰﾗ 1本,爽健美茶 2本,カルピス 1本
    int purchaseNum = 0;
    List<ItemData> data = [...widget.items];
    for (int i = 0; i < data.length; i++) {
      if (data[i].tapCount > 0) {
        if (purchaseNum > 0) {
          str += ', ';
        }
        str += '${data[i].name}';
        if (data[i].tapCount > 1) {
          str += '×${data[i].tapCount}';
        }
        purchaseNum++;
      }
    }
    return str;
  }

  String _pruchaseNum() {
    String str = '';
    // ○点の商品を取り出してください
    int purchaseNum = 0;
    List<ItemData> data = [...widget.items];
    for (int i = 0; i < data.length; i++) {
      if (data[i].tapCount > 0) {
        purchaseNum += data[i].tapCount;
      }
    }
    str = '${purchaseNum}';
    if (purchaseNum > 1) {
      str += ' points';
    } else {
      str += 'point';
    }
    return str;
  }

  int _getNewBalance() {
    UserData user = widget.userData.copyWith();

    List<ItemData> data = [...widget.items];
    for (int i = 0; i < data.length; i++) {
      if (data[i].tapCount > 0) {
        user.balance -= data[i].price * data[i].tapCount;
      }
    }
    return user.balance;
  }

  bool _pressedComplete = false;

  bool _isDialogShowing = false;
  void _loadTopPage() async {
    if (_isDialogShowing) return;
    UserData newData = widget.userData.copyWith();

    // ダイアログが既に表示されている場合は表示しない
    if (!_isDialogShowing) {
      _isDialogShowing = true;
      // ダイアログを呼び出す
      await showLoadingDialog(
          context: context, barrierColor: Colors.white.withOpacity(0.5));
    }

    try {
      // データをロードし、処理が完了するまで待つ
      await purchase(newData, [...widget.items]);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString()),
            duration: const Duration(seconds: 8)));
      return;
    } finally {
      // ダイアログを閉じる
      if (_isDialogShowing) {
        Navigator.of(context, rootNavigator: true).pop();
        _isDialogShowing = false;
      }
    }

    if (!mounted) return;
    await showCheckmarkOverlay(context);

    // ホワイトアウトを使って新しい画面に遷移
    await navigateWithWhiteOut(context, MyApp());

    /* Navigator.of(context).push(
      // blackOut(MyApp()),
      colorOut(PaymentPage(userData: widget.userData, items: widget.items),
          Colors.white),
    ); */
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
            // '決済',
            'Pay',
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
                      : context.colors.error,
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
                          ? context.colors.error
                          : context.colors.onError,
                    ),
                    Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 24,
                        color: !_pressedBack
                            ? context.colors.error
                            : context.colors.onError,
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
            // 購入しているアイコン
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  //スクロール
                  scrollDirection: Axis.horizontal, //スクロールの方向、水平
                  padding: const EdgeInsets.all(0),
                  // childAspectRatio: (200 / 300),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(
                        boughtItems.length,
                        (index) => Padding(
                              padding: const EdgeInsets.only(
                                  bottom: 8, top: 8, left: 8, right: 8),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    maximumSize: Size(220, 260),
                                    // minimumSize: Size(0,400),
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          width: 4), // アウトラインを追加
                                    ),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer),
                                clipBehavior:
                                    Clip.antiAliasWithSaveLayer, // 画像を丸角にする
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      height: 16,
                                    ),
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          height: 196,
                                          child: Image.network(
                                            boughtItems[index]
                                                .imagePath, // 商品の画像
                                          ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: -10,
                                          child: SizedBox(
                                            height: 32,
                                            width: 48,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary, // 背景色を設定
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        8), // 角丸の半径を設定
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '× ${boughtItems[index].tapCount.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onPrimary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // 商品名
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 4),
                                      child: Center(
                                        child: FittedBox(
                                          child: Text(
                                            boughtItems[index].name,
                                            style: TextStyle(
                                              // fontWeight: FontWeight.w600,
                                              fontSize: 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 4,
                                    ),
                                  ],
                                ),
                                onPressed: () {
                                  null;
                                },
                              ),
                            )),
                  ),
                ),
              ),
            ),
            // 購入が完了しました～
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Center(
                          child: FittedBox(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 36,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .inverseSurface,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Please take out the product for ',
                                    style: TextStyle(
                                      fontSize: 32,
                                      // fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  TextSpan(
                                    text: '${_pruchaseNum()}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  // TextSpan(
                                  //   text: ' の商品を取り出してください',
                                  //   style: TextStyle(
                                  //     fontSize: 32,
                                  //     // fontWeight: FontWeight.bold,
                                  //   ),
                                  // ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 6,
                        ),
                        Center(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 32,
                                // fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .inverseSurface,
                                fontFamily: 'Outfit',
                              ),
                              children: [
                                TextSpan(
                                  text: '${widget.userData.userName}\'s',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  // text: ' さんの残金は ',
                                  text: ' remaining balance is ',
                                  style: TextStyle(
                                    fontSize: 28,
                                    // fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      '¥${formatter.format(_getNewBalance())}',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                /* TextSpan(
                                  text: ' です',
                                  style: TextStyle(
                                    fontSize: 28,
                                    // fontWeight: FontWeight.bold,
                                  ),
                                ), */
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        right: 24.0,
                        bottom: !_pressedComplete ? 28 : 24,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {},
                            onTapDown: (details) {
                              setState(() {
                                _pressedComplete = true;
                              });
                            },
                            onTapUp: (details) {
                              _cancelTimer();
                              _loadTopPage();
                              setState(() {
                                // _pressedCancel = false;
                              });
                            },
                            onTapCancel: () {
                              // この完了ボタンは処理をキャンセルできないので気を付けて押してもらう
                              setState(() {
                                _pressedComplete = false;
                              });
                            },
                            child: Container(
                              width: 550,
                              height: 100,
                              decoration: BoxDecoration(
                                color: !_pressedComplete
                                    ? context.colors.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                borderRadius: BorderRadius.circular(
                                    64), // ElevatedButtonのデフォルトの角丸を再現
                                boxShadow: [
                                  BoxShadow(
                                    color: !_pressedComplete
                                        ? Colors.black.withOpacity(0.25)
                                        : Colors.transparent,
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 40),
                              alignment: Alignment.center, // テキストを中央に配置
                              child: Text(
                                'Taken out.',
                                style: TextStyle(
                                  fontSize: 32,
                                  color: context.colors.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

PageRouteBuilder<Object?> colorOut(Widget screen, Color color) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => screen,
    transitionDuration: const Duration(seconds: 1),
    reverseTransitionDuration: const Duration(seconds: 1),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final backgroundColor = ColorTween(
        begin: Colors.transparent,
        end: color,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0, 0.5, curve: Curves.easeInOut),
        ),
      );
      final opacity = Tween<double>(
        begin: 0,
        end: 1,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0.5, 1, curve: Curves.easeInOut),
        ),
      );
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Container(
            color: backgroundColor.value,
            child: Opacity(
              opacity: opacity.value,
              child: child,
            ),
          );
        },
        child: child,
      );
    },
  );
}

Future<void> purchase(UserData user, List<ItemData> items) async {
  final result = await GasApi.instance.transact('purchase', user.sessionToken, {
    'items': items
        .where((item) => item.tapCount > 0)
        .map((item) => {
              'itemId': item.id,
              'quantity': item.tapCount,
            })
        .toList(),
  });
  user.applyApi(result);
}
