// original version taken from https://github.com/tateisu/PushToFCM

const crypto = require('crypto');
const util = require('util');
const base64us = require('urlsafe-base64')

const keyCurve = crypto.createECDH('prime256v1');
keyCurve.generateKeys();
const publicKey = keyCurve.getPublicKey();
const privateKey = keyCurve.getPrivateKey();
const auth = crypto.randomBytes(16)

console.log("public key="+ base64us.encode(publicKey));
console.log("private key="+ base64us.encode(privateKey));
console.log("auth="+ base64us.encode(auth));