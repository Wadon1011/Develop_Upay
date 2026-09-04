import 'package:flutter/material.dart';
import 'package:upay_ver01/select_page.dart';

class DepositPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      appBar: AppBar(
        toolbarHeight: 100, // Set this height
        elevation: 3,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black,
        title: const Text(
          'QRコード読み取り',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.person_pin_rounded,
                  size: 30,
                ),
                SizedBox(width: 10),
                Text('Koji Momota',
                    style: TextStyle(
                      fontSize: 24,
                    )),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: AlertDialog(
          title: Text('横のお金入れに○○円入れてください\nおつりは計算して回収してください'),
          actions: <Widget>[
            // ボタン領域
            ElevatedButton(
              child: Text("入金が完了した"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        /* child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            ElevatedButton.icon(
              icon: const Icon(
                Icons.payments_outlined,
                color: Colors.white,
                size: 40,
              ),
              label: const Text(
                'ホントはQR読み込み',
                style: TextStyle(fontSize: 40), // 文字を大きく
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.all(40),
              ),
              onPressed: () {
                // 押されたら次のシーン(カメラ)に遷移
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SelectPage()),
                );
              },
            ),
          ],
        ), */
      ),
    );
  }
}
