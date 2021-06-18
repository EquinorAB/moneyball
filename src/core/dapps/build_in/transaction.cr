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

module ::Axentro::Core::DApps::BuildIn
  class TransactionCreator < DApp
    def setup
    end

    def transaction_actions : Array(String)
      [] of String
    end

    def transaction_related?(action : String) : Bool
      false
    end

    def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
      ValidatedTransactions.passed(transactions)
    end

    def record(chain : Blockchain::Chain)
    end

    def clear
    end

    def define_rpc?(call, json, context, params) : HTTP::Server::Context?
      case call
      when "create_unsigned_transaction"
        return create_unsigned_transaction(json, context, params)
      when "create_transaction"
        return create_transaction(json, context, params)
      end

      nil
    end

    def create_unsigned_transaction(json, context, params)
      action = json["action"].as_s
      senders = SendersDecimal.from_json(json["senders"].to_json)
      recipients = RecipientsDecimal.from_json(json["recipients"].to_json)
      assets = Assets.from_json(json["assets"].to_json)
      modules = Modules.from_json(json["modules"].to_json)
      inputs = Inputs.from_json(json["inputs"].to_json)
      outputs = Outputs.from_json(json["outputs"].to_json)
      linked = json["linked"].as_s
      message = json["message"].as_s
      token = json["token"].as_s
      kind = TransactionKind.parse(json["kind"].as_s)
      version = TransactionVersion.parse(json["version"].as_s)

      transaction = create_unsigned_transaction_impl(action, senders, recipients, assets, modules, inputs, outputs, linked, message, token, kind, version)

      context.response.print api_success(transaction)
      context
    end

    def create_sender(amount : String, address : String, public_key : String, fee : String, asset_id : String? = nil, asset_quantity : Int32? = nil) : SendersDecimal
 