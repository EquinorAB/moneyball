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

require "./../../spec_helper"

include Axentro::Core
include Axentro::Core::Keys

describe PublicKey do
  describe "#initialize" do
    it "should create a public key object from a public key string" do
      key_pair = KeyUtils.create_new_keypair
      hex_public_key = key_pair[:hex_public_key]

      public_key = PublicKey.new(hex_public_key)
      public_key.as_hex.should eq(hex_public_key)
    end

    it "should raise an error if the public key hex string is not a valid public key" do
      expect_raises(Exception, "invalid public key: 123") do
        PublicKey.new("123")
      end
    end
  end

  describe "#from hex" do
    it "should create a public key object from a public key string" do
      key_pair = KeyUtils.create_new_keypair
      hex_public_key = key_pair[:hex_public_key]

      public_key = PublicKey.from(hex_public_key)
      public_key.as_hex.should eq(hex_public_key)
    end
  end

  describe "#from bytes" do
    it "should create a public key object from a public key byte array" do
      key_pair = KeyUtils.create_new_keypair
      hex_public_key = key_pair[:hex_public_key]
      hexbytes = hex_public_key.hexbytes

      public_key = PublicKey.from(hexbytes)
      public_key.as_bytes.should eq(hexbytes)
      public_key.as_hex.should eq(hex_public_key)
    end
    it "should raise an error if the public key byte array is not a valid public