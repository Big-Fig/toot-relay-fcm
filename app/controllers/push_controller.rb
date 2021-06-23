
require "openssl"
require "base64"
require "stringio"
require "json"
require 'fcm'
require 'net/smtp'
require 'rest-client'


class PushController < ApplicationController

	def push


	    crypto_key = request.headers['Crypto-Key']
	    salt = request.headers['Encryption']
 
	    payload = Base64.urlsafe_encode64(request.raw_post)
	    deviceID = params[:id]
	    account = params[:account]
	    server = params[:server]
	    deviceType = params[:device]
	    
	    Rails.logger.info("DBG:: account: #{account} server: #{server} deviceID: #{deviceID} ")

	    render_object({status: 'fail', message: 'invalid Crypto-Key'}, 500)	and return if crypto_key.blank?

		sender_public_key = crypto_key.split(';')[0]
	    render_object({status: 'fail', message: 'invalid Crypto-Key'}, 500)	and return if sender_public_key.blank?

	    if salt.blank? || !salt.start_with?('salt=')
			render_object({status: 'fail', message: 'invalid salt'}, 500) and return
		end
		salt.gsub!(/^salt=/,'')

	  	sender_public_key.gsub!(/^dh=/,'')

	    registration_ids = [deviceID]

	    fcmKey = ENV.fetch("FCM_SERVER_KEY") {"Specify FCM_SERVER_KEY in .env var"}


	    fcm = FCM.new(fcmKey)

		mode = ENV.fetch("MODE") {"without_decryption"}

		if mode == 'without_decryption'		  

		    options = {
		        "mutable_content": true,
		        "content_available": true,
		        "priority": "high",
		        "data": {
		            "crypto_key": crypto_key,
		            "salt": salt,
		            "payload": payload,
		            "account": account,
		            "server": server
		        }
		    }

		    Rails.logger.info("DBG:: options: #{options}")


		    puts "THIS IS THE OPTIONS"
		    puts options

		    fcmResponse = fcm.send(registration_ids, options)
		    puts "The FCM RESPONSE:"
		    puts fcmResponse

		    render plain: "success"
		elsif mode == 'with_decryption'
  			payload	        = Base64.urlsafe_encode64(request.raw_post)
			decoded_payload = decode_payload(payload: payload, p256dh: sender_public_key, salt: salt)

			payload_json = JSON.parse(decoded_payload)

			puts payload_json

			Rails.logger.info("DBG:: body of message: #{payload_json}")

			access_token = payload_json["access_token"]
			notification_type = payload_json["notification_type"]
			notification_id = payload_json["notification_id"]
			icon = payload_json["icon"]

			options = {
			    "notification": {
			        # "tag": group_key,
			        "title": payload_json['title'],
			        "body": payload_json['body'],
			    },
			    "priority": "high",
			    "data": {
			        "title": payload_json['title'],
			        "body": payload_json['body'],
			        "icon": payload_json['icon'],
			        "notification_id": payload_json['notification_id'],
			        "notification_type": payload_json['notification_type'],
			        "account": account,
			        "server": server,
			        "click_action": "FLUTTER_NOTIFICATION_CLICK",
			        # "group_key": group_key,
			    },
			    "android": {
			        "collapse_key": payload_json['notification_id'],
			        "notification": {
			            "channel_id": notification_type
			        }
			    },
			    "apns": {
			        "headers": {
			            "apns-collapse-id": payload_json['notification_id'],
			        }
			    },
			}

			Rails.logger.info("DBG:: options: #{options}")


			puts "THIS IS THE OPTIONS"
			puts options

			fcmResponse = fcm.send(registration_ids, options)
			puts "The FCM RESPONSE:"
			puts fcmResponse
			fcmResponseJson = fcmResponse
			# unsubscribe ids which if it is already expired
			fcmResponseJsonNotRegisteredIds = fcmResponseJson[:not_registered_ids]
			if fcmResponseJsonNotRegisteredIds.include?(deviceID)

			  # https
			  unsubscribeUrl = "https://#{server}/api/v1/push/subscription"
			  Rails.logger.info("DBG:: notRegisteredId: #{unsubscribeUrl} #{deviceID}")
			  res = RestClient::Request.execute(method: :delete, url: unsubscribeUrl,
			                                    headers: {Authorization: "Bearer #{access_token}"})
			  Rails.logger.info("DBG:: unsubscribe code: #{res.code}")

			  if res.code != 200
			    # http
			    unsubscribeUrl = "http://#{server}/api/v1/push/subscription"
			    Rails.logger.info("DBG:: notRegisteredId: #{unsubscribeUrl} #{deviceID}")
			    res = RestClient::Request.execute(method: :delete, url: unsubscribeUrl,
			                                      headers: {Authorization: "Bearer #{access_token}"})

			  end

			  Rails.logger.info("DBG:: unsubscribe result: #{res.body}")
			end


			render plain: "success"

		else
			Rails.logger.info("DBG:: invalid mode: #{mode}. Check .env MODE var")
		end 
	end

	def decodeBase64(enc)
		Base64.urlsafe_decode64(enc)
	end

	class String
		def to_hex
		self.unpack("H*").join("")
		end
	end

	def decode_base64(enc)
		Base64.urlsafe_decode64(enc)
	end

	# Simplified HKDF, returning keys up to 32 bytes long
	def hkdf(salt, ikm, info, length)
		raise "Cannot return keys of more than 32 bytes, #{length} requested" if length > 32

		# Extract
		digest = OpenSSL::Digest.new("sha256")
		key_hmac = OpenSSL::HMAC.new(salt, digest)
		key_hmac.update(ikm)
		key = key_hmac.digest()

		# Expand
		info_hmac = OpenSSL::HMAC.new(key, digest)
		info_hmac.update(info)
		# A one byte long buffer containing only 0x01
		one_buffer = [1].pack("C")
		info_hmac.update(one_buffer)

		return info_hmac.digest().slice(0, length)
	end

	def create_info(type, client_public_key, server_public_key)
		# The start index for each element within the buffer is:
		# value               | length | start    |
		# -----------------------------------------
		# 'Content-Encoding: '| 18     | 0        |
		# type                | len    | 18       |
		# nul byte            | 1      | 18 + len |
		# 'P-256'             | 5      | 19 + len |
		# nul byte            | 1      | 24 + len |
		# client key length   | 2      | 25 + len |
		# client key          | 65     | 27 + len |
		# server key length   | 2      | 92 + len |
		# server key          | 65     | 94 + len |
		# For the purposes of push encryption the length of the keys will
		# always be 65 bytes.
		# info = Buffer.alloc(18 + len + 1 + 5 + 1 + 2 + 65 + 2 + 65)
		info = StringIO.new

		# The string 'Content-Encoding: ', as utf-8
		info << "Content-Encoding: "
		# The 'type' of the record, a utf-8 string
		info << type
		# A single null-byte
		info << "\0"
		# The string 'P-256', declaring the elliptic curve being used
		info << "P-256"
		# A single null-byte
		info << "\0"
		# The length of the client's public key as a 16-bit integer
		info << [client_public_key.length].pack("n")
		# Now the actual client public key
		info << client_public_key
		# Length of our public key
		info << [server_public_key.length].pack("n")
		# The key itself
		info << server_public_key

		return info.string
	end

	def decode_payload(payload:, p256dh:, salt:)

		server_auth_secret = decode_base64(ENV.fetch("WITH_DECRYPTION_SERVER_AUTH_SECRET") {"Specify WITH_DECRYPTION_SERVER_AUTH_SECRET in .env var"})
		server_public_key = decode_base64(ENV.fetch("WITH_DECRYPTION_SERVER_PUBLIC_KEY") {"Specify WITH_DECRYPTION_SERVER_PUBLIC_KEY in .env var"})
		server_private_key = decode_base64(ENV.fetch("WITH_DECRYPTION_SERVER_PRIVATE_KEY") {"Specify WITH_DECRYPTION_SERVER_PRIVATE_KEY in .env var"})

		client_salt       = decode_base64(salt)
		client_public_key = decode_base64(p256dh)			

		server_curve = OpenSSL::PKey::EC.generate("prime256v1")
		server_curve.private_key = OpenSSL::BN.new(server_private_key, 2)

		client_point = OpenSSL::PKey::EC::Point.new(server_curve.group, client_public_key)

		shared_secret = server_curve.dh_compute_key(client_point)

		auth_info = "Content-Encoding: auth\0"
		prk = hkdf(server_auth_secret, shared_secret, auth_info, 32)

		# Derive the Content Encryption Key
		content_encryption_key_info = create_info("aesgcm", server_public_key, client_public_key)
		content_encryption_key = hkdf(client_salt, prk, content_encryption_key_info, 16)

		# Derive the Nonce
		nonce_info = create_info("nonce", server_public_key, client_public_key)
		nonce = hkdf(client_salt, prk, nonce_info, 12)

		decipher = OpenSSL::Cipher.new("id-aes128-GCM")
		decipher.key = content_encryption_key
		decipher.iv = nonce

		payload = decode_base64(payload)
		result = decipher.update(payload)

		# remove padding and GCM auth tag
		pad_length = 0
		if result.bytes.length >= 3 && result.bytes[2] == 0
		  pad_length = 2 + result.unpack("n").first
		end
		result = result.byteslice(pad_length, result.bytes.length - 16)

		# NOTE/TODO: The above condition is supposed to strip NUL byte padding, but it never 
		# evaluates to true. I'm putting this in to manually strip any leading NUL bytes until
		# a cleaner solution and/or bug fix can be placed with the code above. /sf
		result.gsub!(/^(\u0000)+/,'')		
		  
		result
	end
end