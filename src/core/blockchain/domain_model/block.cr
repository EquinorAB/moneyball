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
module ::Axentro::Core
  alias Chain = Array(Block)

  enum BlockKind
    SLOW
    FAST

    def to_json(j : JSON::Builder)
      j.string(to_s)
    end
  end

  class Block
    extend Hashes

    include JSON::Serializable
    property index : Int64
    property transactions : Array(Transaction)
    property nonce : BlockNonce
    property prev_hash : String
    property merkle_tree_root : String
    property timestamp : Int64
    property difficulty : Int32
    property kind : BlockKind
    property address : String
    property public_key : String
    property signature : String
    property hash : String
    property version : BlockVersion
    property hash_version : HashVersion
    property checkpoint : String
    property mining_version : MiningVersion

    # full
    def initialize(
      @index : Int64,
      @transactions : Array(Transaction),
      @nonce : BlockNonce,
      @prev_hash : String,
      @timestamp : Int64,
      @difficulty : Int32,
      @kind : BlockKind,
      @address : String,
      @public_key : String,
      @signature : String,
      @hash : String,
      @version : BlockVersion,
      @hash_version : HashVersion,
      @merkle_tree_root : String,
      @checkpoint : String,
      @mining_version : MiningVersion
    )
    end

    # slow
    def initialize(
      @index : Int64,
      @transactions : Array(Transaction),
      @nonce : BlockNonce,
      @prev_hash : String,
      @timestamp : Int64,
      @difficulty : Int32,
      @address : String,
      @version : BlockVersion,
      @hash_version : HashVersion,
      @checkpoint : String,
      @mining_version : MiningVersion
    )
      @public_key = ""
      @signature = ""
      @hash = ""
      @kind = BlockKind::SLOW
      if index.odd?
        raise AxentroException.new("index must be even number")
      end

      @merkle_tree_root = calculate_merkle_tree_root(@transactions)
    end

    # fast
    def initialize(
      @index : Int64,
      @transactions : Array(Transaction),
      @prev_hash : String,
      @timestamp : Int64,
      @address : String,
      @public_key : String,
      @signature : String,
      @hash : String,
      @version : BlockVersion,
      @hash_version : HashVersion,
      @checkpoint : String
    )
      @nonce = ""
      @difficulty = 0
      @kind = BlockKind::FAST
      @mining_version = MiningVersion::V1

      if index.even?
        raise AxentroException.new("index must be odd number")
      end

      @merkle_tree_root = calculate_merkle_tree_root(@transactions)
    end

    def to_header : Blockchain::Header
      {
        index:            @index,
        nonce:            @nonce,
        prev_hash:        @prev_hash,
        merkle_tree_root: @merkle_tree_root,
        timestamp:        @timestamp,
        difficulty:       @difficulty,
      }
    end

    def to_hash : String
      string = BlockNoTimestamp.from_block(self).to_json
      argon2(string)
    end

    # for fast block
    def self.to_hash(index : Int64, transactions : Array(Transaction), prev_hash : String, address : String, public_key : String) : String
      string = {index: index, transactions: transactions, prev_hash: prev_hash, address: address, public_key: public_key}.to_json
      sha256(string)
    end

    def ca