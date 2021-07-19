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
require "../blockchain/*"
require "../blockchain/domain_model/*"
require "../node/*"
require "../dapps/dapp"
require "../dapps/build_in/hra"

module ::Axentro::Core::Data::Transactions
  def internal_actions_list
    # exclude burn_token as this is used to calculate recipients sum
    DApps::UTXO_ACTIONS.reject(&.==("burn_token")).map { |action| "'#{action}'" }.uniq!.join(",")
  end

  # ------- Definition -------
  def transaction_insert_fields_string
    "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?"
  end

  # ------- Insert -------
  def transaction_insert_values_array(t : Transaction, transaction_idx : Int32, block_index : Int64) : Array(DB::Any)
    ary = [] of DB::Any
    ary << t.id << transaction_idx << block_index << t.action << t.message << t.token << t.prev_hash << t.timestamp << t.scaled << t.kind.to_s << t.version.to_s
  end

  # ------- Query -------
  def get_all_transactions(block_index : Int64)
    transactions_by_query(
      "select * from transactions " \
      "where block_id = ? " \
      "order by idx asc",
      block_index)
  end

  def get_transactions_for_asset(asset_id : String) : Array(AssetVersion)
    transactions = transactions_by_query("select * from transactions 