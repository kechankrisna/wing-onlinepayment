# dart_wing example

A Flutter demo of [`dart_wing`](https://pub.dev/packages/dart_wing) against
Wing's online payment **UAT** environment: authorize a payment, then inquire
its status.

> Demo only. This app embeds the Wing REST API key and password to call Wing
> directly. In production, call Wing from your server and never ship these
> secrets inside an app.

```sh
flutter run --dart-define-from-file=../.env
```

The `.env` is the package's UAT file (copy `../.env.example`).

```sh
flutter test
```
