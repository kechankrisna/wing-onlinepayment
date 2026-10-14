<?php
// Regenerate spec/test-vectors/php_known_answers.json with:
//   php spec/test-vectors/php_known_answers.php > spec/test-vectors/php_known_answers.json
// Known answers computed the way Wing's Web SDK spec (v2.0.3) describes, with
// PHP's openssl_encrypt as in the spec's PHP appendix:
//   payload = AES-256-CBC(JSON, key = password, iv = first 16 characters of password)
//   hash    = UPPERCASE(SHA256(B64(AES-256-CBC(B64(username#rest_api_key#bill_till_number#amount#order_reference_no#rand_str#timestamp),
//                                              key = password, iv = rand_str))))
// openssl_encrypt pads a short key with NUL bytes and truncates a long one
// to 32 bytes; with options 0 its output is already base64.
$username = 'online.testing';
$rest_api_key = 'test-rest-api-key';
$password = 'test-password-0123456789abcdefgh'; // 32 characters
$bill_till_number = '2000';
$order_reference_no = 'c19245baae';
$rand_str = 'cbae7968ed6d0eff';
$timestamp = '1624684179';

$aes = fn(string $plain, string $key, string $iv) => openssl_encrypt($plain, 'AES-256-CBC', $key, 0, $iv);
$j = fn($v) => json_encode($v, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
$hash = function (string $amount, string $key) use ($aes, $username, $rest_api_key, $bill_till_number, $order_reference_no, $rand_str, $timestamp) {
    $plain = implode('#', [$username, $rest_api_key, $bill_till_number, $amount, $order_reference_no, $rand_str, $timestamp]);
    return strtoupper(hash('sha256', $aes(base64_encode($plain), $key, $rand_str)));
};

// payload: required fields only
$minimal = [
    'amount' => '15.00',
    'bill_till_number' => $bill_till_number,
    'order_reference_no' => $order_reference_no,
    'return_url' => 'https://shop.test/wing/return?order=c19245baae',
    'cancel_url' => 'https://shop.test/wing/cancel?order=c19245baae',
    'rand_str' => $rand_str,
    'timestamp' => $timestamp,
    'integration_type' => 'WEBAPP',
    'is_wingapp_installed' => '0',
];
$out['payload_minimal_json'] = $j($minimal);
$out['payload_minimal'] = $aes($j($minimal), $password, substr($password, 0, 16));

// payload: every field, in the order of the spec's sample
$full = [
    'amount' => '15.00',
    'bill_till_number' => $bill_till_number,
    'order_reference_no' => $order_reference_no,
    'return_url' => 'https://shop.test/wing/return?order=c19245baae',
    'cancel_url' => 'https://shop.test/wing/cancel?order=c19245baae',
    'rand_str' => $rand_str,
    'timestamp' => $timestamp,
    'wing_account' => '00001614',
    'integration_type' => 'MOBAPP',
    'is_wingapp_installed' => '1',
    'item_name' => 'កាហ្វេ / coffee',
    'merchant_name' => 'Testing Shop',
];
$out['payload_full_json'] = $j($full);
$out['payload_full'] = $aes($j($full), $password, substr($password, 0, 16));

// hash
$out['hash_plain'] = implode('#', [$username, $rest_api_key, $bill_till_number, '15.00', $order_reference_no, $rand_str, $timestamp]);
$out['hash'] = $hash('15.00', $password);
$out['hash_khr'] = $hash('12000.00', $password);

// passwords that are not 32 characters: NUL-padded or truncated key
$short = 'short-password-16+4'; // 19 characters
$out['short_password'] = $short;
$out['payload_minimal_short_password'] = $aes($j($minimal), $short, substr($short, 0, 16));
$out['hash_short_password'] = $hash('15.00', $short);
$long = $password . '-and-more'; // 41 characters
$out['long_password'] = $long;
$out['payload_minimal_long_password'] = $aes($j($minimal), $long, substr($long, 0, 16));

// callback: `contents` is the JSON encrypted with the password, iv = first 16 characters
$callback = [
    'amount' => '1.50',
    'total_amount' => '1.50',
    'currency' => 'USD',
    'order_reference_no' => '1234321',
    'remark' => '1234321',
    'customer_name' => ' Wing Testing WCX-USD',
    'fee' => '0',
    'fee_currency' => 'USD',
    'wing_account' => '00001614',
    'ps_trn_id' => ' ONL015627',
    'fc_trn_id' => ' 0002355252200023',
    'biller_name' => 'SounKolap',
    'transaction_date' => '28-08-23 09:34:38',
    'transaction_id' => '0002355252200023',
];
$out['callback_json'] = $j($callback);
$out['callback_contents'] = $aes($j($callback), $password, substr($password, 0, 16));

echo json_encode($out, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE), "\n";
