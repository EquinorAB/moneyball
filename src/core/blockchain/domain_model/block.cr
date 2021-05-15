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
      @timestam