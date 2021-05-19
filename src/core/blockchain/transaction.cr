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
       