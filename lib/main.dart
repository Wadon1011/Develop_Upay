import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:upay_ver01/camera_page.dart';
import 'package:upay_ver01/theme.dart';
import 'package:flutter/services.dart';
import 'package:gsheets/gsheets.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    // 横向き
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(MyApp());
  });
}

extension ContextColorScheme on BuildContext {
  // 色の指定を楽にする
  // color: Theme.of(context).colorScheme.primary が
  // color: context.colors.primary でよい
  ColorScheme get colors => Theme.of(this).colorScheme;
}

Future<void> loadItemData(List<ItemData> items, List<UserData> users) async {
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
  final itemDataSheet = ss.worksheetByTitle('ItemData');

  // セルの値を読み取る
  final cellValue = await itemDataSheet?.values.value(column: 5, row: 2);
  print('セルの値: $cellValue');

  // セルに値を書き込む
  // await sheet.values.insertValue('Hello, Flutter!', column: 0, row: 1);

  // 列の値を読み取る
  final columnValues = await itemDataSheet?.values.column(1);
  print('列の値: $columnValues');

  // 商品データをセットする
  final products = await itemDataSheet?.values.map.allRows();

  // List<Product> productList= products.map((json) => Product.fromGsheets(json)).toList();
  if (products != null) {
    items.addAll(products.map((json) => ItemData.fromGsheets(json)).toList());
    items.removeWhere((element) => element.soldOut); // 売り切れは省く
  } else {
    print('Failed to fetch product data.');
  }
  // 次は全ユーザのデータをセットする
  // シート名を指定してワークシートを取得
  final userDataSheet = ss.worksheetByTitle('UserData');
  final allUsers = await userDataSheet?.values.map.allRows();
  if (allUsers != null) {
    users.addAll(allUsers.map((json) => UserData.fromGsheets(json)).toList());
  } else {
    print('Failed to fetch product data.');
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: ChangeNotifierProvider(
        create: (context) => MyAppState(),
        child: MaterialApp(
          title: 'UPay',
          theme: ThemeData(
              useMaterial3: true,
              colorScheme: MaterialTheme.lightScheme(), // 変更
              fontFamily: 'Outfit', //フォントを変えた
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.transparent,
                titleTextStyle: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: context.colors.primary,
                  fontFamily: 'Outfit',
                ),
              )),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: MaterialTheme.darkScheme(), // 追加
          ),
          themeMode: ThemeMode.system, // システム設定に応じてテーマを自動切替
          home: MyHomePage(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  var current = WordPair.random();
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<ItemData> items = []; // 初期化を忘れないようにします
  List<UserData> users = [];

  bool _buttonPressed = false;

  void _onTap() {}

  void _onTapDown(TapDownDetails value) {
    setState(() {
      _buttonPressed = true;
    });
  }

  void _onTapUp(TapUpDetails value) {
    _loadNext();
    setState(() {
      // _buttonPressed = false;
    });
  }

  void _onTapCancel() {
    _loadNext();
    setState(() {
      // _buttonPressed = false;
    });
  }

  bool _isDialogShowing = false;
  // 変更: loadDataAndProcessを呼び出してからシーンを変更
  void _loadNext() async {
    HapticFeedback.mediumImpact();

    // ダイアログが既に表示されている場合は表示しない
    if (!_isDialogShowing) {
      _isDialogShowing = true;
      // ダイアログを呼び出す
      await showLoadingDialog(context: context);
    }

    try {
      // データをロードし、処理が完了するまで待つ
      await loadItemData(items, users);
    } finally {
      // ダイアログを閉じる
      if (_isDialogShowing) {
        Navigator.of(context, rootNavigator: true).pop();
        _isDialogShowing = false;
      }
    }

    for (int i = 0; i < items.length; i++) {
      print(items.toString());
    }

    // Navigatorで新しいシーンをプッシュ
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return CameraPage(
            items: items,
            users: users,
          );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: context.colors.surfaceContainerLow,
        appBar: AppBar(
          toolbarHeight: 100,
          title: Text(
            'Welcome to UPay',
            style: TextStyle(color: context.colors.primary),
          ),
          centerTitle: true,
          actions: <Widget>[],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                // 押されたときにボタンが下に動くための余白
                height: !_buttonPressed ? 0 : 6,
              ),
              GestureDetector(
                onTap: _onTap,
                onTapCancel: _onTapCancel,
                onTapUp: _onTapUp,
                onTapDown: _onTapDown,
                child: Container(
                  decoration: BoxDecoration(
                    color: !_buttonPressed
                        ? context.colors.primary
                        : context.colors.outlineVariant,
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                        color: !_buttonPressed
                            ? Colors.black.withOpacity(0.25)
                            : Colors.black.withOpacity(0),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 30, horizontal: 70),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: Colors.white,
                        size: 240,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        // 'スタート',
                        'Start',
                        style: TextStyle(
                          fontSize: 40,
                          color: context.colors.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: !_buttonPressed ? 80 : 74,
              ),
            ],
          ),
        ));
  }
}

class ItemData {
  ItemData({
    required this.id,
    required this.name,
    required this.price,
    required this.imagePath,
    required this.category,
    required this.soldOut,
    required this.salesFigure,
    required this.stock,
  });

  final int id;
  final String name;
  final int price;
  final String imagePath;
  final ItemCategory category;

  bool soldOut = false;
  int salesFigure;
  int stock;

  int tapCount = 0;

  ItemData copyWith(
          {int? id,
          String? name,
          int? price,
          String? imagePath,
          int? tapCount}) =>
      ItemData(
          id: id ?? this.id,
          name: name ?? this.name,
          price: price ?? this.price,
          category: category ?? this.category,
          imagePath: imagePath ?? this.imagePath,
          soldOut: soldOut ?? this.soldOut,
          salesFigure: salesFigure ?? this.salesFigure,
          stock: stock ?? this.stock);

  @override
  String toString() =>
      'Product{id: $id, name: $name, price: $price, category: ${category.displayName}}';

  factory ItemData.fromGsheets(Map<String, dynamic> json) {
    return ItemData(
      id: int.tryParse(json['ItemID'] ?? '') ?? 0,
      name: json['Name'],
      price: int.tryParse(json['Price'] ?? '') ?? 0,
      category: stringToCategory(json['Category']),
      imagePath: json['ImagePath'],
      soldOut: stringToBool(json['SoldOut']),
      salesFigure: int.tryParse(json['SalesFigure'] ?? '') ?? 0,
      stock: int.tryParse(json['Stock'] ?? '') ??
          1000, // 何も設定されていない場合はとりあえず1000にしておく
    );
  }

  Map<String, dynamic> toGsheets() {
    return {
      'ItemID': id,
      'Name': name,
      'Price': price,
      'Category': category.displayName,
      'ImagePath': imagePath,
      'SoldOut': boolToString(soldOut),
      'SalesFigure': salesFigure,
      'Stock': stock,
    };
  }
}

enum ItemCategory {
  drink('drink'),
  snack('snack'),
  food('food');

  const ItemCategory(this.displayName);
  final String displayName;
}

ItemCategory stringToCategory(String str) {
  if (str == 'drink') {
    return ItemCategory.drink;
  } else if (str == 'snack') {
    return ItemCategory.snack;
  } else {
    return ItemCategory.food;
  }
}

bool stringToBool(String str) {
  if (str == 'false') {
    return false;
  } else {
    return true;
  }
}

String boolToString(bool flag) {
  if (!flag) {
    return 'false';
  } else {
    return 'true';
  }
}

class UserData {
  UserData({
    required this.id,
    required this.userName,
    required this.balance,
    required this.purchaseNum,
    required this.totalAmount,
    required this.giftAmount,
  });

  final int id;
  final String userName;
  int balance;
  int purchaseNum;
  int totalAmount;
  int giftAmount;

  UserData copyWith({int? id, String? userName, int? balance}) => UserData(
        id: id ?? this.id,
        userName: userName ?? this.userName,
        balance: balance ?? this.balance,
        purchaseNum: purchaseNum ?? this.purchaseNum,
        totalAmount: totalAmount ?? this.totalAmount,
        giftAmount: giftAmount ?? this.giftAmount,
      );

  factory UserData.fromGsheets(Map<String, dynamic> json) {
    return UserData(
      id: int.tryParse(json['UserID'] ?? '') ?? 0,
      userName: json['UserName'],
      balance: int.tryParse(json['Balance'] ?? '') ?? 0,
      purchaseNum: int.tryParse(json['PurchaseNum'] ?? '') ?? 0,
      totalAmount: int.tryParse(json['TotalAmount'] ?? '') ?? 0,
      giftAmount: int.tryParse(json['GiftAmount'] ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toGsheets() {
    return {
      'UserID': id,
      'UserName': userName,
      'Balance': balance,
      'PurchaseNum': purchaseNum,
      'TotalAmount': totalAmount,
      'GiftAmount': giftAmount,
    };
  }
}

class TopupHistory {
  TopupHistory(
      {required this.time,
      required this.userID,
      required this.amount,
      required this.afterTopup});
  final String time;
  final int userID;
  final int amount;
  final int afterTopup;

  factory TopupHistory.fromGsheets(Map<String, dynamic> json) {
    return TopupHistory(
      time: json['DateTime'],
      userID: int.tryParse(json['UserID'] ?? '') ?? 0,
      amount: int.tryParse(json['Amount'] ?? '') ?? 0,
      afterTopup: int.tryParse(json['AfterTopup'] ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toGsheets() {
    return {
      'DateTime': time,
      'UserID': userID,
      'Amount': amount,
      'AfterTopup': afterTopup,
    };
  }
}

class PurchaseHistory {
  PurchaseHistory(
      {required this.time,
      required this.userID,
      required this.itemIDs,
      required this.itemNames,
      required this.numbers,
      required this.afterPurchase,
      required this.amountSpent});
  final String time;
  final int userID;
  final List<int> itemIDs;
  final List<String> itemNames;
  final List<int> numbers;
  final int afterPurchase;
  final int amountSpent;

  factory PurchaseHistory.fromGsheets(Map<String, dynamic> json) {
    return PurchaseHistory(
      time: json['DateTime'],
      userID: int.tryParse(json['UserID'] ?? '') ?? 0,
      itemIDs: stringToList(json['ItemID']),
      itemNames: json['ItemName'],
      numbers: stringToList(json['Number']),
      afterPurchase: int.tryParse(json['AfterPurchase'] ?? '') ?? 0,
      amountSpent: int.tryParse(json['AmountSpent'] ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toGsheets() {
    return {
      'DateTime': time,
      'UserID': userID,
      'ItemID': listToString(itemIDs),
      'ItemName': stringListToString(itemNames),
      'Number': listToString(numbers),
      'AfterPurchase': afterPurchase,
      'AmountSpent': amountSpent,
    };
  }
}

String listToString(List<int> list) {
  return list.map<String>((int value) => value.toString()).join(',');
}

String stringListToString(List<String> list) {
  return list.map<String>((String value) => value).join(',');
}

List<int> stringToList(String listAsString) {
  return listAsString
      .split(',')
      .map<int>((String item) => int.parse(item))
      .toList();
}

Future<void> showLoadingDialog({
  required BuildContext context,
  Color barrierColor = const Color(0x80000000), // デフォルトの透明度50%の黒色
}) async {
  showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 250),
      barrierColor: barrierColor, // 引数で渡された色を使用
      pageBuilder: (BuildContext context, Animation animation,
          Animation secondaryAnimation) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
              ],
            ),
          ),
        );
      });
}
