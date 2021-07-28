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

  MAINNET = {prefix: "M0", name: "mainnet"}
  TESTNET = {prefix: "T0", name: "testnet"}

  class KeyRing
    getter private_key : PrivateKey
    getter public_key : PublicKey
    getter wif : Wif
    getter address : Address
    getter seed : String?

    def initialize(@private_key : PrivateKey, @public_key : PublicKey, @wif : Wif, @address : Address, @seed : String? = nil)
    end

    def self.generate(network : Core::Node::Network = MAINNET)
      key_pair = KeyUtils.create_new_keypair
      private_key = PrivateKey.new(key_pair[:hex_private_key], network)
      public_key = PublicKey.new(key_pair[:hex_public_key], network)
      KeyRing.new(private_key, public_key, private_key.wif, public_key.address)
    end

    def self.generate_hd(seed : String? = nil, derivation : String? = nil, network : Core::Node::Network = MAINNET)
      _seed = seed.nil? ? Random::Secure.random_bytes(64).hexstring : seed.not_nil!
      keys = (derivation.nil? || derivation.not_nil! == "m") ? ED25519::HD::KeyRing.get_master_key_from_seed(_seed) : E