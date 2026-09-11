const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const crypto = require('node:crypto');

function setup() {
  const key = 'k'.repeat(32), token = 'a'.repeat(32), session = 'b'.repeat(32);
  const cache = new Map([['qrtoken_' + token, JSON.stringify({userId: '26012'})],
    ['register_' + session, JSON.stringify({userId: '26012'})]]);
  const properties = {REGISTER_API_KEY: key};
  let sheets = [
    {id: 1, name: 'UserData', rows: [['UserID','UserName','Balance','PurchaseNum','TotalAmount','GiftAmount','Email'], ['26012','Test',1000,0,0,200,'test@example.com']]},
    {id: 2, name: 'ItemData', rows: [['ItemID','Name','Price','Stock','SalesFigure','SoldOut'], [3,'Chips',150,5,0,false], [4,'Tea',100,1,2,false]]}
  ];
  let batches = 0, locked = false, rejectBatch = false, lostResponse = false;
  const ss = {getSheetByName(name) {
    const sheet = sheets.find(s => s.name === name);
    return sheet ? {
      getSheetId: () => sheet.id,
      getDataRange: () => ({getValues: () => structuredClone(sheet.rows)}),
      appendRow: row => sheet.rows.push([...row]),
      getRange: (row, column) => ({setValue: value => {sheet.rows[row - 1][column - 1] = value;}})
    } : null;
  }, insertSheet(name) {
    assert.ok(!sheets.some(s => s.name === name));
    sheets.push({id: Math.max(...sheets.map(s => s.id)) + 1, name, rows: []});
    return this.getSheetByName(name);
  }};
  const context = vm.createContext({console, Date, Math, JSON, Number,
    PropertiesService: {getScriptProperties: () => ({getProperty: k => properties[k]})},
    CacheService: {getScriptCache: () => ({get: k => cache.get(k), put: (k,v) => cache.set(k,v), remove: k => cache.delete(k)})},
    LockService: {getScriptLock: () => ({tryLock: () => {if (locked) return false; locked = true; return true;},
      waitLock: () => {assert.equal(locked, false); locked = true;}, releaseLock: () => {locked = false;}})},
    SpreadsheetApp: {openById: () => ss},
    Utilities: {getUuid: () => crypto.randomUUID(), formatDate: () => '2609', DigestAlgorithm: {SHA_256: 'sha256'},
      computeDigest: (algorithm, text) => crypto.createHash(algorithm).update(text).digest(), base64Encode: bytes => Buffer.from(bytes).toString('base64')},
    ContentService: {MimeType: {JSON: 'json'}, createTextOutput: text => ({setMimeType: () => JSON.parse(text)})},
    Sheets: {Spreadsheets: {batchUpdate(body) {
      assert.equal(locked, true);
      if (rejectBatch) throw new Error('Injected atomic batch failure');
      const pending = structuredClone(sheets);
      for (const request of body.requests) {
        if (request.addSheet) {
          const p = request.addSheet.properties;
          assert.ok(!pending.some(s => s.id === p.sheetId || s.name === p.title));
          pending.push({id: p.sheetId, name: p.title, rows: []});
        }
        if (request.appendCells) {
          const p = request.appendCells;
          pending.find(s => s.id === p.sheetId).rows.push(...p.rows.map(r => r.values.map(c => Object.values(c.userEnteredValue)[0])));
        }
        if (request.updateCells) {
          const p = request.updateCells, start = p.start;
          pending.find(s => s.id === start.sheetId).rows[start.rowIndex][start.columnIndex] = Object.values(p.rows[0].values[0].userEnteredValue)[0];
        }
      }
      sheets = pending;
      batches++;
      if (lostResponse) {lostResponse = false; throw new Error('Response lost after commit');}
    }}}
  });
  vm.runInContext(fs.readFileSync(__dirname + '/Code.gs', 'utf8'), context);
  const request = (overrides = {}) => ({action: 'purchase', apiKey: key, sessionToken: session, requestId: 'c'.repeat(32), items: [{itemId:3,quantity:2}], ...overrides});
  return {context, request, cache, properties, key, token, session,
    post: body => context.doPost({postData: {contents: JSON.stringify(body)}}),
    rows: name => sheets.find(s => s.name === name)?.rows,
    count: () => batches, reject: () => {rejectBatch = true;}, loseResponse: () => {lostResponse = true;}};
}

test('purchase uses server price, updates balance/stock/counters and monthly history together', () => {
  const f = setup();
  const result = f.post(f.request({amount:1, userId:'another-user'}));
  assert.equal(result.success, true);
  assert.equal(result.amount, 300);
  assert.equal(result.user.Balance, 700);
  assert.equal(result.user.PurchaseNum, 2);
  assert.equal(result.user.TotalAmount, 300);
  assert.equal(f.rows('ItemData')[1][3], 3);
  assert.equal(f.rows('ItemData')[1][4], 2);
  assert.equal(f.rows('PurchaseHistory2609')[1][6], 300);
  assert.equal(f.rows('UserData')[1][6], 'test@example.com');
  assert.equal(f.count(), 1);
});

for (const [label, change] of [
  ['insufficient balance', f => {f.rows('UserData')[1][2] = 1;}],
  ['insufficient stock', f => {f.rows('ItemData')[1][3] = 1;}],
  ['sold out', f => {f.rows('ItemData')[1][5] = true;}],
  ['invalid price', f => {f.rows('ItemData')[1][2] = 'bad';}],
  ['missing column', f => {f.rows('UserData')[0][2] = 'unknown';}],
  ['duplicate user', f => {f.rows('UserData').push([...f.rows('UserData')[1]]);}]
]) test(label + ' causes no writes', () => {
  const f = setup(); change(f);
  const before = JSON.stringify([f.rows('UserData'), f.rows('ItemData')]);
  assert.equal(f.post(f.request()).success, false);
  assert.equal(f.count(), 0);
  assert.equal(JSON.stringify([f.rows('UserData'), f.rows('ItemData')]), before);
});

test('zero, negative, fractional and string quantities, unknown products and empty cart are rejected', () => {
  for (const items of [[], [{itemId:3,quantity:0}], [{itemId:3,quantity:-1}], [{itemId:3,quantity:1.5}], [{itemId:3,quantity:'1'}], [{itemId:999,quantity:1}]]) {
    const f = setup();
    assert.equal(f.post(f.request({items})).success, false);
    assert.equal(f.count(), 0);
  }
});

test('duplicate product lines are aggregated before stock validation', () => {
  const f = setup();
  assert.equal(f.post(f.request({items:[{itemId:3,quantity:3},{itemId:3,quantity:3}]})).success, false);
  assert.equal(f.count(), 0);
});

test('last item marks SoldOut', () => {
  const f = setup();
  assert.equal(f.post(f.request({items:[{itemId:4,quantity:1}]})).success, true);
  assert.equal(f.rows('ItemData')[2][3], 0);
  assert.equal(f.rows('ItemData')[2][5], true);
});

test('identical retry returns saved result; changed payload and second purchase are rejected', () => {
  const f = setup();
  const first = f.post(f.request());
  assert.deepEqual(f.post(f.request()), first);
  assert.equal(f.post(f.request({items:[{itemId:3,quantity:1}]})).success, false);
  assert.equal(f.post(f.request({requestId:'d'.repeat(32)})).success, false);
  assert.equal(f.count(), 1);
});

test('retry after committed but lost response does not charge twice', () => {
  const f = setup(); f.loseResponse();
  assert.equal(f.post(f.request()).success, false);
  assert.equal(f.post(f.request()).user.Balance, 700);
  assert.equal(f.count(), 1);
});

test('batch failure leaves balance, stock and history unchanged', () => {
  const f = setup(); f.reject();
  assert.equal(f.post(f.request()).success, false);
  assert.equal(f.rows('UserData')[1][2], 1000);
  assert.equal(f.rows('ItemData')[1][3], 5);
  assert.equal(f.rows('PurchaseHistory2609'), undefined);
});

test('API key and QR session required; raw user ID cannot authorize a payment', () => {
  const f = setup();
  for (const overrides of [{apiKey:''}, {sessionToken:''}, {sessionToken:'f'.repeat(32)}, {sessionToken:undefined,userId:26012}]) {
    assert.equal(f.post(f.request(overrides)).success, false);
  }
  f.properties.REGISTER_API_KEY = 'CHANGE_ME_REGISTER_API_KEY';
  assert.equal(f.post(f.request({apiKey:f.properties.REGISTER_API_KEY})).success, false);
  assert.equal(f.count(), 0);
});

test('QR verification returns only selected user and consumes token once', () => {
  const f = setup();
  const request = {action:'verifyQrToken',apiKey:f.key,token:f.token};
  const result = f.post(request);
  assert.equal(result.success, true);
  assert.equal(result.user.UserID, '26012');
  assert.equal(result.user.Email, undefined);
  assert.match(result.sessionToken, /^[a-f0-9]{32}$/);
  assert.equal(f.post(request).success, false);
});

test('gift amount is taken from server and is credited only once', () => {
  const f = setup();
  const request = f.request({action:'claimGift',items:undefined,amount:999999});
  const result = f.post(request);
  assert.equal(result.user.Balance, 1200);
  assert.equal(result.user.GiftAmount, 0);
  assert.deepEqual(f.post(request), result);
  assert.equal(f.post({...request,requestId:'d'.repeat(32)}).success, false);
  assert.equal(f.rows('TopupHistory')[1][2], 200);
});

test('cash topup requires explicit enablement and validates amount; retry is idempotent', () => {
  const f = setup(), request = f.request({action:'topup',items:undefined,amount:500});
  assert.equal(f.post(request).success, false);
  f.properties.ALLOW_REGISTER_TOPUP = 'true';
  for (const amount of [0,-1,1.5,'100',100001]) assert.equal(f.post({...request,amount}).success, false);
  const result = f.post(request);
  assert.equal(result.user.Balance, 1500);
  assert.deepEqual(f.post(request), result);
  assert.equal(f.count(), 1);
});

test('catalog validates required headers and returns numeric price/stock without authentication', () => {
  const f = setup();
  assert.equal(f.context.doGet({}).success, false);
  f.rows('ItemData')[0].push('ImagePath', 'Category');
  f.rows('ItemData')[1].push('images/chips.png', 'snack');
  f.rows('ItemData')[2][5] = true;
  const result = f.context.doGet({});
  assert.equal(result.success, true);
  assert.equal(result.items.length, 1);
  assert.equal(result.items[0].price, 150);
  assert.equal(result.items[0].stock, 5);
  assert.equal(f.count(), 0);
});

test('expired QR and expired session are rejected without updates', () => {
  const f = setup();
  f.cache.delete('qrtoken_' + f.token);
  f.cache.delete('register_' + f.session);
  assert.equal(f.post({action:'verifyQrToken',apiKey:f.key,token:f.token}).success, false);
  assert.equal(f.post(f.request()).success, false);
  assert.equal(f.count(), 0);
});

test('restock route remains public and counts toggle without going below zero', () => {
  const f = setup();
  assert.equal(f.post({action:'toggleRestockReaction',itemId:3,add:true}).count, 1);
  assert.equal(f.post({action:'toggleRestockReaction',itemId:3,add:false}).count, 0);
  assert.equal(f.post({action:'toggleRestockReaction',itemId:3,add:false}).count, 0);
  assert.equal(f.rows('ItemReactions')[1][0], 3);
  // The public route does not bypass register authentication.
  assert.equal(f.post(f.request({apiKey:''})).success, false);
  assert.equal(f.post(f.request()).user.Balance, 700);
});

test('authenticated reservation routes retain duplicate checks, ownership and cancellation', () => {
  const f = setup();
  f.context.verifyIdToken_ = token => ({aud:f.context.CLIENT_ID, email_verified:true, email:token});
  const reserve = {action:'reserveItem',itemId:3,idToken:'test@example.com'};
  assert.equal(f.post({...reserve,idToken:undefined}).success, false);
  const result = f.post(reserve);
  assert.equal(result.success, true);
  assert.equal(f.post(reserve).success, false);
  const list = f.post({action:'myReservations',idToken:reserve.idToken});
  assert.equal(list.reservations.length, 1);
  assert.equal(list.reservations[0].itemName, 'Chips');
  assert.equal(f.post({action:'cancelReservation',idToken:'other@example.com',reservationId:result.reservationId}).success, false);
  assert.equal(f.post({action:'cancelReservation',idToken:reserve.idToken,reservationId:result.reservationId}).success, true);
  assert.equal(f.post({action:'myReservations',idToken:reserve.idToken}).reservations.length, 0);
});

test('catalog combines reserved stock, reaction count and tolerant price display', () => {
  const f = setup();
  f.rows('ItemData')[0].push('ImagePath', 'Category');
  f.rows('ItemData')[1].push('images/chips.png', 'snack');
  f.rows('ItemData')[2].push('images/tea.png', 'drink');
  assert.equal(f.context.reserveItem_('test@example.com',{itemId:3}).success, true);
  assert.equal(f.post({action:'toggleRestockReaction',itemId:3,add:true}).success, true);
  const item = f.context.doGet({}).items.find(i => i.id === 3);
  assert.equal(item.stock, 4);
  assert.equal(item.reactionCount, 1);
  assert.equal(item.price, 150);
  assert.equal(f.rows('ItemData')[1][3], 5);
  f.rows('Reservations')[1][4] = new Date(Date.now() - 1000);
  assert.equal(f.context.doGet({}).items.find(i => i.id === 3).stock, 5);
  assert.equal(f.rows('Reservations')[1][5], 'expired');
  f.rows('ItemData')[1][2] = 'invalid';
  const fallback = f.context.doGet({});
  assert.equal(fallback.success, true);
  assert.equal(fallback.items.find(i => i.id === 3).price, 0);
  assert.equal(f.post(f.request()).success, false);
  assert.equal(f.count(), 0);
});

test('blank and nonnumeric catalog values do not hide other products; purchase stays strict', () => {
  for (const field of ['Price', 'Stock']) {
    for (const value of ['', '   ', 'invalid', null]) {
      const f = setup();
      f.rows('ItemData')[0].push('ImagePath', 'Category');
      f.rows('ItemData')[1].push('images/chips.png', 'snack');
      f.rows('ItemData')[2].push('images/tea.png', 'drink');
      f.rows('ItemData')[1][f.rows('ItemData')[0].indexOf(field)] = value;
      const result = f.context.doGet({});
      assert.equal(result.success, true);
      assert.equal(result.items.length, 2);
      assert.equal(result.items.find(i => i.id === 3)[field.toLowerCase()], 0);
      assert.equal(result.items.find(i => i.id === 4).price, 100);
      assert.equal(result.items.find(i => i.id === 4).stock, 1);
      assert.equal(f.post(f.request()).success, false);
      assert.equal(f.count(), 0);
      assert.equal(f.rows('UserData')[1][2], 1000);
    }
  }
});

test('reservation capacity is enforced and expiry frees a reservation slot', () => {
  const f = setup();
  assert.equal(f.context.reserveItem_('one@example.com',{itemId:4}).success, true);
  assert.equal(f.context.reserveItem_('two@example.com',{itemId:4}).success, false);
  f.rows('Reservations')[1][4] = new Date(Date.now() - 1000);
  assert.equal(f.context.reserveItem_('two@example.com',{itemId:4}).success, true);
  assert.equal(f.rows('Reservations')[1][5], 'expired');
});
