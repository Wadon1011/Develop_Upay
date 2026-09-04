import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class ItemCard extends StatefulWidget {
  @override
  _ItemCardState createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  int tapCount = 0;

  void _onButtonPressed() {
    setState(() {
      print("押された");
      if (tapCount < 100) {
        tapCount++;
      } else {
        // ボタンが震えるエフェクト
        // 実装方法は様々ですが、簡単な方法としてVibrationパッケージを使用できます
        // Vibration.vibrate();
      }
    });
  }

// ゲッターを追加
  int get currentTapCount => tapCount;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        maximumSize: Size(220, 400),
        // minimumSize: Size(0,400),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: tapCount > 0
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary, width: 4)
              : BorderSide(color: Colors.transparent), // アウトラインを追加
        ),
        backgroundColor: tapCount > 0
            ? Theme.of(context).colorScheme.primaryContainer
            : Color(0xFFFAFAFA),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer, // 画像を丸角にする
      child: Column(
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
                height: 220,
                child: Image.asset(
                  'images/coca-cola.png', // 商品の画像
                  fit: BoxFit.fitHeight,
                ),
              ),
              Positioned(
                top: -10,
                right: -10,
                child: SizedBox(
                    height: 48,
                    width: 48,
                    child: Center(
                      child: Text('× ${tapCount.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: tapCount > 0
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent)),
                    )),
              ),
            ],
          ),
          // タイトル
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Center(
              child: const Text(
                'ｺｶ･ｺｰﾗ',
                style: TextStyle(
                  // fontWeight: FontWeight.w600,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          // 説明文
          Container(
            width: double.infinity,
            // padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: const Text(
                '¥100',
                style: TextStyle(
                    // color: Colors.grey,
                    fontSize: 36,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      onPressed: () {
        _onButtonPressed();
      },
    );
  }
}
