# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

module ::Axentro::Core::Keys
  include Axentro::Core::Hashes

  class KeyUtils
    def self.verify_signature(message, signature_hex, hex_public_key) : Bool
      public_key = Crypto::Ed25519PublicSigningKey.new(hex_public_key)
      signature = Crypto::Ed25519Signature.new(signature_hex)
      signature.check(message, public: public_key)
    rescue e : Exception
      raise Axentro::Common::AxentroException.new("Verify fail: #{e.message}")
    end

    def self.sign(hex_private_key, message) : String
      secret_key = Crypto::SecretKey.new(hex_private_key)
      signature = Crypto::Ed25519Signature.new(message, secret: secret_key)
      signature.to_slice.hexstring
    end

    def self.create_new_keypair
      secret_key = Crypto::SecretKey.new
      {
        hex_private_key: secret_key.to_slice.hexstring,
        hex_public_key:  Crypto::Ed25519PublicSigningKey.new(secret: secret_key).to_slice.hexstring,
      }
    end

    def self.to_hex(bytes : Bytes) : String
      bytes.to_unsafe.to_slice(bytes.size).hexstring
    end

    def self.to_bytes(hex : String) : Bytes
      hex.hexbytes
    e