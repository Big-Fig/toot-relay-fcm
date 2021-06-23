# TootRelayFCM

* Relay Web Push messages from [Pleroma and Mastodon](https://docs.joinmastodon.org/methods/notifications/push/) to Firebase Cloud Messaging
* Developed to use with [Fedi for Pleroma and Mastodon](https://github.com/Big-Fig/Fediverse.app). But it is possible to use with other apps
* Written with using Ruby On Rails. Original idea and decryption logic taken from [DagAgren/toot-relay](https://github.com/DagAgren/toot-relay) written in Go and [tateisu/PushToFCM](https://github.com/tateisu/PushToFCM) written with Node.js

* [How it works](#how-it-works)
* [Example of subscription](#example-of-subscription)
* [Modes](#modes)
* [Without encryption](#without-encryption)
  * [Which data TootRelayFCM know without decryption?](#which-data-tootrelayfcm-know-without-decryption)
  * [Pros](#pros)
  * [Cons](#cons)
* [With encryption](#with-encryption)
  * [Which data TootRelayFCM server have access after decryption?](#which-data-tootrelayfcm-server-have-access-after-decryption)
  * [Pros](#pros-1)
  * [Cons](#cons-1)
* [How to obtain FCM server key?](#how-to-obtain-fcm-server-key)
* [How to generate public/private key pair and auth secret?](#how-to-generate-publicprivate-key-pair-and-auth-secret)
* [Config](#config)
* [How to build &amp; run from source (macOS/Linux)](#how-to-build--run-from-source-macoslinux)
* [License](#license)


## How it works

* Server listens to `/push/` endpoint. For example

```
https://pushrelay.example.com/push/
```
* App subscribes to Pleroma/Mastodon instance [push notifications](https://docs.joinmastodon.org/methods/notifications/push/). 

* Event occurs Pleroma/Mastodon instance
* Pleroma/Mastodon instance send message to TootRelayFCM server subscription endpoint `https://pushrelay.example.com/push/`. Message body example can be found below
* TootRelayFCM decrypts(or not) payload and send notification/data message to app via FCM. Example of decrypted message can be found below
* TootRelayFCM unsubscribes from Pleroma/Mastodon instance If FCM push fails (only in with-decryption mode)

### Example of subscription

Example POST data to `/api/v1/push/subscription` Pleroma/Mastodon endpoint

```
{
   "endpoint":"https://pushrelayexample.com/push/e8-s26bOSM2pJxKqifIqfY:APA91bE0GZxW-nlMsptwnfbAy1Y33KILRN8ZsJZrB1P0pgVfxzOFcNAhk3MoGZOZl-BMuOikTaCL0C2fPwl2-aGaTiKza_fPlUPT9EuKugIyjy2r1HoWitDRECrkiqcuTeNQg9Am-CYz?account=jffdev&server=fedi.app",
   "keys":{
      "p256dh":"BEpPCn0cfs3P0E0fY-gyOuahx5dW5N8quUowlrPyfXlMa6tABLqqcSpOpMnC1-o_UB_s4R8NQsqMLbASjnqS",
      "auth":"T5bhIIyre5TDC1LyX4m"
   }
}
```

As you can see in additional to TootRelayFCM endpoint URL you must add additional info:

* `e8-s26bOSM2pJxKqifIqfY:APA91bE0GZxW-nlMsptwnfbAy1Y33KILRN8ZsJZrB1P0pgVfxzOFcNAhk3MoGZOZl-BMuOikTaCL0C2fPwl2-aGaTiKza_fPlUPT9EuKugIyjy2r1HoWitDRECrkiqcuTeNQg9Am-CYz` is **FCM device token**
* `?account=jffdev&server=fedi.app` which will be added to FCM notification. `account` it is username and `server` is hostname.

## Modes

TootRelayFCM can work in two modes:

* **Without server-side decryption(preferable)** - TootRelayFCM simple proxy encrypted messages
* **With server-side decryption** - Decrypt messages and have access to notification content and user `access_token`

### Without encryption

1. App subscribes to `/api/v1/push/subscription` with `subscription[endpoint]`set to TootRelayFCM server URL
2. Instances send Web push notifications to relay server
3. TootRelayFCM **don't decrypt** message
4. TootRelayFCM send notifications to App via FCM

##### Which data TootRelayFCM know without decryption?


```
{
	:data=>{
		:crypto_key=>"dh=BF7CAl3J1o7jNf8i0dHxTwvY5QNx0v5LUN5CgjO6BUIUxa8q5RP9ML8HDWON9JplrMhwxWdM5EQZ0kfw3IXy_7Q;p256ecdsa=BMwPQzjwXKDqt5xZz6rGAa9iSWiEsO73UmNRoZwkaGOOQeW7_EEFcTVpzP-AqoZKcjiV_h88zSBAtaAYpBBwp5Y", 
		:salt=>"salt=PC48KPkE4izfdQilBfOF_w", 
		:payload=>"9crGlId2xj5RVjxig1MS-g3B3CX2jVOnTY8gxsFo_yUVWLN_y_oAU0wrh-YG6PWC_W0t8Ub9tQEoySHJSeOJ7l3euiTKUeccxowV6lcF-V9Vhi9yx4bX52eKxKjII9n9WNCByU1J6oHcGo3CwHMyr0Tyn3HVwqzm9hJ2-TjP3Y2Iir-aor96mskTehbes7SY-QCYVT1FoI6xvgGFE0NmduKwYCe6BwqHqsuNSwIXiaWANwa07aLAtv3zlqFkBkSD-NwAVxJ2MTmsRGnEPoNb05k4Wbl6Kkct6ZqWoFd6C_FVDwtVG6Odo_RPWXsIEw3qh4koUMZwGve_MK3mGYejNbxWqjFxXcooZd6KedMrZ8200fcDWhToPyB52rgRARLp0JamBi4Q99nrIKPIHI0c4numKk7zJE9-6mwxN1T84NliWTMVKRUORwtnpjnodIumhg==", 
		:account=>"jffdev", 
		:server=>"fedi.app"
	}
}
```

Since TootRelayFCM in this mode don't know private decryption keys, it is can't access any privacy data.

##### Pros
* **Don't have access to user private data**
* It is possible to customize notification on client side(for example rich layouts or localization)

##### Cons
* Delivery may be delayed. Because server send FCM push message without `notification` (FCM calls it data message). Read FCM documentation for details. 
* TootRelayFCM uses `:mutable_content=>true,` `:content_available=>true,` `:priority=>"high",` to increase delivery priority


### With encryption

**Preferable**

1. App subscribe to `/api/v1/push/subscription` with `subscription[endpoint]` set to TootRelayFCM URL
2. Instances send Web push notifications to TootRelayFCM
3. TootRelayFCM **decrypt** notification
4. TootRelayFCM relay notification to App via FCM

##### Which data TootRelayFCM server have access after decryption?

```
{
   "access_token""=>""QiQGKu6wAsF6M3bWJ3FMTvfK_rW...",
   "body""=>"@jffdev2: @jffdev hello world",
   "icon""=>""https://fedi.app/images/avi.png",
   "notification_id"=>1114,
   "notification_type""=>""mention",
   "pleroma""=>"{
      "activity_id""=>""A82wvAgZu7n7B...",
      "direct_conversation_id"=>42..
   },
   "preferred_locale""=>""en",
   "title""=>""New Direct Message"
}
```

* As you can see server sent `body` which may have private data(like private Status body) and `access_token`
* `access_token` is sensitive data. It is possible to login to your account if someone know `access_token`

##### Pros
* Faster push delivery. Because FCM push message are FCM message type with `notification.title` and `notification.body`. Which have higher priority than message without `notification.title` & `notification.body` fields. Actually it is more affects iOS, than Android. Read FCM documentation for details. Anyway even data-only messages usually appear within 1 min

##### Cons
* **Server have access to users private data. It is main reason why we moved to `Without server-side decryption`** way
* Impossible to customize notification on client-side


## How to obtain FCM server key?

You can create FCM project by following official [Firebase Messaging documentation for Flutter](https://firebase.flutter.dev/docs/messaging/overview/). It is for Flutter but contains base information how to create Firebase project and use it with Android and/or iOS apps(non-Flutter apps too).

Keep in mind that you will generate keys to use in your Android/iOS/Flutter App and it is possible to use those keys only with App ID which you entered during Firebase registration process. 

So several mobile apps(and forks with different app ids) can't use one TootRelayFCM server instance and vice versa. One app id = one TootRelayFCM instance

However you still can connect Android/iOS apps to one TootRelayFCM because Firebase Messaging supports different config for different platforms

## How to generate public/private key pair and auth secret?

To use TootRelayFCM you will need:

* **ECDH prime256v1 public/private key pair** - url-safe Base64 encoded
* **Auth secret** - url-safe Base64 encoded
 string of 16 bytes of random data.

You can find `gen_keys` folder taken from [tateisu/PushToFCM](https://github.com/tateisu/PushToFCM).

It is Node.js(yeah because node.js script already exist and works and repo still uses RoR) script which generated keys pair and auth secret.

* Install Node.js and npm from [official website](https://nodejs.org/)
* Run script

```
cd gen_keys
npm install
npm run gen_keys
```

* Receive generated keys & auth secret

```
public key=BNnfz5TiZLJ0ZQWswOC6UbE4erPGW6VGpRuYr35AHOuERadkhQzIk7HMEiNsW4vq3c50EjcbU2C6mfBRK7Jfd1w
private key=VctYkN-tBhx7ajBvA0A788F_7wMVl3_x7PDM9cx3mo4
auth=Juyue7yTkUZwT_B9wZ-g4Q
```

You should use `auth` and `public key` on mobile client side. They are required when you subscribing to Pleroma/Mastodon push.

You should use all items: `auth`, `public key` and `private key` when you want to decrypt message. It may be TootRelayFCM or mobile client app. In some cases you may not need `private key` at all, for example you can use push as trigger to retrieve latest notification via REST API and don't decrypt push payload.

## Config

`.env` in repository root(excluded form source control)

```
FCM_SERVER_KEY=AAAAConY4EE:APA91bGCX-pOmnHQqrOeYCXkPOkxCIxuEwVg-D47xTxtZ0VtEDAIN2KkTMTlK2gjttzIxUpZGbxsJyxhWM...
MODE=without_decryption
#MODE=with_decryption
#WITH_DECRYPTION_SERVER_AUTH_SECRET=T5bhIIyre5TDC1LyX4...
#WITH_DECRYPTION_SERVER_PUBLIC_KEY=BEpPCn0cfs3P0E0fY-gyOuahx5dW5N8quUowlrPyfXlMa6tABLqqcSpOpMnC1-o_UB_s4R8NQsqMLbASjnqS...
#WITH_DECRYPTION_SERVER_PRIVATE_KEY=ygY0_h2bMNRT5pB6xyGP84J_AW7LW76mu6svJfo...
```

## How to build & run from source (macOS/Linux)

* Install Ruby & RubyOnRails by following [official guide](https://guides.rubyonrails.org/v5.0/getting_started.html)
* Clone repository
* Go to repository root directory

```
cd toot-relay-fcm
```

* Install required dependencies

```
bundle install
```


* Copy example config file to actual config file(*.env is ignored in .gitignore*)

```
cp example.env .env
```

* Modify `.env` with your favourite text editor. Above you can find details how to obtain all required variables

* Make `start.sh` executable

```
chmod +x start.sh
```

* Run

```
./start.sh
```

You can use screen if you want to run in background even after terminal/ssh will be closed 
 
```
screen
./start.sh
```

Actually `start.sh` is export vars from .env and run rails server

```
set -o allexport
source .env
set +o allexport
rails server
# you should specify new --pid if you wan to run several instances of this app and port via -p
# rails server -p 3300 --pid tmp/pids/server2.pid
```

## License

* [AGPL-3](./LICENSE)