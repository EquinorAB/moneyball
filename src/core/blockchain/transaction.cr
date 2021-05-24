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

require "./transaction/models"
require "json_mapping"

module ::Axentro::Core
  class Transaction
    JSON.mapping(
      id: String,
      action: String,
      senders: Array(Sender),
      recipients: Recipients,
      assets: Array(Asset),
      modules: Array(Module),
      inputs: Array(Input),
      outputs: Array(Output),
      linked: String,
      message: String,
      token: String,
      prev_hash: String,
      timestamp: Int64,
      scaled: Int32,
      kind: TransactionKind,
      version: TransactionVersion
    )

    setter prev_hash : String
    @common_validated : Bool = false

    def to_json(j : JSON::Builder)
      sorted_senders = @senders.sort_by { |s| {s.address, s.public_key, s.amount, s.fee, s.signature, s.asset_id || "", s.asset_quantity || 0} }
      sorted_recipients = @recipients.sort_by { |r| {r.address, r.amount, r.asset_id || "", r.asset_quantity || 0} }
      sorted_assets = @assets.sort_by { |a| {a.timestamp, a.asset_id} }
      sorted_modules = @modules.sort_by { |a| {a.timestamp, a.module_id} }
      sorted_inputs = @inputs.sort_by { |a| {a.timestamp, a.input_id} }
      sorted_outputs = @outputs.sort_by { |a| {a.timestamp, a.output_id} }
      j.object do
        j.field("id", @id)
        j.field("action", @action)
        j.field("message", @message)
        j.field("token", @token)
        j.field("prev_hash", @prev_hash)
        j.field("timestamp", @timestamp)
        j.field("scaled", @scaled)
        j.field("kind", @kind)
        j.field("version", @version)
        j.field("senders", sorted_senders)
        j.field("recipients", sorted_recipients)
        j.field("assets", sorted_assets)
        j.field("modules", sorted_modules)
        j.field("inputs", sorted_inputs)
        j.field("outputs", sorted_outputs)
        j.field("linked", @linked)
      end
    end

    def initialize(
      @id : String,
      @action : String,
      @senders : Array(Sender),
      @recipients : Recipients,
      @assets : Array(Asset),
      @modules : Array(Module),
      @inputs : Array(Input),
      @outputs : Array(Output),
      @linked : String,
      @message : String,
      @token : String,
      @prev_hash : String,
      @timestamp : Int64,
      @scaled : Int32,
      @kind : TransactionKind,
      @version : TransactionVersion
    )
    end

    def set_common_validated : Core::Transaction
      @common_validated = true
      self
    end

    def is_common_validated?
      @common_validated
    end

    def is_coinbase?
      @action == "head"
    end

    def add_prev_hash(prev_hash : String) : Transaction
      unless is_coinbase?
        self.prev_hash = prev_hash
      end
      self
    end

    def self.create_id : String
      tmp_id = Random::Secure.hex(32)
      return create_id if tmp_id[0] == "0"
      tmp_id
    end

    def to_hash : String
      string = self.to_json
      sha256(string)
    end

    def short_id : String
      @id[0..7]
    end

    def self.short_id(txn_id) : String
      txn_id[0..7]
    end

    def as_unsigned : Transaction
      unsigned_senders = self.senders.map do |s|
        Sender.new(s.address, s.public_key, s.amount, s.fee, "0", s.asset_id, s.asset_quantity)
      end

      Transaction.new(
        self.id,
        self.action,
        unsigned_senders,
        self.recipients,
        self.assets,
        self.modules,
        self.inputs,
        self.outputs,
        self.linked,
        self.message,
        self.token,
        "0",
        self.timestamp,
        self.scaled,
        self.kind,
        self.version
      )
    end

    def as_signed(wallets : Array(Wallet)) : Transaction
      signed_senders = self.senders.map_with_index {