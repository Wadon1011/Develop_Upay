import 'package:upay_ver01/gas_api.dart';
import 'package:flutter/material.dart';
import 'package:upay_ver01/gift_page.dart';
import 'package:upay_ver01/main.dart';
import 'package:upay_ver01/select_page.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({
    super.key,
    required this.items,
    required this.users,
  });

  final List<ItemData> items;
  final List<UserData> users;
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage>
    with SingleTickerProviderStateMixin {
  // スキャナーの作用を制御するコントローラーのオブジェクト
  MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool isStarted = true; // カメラがオンしているかどうか
  double zoomFactor = 0.0; // ズームの程度。0から1まで。多いほど近い

  @override
  void initState() {
    super.initState();
    // カメラの向きをフロントカメラに設定
    // controller.switchCamera();
    // ↑意味ないのでmobile_scanner_controllerを内部から変える
    print('暗号化と復号化テスト');
    /* final key = 'my_secret_key'; // キーワード
    final encryptionHelper = EncryptionHelper(key);

    final originalStrings = ['A', 'B', 'C', 'D'];
    final encryptedStrings =
        originalStrings.map(encryptionHelper.encryptString).toList();
    final decryptedStrings =
        encryptedStrings.map(encryptionHelper.decryptString).toList();

    print('Original Strings: $originalStrings');
    print('Encrypted Strings: $encryptedStrings');
    print('Decrypted Strings: $decryptedStrings'); */
  }

  /* // 引数の全ユーザの情報から、読み取ったユーザを探してそれを引数に次へ渡す
  UserData _loadUserData(int id) {
    print('読み込んだidは${id}');
    // UserData findData = widget.users.firstWhere((element) => element.id == id);

    // 末尾はチェックデジットなので省く
    id = id ~/ 10;

    // 上7桁は関係ない
    id = id % 100000;

    print('編集したidは${id}');
    // firstWhereだと見つからなかったとき止まるので編集
    for (int i = 0; i < widget.users.length; i++) {
      if (widget.users[i].id == id) {
        return widget.users[i];
      }
    }
    // 正しいバーコードでなかったとき
    // ダイアログが出て再度実行できるようにしたい
    return widget.users[0];
  } */

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

  bool _verifying = false;
  Future<void> _loadScanData(BarcodeCapture scanData) async {
    if (_verifying || scanData.barcodes.isEmpty) return;
    final token = scanData.barcodes.first.rawValue;
    if (token == null) return;
    _verifying = true;
    try {
      await controller.stop();
      final result = await GasApi.instance.verifyQr(token.trim());
      final user = UserData.fromApi(
          Map<String, dynamic>.from(result['user'] as Map),
          result['sessionToken'] as String);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _loadNextPage(user, widget.items);
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('QRコードを確認してください'),
                content: Text(error.toString()),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('再読み取り'))
                ],
              ));
      if (mounted) {
        _verifying = false;
        await controller.start();
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

// 次のシーンの読み出しはこの関数が行う
// もしユーザのGiftAmountが0より大きければgift_page.dartを読み込む、0以下であれば今まで通りselect_page.dart
  void _loadNextPage(UserData loadUserData, List<ItemData> items) {
    if (loadUserData.giftAmount > 0) {
      // gift_page.dart
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return GiftPage(
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
          backgroundColor: context.colors.surfaceContainerLow,
          appBar: AppBar(
            toolbarHeight: 100, // Set this height
            // elevation: 3,
            // backgroundColor: context.colors.onPrimary,
            // surfaceTintColor: Colors.transparent,
            // shadowColor: Colors.black,
            title: Text(
              // 'QRコード読み取り',
              'Code Scanning',
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
                    controller.stop();
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
            actions: <Widget>[],
          ),
          body: Center(
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: Container(
                      // height: double.infinity,
                      // color: Colors.red,
                      child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 560,
                        child: SvgPicture.asset(
                          'images/CodeIcon.svg',
                          fit: BoxFit.fitHeight,
                          colorFilter: ColorFilter.mode(
                            context.colors.primary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ],
                  )),
                ),
                Expanded(
                  flex: 7,
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: MobileScanner(
                      controller: controller,

                      fit: BoxFit.cover,
                      // QRコードかバーコードが見つかった後すぐ実行する関数
                      onDetect: _loadScanData,
                    ),
                  ),
                ),
                // こっちはカメラが面倒だからテスト用に
                /* Expanded(
                  flex: 7,
                  child: RotatedBox(
                    quarterTurns: 0,
                    child: ElevatedButton.icon(
                      icon: const Icon(
                        Icons.camera_alt_rounded,
                        // color: context.colors.onPrimary,
                        size: 40,
                      ),
                      label: const Text(
                        'testユーザーなので通ってよし',
                        style: TextStyle(fontSize: 40), // 文字を大きく
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        foregroundColor: context.colors.onPrimary,
                        padding: const EdgeInsets.all(40),
                      ),
                      onPressed: () {
                        _loadNextPage(widget.users[0], widget.items);
                      },
                    ),
                  ),
                ), */
              ],
            ),
          ),
        ));
  }
}

class AlertDialogSample extends StatefulWidget {
  const AlertDialogSample({
    super.key,
    required this.items,
    required this.users,
  });
  final List<ItemData> items;
  final List<UserData> users;

  @override
  State<AlertDialogSample> createState() => _AlertDialogSampleState();
}

class _AlertDialogSampleState extends State<AlertDialogSample> {
  bool _pressedCancel = false;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.secondaryContainer,
      insetPadding: EdgeInsets.all(60),
      title: Container(
          width: 500,
          height: 120,
          child: Center(
            child: Text('Failed to read the relevant code',
                // '該当するバーコードが\n読み取れませんでした',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  // fontWeight: FontWeight.bold,
                  color: context.colors.onSecondaryContainer,
                )),
          )),
      actions: <Widget>[
        Center(
          child: SizedBox(
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CameraPage(
                              items: widget.items,
                              users: widget.users,
                            )),
                  );
                  setState(() {
                    // _pressedCancel = false;
                  });
                },
                onTapCancel: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CameraPage(
                              items: widget.items,
                              users: widget.users,
                            )),
                  );
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
                      // 'やり直す',
                      'Retry',
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
          /* SizedBox(
            width: 300,
            height: 80,
            child: GestureDetector(
              child: Center(
                  child: Text(
                'やり直す',
                style: TextStyle(
                  fontSize: 28,
                  // fontWeight: FontWeight.bold,
                  // color: Theme.of(context).colorScheme.primary,
                ),
              )),
              onTap: () {
                // Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CameraPage(
                            items: items,
                            users: users,
                          )),
                );
              },
            ),
          ), */
        ),
      ],
    );
  }
}
